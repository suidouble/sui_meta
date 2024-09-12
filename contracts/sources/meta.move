// contracts/sources/meta.move

module sui_meta::meta {
    use sui::coin;
    use sui::balance;
    
    use sui_meta::icon;
   
    const UNIT: u64 = 1_000_000_000;
    const TOTAL_SUPPLY: u64 = 21_000_000 * UNIT;
    const DECIMALS: u8 = 9;

    public struct META has drop {}

    public struct Treasury has key, store {
        id: UID,
        meta: balance::Balance<META>,
    }

    const ErrTreasuryEmpty: u64 = 1;
    const ErrTreasuryNotEmpty: u64 = 2;

    #[allow(lint(share_owned))]
    /// Create a new coin with the given name, symbol, and initial supply.
    /// Only the admin can call this function.
    fun init(
        witness: META, 
        ctx: &mut TxContext
    ) {
        // Create the new currency
        let (mut treasury_cap, metadata) = coin::create_currency<META>(
            witness,
            DECIMALS, 
            b"META", 
            b"META", 
            b"META", 
            option::some(icon::get_icon_url()), 
            ctx
        );

        let total_mint = coin::into_balance(
            coin::mint(&mut treasury_cap, TOTAL_SUPPLY, ctx)
        );

        transfer::public_transfer(
            treasury_cap,
            sui::object::id_address(&metadata)
        );
        transfer::public_freeze_object(metadata);

        // Initialize the Treasury
        let treasury = Treasury {
            id: object::new(ctx),
            meta: total_mint,
        };
        
        // Share the Treasury object
        transfer::public_share_object(treasury);
    }

    public(package) fun mint(treasury: &mut Treasury, to: address, value: u64, ctx: &mut TxContext) {
        assert!(balance::value(&treasury.meta) > 0, ErrTreasuryEmpty);
        let minted_balance = balance::split<META>(&mut treasury.meta, value);
        let c = coin::from_balance(minted_balance, ctx);
        transfer::public_transfer(c, to);
    }

    public fun decimals(): u8 {
        DECIMALS
    }

    public fun destroy_treasury(treasury: Treasury) {
        assert!(balance::value(&treasury.meta) == 0, ErrTreasuryNotEmpty);
        let Treasury { id, meta } = treasury;
        balance::destroy_zero(meta);
        id.delete();
    }

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(META{}, ctx);
    }
}
