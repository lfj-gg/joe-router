// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import "../src/ForwarderLogic.sol";
import "../src/RouterAdapter.sol";
import "../src/interfaces/IFeeAdapter.sol";
import "./PackedRouteHelper.sol";
import "./mocks/MockERC20.sol";
import "./mocks/MockTaxToken.sol";

contract ForwarderLogicTest is Test, PackedRouteHelper {
    ForwarderLogic public forwarderLogic;

    address public token0;
    address public token1;

    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address feeReceiver = makeAddr("feeReceiver");
    address thirdPartyFeeReceiver = makeAddr("thirdPartyFeeReceiver");

    bytes public revertData;
    bytes public returnData;

    uint16 FEE_BIPS = 0.15e4; // 15%

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

    function setUp() public virtual {
        forwarderLogic = new ForwarderLogic(address(this), feeReceiver, FEE_BIPS);

        forwarderLogic.updateTrustedRouter(address(this), true);

        token0 = address(new MockERC20("Token0", "T0", 18));
        token1 = address(new MockERC20("Token1", "T1", 6));

        vm.label(token0, "Token0");
        vm.label(token1, "Token1");
    }

    function test_Constructor() public {
        vm.expectRevert(IForwarderLogic.ForwarderLogic__InvalidRouter.selector);
        new ForwarderLogic(address(0), feeReceiver, 0);

        vm.expectRevert(IFeeAdapter.FeeAdapter__InvalidProtocolFeeReceiver.selector);
        new ForwarderLogic(address(this), address(0), 0);

        vm.expectRevert(IFeeAdapter.FeeAdapter__InvalidProtocolFeeShare.selector);
        new ForwarderLogic(address(this), address(1), 10_001);
    }

    function test_Fuzz_SwapExactIn(bool zeroToOne, uint256 amountIn, uint256 amountOut, address from, address to)
        public
    {
        if (from == address(0) || from == address(this) || from == address(forwarderLogic)) from = address(1);
        if (to == address(0) || to == address(this) || to == address(forwarderLogic)) to = address(2);
        if (from == to) {
            from = address(1);
            to = address(2);
        }

        amountIn = bound(amountIn, 0, type(uint256).max - 1);

        (address tokenIn, address tokenOut) = zeroToOne ? (token0, token1) : (token1, token0);

        MockERC20(tokenIn).mint(from, amountIn);

        bytes memory data = abi.encodePacked(
            address(this),
            address(this),
            uint16(0),
            abi.encodeCall(this.swap, (tokenIn, tokenOut, amountIn, amountOut, address(forwarderLogic)))
        );

        vm.prank(from);
        IERC20(tokenIn).approve(address(this), amountIn);

        forwarderLogic.swapExactIn(tokenIn, tokenOut, amountIn, 0, from, to, data);

        assertEq(IERC20(tokenIn).balanceOf(address(forwarderLogic)), 0, "test_Fuzz_SwapExactIn::1");
        assertEq(IERC20(tokenIn).balanceOf(from), 0, "test_Fuzz_SwapExactIn::2");
        assertEq(IERC20(tokenIn).balanceOf(to), 0, "test_Fuzz_SwapExactIn::3");
        assertEq(IERC20(tokenIn).balanceOf(address(this)), amountIn, "test_Fuzz_SwapExactIn::4");

        assertEq(IERC20(tokenOut).balanceOf(address(forwarderLogic)), 0, "test_Fuzz_SwapExactIn::5");
        assertEq(IERC20(tokenOut).balanceOf(from), 0, "test_Fuzz_SwapExactIn::6");
        assertEq(IERC20(tokenOut).balanceOf(to), amountOut, "test_Fuzz_SwapExactIn::7");
        assertEq(IERC20(tokenOut).balanceOf(address(this)), 0, "test_Fuzz_SwapExactIn::8");
    }

    function test_Fuzz_SwapExactInWithFeeIn(
        bool zeroToOne,
        uint256 amountIn,
        uint256 feePercent,
        uint256 amountOut,
        address from,
        address to
    ) public {
        if (
            from == address(0) || from == address(this) || from == address(forwarderLogic) || from == feeReceiver
                || from == thirdPartyFeeReceiver
        ) {
            from = address(1);
        }
        if (
            to == address(0) || to == address(this) || to == address(forwarderLogic) || to == feeReceiver
                || to == thirdPartyFeeReceiver
        ) {
            to = address(2);
        }
        if (from == to) {
            from = address(1);
            to = address(2);
        }

        amountIn = bound(amountIn, 1, type(uint256).max / 10_000);
        feePercent = bound(feePercent, 0, 10_000);

        (address tokenIn, address tokenOut) = zeroToOne ? (token0, token1) : (token1, token0);

        MockERC20(tokenIn).mint(from, amountIn);

        uint256 feeAmountIn = (amountIn * feePercent) / 10_000;
        uint256 protocolFeeAmountIn = (feeAmountIn * FEE_BIPS) / 1e4;

        bytes memory data = feePercent == 0
            ? abi.encodePacked(
                address(this),
                address(this),
                uint16(0),
                abi.encodeCall(this.swap, (tokenIn, tokenOut, amountIn - feeAmountIn, amountOut, address(forwarderLogic)))
            )
            : abi.encodePacked(
                address(this),
                address(this),
                uint16(feePercent),
                uint8(1),
                thirdPartyFeeReceiver,
                abi.encodeCall(this.swap, (tokenIn, tokenOut, amountIn - feeAmountIn, amountOut, address(forwarderLogic)))
            );

        vm.prank(from);
        IERC20(tokenIn).approve(address(this), amountIn);

        (uint256 totalIn, uint256 totalOut) = forwarderLogic.swapExactIn(tokenIn, tokenOut, amountIn, 0, from, to, data);

        assertEq(IERC20(tokenIn).balanceOf(address(forwarderLogic)), 0, "test_Fuzz_SwapExactInWithFeeIn::1");
        assertEq(IERC20(tokenIn).balanceOf(from), 0, "test_Fuzz_SwapExactInWithFeeIn::2");
        assertEq(IERC20(tokenIn).balanceOf(to), 0, "test_Fuzz_SwapExactInWithFeeIn::3");
        assertEq(IERC20(tokenIn).balanceOf(address(this)), amountIn - feeAmountIn, "test_Fuzz_SwapExactInWithFeeIn::4");
        assertEq(
            IERC20(tokenIn).balanceOf(thirdPartyFeeReceiver),
            feeAmountIn - protocolFeeAmountIn,
            "test_Fuzz_SwapExactInWithFeeIn::5"
        );
        assertEq(IERC20(tokenIn).balanceOf(feeReceiver), protocolFeeAmountIn, "test_Fuzz_SwapExactInWithFeeIn::6");
        assertEq(totalIn, amountIn, "test_Fuzz_SwapExactInWithFeeIn::7");

        assertEq(IERC20(tokenOut).balanceOf(address(forwarderLogic)), 0, "test_Fuzz_SwapExactInWithFeeIn::8");
        assertEq(IERC20(tokenOut).balanceOf(from), 0, "test_Fuzz_SwapExactInWithFeeIn::9");
        assertEq(IERC20(tokenOut).balanceOf(to), amountOut, "test_Fuzz_SwapExactInWithFeeIn::10");
        assertEq(IERC20(tokenOut).balanceOf(address(this)), 0, "test_Fuzz_SwapExactInWithFeeIn::11");
        assertEq(totalOut, amountOut, "test_Fuzz_SwapExactInWithFeeIn::12");
    }

    function test_Fuzz_SwapExactInWithFeeOut(
        bool zeroToOne,
        uint256 amountIn,
        uint256 feePercent,
        uint256 amountOut,
        address from,
        address to
    ) public {
        if (
            from == address(0) || from == address(this) || from == address(forwarderLogic) || from == feeReceiver
                || from == thirdPartyFeeReceiver
        ) {
            from = address(1);
        }
        if (
            to == address(0) || to == address(this) || to == address(forwarderLogic) || to == feeReceiver
                || to == thirdPartyFeeReceiver
        ) {
            to = address(2);
        }
        if (from == to) {
            from = address(1);
            to = address(2);
        }

        amountIn = bound(amountIn, 0, type(uint256).max - 1);
        amountOut = bound(amountOut, 1, type(uint256).max / 10_000);
        feePercent = bound(feePercent, 0, 10_000);

        (address tokenIn, address tokenOut) = zeroToOne ? (token0, token1) : (token1, token0);

        MockERC20(tokenIn).mint(from, amountIn);

        uint256 feeAmountOut = (amountOut * feePercent) / 10_000;
        uint256 protocolFeeAmountOut = (feeAmountOut * FEE_BIPS) / 1e4;

        bytes memory data = feePercent == 0
            ? abi.encodePacked(
                address(this),
                address(this),
                uint16(0),
                abi.encodeCall(this.swap, (tokenIn, tokenOut, amountIn, amountOut, address(forwarderLogic)))
            )
            : abi.encodePacked(
                address(this),
                address(this),
                uint16(feePercent),
                uint8(0),
                thirdPartyFeeReceiver,
                abi.encodeCall(this.swap, (tokenIn, tokenOut, amountIn, amountOut, address(forwarderLogic)))
            );

        vm.prank(from);
        IERC20(tokenIn).approve(address(this), amountIn);

        (uint256 totalIn, uint256 totalOut) = forwarderLogic.swapExactIn(tokenIn, tokenOut, amountIn, 0, from, to, data);

        assertEq(IERC20(tokenIn).balanceOf(address(forwarderLogic)), 0, "test_Fuzz_SwapExactInWithFeeOut::1");
        assertEq(IERC20(tokenIn).balanceOf(from), 0, "test_Fuzz_SwapExactInWithFeeOut::2");
        assertEq(IERC20(tokenIn).balanceOf(to), 0, "test_Fuzz_SwapExactInWithFeeOut::3");
        assertEq(IERC20(tokenIn).balanceOf(address(this)), amountIn, "test_Fuzz_SwapExactInWithFeeOut::4");
        assertEq(totalIn, amountIn, "test_Fuzz_SwapExactInWithFeeOut::5");

        assertEq(IERC20(tokenOut).balanceOf(address(forwarderLogic)), 0, "test_Fuzz_SwapExactInWithFeeOut::6");
        assertEq(IERC20(tokenOut).balanceOf(from), 0, "test_Fuzz_SwapExactInWithFeeOut::7");
        assertEq(IERC20(tokenOut).balanceOf(to), amountOut - feeAmountOut, "test_Fuzz_SwapExactInWithFeeOut::8");
        assertEq(IERC20(tokenOut).balanceOf(address(this)), 0, "test_Fuzz_SwapExactInWithFeeOut::9");
        assertEq(
            IERC20(tokenOut).balanceOf(thirdPartyFeeReceiver),
            feeAmountOut - protocolFeeAmountOut,
            "test_Fuzz_SwapExactInWithFeeOut::10"
        );
        assertEq(IERC20(tokenOut).balanceOf(feeReceiver), protocolFeeAmountOut, "test_Fuzz_SwapExactInWithFeeOut::11");
        assertEq(totalOut, amountOut - feeAmountOut, "test_Fuzz_SwapExactInWithFeeOut::12");
    }

    function test_Fuzz_Revert_SwapExactIn(address caller) public {
        vm.assume(caller != address(this));

        vm.expectRevert(IForwarderLogic.ForwarderLogic__OnlyRouter.selector);
        vm.prank(caller);
        forwarderLogic.swapExactIn(address(0), address(0), 0, 0, address(0), address(0), "");

        vm.expectRevert();
        forwarderLogic.swapExactIn(token0, address(0), 0, 0, address(0), address(0), new bytes(42));

        vm.expectRevert();
        forwarderLogic.swapExactIn(
            token0,
            address(0),
            0,
            0,
            address(0),
            address(0),
            abi.encodePacked(address(0), address(0), uint16(1), uint8(1), new bytes(19))
        );

        vm.expectRevert(IForwarderLogic.ForwarderLogic__UntrustedRouter.selector);
        forwarderLogic.swapExactIn(
            token0,
            address(0),
            0,
            0,
            address(1),
            address(0),
            abi.encodePacked(address(1), address(1), uint16(0), uint8(0), "")
        );

        forwarderLogic.updateTrustedRouter(address(0), true);

        vm.expectRevert(IForwarderLogic.ForwarderLogic__NoCode.selector);
        forwarderLogic.swapExactIn(
            token0,
            address(0),
            0,
            0,
            address(1),
            address(0),
            abi.encodePacked(address(this), address(0), uint16(0), uint8(0), "")
        );

        revertData = bytes("Error");

        vm.expectRevert("Error");
        forwarderLogic.swapExactIn(
            token0,
            address(0),
            0,
            0,
            address(1),
            address(0),
            abi.encodePacked(address(this), address(this), uint16(0), uint8(0), "")
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

        vm.expectRevert(IForwarderLogic.ForwarderLogic__Blacklisted.selector);
        forwarderLogic.swapExactIn(address(0), address(0), 0, 0, address(0), user, "");

        vm.expectRevert(IForwarderLogic.ForwarderLogic__Blacklisted.selector);
        forwarderLogic.swapExactIn(address(0), address(0), 0, 0, user, user, "");

        forwarderLogic.updateBlacklist(user, false);

        assertFalse(forwarderLogic.isBlacklisted(user), "test_Fuzz_Blacklist::3");
    }

    function test_Fuzz_SetFeeParameters(address newFeeReceiver, uint96 feeShare) public {
        vm.assume(newFeeReceiver != address(0));
        uint256 validFeeShare = bound(feeShare, 0, 10_000);

        forwarderLogic.setProtocolFeeParameters(newFeeReceiver, uint96(validFeeShare));

        assertEq(forwarderLogic.getProtocolFeeRecipient(), newFeeReceiver, "test_Fuzz_SetFeeParameters::1");
        assertEq(forwarderLogic.getProtocolFeeShare(), validFeeShare, "test_Fuzz_SetFeeParameters::2");

        forwarderLogic.setProtocolFeeParameters(feeReceiver, 0);

        assertEq(forwarderLogic.getProtocolFeeRecipient(), feeReceiver, "test_Fuzz_SetFeeParameters::3");
        assertEq(forwarderLogic.getProtocolFeeShare(), 0, "test_Fuzz_SetFeeParameters::4");

        vm.expectRevert(IFeeAdapter.FeeAdapter__InvalidProtocolFeeReceiver.selector);
        forwarderLogic.setProtocolFeeParameters(address(0), uint96(validFeeShare));

        vm.expectRevert(IFeeAdapter.FeeAdapter__InvalidProtocolFeeShare.selector);
        forwarderLogic.setProtocolFeeParameters(newFeeReceiver, uint96(bound(feeShare, 10_001, type(uint96).max)));

        vm.expectRevert(IForwarderLogic.ForwarderLogic__OnlyRouterOwner.selector);
        vm.prank(alice);
        forwarderLogic.setProtocolFeeParameters(newFeeReceiver, uint96(validFeeShare));
    }

    function test_Revert_Fuzz_SwapExactIn_ExactInNotFullyConsumed(
        bool zeroToOne,
        uint256 usedIn,
        uint256 amountIn,
        uint256 amountOut,
        address from,
        address to
    ) public {
        if (from == address(0) || from == address(this) || from == address(forwarderLogic)) from = address(1);
        if (to == address(0) || to == address(this) || to == address(forwarderLogic)) to = address(2);
        if (from == to) {
            from = address(1);
            to = address(2);
        }

        amountIn = bound(amountIn, 1, type(uint256).max);
        usedIn = bound(usedIn, 0, amountIn - 1);

        (address tokenIn, address tokenOut) = zeroToOne ? (token0, token1) : (token1, token0);

        MockERC20(tokenIn).mint(from, amountIn);

        bytes memory data = abi.encodePacked(
            address(this),
            address(this),
            uint16(0),
            abi.encodeCall(this.swap, (tokenIn, tokenOut, usedIn, amountOut, address(forwarderLogic)))
        );

        vm.prank(from);
        IERC20(tokenIn).approve(address(this), amountIn);

        vm.expectRevert(IForwarderLogic.ForwarderLogic__UnspentAmountIn.selector);
        forwarderLogic.swapExactIn(tokenIn, tokenOut, amountIn, 0, from, to, data);
    }
}
