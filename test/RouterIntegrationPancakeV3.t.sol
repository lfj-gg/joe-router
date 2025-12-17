// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Test} from "forge-std/Test.sol";

import {IRouter, Router} from "../src/Router.sol";
import {RouterLogic} from "../src/RouterLogic.sol";
import {PackedRouteHelper} from "./PackedRouteHelper.sol";

/// forge-config: default.evm_version = "shanghai"
contract RouterIntegrationPancakeSwapV3Test is Test, PackedRouteHelper {
    Router public router;
    RouterLogic public logic;

    address public WETH = 0xEE8c0E9f1BFFb4Eb878d8f15f368A02a35481242;
    address public WMON = 0x3bd359C1119dA7Da1D913D1C4D2B7c461115433A;
    address public USDC = 0x754704Bc059F8C67012fEd69BC8A327a5aafb603;

    address public PSV3_MON_WETH = 0xB02793FE655C1169A8699B4ee462F8Ac9c75E402;

    address public PSV3_MON_USDC = 0x63e48B725540A3Db24ACF6682a29f877808C53F2;

    address alice = makeAddr("Alice");
    address feeReceiver = makeAddr("FeeReceiver");

    function setUp() public {
        vm.createSelectFork("https://rpc1.monad.xyz", 42520931);

        router = new Router(WMON, address(this));
        logic = new RouterLogic(address(router), address(0), address(0), WMON, feeReceiver, 0.15e4);

        router.updateRouterLogic(address(logic), true);

        vm.label(address(router), "Router");
        vm.label(address(logic), "RouterLogic");
        vm.label(WMON, "WMON");
        vm.label(WETH, "WETH");
        vm.label(USDC, "USDC");
        vm.label(PSV3_MON_WETH, "PSV3_MON_WETH");
        vm.label(PSV3_MON_USDC, "PSV3_MON_USDC");
    }

    function test_SwapExactInTokenToToken() public {
        uint128 amountIn = 0.001e18;

        vm.deal(alice, 0.1e18);
        deal(WETH, alice, amountIn);

        (bytes memory route, uint256 ptr) = _createRoutes(3, 2);

        ptr = _setIsTransferTaxToken(route, ptr, false);
        ptr = _setToken(route, ptr, WETH);
        ptr = _setToken(route, ptr, WMON);
        ptr = _setToken(route, ptr, USDC);

        ptr = _setRoute(route, ptr, WETH, WMON, PSV3_MON_WETH, 1e4, UV3ID | ONE_FOR_ZERO | CALLBACK);
        ptr = _setRoute(route, ptr, WMON, USDC, PSV3_MON_USDC, 1e4, UV3ID | ZERO_FOR_ONE | CALLBACK);

        vm.startPrank(alice);
        IERC20(WETH).approve(address(router), amountIn);

        uint256 expectedOut;
        {
            bytes[] memory multiRoutes = new bytes[](3);

            multiRoutes[0] = route;
            multiRoutes[1] = route;

            (bool success, bytes memory data) = address(router).call{value: 0.1e18}(
                abi.encodeWithSelector(
                    IRouter.simulate.selector, logic, WETH, USDC, amountIn, 1, alice, true, multiRoutes
                )
            );
            assertFalse(success, "test_SwapExactInTokenToToken::1");

            uint256[] memory values;

            assembly ("memory-safe") {
                values := add(data, 68)
            }

            assertEq(values.length, 3, "test_SwapExactInTokenToToken::2");
            assertEq(values[0], values[1], "test_SwapExactInTokenToToken::3");
            assertEq(values[2], 0, "test_SwapExactInTokenToToken::4");

            expectedOut = values[0];
        }

        (uint256 totalIn, uint256 totalOut) =
            router.swapExactIn{value: 0.1e18}(address(logic), WETH, USDC, amountIn, 1, alice, block.timestamp, route);
        vm.stopPrank();

        assertEq(totalIn, amountIn, "test_SwapExactInTokenToToken::5");
        assertGt(totalOut, 0, "test_SwapExactInTokenToToken::6");
        assertEq(totalOut, expectedOut, "test_SwapExactInTokenToToken::7");
        assertEq(alice.balance, 0.1e18, "test_SwapExactInTokenToToken::8");
        assertEq(IERC20(WETH).balanceOf(alice), 0, "test_SwapExactInTokenToToken::9");
        assertEq(IERC20(USDC).balanceOf(alice), totalOut, "test_SwapExactInTokenToToken::10");
    }

    function test_SwapExactOutTokenToToken() public {
        uint128 amountOut = 0.001e18;
        uint256 maxAmountIn = 1_000e6;

        vm.deal(alice, 0.1e18);
        deal(USDC, alice, maxAmountIn);

        (bytes memory route, uint256 ptr) = _createRoutes(3, 2);

        ptr = _setIsTransferTaxToken(route, ptr, false);
        ptr = _setToken(route, ptr, USDC);
        ptr = _setToken(route, ptr, WMON);
        ptr = _setToken(route, ptr, WETH);

        ptr = _setRoute(route, ptr, USDC, WMON, PSV3_MON_USDC, 1.0e4, UV3ID | ONE_FOR_ZERO | CALLBACK);
        ptr = _setRoute(route, ptr, WMON, WETH, PSV3_MON_WETH, 1.0e4, UV3ID | ZERO_FOR_ONE | CALLBACK);

        vm.startPrank(alice);
        IERC20(USDC).approve(address(router), maxAmountIn);

        uint256 expectedIn;
        {
            bytes[] memory multiRoutes = new bytes[](3);

            multiRoutes[0] = route;
            multiRoutes[1] = route;

            (bool success, bytes memory data) = address(router).call{value: 0.1e18}(
                abi.encodeWithSelector(
                    IRouter.simulate.selector,
                    logic,
                    USDC,
                    WETH,
                    type(uint128).max,
                    amountOut,
                    alice,
                    false,
                    multiRoutes
                )
            );
            assertFalse(success, "test_SwapExactOutTokenToToken::1");

            uint256[] memory values;

            assembly ("memory-safe") {
                values := add(data, 68)
            }

            assertEq(values.length, 3, "test_SwapExactOutTokenToToken::2");
            assertEq(values[0], values[1], "test_SwapExactOutTokenToToken::3");
            assertEq(values[2], type(uint256).max, "test_SwapExactOutTokenToToken::4");

            expectedIn = values[0];
        }

        (uint256 totalIn, uint256 totalOut) = router.swapExactOut{value: 0.1e18}(
            address(logic), USDC, WETH, amountOut, maxAmountIn, alice, block.timestamp, route
        );
        vm.stopPrank();

        assertLe(totalIn, maxAmountIn, "test_SwapExactOutTokenToToken::5");
        assertEq(totalIn, expectedIn, "test_SwapExactOutTokenToToken::6");
        assertGe(totalOut, amountOut, "test_SwapExactOutTokenToToken::7");
        assertEq(alice.balance, 0.1e18, "test_SwapExactOutTokenToToken::8");
        assertEq(IERC20(USDC).balanceOf(alice), maxAmountIn - totalIn, "test_SwapExactOutTokenToToken::9");
        assertEq(IERC20(WETH).balanceOf(alice), amountOut, "test_SwapExactOutTokenToToken::10");
    }

    function test_SwapExactInNativeToToken() public {
        uint128 amountIn = 0.1e18;

        vm.deal(alice, amountIn + 0.2e18);

        (bytes memory route, uint256 ptr) = _createRoutes(2, 1);

        ptr = _setIsTransferTaxToken(route, ptr, false);
        ptr = _setToken(route, ptr, WMON);
        ptr = _setToken(route, ptr, USDC);

        ptr = _setRoute(route, ptr, WMON, USDC, PSV3_MON_USDC, 1.0e4, UV3ID | ZERO_FOR_ONE | CALLBACK);

        vm.prank(alice);
        (uint256 totalIn, uint256 totalOut) = router.swapExactIn{value: amountIn + 0.2e18}(
            address(logic), address(0), USDC, amountIn, 1, alice, block.timestamp, route
        );

        assertEq(totalIn, amountIn, "test_SwapExactInNativeToToken::1");
        assertGt(totalOut, 0, "test_SwapExactInNativeToToken::2");
        assertEq(alice.balance, 0.2e18, "test_SwapExactInNativeToToken::3");
        assertEq(IERC20(USDC).balanceOf(alice), totalOut, "test_SwapExactInNativeToToken::4");
    }

    function test_SwapExactOutNativeToToken() public {
        uint128 amountOut = 1e6;
        uint256 maxAmountIn = 100e18;

        vm.deal(alice, maxAmountIn + 0.2e18);

        (bytes memory route, uint256 ptr) = _createRoutes(2, 1);

        ptr = _setIsTransferTaxToken(route, ptr, false);
        ptr = _setToken(route, ptr, WMON);
        ptr = _setToken(route, ptr, USDC);

        ptr = _setRoute(route, ptr, WMON, USDC, PSV3_MON_USDC, 1.0e4, UV3ID | ZERO_FOR_ONE | CALLBACK);

        vm.prank(alice);
        (uint256 totalIn, uint256 totalOut) = router.swapExactOut{value: maxAmountIn + 0.1e18}(
            address(logic), address(0), USDC, amountOut, maxAmountIn, alice, block.timestamp, route
        );

        assertLe(totalIn, maxAmountIn, "test_SwapExactOutNativeToToken::1");
        assertGe(totalOut, amountOut, "test_SwapExactOutNativeToToken::2");
        assertEq(alice.balance, maxAmountIn + 0.2e18 - totalIn, "test_SwapExactOutNativeToToken::3");
        assertGe(IERC20(USDC).balanceOf(alice), amountOut, "test_SwapExactOutNativeToToken::4");
    }

    function test_SwapExactInTokenToNative() public {
        uint128 amountIn = 1e6;

        vm.deal(alice, 0.1e18);
        deal(USDC, alice, amountIn);

        (bytes memory route, uint256 ptr) = _createRoutes(2, 1);

        ptr = _setIsTransferTaxToken(route, ptr, false);
        ptr = _setToken(route, ptr, USDC);
        ptr = _setToken(route, ptr, WMON);

        ptr = _setRoute(route, ptr, USDC, WMON, PSV3_MON_USDC, 1.0e4, UV3ID | ONE_FOR_ZERO | CALLBACK);

        vm.startPrank(alice);
        IERC20(USDC).approve(address(router), amountIn);

        (uint256 totalIn, uint256 totalOut) = router.swapExactIn{value: 0.1e18}(
            address(logic), USDC, address(0), amountIn, 1, alice, block.timestamp, route
        );
        vm.stopPrank();

        assertEq(totalIn, amountIn, "test_SwapExactInTokenToNative::1");
        assertGt(totalOut, 0, "test_SwapExactInTokenToNative::2");
        assertEq(alice.balance, 0.1e18 + totalOut, "test_SwapExactInTokenToNative::3");
        assertEq(IERC20(USDC).balanceOf(alice), 0, "test_SwapExactInTokenToNative::4");
    }

    function test_SwapExactOutTokenToNative() public {
        uint128 amountOut = 0.1e18;
        uint256 maxAmountIn = 10e6;

        vm.deal(alice, 0.2e18);
        deal(USDC, alice, maxAmountIn);

        (bytes memory route, uint256 ptr) = _createRoutes(2, 1);

        ptr = _setIsTransferTaxToken(route, ptr, false);
        ptr = _setToken(route, ptr, USDC);
        ptr = _setToken(route, ptr, WMON);

        ptr = _setRoute(route, ptr, USDC, WMON, PSV3_MON_USDC, 1.0e4, UV3ID | ONE_FOR_ZERO | CALLBACK);

        vm.startPrank(alice);
        IERC20(USDC).approve(address(router), maxAmountIn);

        (uint256 totalIn, uint256 totalOut) = router.swapExactOut{value: 0.2e18}(
            address(logic), USDC, address(0), amountOut, maxAmountIn, alice, block.timestamp, route
        );
        vm.stopPrank();

        assertLe(totalIn, maxAmountIn, "test_SwapExactOutTokenToNative::1");
        assertGe(totalOut, amountOut, "test_SwapExactOutTokenToNative::2");
        assertEq(alice.balance, 0.2e18 + totalOut, "test_SwapExactOutTokenToNative::3");
        assertEq(IERC20(USDC).balanceOf(alice), maxAmountIn - totalIn, "test_SwapExactOutTokenToNative::4");
    }
}
