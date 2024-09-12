// contracts/sources/utils.move

module sui_meta::utils {

    const MAX_U256: u256 = 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;

    // Helper function to adjust value a little to older one ( so we don't get too close to MAX_U256 in any case)
    public fun median_to_max(old_value: u256, new_value: u256): u256 {
        if (new_value > old_value) {
            let diff: u256 = new_value - old_value;
            return (new_value - (diff / 33))
        } else if (new_value < old_value) {
            let diff: u256 = old_value - new_value;
            return (new_value + (diff / 33))

        };

        new_value
    }

    // Adjust difficulty taking into account difference between expected mining time and actual time it took
    public fun adjust_difficulty_by_diff(current_target: u256, expected_time: u256, actual_time: u256): u256 {
        if (expected_time == 0 || actual_time == 0 || actual_time == expected_time) {
            return current_target    // something is wrong with times - do not change anything
        };

        // @todo: what if we are in fantasy world and actual_time >= (MAX_U256 / 100)
        let mut percent: u256 = (actual_time * 100) / (expected_time);
        // percent > 100 - took more time to mine than planned, we need to decrease difficulty, thus increase target to accept nonces
        //                                                                                making target >>>> MAX_U256  ( closer to MAX_U256 )
        //
        // percent < 100 - took less time to mine than planned, we need to increase difficulty, this decrease target to accept nonces
        //                                                                                making target <<<< MAX_U256  ( closer to 0 )

        if (percent > 400) {
            // limiting to 4x target
            percent = 400;
        } else if (percent < 25) {
            // limiting to /4 target
            percent = 25;
        };

        let max_target = 0x0000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;
        // MAX_U256 / (256*256) - MAX_U256 / 65536 - easiest target algo supports, accepts every 65536th nonce

        if (percent > 100 && current_target >= max_target) {
            // let's ignore cases when difficulty is too easy and we'd go to make it easier even more,
            //   so we can just get rid of math we'll never met in real life.
            return current_target
        };

        let mut step = current_target / 100; // shift amount by 1%
        if (step == 0) {
            // too close to 0, making step little large, so the minimum target we can get = 25 * 1 = 25 (that's close to impossible to mine)
            step = 1;
        };

        if (percent <= 100) {
            // we are making target smaller, increasing difficulty
            return (step * percent)
        } else {
            // we are making target larger, decreasing difficulty
            if (percent > MAX_U256 / step) {
                // trying to jump over MAX_U256 and max_target
                return max_target
            };
            let mut adjusted = step * percent;
            if (adjusted > max_target) {
                adjusted = max_target;
            };

            return adjusted
        }
    }
    
    // Helper function to perform exponentiation for u256
    public fun u256_pow(mut base: u256, mut exponent: u8): u256 {
        if (exponent == 0) {
            1
        } else {
            let mut p = 1;
            while (exponent > 1) {
                if (exponent % 2 == 1) {
                    p = p * base;
                };
                exponent = exponent / 2;
                base = base * base;
            };
            p * base
        }
    }

    /// Calculate x / y, but round up the result.
    public fun u256_try_divide_and_round_up(x: u256, y: u256): (bool, u256) {
        if (y == 0) (false, MAX_U256) else (true, u256_div_up(x, y))
    }

    /*
     * @notice It tries to perform `x` * `y` / `z` rounding down.
     *
     * @dev Checks for zero division.
     * @dev Checks for overflow.
     *
     * @param x The first operand.
     * @param y The second operand.
     * @param z The divisor.
     * @return bool. If the operation was successful.
     * @return u256. The result of `x` * `y` / `z`. If it fails, it will be 0.
     */
    public fun u256_try_mul_div_down(x: u256, y: u256, z: u256): u256 {
        if (y == z) {
            return x
        };
        if (x == z) {
            return y
        };

        let a = x / z;
        let b = x % z;
        let c = y / z;
        let d = y % z;
        let res = a * c * z + a * d + b * c + b * d / z;

        res
    }

    /*
     * @notice It tries to perform `x` * `y` / `z` rounding up.
     *
     * @dev Checks for zero division.
     * @dev Checks for overflow.
     *
     * @param x The first operand.
     * @param y The second operand.
     * @param z The divisor.
     * @return bool. If the operation was successful.
     * @return u256. The result of `x` * `y` / `z`. If it fails, it will be 0.
     */
    public fun u256_try_mul_div_up(x: u256, y: u256, z: u256): (bool, u256) {
        if (z == 0) return (false, MAX_U256);
        let (pred, _) = u256_try_mul(x, y);
        if (!pred) return (false, MAX_U256);

        (true, u256_mul_div_up(x, y, z))
    }

    // This function checks for overflow and returns a boolean indicating success
    // and the result of the multiplication. If the multiplication overflows, the
    // result will be 0.
    fun u256_try_mul(x: u256, y: u256): (bool, u256) {
        if (y == 0) return (true, 0);
        if (x > MAX_U256 / y) (false, 0) else (true, x * y)
    }

    fun u256_div_up(x: u256, y: u256): u256 {
        if (x == 0) 0 else 1 + (x - 1) / y
    }

    fun u256_mul_div_down(x: u256, y: u256, z: u256): u256 {
        x * y / z
    }

    /*
     * @notice It performs `x` * `y` / `z` rounding up.
     *
     * @dev It will throw on zero division.
     *
     * @param x The first operand.
     * @param y The second operand.
     * @param z The divisor.
     * @return u256. The result of `x` * `y` / `z`.
     */
    fun u256_mul_div_up(x: u256, y: u256, z: u256): u256 {
        let r = u256_mul_div_down(x, y, z);
        r + if ((x * y) % z > 0) 1 else 0
    }

    /// Convert a vector<u8> to u256
    public fun vector_to_u256(vec: vector<u8>): u256 {
        let mut value = 0u256;
        let mut i = 0;
        while (i < vector::length(&vec)) {
            value = value * 256 + (*vector::borrow(&vec, i) as u256);
            i = i + 1;
        };
        value
    }
}
