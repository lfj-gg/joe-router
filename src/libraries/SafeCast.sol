// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title SafeCast
 * @dev Library for safely casting between different integer types.
 */
library SafeCast {
    error SafeCast__Overflow();

    /**
     * @dev Converts a uint256 to int256, reverting on overflow.
     * Requirements:
     * - The input must be less than or equal to type(int256).max.
     */
    function toInt256(uint256 x) internal pure returns (int256) {
        // forge-lint: disable-next-line(unsafe-typecast)
        if (int256(x) >= 0) return int256(x);
        revert SafeCast__Overflow();
    }

    /**
     * @dev Converts an int256 to uint256, reverting on underflow.
     * Requirements:
     * - The input must be greater than or equal to 0.
     */
    function toUint256(int256 x) internal pure returns (uint256) {
        // forge-lint: disable-next-line(unsafe-typecast)
        if (x >= 0) return uint256(x);
        revert SafeCast__Overflow();
    }
}
