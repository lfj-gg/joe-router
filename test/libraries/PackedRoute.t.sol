// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import "../../src/libraries/PackedRoute.sol";

contract PackedRouteTest is Test {
    PackedRouteLib lib;

    function setUp() public {
        lib = new PackedRouteLib();
    }

    function test_Fuzz_Length(uint256 l) public view {
        l = bound(l, 0, 10);

        bytes memory route = new bytes(16 + l * 44);

        assertEq(lib.length(route), l, "test_Fuzz_Length::1");
    }

    function test_Fuzz_Revert_Length(uint256 l) public {
        l = bound(l, 0, 256);

        if (l % 44 == 16) ++l;

        bytes memory route = new bytes(l);
        vm.expectRevert(PackedRoute.PackedRoute__InvalidLength.selector);
        lib.length(route);
    }

    function test_Fuzz_AmountNextPrevious(bytes calldata route) external pure {
        vm.assume(route.length >= 16 + 44);

        (uint256 ptr, uint256 amount) = PackedRoute.start(route);

        assertEq(ptr, 16, "test_Fuzz_AmountNextPrevious::1");
        assertEq(amount, uint128(bytes16(route[0:16])), "test_Fuzz_AmountNextPrevious::2");

        address token;
        address pair;
        uint256 nextPtr;
        uint256 flags;

        for (; ptr + 44 <= route.length; ptr += 44) {
            (nextPtr, pair, token, flags) = PackedRoute.next(route, ptr);

            assertEq(nextPtr, ptr + 44, "test_Fuzz_AmountNextPrevious::3");
            assertEq(pair, address(bytes20(route[ptr:ptr + 20])), "test_Fuzz_AmountNextPrevious::4");
            assertEq(token, address(bytes20(route[ptr + 20:ptr + 40])), "test_Fuzz_AmountNextPrevious::5");
            assertEq(flags, uint32(bytes4(route[ptr + 40:ptr + 44])), "test_Fuzz_AmountNextPrevious::6");
        }

        for (; ptr >= 44;) {
            (nextPtr, pair, token, flags) = PackedRoute.previous(route, ptr);

            assertEq(nextPtr, ptr -= 44, "test_Fuzz_AmountNextPrevious::7");
            assertEq(pair, address(bytes20(route[ptr:ptr + 20])), "test_Fuzz_AmountNextPrevious::8");
            assertEq(token, address(bytes20(route[ptr + 20:ptr + 40])), "test_Fuzz_AmountNextPrevious::9");
            assertEq(flags, uint32(bytes4(route[ptr + 40:ptr + 44])), "test_Fuzz_AmountNextPrevious::10");
        }
    }
}

contract PackedRouteLib {
    function length(bytes calldata route) external pure returns (uint256) {
        return PackedRoute.length(route);
    }
}
