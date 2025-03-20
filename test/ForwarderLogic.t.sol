// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import "../src/ForwarderLogic.sol";
import "../src/RouterAdapter.sol";
import "./mocks/MockERC20.sol";
import "./mocks/MockTaxToken.sol";
import "./PackedRouteHelper.sol";

contract ForwarderLogicTest is Test, PackedRouteHelper {
    ForwarderLogic public forwarderLogic;

    address public token0;
    address public token1;

    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    bytes public revertData;
    bytes public returnData;

    function owner() public view returns (address) {
        return address(this);
    }

    fallback() external {
        address token;
        address from;
        address to;
        uint256 amount;

        assembly ("memory-safe") {
            if and(eq(calldatasize(), 96), iszero(shr(224, calldataload(0)))) {
                token := shr(96, calldataload(4))
                from := shr(96, calldataload(24))
                to := shr(96, calldataload(44))
                amount := calldataload(64)
            }
        }

        if (token != address(0)) {
            IERC20(token).transferFrom(from, to, amount);
        } else {
            bytes memory data = revertData;
            if (data.length > 0) {
                assembly ("memory-safe") {
                    revert(add(data, 32), mload(data))
                }
            }
        }
    }

    function swap(address tokenIn, address tokenOut, uint256 amountIn, uint256 amountOut, address to) public {
        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);
        MockERC20(tokenOut).mint(to, amountOut);
    }

    function setUp() public {
        forwarderLogic = new ForwarderLogic(address(this));

        forwarderLogic.updateTrustedRouter(address(this), true);

        token0 = address(new MockERC20("Token0", "T0", 18));
        token1 = address(new MockERC20("Token1", "T1", 6));

        vm.label(token0, "Token0");
        vm.label(token1, "Token1");
    }

    function test_Constructor() public {
        vm.expectRevert(IForwarderLogic.ForwarderLogic__InvalidRouter.selector);
        new ForwarderLogic(address(0));
    }

    function test_Fuzz_SwapExactIn(bool zeroToOne, uint256 amountIn, uint256 amountOut, address from, address to)
        public
    {
        if (from == address(0) || from == address(this) || from == address(forwarderLogic)) from = address(1);
        if (to == from || to == address(0) || to == address(this) || to == address(forwarderLogic)) to = address(2);

        (address tokenIn, address tokenOut) = zeroToOne ? (token0, token1) : (token1, token0);

        MockERC20(tokenIn).mint(from, amountIn);

        bytes memory data = abi.encodePacked(
            address(this),
            address(this),
            abi.encodeCall(this.swap, (tokenIn, tokenOut, amountIn, amountOut, address(forwarderLogic)))
        );

        vm.prank(from);
        IERC20(tokenIn).approve(address(this), amountIn);

        forwarderLogic.swapExactIn(tokenIn, tokenOut, amountIn, amountOut, from, to, data);

        assertEq(IERC20(tokenIn).balanceOf(address(forwarderLogic)), 0, "test_Fuzz_SwapExactIn::1");
        assertEq(IERC20(tokenIn).balanceOf(from), 0, "test_Fuzz_SwapExactIn::2");
        assertEq(IERC20(tokenIn).balanceOf(to), 0, "test_Fuzz_SwapExactIn::3");
        assertEq(IERC20(tokenIn).balanceOf(address(this)), amountIn, "test_Fuzz_SwapExactIn::4");

        assertEq(IERC20(tokenOut).balanceOf(address(forwarderLogic)), 0, "test_Fuzz_SwapExactIn::5");
        assertEq(IERC20(tokenOut).balanceOf(from), 0, "test_Fuzz_SwapExactIn::6");
        assertEq(IERC20(tokenOut).balanceOf(to), amountOut, "test_Fuzz_SwapExactIn::7");
        assertEq(IERC20(tokenOut).balanceOf(address(this)), 0, "test_Fuzz_SwapExactIn::8");
    }

    function test_Fuzz_Revert_SwapExactIn(address caller) public {
        vm.assume(caller != address(this));

        vm.expectRevert(IForwarderLogic.ForwarderLogic__OnlyRouter.selector);
        vm.prank(caller);
        forwarderLogic.swapExactIn(address(0), address(0), 0, 0, address(0), address(0), "");

        vm.expectRevert();
        forwarderLogic.swapExactIn(token0, address(0), 0, 0, address(0), address(0), new bytes(39));

        vm.expectRevert(IForwarderLogic.ForwarderLogic__UntrustedRouter.selector);
        forwarderLogic.swapExactIn(
            token0, address(0), 0, 0, address(1), address(0), abi.encodePacked(address(1), address(1), "")
        );

        forwarderLogic.updateTrustedRouter(address(0), true);

        vm.expectRevert(IForwarderLogic.ForwarderLogic__NoCode.selector);
        forwarderLogic.swapExactIn(
            token0, address(0), 0, 0, address(1), address(0), abi.encodePacked(address(this), address(0), "")
        );

        revertData = bytes("Error");

        vm.expectRevert("Error");
        forwarderLogic.swapExactIn(
            token0, address(0), 0, 0, address(1), address(0), abi.encodePacked(address(this), address(this), "")
        );
    }

    function test_Revert_SwapExactOut() public {
        vm.expectRevert(IForwarderLogic.ForwarderLogic__NotImplemented.selector);
        forwarderLogic.swapExactOut(address(0), address(0), 0, 0, address(0), address(0), "");
    }

    function test_Sweep() public {
        vm.deal(address(forwarderLogic), 1e18);

        forwarderLogic.sweep(address(0), alice, 1e18);

        assertEq(alice.balance, 1e18, "test_Sweep::1");

        MockERC20(token0).mint(address(forwarderLogic), 1e18);

        forwarderLogic.sweep(token0, alice, 1e18);

        assertEq(IERC20(token0).balanceOf(alice), 1e18, "test_Sweep::2");
    }

    function test_Fuzz_UpdateTrustedRouter(address router) public {
        vm.assume(router != address(this));

        forwarderLogic.updateTrustedRouter(router, true);

        assertEq(forwarderLogic.getTrustedRouterLength(), 2, "test_Fuzz_UpdateTrustedRouter::1");
        assertEq(forwarderLogic.getTrustedRouterAt(0), address(this), "test_Fuzz_UpdateTrustedRouter::2");
        assertEq(forwarderLogic.getTrustedRouterAt(1), router, "test_Fuzz_UpdateTrustedRouter::3");

        forwarderLogic.updateTrustedRouter(router, false);

        assertEq(forwarderLogic.getTrustedRouterLength(), 1, "test_Fuzz_UpdateTrustedRouter::4");
        assertEq(forwarderLogic.getTrustedRouterAt(0), address(this), "test_Fuzz_UpdateTrustedRouter::5");
    }

    function test_Revert_Fuzz_UpdateTrustedRouter(address router) public {
        vm.assume(router != address(this));

        vm.expectRevert(IForwarderLogic.ForwarderLogic__RouterUpdateFailed.selector);
        forwarderLogic.updateTrustedRouter(router, false);

        forwarderLogic.updateTrustedRouter(router, true);

        vm.expectRevert(IForwarderLogic.ForwarderLogic__RouterUpdateFailed.selector);
        forwarderLogic.updateTrustedRouter(router, true);

        vm.expectRevert(IForwarderLogic.ForwarderLogic__OnlyRouterOwner.selector);
        vm.prank(alice);
        forwarderLogic.updateTrustedRouter(router, false);
    }

    function test_Revert_Sweep() public {
        vm.expectRevert(IForwarderLogic.ForwarderLogic__OnlyRouterOwner.selector);
        vm.prank(alice);
        forwarderLogic.sweep(address(0), address(0), 0);
    }

    function test_Fuzz_Blacklist(address user) public {
        assertFalse(forwarderLogic.isBlacklisted(user), "test_Fuzz_Blacklist::1");

        forwarderLogic.updateBlacklist(user, true);

        assertTrue(forwarderLogic.isBlacklisted(user), "test_Fuzz_Blacklist::2");

        vm.expectRevert(IForwarderLogic.ForwarderLogic__Blacklisted.selector);
        forwarderLogic.swapExactIn(address(0), address(0), 0, 0, user, address(0), "");

        forwarderLogic.updateBlacklist(user, false);

        assertFalse(forwarderLogic.isBlacklisted(user), "test_Fuzz_Blacklist::3");
    }
}
