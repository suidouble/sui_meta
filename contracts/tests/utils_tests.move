#[test_only]
module sui_meta::utils_tests {
    use sui_meta::utils;

    #[test]
    public fun test_vector_to_u256() {
        let vec: vector<u8> = b"\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x01";
        let value = utils::vector_to_u256(vec);
        assert!(value == 1u256, 1);

        let vec: vector<u8> = b"\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00";
        let value = utils::vector_to_u256(vec);
        assert!(value == 452312848583266388373324160190187140051835877600158453279131187530910662656u256, 2);
    }
}
