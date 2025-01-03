// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import "../../src/libraries/Flags.sol";

contract FlagsTest is Test {
    function test_Fuzz_ZeroForOne(uint256 flags) public pure {
        assertEq(Flags.zeroForOne(flags), flags & 1 == 1, "test_Fuzz_ZeroForOne::1");
    }

    function test_Fuzz_Callback(uint256 flags) public pure {
        assertEq(Flags.callback(flags), flags & 2 == 2, "test_Fuzz_Callback::1");
    }

    function test_Fuzz_Id(uint256 flags) public pure {
        assertEq(Flags.id(flags), (((flags >> 8) & 0xff) << 8), "test_Fuzz_Id::1");
    }
}
