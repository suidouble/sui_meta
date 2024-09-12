#[test_only]
module sui_meta::mining_tests {
    use sui::clock;
    use sui::random;
    use sui::test_scenario;

    use sui_meta::meta;
    use sui_meta::mining;

    #[test]
    public fun test_init_genesis() {
        // Create a new transaction context
        let mut ctx = tx_context::dummy();
    
        // Create a new clock object for testing
        let mut clock = clock::create_for_testing(&mut ctx);
        clock::set_for_testing(&mut clock, 1000);

        // Retrieve the BlockStore object
        let mut block_store = mining::create_for_testing(&mut ctx, 0x00ffff0000000000000000000000000000000000000000000000000000);

        // Initialize the genesis block
        mining::init_genesis(&clock, &mut block_store, &mut ctx);

        // Check if BlockStore is initialized successfully
        assert!(mining::get_current_height(&block_store) == 1, 0);

        // Check if the genesis block exists using get_block_by_height
        let genesis_block = mining::borrow_block_by_height(&block_store, 0);

        assert!(mining::get_block_previous_hash(genesis_block) == b"genesis_previous_hash", 1);
        assert!(mining::get_block_salt(genesis_block) == 0, 2);
        assert!(mining::get_block_meta(genesis_block) == vector::empty(), 3);
        assert!(mining::get_block_payload(genesis_block) == b"initial_merkle_root", 4);
        assert!(mining::get_block_target(genesis_block) == 0x00ffff0000000000000000000000000000000000000000000000000000, 5);
        assert!(mining::get_block_nonce(genesis_block) == 0, 6);
        assert!(mining::get_block_hash(genesis_block) == b"genesis_hash", 7);

        // Destroy the BlockStore object after testing
        mining::destroy_for_testing(block_store);

        // Destroy the clock object after testing
        clock::destroy_for_testing(clock);
    }

    #[test]
    public fun test_mint_normal() {
        let mut scenario = test_scenario::begin(@0x0);

        // Create a new transaction context
        let mut ctx = tx_context::dummy();
    
        // Create a new clock object for testing
        let mut clock = clock::create_for_testing(&mut ctx);
        clock::set_for_testing(&mut clock, 1000);

        // Create Random
        random::create_for_testing(scenario.ctx());
        meta::init_for_testing(&mut ctx);
        scenario.next_tx(@0x0);

        let random_state = scenario.take_shared<random::Random>();

        // init target
        let init_target = 0x00ffff0000000000000000000000000000000000000000000000000000;

        // Retrieve the BlockStore object
        let mut block_store = mining::create_for_testing(&mut ctx, init_target);

        // Initialize the genesis block
        mining::init_genesis(&clock, &mut block_store, &mut ctx);

        // Check if the target is still the initial target before triggering adjust_difficulty
        assert!(mining::get_current_target(&block_store) == init_target, 0);

        // Create a new Treasury object for testing
        let mut treasury = test_scenario::take_shared<meta::Treasury>(&scenario);

        // Mint 2015 blocks (one less than ADJUST_DIFFICULTY_EACH_HEIGHT)
        let miner_address = @1234;
        let meta = b"";
        let payload = b"";
        let mut i = 0;
        while (i < 4040) {
            scenario.next_tx(@0x0);

            mining::mint_for_testing(&clock, &random_state, &mut block_store, &mut treasury, meta, payload, 0, miner_address, &mut ctx);
            clock::increment_for_testing(&mut clock, 10000); // Increment clock by 10 minutes for each block
            i = i + 1;
        };

        // Check if the target is still the initial target before triggering adjust_difficulty
        assert!(mining::get_current_target(&block_store) != mining::get_initial_target(), 1);

        // Destroy the BlockStore object after testing
        mining::destroy_for_testing(block_store);

        // Destroy the clock object after testing
        clock::destroy_for_testing(clock);

        test_scenario::return_shared(random_state);
        test_scenario::return_shared(treasury);
        scenario.end();
    }

    #[test]
    public fun test_mint_with_big_difficulty() {
        let mut scenario = test_scenario::begin(@0x0);

        // Create a new transaction context
        let mut ctx = tx_context::dummy();
    
        // Create a new clock object for testing
        let mut clock = clock::create_for_testing(&mut ctx);
        clock::set_for_testing(&mut clock, 1000);

        // Create Random
        random::create_for_testing(scenario.ctx());
        meta::init_for_testing(&mut ctx);
        scenario.next_tx(@0x0);

        let random_state = scenario.take_shared<random::Random>();

        // init target
        let init_target = 0xffff0000000000000000000000000000000000000000000000000000000000;

        // Retrieve the BlockStore object
        let mut block_store = mining::create_for_testing(&mut ctx, init_target);

        // Initialize the genesis block
        mining::init_genesis(&clock, &mut block_store, &mut ctx);

        // Check if the target is still the initial target before triggering adjust_difficulty
        assert!(mining::get_current_target(&block_store) == init_target, 0);

        // Create a new Treasury object for testing
        let mut treasury = test_scenario::take_shared<meta::Treasury>(&scenario);

        // Mint 2015 blocks (one less than ADJUST_DIFFICULTY_EACH_HEIGHT)
        let miner_address = @1234;
        let meta = b"";
        let payload = b"";
        let mut i = 0;
        while (i < 2017) {
            scenario.next_tx(@0x0);

            mining::mint_for_testing(&clock, &random_state, &mut block_store, &mut treasury, meta, payload, 0, miner_address, &mut ctx);
            clock::increment_for_testing(&mut clock, 10000); // Increment clock by 10 minutes for each block
            i = i + 1;
        };

        // Check if the target is still the initial target before triggering adjust_difficulty
        assert!(mining::get_current_target(&block_store) != mining::get_initial_target(), 1);

        // Destroy the BlockStore object after testing
        mining::destroy_for_testing(block_store);

        // Destroy the clock object after testing
        clock::destroy_for_testing(clock);

        test_scenario::return_shared(random_state);
        test_scenario::return_shared(treasury);
        scenario.end();
    }

    #[test]
    public fun test_mint_with_small_interval() {
        let mut scenario = test_scenario::begin(@0x0);

        // Create a new transaction context
        let mut ctx = tx_context::dummy();
    
        // Create a new clock object for testing
        let mut clock = clock::create_for_testing(&mut ctx);
        clock::set_for_testing(&mut clock, 1000);

        // Create Random
        random::create_for_testing(scenario.ctx());
        meta::init_for_testing(&mut ctx);
        scenario.next_tx(@0x0);

        let random_state = scenario.take_shared<random::Random>();

        // init target
        let init_target = 0xffff0000000000000000000000000000000000000000000000000000000000;

        // Retrieve the BlockStore object
        let mut block_store = mining::create_for_testing(&mut ctx, init_target);

        // Initialize the genesis block
        mining::init_genesis(&clock, &mut block_store, &mut ctx);

        // Check if the target is still the initial target before triggering adjust_difficulty
        assert!(mining::get_current_target(&block_store) == init_target, 0);

        // Create a new Treasury object for testing
        let mut treasury = test_scenario::take_shared<meta::Treasury>(&scenario);

        // Mint 2015 blocks (one less than ADJUST_DIFFICULTY_EACH_HEIGHT)
        let miner_address = @1234;
        let meta = b"";
        let payload = b"";
        let mut i = 0;
        while (i < 2017) {
            scenario.next_tx(@0x0);

            mining::mint_for_testing(&clock, &random_state, &mut block_store, &mut treasury, meta, payload, 0, miner_address, &mut ctx);
            clock::increment_for_testing(&mut clock, 1);
            i = i + 1;
        };

        // Check if the target is still the initial target before triggering adjust_difficulty
        assert!(mining::get_current_target(&block_store) != mining::get_initial_target(), 1);

        // Destroy the BlockStore object after testing
        mining::destroy_for_testing(block_store);

        // Destroy the clock object after testing
        clock::destroy_for_testing(clock);

        test_scenario::return_shared(random_state);
        test_scenario::return_shared(treasury);
        scenario.end();
    }

    #[test]
    public fun test_mint_with_big_interval() {
        let mut scenario = test_scenario::begin(@0x0);

        // Create a new transaction context
        let mut ctx = tx_context::dummy();
    
        // Create a new clock object for testing
        let mut clock = clock::create_for_testing(&mut ctx);
        clock::set_for_testing(&mut clock, 1000);

        // Create Random
        random::create_for_testing(scenario.ctx());
        meta::init_for_testing(&mut ctx);
        scenario.next_tx(@0x0);

        let random_state = scenario.take_shared<random::Random>();

        // init target
        let init_target = 0xffff0000000000000000000000000000000000000000000000000000000000;

        // Retrieve the BlockStore object
        let mut block_store = mining::create_for_testing(&mut ctx, init_target);

        // Initialize the genesis block
        mining::init_genesis(&clock, &mut block_store, &mut ctx);

        // Check if the target is still the initial target before triggering adjust_difficulty
        assert!(mining::get_current_target(&block_store) == init_target, 0);

        // Create a new Treasury object for testing
        let mut treasury = test_scenario::take_shared<meta::Treasury>(&scenario);

        // Mint 2015 blocks (one less than ADJUST_DIFFICULTY_EACH_HEIGHT)
        let miner_address = @1234;
        let meta = b"";
        let payload = b"";
        let mut i = 0;
        while (i < 2017) {
            scenario.next_tx(@0x0);

            mining::mint_for_testing(&clock, &random_state, &mut block_store, &mut treasury, meta, payload, 0, miner_address, &mut ctx);
            clock::increment_for_testing(&mut clock, 600000*2016*1000);
            i = i + 1;
        };

        // Check if the target is still the initial target before triggering adjust_difficulty
        assert!(mining::get_current_target(&block_store) != mining::get_initial_target(), 1);

        // Destroy the BlockStore object after testing
        mining::destroy_for_testing(block_store);

        // Destroy the clock object after testing
        clock::destroy_for_testing(clock);

        test_scenario::return_shared(random_state);
        test_scenario::return_shared(treasury);
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = mining::ERR_INVALID_NONCE)]
    public fun test_mint_invalid_nonce() {
        let mut scenario = test_scenario::begin(@0x0);

        // Create a new transaction context
        let mut ctx = tx_context::dummy();
        
        // Create a new clock object for testing
        let mut clock = clock::create_for_testing(&mut ctx);
        clock::set_for_testing(&mut clock, 1000);

        // Create Random
        random::create_for_testing(scenario.ctx());
        meta::init_for_testing(&mut ctx);
        scenario.next_tx(@0x0);

        let random_state = scenario.take_shared<random::Random>();

        // Retrieve the BlockStore object
        let mut block_store = mining::create_for_testing(&mut ctx, 0x00ffff0000000000000000000000000000000000000000000000000000);

        // Initialize the genesis block
        mining::init_genesis(&clock, &mut block_store, &mut ctx);

        // Create a new Treasury object for testing
        let mut treasury = test_scenario::take_shared<meta::Treasury>(&scenario);

        // Mint a block with an invalid nonce (this should fail)
        let miner_address = @1234;
        let meta = b"";
        let payload = b"";
        mining::mint(&clock, &random_state, &mut block_store, &mut treasury, meta, payload, 12345, miner_address, &mut ctx);

        // Destroy the BlockStore object after testing
        mining::destroy_for_testing(block_store);

        // Destroy the clock object after testing
        clock::destroy_for_testing(clock);

        test_scenario::return_shared(random_state);
        test_scenario::return_shared(treasury);
        scenario.end();
    }

    #[test]
    public fun test_is_valid_hash() {
        let target: u256 = 0x00ffff0000000000000000000000000000000000000000000000000000;
        let valid_hash: vector<u8> = b"\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x01";
        let invalid_hash: vector<u8> = b"\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00";

        assert!(mining::is_valid_hash(valid_hash, target), 1);
        assert!(!mining::is_valid_hash(invalid_hash, target), 2);
    }
}
