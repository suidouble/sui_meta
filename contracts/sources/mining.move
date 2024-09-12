// contracts/sources/mining.move

module sui_meta::mining {
    use sui::table;
    use sui::hash;
    use sui::clock;
    use sui::bcs;
    use sui::event;
    use sui::random;

    use sui_meta::meta;
    use sui_meta::utils;

    const INITIAL_TARGET: u256 = 0x000002fab811955af6e8a71f4faed271190fb743cf9612e3908f96d7a6979cb6;
    const ADJUST_TARGET_EACH_HEIGHT: u64 = 256;
    const TARGET_BLOCK_MINING_TIME_MS: u64 = 600000; // try to adjust difficulty so next blocks would be mined in this time, 10 minutes

    const ERR_INVALID_NONCE: u64 = 1;
    const ERR_INVALID_META_SIZE: u64 = 2;
    const ERR_INVALID_PAYLOAD_SIZE: u64 = 3;

    #[allow(unused_field)]
    /// Define the structure for a Block
    public struct Block has key, store {
        id: UID,
        previous_hash: vector<u8>,
        salt: u64,
        meta: vector<u8>,
        payload: vector<u8>,
        timestamp: u64,
        target: u256,
        nonce: u64,
        miner: address,
        hash: vector<u8>,
    }

    #[allow(unused_field)]
    /// Define the structure for BlockInfo
    public struct BlockInfo has store {
        previous_hash: vector<u8>,
        salt: u64,
        target: u256,
    }
 
    /// Define the structure for BlockStore
    public struct BlockStore has key, store {
        id: UID,
        blocks: table::Table<u64, Block>,
        current_height: u64,
        current_salt: u64,
        current_target: u256,
    }

    // New block event
    public struct BlockMinted has copy, drop {
        block_id: ID,
        height: u64,
    }

    // Difficulty adjusted event
    public struct DifficultyAdjusted has copy, drop {
        height: u64,
        target: u256,
        previous_time: u64,
        previous_target: u256,
    }

    public fun get_initial_target(): u256 {
        INITIAL_TARGET
    }

    /// Get the current height of the BlockStore
    public fun get_current_height(block_store: &BlockStore): u64 {
        block_store.current_height
    }

    /// Get the current salt from the BlockStore
    fun get_current_salt(block_store: &BlockStore): u64 {
        block_store.current_salt
    }

    /// Get the current target from the BlockStore
    public fun get_current_target(block_store: &BlockStore): u256 {
        block_store.current_target
    }

    /// Get the previous hash of the Block
    public fun get_block_previous_hash(block: &Block): vector<u8> {
        block.previous_hash
    }

     /// Get the salt of the Block
    public fun get_block_salt(block: &Block): u64 {
        block.salt
    }

    /// Get the meta of the Block
    public fun get_block_meta(block: &Block): vector<u8> {
        block.meta
    }

    /// Get the payload of the Block
    public fun get_block_payload(block: &Block): vector<u8> {
        block.payload
    }

    /// Get the target of the Block
    public fun get_block_target(block: &Block): u256 {
        block.target
    }

    /// Get the nonce of the Block
    public fun get_block_nonce(block: &Block): u64 {
        block.nonce
    }

    /// Get the hash of the Block
    public fun get_block_hash(block: &Block): vector<u8> {
        block.hash
    }

    /// Initialize the BlockStore
    fun init(ctx: &mut TxContext) {
        // Create a new table for blocks
        let blocks = table::new<u64, Block>(ctx);
        
        // Initialize the BlockStore
        let block_store = BlockStore {
            id: object::new(ctx),
            blocks: blocks,
            current_height: 0,
            current_salt: 0,
            current_target: INITIAL_TARGET,
        };
        
        // Share the BlockStore object
        transfer::public_share_object(block_store);
    
        // emit new DifficultyAdjusted event
        event::emit(DifficultyAdjusted { 
            height: 0,
            target: INITIAL_TARGET,
            previous_time: 0,
            previous_target: INITIAL_TARGET,
        });
    }

    #[test_only]
    /// Create a BlockStore for testing
    public fun create_for_testing(ctx: &mut TxContext, init_target: u256): BlockStore {
        let blocks = table::new<u64, Block>(ctx);
        BlockStore {
            id: object::new(ctx),
            blocks: blocks,
            current_height: 0,
            current_salt: 0,
            current_target: init_target,
        }
    }

    #[test_only]
    /// Destroy a BlockStore for testing
    public fun destroy_block(block: Block) {
        let Block { id, previous_hash:_, salt:_, meta:_, payload:_, timestamp: _, target: _, nonce:_, miner:_, hash:_, } = block;
        
        // Delete the BlockStore ID
        id.delete();
    }

    #[test_only]
    /// Destroy a BlockStore for testing
    public fun destroy_for_testing(block_store: BlockStore) {
        let BlockStore { id, mut blocks, current_height, current_salt:_, current_target:_ } = block_store;
        
        // Iterate over the blocks and destroy each one
        let mut i = 0;
        while (i < current_height) {
            let block = table::remove(&mut blocks, i);
            destroy_block(block);
            i = i + 1;
        };
        
        // Destroy the table
        table::destroy_empty(blocks);
        
        // Delete the BlockStore ID
        id.delete();
    }

    /// Initialize the genesis block
    public entry fun init_genesis(clock: &clock::Clock, block_store: &mut BlockStore, ctx: &mut TxContext) {
        // Ensure the genesis block is not already initialized
        assert!(block_store.current_height == 0, 1);

        let initial_payload = b"initial_merkle_root";
        let genesis_block = Block {
            id: object::new(ctx),
            previous_hash: b"genesis_previous_hash",
            salt: 0,
            meta: vector::empty(),
            payload: initial_payload,
            timestamp: clock::timestamp_ms(clock),
            target: block_store.current_target,
            nonce: 0,
            miner: ctx.sender(),
            hash: b"genesis_hash",
        };
        table::add(&mut block_store.blocks, 0, genesis_block);

        // Mark the genesis block as initialized
        block_store.current_height = 1;
    }

    /// Get the current block information for mining.
    /// Any miner can call this function.
    public fun get_block_info(block_store: &BlockStore): BlockInfo {
        // Return the basic information of the current block for miners to use
        let previous_hash = get_previous_hash(block_store);
        let salt = get_current_salt(block_store);
        let target = get_current_target(block_store);
        
        return BlockInfo {
            previous_hash: previous_hash,
            salt: salt,
            target: target,
        }
    }
   
    fun mint_internal(
        c: &clock::Clock,
        r: &random::Random,
        block_store: &mut BlockStore, 
        treasury: &mut meta::Treasury, 
        meta: vector<u8>,
        payload: vector<u8>,
        nonce: u64,
        miner_address: address, 
        validate_nonce: bool,
        ctx: &mut TxContext
    ) {
        // Limit meta size to 4KB
        assert!(vector::length(&meta) <= 4096, ERR_INVALID_META_SIZE);

        // Limit payload size to 4MB
        assert!(vector::length(&payload) <= 4194304, ERR_INVALID_PAYLOAD_SIZE);

        let BlockInfo{previous_hash, salt, target} = get_block_info(block_store);

        let mut buf = vector::empty();
        buf.append(previous_hash);
        buf.append(bcs::to_bytes(&salt));
        buf.append(meta);
        buf.append(payload);
        let tmp_hash = hash::keccak256(&buf);

        let mut final_buf = vector::empty();
        final_buf.append(tmp_hash);
        final_buf.append(bcs::to_bytes(&nonce));
        let new_hash = hash::keccak256(&final_buf);

        if (validate_nonce) {
            assert!(is_valid_hash(new_hash, target), ERR_INVALID_NONCE);
        };
        
        let new_block = Block {
            id: object::new(ctx),
            previous_hash: previous_hash,
            salt: salt,
            meta: meta,
            payload: payload,
            timestamp: clock::timestamp_ms(c),
            target: target,
            nonce: nonce,
            miner: miner_address,
            hash: new_hash,
        };

        // emit new block event
        event::emit(BlockMinted { 
            block_id: object::uid_to_inner(&new_block.id),
            height: block_store.current_height,
        });

        // Save the new block
        table::add(&mut block_store.blocks, block_store.current_height, new_block);
        block_store.current_height = block_store.current_height + 1;

        // Distribute mine reward
        distribute_reward(block_store, treasury, miner_address, ctx);
    
        // Update difficulty
        adjust_difficulty(block_store);

        // Update next block salt
        update_next_block_salt(block_store, r, ctx);
    }
    
    /// Mint a new block by submitting a valid nonce.
    /// Any miner can call this function.
    entry fun mint(
        c: &clock::Clock,
        r: &random::Random,
        block_store: &mut BlockStore, 
        treasury: &mut meta::Treasury, 
        meta: vector<u8>,
        payload: vector<u8>,
        nonce: u64,
        miner_address: address,
        ctx: &mut TxContext
    ) {
        mint_internal(c, r, block_store, treasury, meta, payload, nonce, miner_address, true, ctx)
    }

    #[test_only]
    /// Mint a new block for testing purposes without nonce validation.
    public fun mint_for_testing(
        c: &clock::Clock,
        r: &random::Random,
        block_store: &mut BlockStore, 
        treasury: &mut meta::Treasury, 
        meta: vector<u8>,
        payload: vector<u8>,
        nonce: u64,
        miner_address: address, 
        ctx: &mut TxContext
    ) {
        mint_internal(c, r, block_store, treasury, meta, payload, nonce, miner_address, false, ctx)
    }

    public fun is_valid_hash(hash: vector<u8>, target: u256): bool {
        let hash_value = utils::vector_to_u256(hash);
        hash_value <= target
    }
    
    fun adjust_difficulty(block_store: &mut BlockStore) {
        // Adjust difficulty every 2016 blocks
        if (block_store.current_height % ADJUST_TARGET_EACH_HEIGHT == 0) { 
            let last_height = block_store.current_height - ADJUST_TARGET_EACH_HEIGHT;
            // Calculate the total time spent mining the last 2016 blocks
            let total_time = table::borrow(&block_store.blocks, block_store.current_height - 1).timestamp - table::borrow(&block_store.blocks, last_height).timestamp;
            // Target time for 2016 blocks (10 minutes per block in seconds)
            let target_time: u256 = (ADJUST_TARGET_EACH_HEIGHT as u256) * (TARGET_BLOCK_MINING_TIME_MS as u256); // ms
            let previous_target = block_store.current_target;

            let mut new_target = utils::adjust_difficulty_by_diff(block_store.current_target, target_time, total_time as u256);

            // if difficulty goes too high, adjust it to the median
            new_target = utils::median_to_max(block_store.current_target, new_target);
            
            block_store.current_target = new_target;

            let (_, average_time) = utils::u256_try_divide_and_round_up(total_time as u256, ADJUST_TARGET_EACH_HEIGHT as u256);

            // emit new DifficultyAdjusted event
            event::emit(DifficultyAdjusted { 
                height: block_store.current_height,
                target: block_store.current_target,
                previous_time: average_time as u64,
                previous_target
            });
        }
    }

    fun distribute_reward(block_store: &BlockStore, treasury: &mut meta::Treasury, miner_address: address, ctx: &mut TxContext) {
        let block_height = block_store.current_height;
        let halvings = block_height / 210000;
        
        // 50.00 on the start
        // 25.00 after the first halving
        // 12.50 after the second
        // .. etc
        let reward = utils::u256_try_mul_div_down(
            50u256,
            utils::u256_pow(10, meta::decimals()),
            utils::u256_pow(2, halvings as u8)
        );

        meta::mint(treasury, miner_address, reward as u64, ctx);
    }

    /// Generates a new random salt for the next block and updates the `current_salt` in the `BlockStore`.
    fun update_next_block_salt(block_store: &mut BlockStore, r: &random::Random, ctx: &mut TxContext) {
        let mut generator = random::new_generator(r, ctx);

        // Generate a new salt using a random number and update the global salt
        let salt = random::generate_u64(&mut generator);
        block_store.current_salt = salt;
    }

    /// Get the previous hash from the BlockStore
    fun get_previous_hash(block_store: &BlockStore): vector<u8> {
        if (block_store.current_height == 0) {
            return vector::empty()
        };

        let previous_block = borrow_block_by_height(block_store, block_store.current_height - 1);
        previous_block.hash
    }

    /// Borrow a block by its height
    public fun borrow_block_by_height(block_store: &BlockStore, height: u64): &Block {
        table::borrow(&block_store.blocks, height)
    }
}
