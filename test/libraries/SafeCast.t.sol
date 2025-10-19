// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";

import {SafeCast} from "../../src/libraries/SafeCast.sol";

contract SafeCastTest is Test {
    function test_Fuzz_ToInt256(uint256 x) public pure {
        x = bound(x, 0, uint256(type(int256).max));
        int256 y = SafeCast.toInt256(x);
        assertEq(uint256(y), x, "test_Fuzz_ToInt256::1");
    }

    function test_Fuzz_Revert_ToInt256(uint256 x) public {
        x = bound(x, uint256(type(int256).max) + 1, type(uint256).max);
        vm.expectRevert(SafeCast.SafeCast__Overflow.selector);
        this.toInt256(x);
    }

    function test_Fuzz_ToUint256(int256 x) public pure {
        x = int256(bound(uint256(x), 0, uint256(type(int256).max)));
        uint256 y = SafeCast.toUint256(x);
        assertEq(int256(y), x, "test_Fuzz_ToUint256::1");
    }

    function test_Fuzz_Revert_ToUint256(int256 x) public {
        x = int256(bound(x, type(int256).min, -1));
        vm.expectRevert(SafeCast.SafeCast__Overflow.selector);
        this.toUint256(x);
    }

    // Helper functions

    function toInt256(uint256 x) external pure returns (int256) {
        return SafeCast.toInt256(x);
    }

    function toUint256(int256 x) external pure returns (uint256) {
        return SafeCast.toUint256(x);
    }
}
