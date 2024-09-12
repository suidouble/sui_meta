#[test_only]
module sui_meta::btc_tests {
    use sui_meta::meta;

    #[test]
    public fun test_init_for_testing() {
        // Create a new transaction context
        let mut ctx = tx_context::dummy();

        meta::init_for_testing(&mut ctx);
    }
}
