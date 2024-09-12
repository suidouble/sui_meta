#[test_only]
module sui_meta::adjust_difficulty_tests {
    use sui_meta::utils;

    // use std::debug;


    #[test]
    public fun adjust_difficulty_by_diff() {
        // let max_u256: u256 = 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;
        let easiest_target: u256 = 0x0000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;
        // we do not let target goes higher that max_u256 / (256^2), means, accepting each 65536th random nonce
        
        let current_target: u256 = easiest_target; // easiest  possible
        let adjusted_target = utils::adjust_difficulty_by_diff(current_target, 1000, 20000); // 1 second, took 20 seconds
        // debug::print(&current_target); debug::print(&adjusted_target);
        assert!(adjusted_target == current_target, 1); // can not get any easier


        let current_target = easiest_target / 2; // 2x smaller target, 2x harder to mine
        let adjusted_target = utils::adjust_difficulty_by_diff(current_target, 1000, 20000); // 1 second, took 20 seconds
        // debug::print(&current_target); debug::print(&adjusted_target);
        assert!(adjusted_target == easiest_target, 1); // still at easiest ( * 2 , not * 4 )

        let mut dyn_target: u256 = easiest_target / 10; // accepting every 655360th nonce
        while (dyn_target > 0xffff) {
            // try many steps while going from very easy to very hard mining
            let adjusted = utils::adjust_difficulty_by_diff(dyn_target, 11000, 10000); // expected 11 seconds, took 10 seconds
            assert!(adjusted < dyn_target, 1); // difficulty increased
            let adjusted = utils::adjust_difficulty_by_diff(dyn_target, 10000, 1); // expected 10 seconds, took 1ms
            assert!(adjusted < dyn_target, 1); // difficulty increased



            let adjusted = utils::adjust_difficulty_by_diff(dyn_target, 10000, 11000); // expected 10 seconds, took 11 seconds
            assert!(adjusted > dyn_target, 1); // difficulty decreased
            let adjusted = utils::adjust_difficulty_by_diff(dyn_target, 1, 10000); // expected 1 ms, took 10 seconds
            assert!(adjusted > dyn_target, 1); // difficulty increased

            dyn_target = (dyn_target / 10) * 6;
        };


    }

}
