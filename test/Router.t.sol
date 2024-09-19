// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import "../src/Router.sol";
import "./mocks/MockERC20.sol";
import "./mocks/WNative.sol";

contract RouterTest is Test {
    MockERC20 public token0;
    MockERC20 public token1;
    MockERC20 public token2;
    WNative public wnative;

    Router public router;
    MockRouterLogic public routerLogic;

    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");

    function setUp() public {
        token0 = new MockERC20("Token0", "T0", 18);
        token1 = new MockERC20("Token1", "T1", 9);
        token2 = new MockERC20("Token2", "T2", 6);

        wnative = new WNative();

        routerLogic = new MockRouterLogic();
        router = new Router(address(wnative), address(this));

        router.updateRouterLogic(address(routerLogic));

        vm.label(address(router), "Router");
        vm.label(address(routerLogic), "RouterLogic");
        vm.label(address(token0), "Token0");
        vm.label(address(token1), "Token1");
        vm.label(address(token2), "Token2");
        vm.label(address(wnative), "WNative");
    }

    function test_Constructor() public view {
        assertEq(address(router.WNATIVE()), address(wnative), "test_Constructor::1");
        assertEq(router.owner(), address(this), "test_Constructor::2");
    }

    function test_Fuzz_UpdateLogic(address logic) public {
        assertEq(router.getLogic(), address(routerLogic), "test_Fuzz_UpdateLogic::1");

        router.updateRouterLogic(address(logic));

        assertEq(router.getLogic(), address(logic), "test_Fuzz_UpdateLogic::2");

        router.updateRouterLogic(address(0));

        assertEq(router.getLogic(), address(0), "test_Fuzz_UpdateLogic::3");
    }

    function test_Fuzz_Revert_Transfer(address token, address from, address to, uint256 amount) public {
        vm.expectRevert(IRouter.Router__ZeroAmount.selector);
        router.transfer(token, from, to, 0);

        amount = bound(amount, 1, type(uint256).max);

        vm.expectRevert(abi.encodeWithSelector(IRouter.Router__InsufficientAllowance.selector, 0, amount));
        router.transfer(token, from, to, amount);
    }

    function test_Fuzz_SwapExactInTokenToToken(uint256 amountIn, uint256 amountOutMin) public {
        amountIn = bound(amountIn, 1, type(uint256).max);
        amountOutMin = bound(amountOutMin, 1, type(uint256).max);

        bytes memory routes = abi.encode(amountIn, amountOutMin);

        token0.mint(alice, amountIn);

        vm.startPrank(alice);
        token0.approve(address(router), amountIn);
        router.swapExactIn(address(token0), address(token1), amountIn, amountOutMin, bob, block.timestamp, routes);
        vm.stopPrank();

        assertEq(token0.balanceOf(address(routerLogic)), amountIn, "test_Fuzz_SwapExactInTokenToToken::1");
        assertEq(token1.balanceOf(bob), amountOutMin, "test_Fuzz_SwapExactInTokenToToken::2");
    }

    function test_Fuzz_SwapExactInWNativeToToken(uint256 amountIn, uint256 amountOutMin) public {
        amountIn = bound(amountIn, 1, 100e18);
        amountOutMin = bound(amountOutMin, 1, type(uint256).max);

        bytes memory routes = abi.encode(amountIn, amountOutMin);

        wnative.deposit{value: amountIn}();
        wnative.transfer(alice, amountIn);

        vm.startPrank(alice);
        wnative.approve(address(router), amountIn);
        router.swapExactIn(address(wnative), address(token1), amountIn, amountOutMin, bob, block.timestamp, routes);
        vm.stopPrank();

        assertEq(wnative.balanceOf(address(routerLogic)), amountIn, "test_Fuzz_SwapExactInWNativeToToken::1");
        assertEq(token1.balanceOf(bob), amountOutMin, "test_Fuzz_SwapExactInWNativeToToken::2");
    }

    function test_Fuzz_SwapExactInNativeToToken(uint256 amountIn, uint256 amountOutMin) public {
        amountIn = bound(amountIn, 1, 100e18);
        amountOutMin = bound(amountOutMin, 1, type(uint256).max);

        bytes memory routes = abi.encode(amountIn, amountOutMin);

        payable(alice).transfer(amountIn);

        vm.startPrank(alice);
        router.swapExactIn{value: amountIn}(
            address(0), address(token1), amountIn, amountOutMin, bob, block.timestamp, routes
        );
        vm.stopPrank();

        assertEq(wnative.balanceOf(address(routerLogic)), amountIn, "test_Fuzz_SwapExactInNativeToToken::1");
        assertEq(token1.balanceOf(bob), amountOutMin, "test_Fuzz_SwapExactInNativeToToken::2");
    }

    function test_Fuzz_SwapExactInTokenToWnative(uint256 amountIn, uint256 amountOutMin) public {
        amountIn = bound(amountIn, 1, type(uint256).max);
        amountOutMin = bound(amountOutMin, 1, 100e18);

        bytes memory routes = abi.encode(amountIn, amountOutMin);

        token0.mint(alice, amountIn);

        wnative.deposit{value: amountOutMin}();
        wnative.transfer(address(routerLogic), amountOutMin);

        vm.startPrank(alice);
        token0.approve(address(router), amountIn);
        router.swapExactIn(address(token0), address(wnative), amountIn, amountOutMin, bob, block.timestamp, routes);
        vm.stopPrank();

        assertEq(token0.balanceOf(address(routerLogic)), amountIn, "test_Fuzz_SwapExactInTokenToWnative::1");
        assertEq(wnative.balanceOf(bob), amountOutMin, "test_Fuzz_SwapExactInTokenToWnative::2");
    }

    function test_Fuzz_SwapExactInTokenToNative(uint256 amountIn, uint256 amountOutMin) public {
        amountIn = bound(amountIn, 1, type(uint256).max);
        amountOutMin = bound(amountOutMin, 1, 100e18);

        bytes memory routes = abi.encode(amountIn, amountOutMin);

        token0.mint(alice, amountIn);

        wnative.deposit{value: amountOutMin}();
        wnative.transfer(address(routerLogic), amountOutMin);

        vm.startPrank(alice);
        token0.approve(address(router), amountIn);
        router.swapExactIn(address(token0), address(0), amountIn, amountOutMin, bob, block.timestamp, routes);
        vm.stopPrank();

        assertEq(token0.balanceOf(address(routerLogic)), amountIn, "test_Fuzz_SwapExactInTokenToNative::1");
        assertEq(bob.balance, amountOutMin, "test_Fuzz_SwapExactInTokenToNative::2");
    }

    function test_Fuzz_SwapExactInNativeToNative(uint256 amountIn, uint256 amountOutMin) public {
        amountIn = bound(amountIn, 1, 100e18);
        amountOutMin = bound(amountOutMin, 1, 100e18);

        bytes memory routes = abi.encode(amountIn, amountOutMin);

        payable(alice).transfer(1e18 + amountIn);

        wnative.deposit{value: amountOutMin}();
        wnative.transfer(address(routerLogic), amountOutMin);

        vm.startPrank(alice);
        token0.approve(address(router), amountIn);
        router.swapExactIn{value: 1e18 + amountIn}(
            address(0), address(0), amountIn, amountOutMin, bob, block.timestamp, routes
        );
        vm.stopPrank();

        assertEq(wnative.balanceOf(address(routerLogic)), amountIn, "test_Fuzz_SwapExactInNativeToNative::1");
        assertEq(alice.balance, 1e18, "test_Fuzz_SwapExactInNativeToNative::2");
        assertEq(bob.balance, amountOutMin, "test_Fuzz_SwapExactInNativeToNative::3");
    }

    function test_Fuzz_SwapExactOutTokenToToken(uint256 amountOut, uint256 amountInMax) public {
        amountOut = bound(amountOut, 1, type(uint256).max);
        amountInMax = bound(amountInMax, 1, type(uint256).max);

        bytes memory routes = abi.encode(amountInMax, amountOut);

        token0.mint(alice, amountInMax);

        vm.startPrank(alice);
        token0.approve(address(router), amountInMax);
        router.swapExactOut(address(token0), address(token1), amountOut, amountInMax, bob, block.timestamp, routes);
        vm.stopPrank();

        assertEq(token0.balanceOf(address(routerLogic)), amountInMax, "test_Fuzz_SwapExactOutTokenToToken::1");
        assertEq(token1.balanceOf(bob), amountOut, "test_Fuzz_SwapExactOutTokenToToken::2");
    }

    function test_Fuzz_SwapExactOutWNativeToToken(uint256 amountOut, uint256 amountInMax) public {
        amountOut = bound(amountOut, 1, type(uint256).max);
        amountInMax = bound(amountInMax, 1, 100e18);

        bytes memory routes = abi.encode(amountInMax, amountOut);

        wnative.deposit{value: amountInMax}();
        wnative.transfer(alice, amountInMax);

        vm.startPrank(alice);
        wnative.approve(address(router), amountInMax);
        router.swapExactOut(address(wnative), address(token1), amountOut, amountInMax, bob, block.timestamp, routes);
        vm.stopPrank();

        assertEq(wnative.balanceOf(address(routerLogic)), amountInMax, "test_Fuzz_SwapExactOutWNativeToToken::1");
        assertEq(token1.balanceOf(bob), amountOut, "test_Fuzz_SwapExactOutWNativeToToken::2");
    }

    function test_Fuzz_SwapExactOutNativeToToken(uint256 amountOut, uint256 amountInMax) public {
        amountOut = bound(amountOut, 1, type(uint256).max);
        amountInMax = bound(amountInMax, 1, 100e18);

        bytes memory routes = abi.encode(amountInMax, amountOut);

        payable(alice).transfer(amountInMax);

        vm.startPrank(alice);
        router.swapExactOut{value: amountInMax}(
            address(0), address(token1), amountOut, amountInMax, bob, block.timestamp, routes
        );
        vm.stopPrank();

        assertEq(wnative.balanceOf(address(routerLogic)), amountInMax, "test_Fuzz_SwapExactOutNativeToToken::1");
        assertEq(token1.balanceOf(bob), amountOut, "test_Fuzz_SwapExactOutNativeToToken::2");
    }

    function test_Fuzz_SwapExactOutTokenToWnative(uint256 amountOut, uint256 amountInMax) public {
        amountOut = bound(amountOut, 1, 100e18);
        amountInMax = bound(amountInMax, 1, type(uint256).max);

        bytes memory routes = abi.encode(amountInMax, amountOut);

        token0.mint(alice, amountInMax);

        wnative.deposit{value: amountOut}();
        wnative.transfer(address(routerLogic), amountOut);

        vm.startPrank(alice);
        token0.approve(address(router), amountInMax);
        router.swapExactOut(address(token0), address(wnative), amountOut, amountInMax, bob, block.timestamp, routes);
        vm.stopPrank();

        assertEq(token0.balanceOf(address(routerLogic)), amountInMax, "test_Fuzz_SwapExactOutTokenToWnative::1");
        assertEq(wnative.balanceOf(bob), amountOut, "test_Fuzz_SwapExactOutTokenToWnative::2");
    }

    function test_Fuzz_SwapExactOutTokenToNative(uint256 amountOut, uint256 amountInMax) public {
        amountOut = bound(amountOut, 1, 100e18);
        amountInMax = bound(amountInMax, 1, type(uint256).max);

        bytes memory routes = abi.encode(amountInMax, amountOut);

        token0.mint(alice, amountInMax);

        wnative.deposit{value: amountOut}();
        wnative.transfer(address(routerLogic), amountOut);

        vm.startPrank(alice);
        token0.approve(address(router), amountInMax);
        router.swapExactOut(address(token0), address(0), amountOut, amountInMax, bob, block.timestamp, routes);
        vm.stopPrank();

        assertEq(token0.balanceOf(address(routerLogic)), amountInMax, "test_Fuzz_SwapExactOutTokenToNative::1");
        assertEq(bob.balance, amountOut, "test_Fuzz_SwapExactOutTokenToNative::2");
    }

    function test_Fuzz_SwapExactOutNativeToNative(uint256 amountOut, uint256 amountInMax) public {
        amountOut = bound(amountOut, 1, 100e18);
        amountInMax = bound(amountInMax, 1, 100e18);

        bytes memory routes = abi.encode(amountInMax, amountOut);

        payable(alice).transfer(1e18 + amountInMax);

        wnative.deposit{value: amountOut}();
        wnative.transfer(address(routerLogic), amountOut);

        vm.startPrank(alice);
        router.swapExactOut{value: 1e18 + amountInMax}(
            address(0), address(0), amountOut, amountInMax, bob, block.timestamp, routes
        );
        vm.stopPrank();

        assertEq(wnative.balanceOf(address(routerLogic)), amountInMax, "test_Fuzz_SwapExactOutNativeToNative::1");
        assertEq(alice.balance, 1e18, "test_Fuzz_SwapExactOutNativeToNative::2");
        assertEq(bob.balance, amountOut, "test_Fuzz_SwapExactOutNativeToNative::3");
    }

    function test_Revert_SwapExactIn() public {
        vm.expectRevert(IRouter.Router__InvalidTo.selector);
        router.swapExactIn(address(0), address(0), 0, 0, address(0), block.timestamp, new bytes(0));

        vm.expectRevert(IRouter.Router__InvalidTo.selector);
        router.swapExactIn(address(0), address(0), 0, 0, address(router), block.timestamp, new bytes(0));

        vm.expectRevert(IRouter.Router__DeadlineExceeded.selector);
        router.swapExactIn(address(0), address(0), 0, 0, bob, block.timestamp - 1, new bytes(0));

        vm.expectRevert(IRouter.Router__ZeroAmountIn.selector);
        router.swapExactIn(address(token0), address(0), 0, 0, alice, block.timestamp, new bytes(0));

        token0.mint(alice, 10e18);

        wnative.deposit{value: 1e18}();
        wnative.transfer(address(routerLogic), 1e18);

        bytes memory routes = abi.encode(10e18, 1e18);

        vm.startPrank(alice);
        token0.approve(address(router), 10e18);
        vm.expectRevert(IRouter.Router__NativeTransferFailed.selector);
        router.swapExactIn(address(token0), address(0), 10e18, 1e18, address(this), block.timestamp, routes);
        vm.stopPrank();
    }

    function test_Revert_SwapExactOut() public {
        vm.expectRevert(IRouter.Router__InvalidTo.selector);
        router.swapExactOut(address(0), address(0), 0, 0, address(0), block.timestamp, new bytes(0));

        vm.expectRevert(IRouter.Router__InvalidTo.selector);
        router.swapExactOut(address(0), address(0), 0, 0, address(router), block.timestamp, new bytes(0));

        vm.expectRevert(IRouter.Router__DeadlineExceeded.selector);
        router.swapExactOut(address(0), address(0), 0, 0, bob, block.timestamp - 1, new bytes(0));

        vm.expectRevert(IRouter.Router__ZeroAmountOut.selector);
        router.swapExactOut(address(token0), address(0), 0, 0, alice, block.timestamp, new bytes(0));

        token0.mint(alice, 10e18);

        wnative.deposit{value: 1e18}();
        wnative.transfer(address(routerLogic), 1e18);

        bytes memory routes = abi.encode(10e18, 1e18);

        vm.startPrank(alice);
        token0.approve(address(router), 10e18);
        vm.expectRevert(IRouter.Router__NativeTransferFailed.selector);
        router.swapExactOut(address(token0), address(0), 1e18, 10e18, address(this), block.timestamp, routes);
        vm.stopPrank();
    }

    function test_Fuzz_Revert_SwapExactIn(uint256 amountIn, uint256 amountOutMin) public {
        amountIn = bound(amountIn, 1, type(uint256).max - 1);
        amountOutMin = bound(amountOutMin, 1, type(uint256).max);

        token0.mint(alice, amountIn);

        bytes memory routes = abi.encode(amountIn + 1, amountOutMin);

        vm.startPrank(alice);
        token0.approve(address(router), amountIn);
        vm.expectRevert(abi.encodeWithSelector(IRouter.Router__InsufficientAllowance.selector, amountIn, amountIn + 1));
        router.swapExactIn(address(token0), address(token1), amountIn, amountOutMin, bob, block.timestamp, routes);
        vm.stopPrank();

        routes = abi.encode(amountIn, amountOutMin, amountIn - 1, amountOutMin);

        vm.startPrank(alice);
        token0.approve(address(router), amountIn);
        vm.expectRevert(abi.encodeWithSelector(IRouter.Router__InvalidTotalIn.selector, amountIn - 1, amountIn));
        router.swapExactIn(address(token0), address(token1), amountIn, amountOutMin, bob, block.timestamp, routes);
        vm.stopPrank();

        routes = abi.encode(amountIn, amountOutMin - 1);

        vm.startPrank(alice);
        token0.approve(address(router), amountIn);
        vm.expectRevert(
            abi.encodeWithSelector(IRouter.Router__InsufficientOutputAmount.selector, amountOutMin - 1, amountOutMin)
        );
        router.swapExactIn(address(token0), address(token1), amountIn, amountOutMin, bob, block.timestamp, routes);
        vm.stopPrank();

        routes = abi.encode(amountIn, amountOutMin - 1, amountIn, amountOutMin);

        vm.startPrank(alice);
        token0.approve(address(router), amountIn);
        vm.expectRevert(
            abi.encodeWithSelector(
                IRouter.Router__InsufficientAmountReceived.selector, 0, amountOutMin - 1, amountOutMin
            )
        );
        router.swapExactIn(address(token0), address(token1), amountIn, amountOutMin, bob, block.timestamp, routes);
        vm.stopPrank();

        router.updateRouterLogic(address(0));

        vm.expectRevert(IRouter.Router__LogicNotSet.selector);
        router.swapExactIn(address(token0), address(token1), amountIn, amountOutMin, bob, block.timestamp, routes);
    }

    function test_Fuzz_Revert_SwapExactOut(uint256 amountOut, uint256 amountInMax) public {
        amountOut = bound(amountOut, 1, type(uint256).max);
        amountInMax = bound(amountInMax, 1, type(uint256).max - 1);

        token0.mint(alice, amountInMax);

        bytes memory routes = abi.encode(amountInMax + 1, amountOut);

        vm.startPrank(alice);
        token0.approve(address(router), amountInMax);
        vm.expectRevert(
            abi.encodeWithSelector(IRouter.Router__InsufficientAllowance.selector, amountInMax, amountInMax + 1)
        );
        router.swapExactOut(address(token0), address(token1), amountOut, amountInMax, bob, block.timestamp, routes);
        vm.stopPrank();

        routes = abi.encode(amountInMax, amountOut, amountInMax + 1, amountOut);

        vm.startPrank(alice);
        token0.approve(address(router), amountInMax);
        vm.expectRevert(
            abi.encodeWithSelector(IRouter.Router__MaxAmountInExceeded.selector, amountInMax + 1, amountInMax)
        );
        router.swapExactOut(address(token0), address(token1), amountOut, amountInMax, bob, block.timestamp, routes);
        vm.stopPrank();

        routes = abi.encode(amountInMax, amountOut - 1);

        vm.startPrank(alice);
        token0.approve(address(router), amountInMax);
        vm.expectRevert(
            abi.encodeWithSelector(IRouter.Router__InsufficientOutputAmount.selector, amountOut - 1, amountOut)
        );
        router.swapExactOut(address(token0), address(token1), amountOut, amountInMax, bob, block.timestamp, routes);
        vm.stopPrank();

        routes = abi.encode(amountInMax, amountOut - 1, amountInMax, amountOut);

        vm.startPrank(alice);
        token0.approve(address(router), amountInMax);
        vm.expectRevert(
            abi.encodeWithSelector(IRouter.Router__InsufficientAmountReceived.selector, 0, amountOut - 1, amountOut)
        );
        router.swapExactOut(address(token0), address(token1), amountOut, amountInMax, bob, block.timestamp, routes);
        vm.stopPrank();

        router.updateRouterLogic(address(0));

        vm.expectRevert(IRouter.Router__LogicNotSet.selector);
        router.swapExactOut(address(token0), address(token1), amountOut, amountInMax, bob, block.timestamp, routes);
    }
}

contract MockRouterLogic is IRouterLogic {
    function swapExactIn(
        address tokenIn,
        address tokenOut,
        address from,
        address to,
        uint256,
        uint256,
        bytes calldata routes
    ) external returns (uint256 totalIn, uint256 totalOut) {
        (totalIn, totalOut) = abi.decode(routes, (uint256, uint256));

        IRouter(msg.sender).transfer(tokenIn, from, address(this), totalIn);

        MockERC20(tokenOut).mint(to, totalOut);

        if (routes.length >= 128) return abi.decode(routes[64:], (uint256, uint256));
    }

    function swapExactOut(
        address tokenIn,
        address tokenOut,
        address from,
        address to,
        uint256,
        uint256,
        bytes calldata routes
    ) external payable returns (uint256 totalIn, uint256 totalOut) {
        (totalIn, totalOut) = abi.decode(routes, (uint256, uint256));

        IRouter(msg.sender).transfer(tokenIn, from, address(this), totalIn);

        MockERC20(tokenOut).mint(to, totalOut);

        if (routes.length >= 128) return abi.decode(routes[64:], (uint256, uint256));
    }
}
