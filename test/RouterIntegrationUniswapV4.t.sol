// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import "../src/Router.sol";
import "../src/RouterLogic.sol";
import "./PackedRouteHelper.sol";
import "./mocks/MockERC20.sol";

/// forge-config: default.evm_version = "cancun"
contract RouterIntegrationUniswapV4Test is Test, PackedRouteHelper {
    Router public router;
    RouterLogic public logic;

    address public LB0_ROUTER = 0xE3Ffc583dC176575eEA7FD9dF2A7c65F7E23f4C3;
    address public UNISWAP_V4_MANAGER = 0x06380C0e0912312B5150364B9DC4542BA0DbBc85;

    address public WAVAX = 0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7;
    address public USDT = 0x9702230A8Ea53601f5cD2dc00fDBc13d4dF4A8c7;
    address public USDC = 0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E;

    uint24 public UV4_WAVAX_USDC_FEE = 0.05e4;
    int24 public UV4_WAVAX_USDC_TICK_SPACING = 10;

    uint24 public UV4_WAVAX_USDT_FEE = 0.3e4;
    int24 public UV4_WAVAX_USDT_TICK_SPACING = 60;

    uint24 public UV4_USDT_USDC_FEE = 0.0032e4;
    int24 public UV4_USDT_USDC_TICK_SPACING = 1;

    address public NO_HOOKS = address(0);

    address alice = makeAddr("Alice");
    address feeReceiver = makeAddr("FeeReceiver");

    function setUp() public {
        vm.createSelectFork(StdChains.getChain("avalanche").rpcUrl, 69401819);

        router = new Router(WAVAX, address(this));
        logic = new RouterLogic(address(router), LB0_ROUTER, UNISWAP_V4_MANAGER, WAVAX, feeReceiver, 0.15e4);

        router.updateRouterLogic(address(logic), true);

        vm.label(address(router), "Router");
        vm.label(address(logic), "RouterLogic");
        vm.label(WAVAX, "WAVAX");
        vm.label(USDC, "USDC");
        vm.label(USDT, "USDT");
        vm.label(LB0_ROUTER, "LB0_ROUTER");
        vm.label(UNISWAP_V4_MANAGER, "UNISWAP_V4_MANAGER");
    }

    function test_SwapExactInTokenToToken() public {
        uint128 amountIn = 1000e6;

        vm.deal(alice, 0.1e18);
        deal(USDC, alice, amountIn);

        (bytes memory route, uint256 ptr, uint256 extraDataPtr) =
            _createRoutesWithExtraData(3, 2, UNISWAP_V4_EXTRA_DATA_SIZE * 2);
        ptr = _setIsTransferTaxToken(route, ptr, false);
        ptr = _setToken(route, ptr, USDC);
        ptr = _setToken(route, ptr, WAVAX);
        ptr = _setToken(route, ptr, USDT);

        (ptr, extraDataPtr) = _setRouteUV4(
            route,
            ptr,
            extraDataPtr,
            USDC,
            WAVAX,
            1e4,
            ONE_FOR_ZERO | UV4_ID | CALLBACK,
            ExtraDataUV4({
                fee: UV4_WAVAX_USDC_FEE,
                tickSpacing: UV4_WAVAX_USDC_TICK_SPACING,
                nativeFlag: UV4_NATIVE_FLAG_OUT,
                hooks: NO_HOOKS,
                hookData: ""
            })
        );
        (ptr, extraDataPtr) = _setRouteUV4(
            route,
            ptr,
            extraDataPtr,
            WAVAX,
            USDT,
            1e4,
            ZERO_FOR_ONE | UV4_ID | CALLBACK,
            ExtraDataUV4({
                fee: UV4_WAVAX_USDT_FEE,
                tickSpacing: UV4_WAVAX_USDT_TICK_SPACING,
                nativeFlag: UV4_NATIVE_FLAG_IN,
                hooks: NO_HOOKS,
                hookData: ""
            })
        );

        vm.startPrank(alice);
        MockERC20(USDC).approve(address(router), amountIn);

        (uint256 totalIn, uint256 totalOut) =
            router.swapExactIn{value: 0.1e18}(address(logic), USDC, USDT, amountIn, 1, alice, block.timestamp, route);
        vm.stopPrank();

        assertEq(totalIn, amountIn, "test_SwapExactInTokenToToken::1");
        assertGt(totalOut, 0, "test_SwapExactInTokenToToken::2");
        assertEq(alice.balance, 0.1e18, "test_SwapExactInTokenToToken::3");
        assertEq(IERC20(USDC).balanceOf(alice), 0, "test_SwapExactInTokenToToken::4");
        assertEq(IERC20(USDT).balanceOf(alice), totalOut, "test_SwapExactInTokenToToken::5");
    }

    function test_SwapExactOutTokenToToken() public {
        uint128 amountOut = 1000e6;
        uint256 maxAmountIn = 1500e6;

        vm.deal(alice, 0.1e18);
        deal(USDT, alice, maxAmountIn);

        (bytes memory route, uint256 ptr, uint256 extraDataPtr) =
            _createRoutesWithExtraData(3, 2, UNISWAP_V4_EXTRA_DATA_SIZE * 2);
        ptr = _setIsTransferTaxToken(route, ptr, false);
        ptr = _setToken(route, ptr, USDT);
        ptr = _setToken(route, ptr, WAVAX);
        ptr = _setToken(route, ptr, USDC);

        (ptr, extraDataPtr) = _setRouteUV4(
            route,
            ptr,
            extraDataPtr,
            USDT,
            WAVAX,
            1e4,
            ONE_FOR_ZERO | UV4_ID | CALLBACK,
            ExtraDataUV4({
                fee: UV4_WAVAX_USDT_FEE,
                tickSpacing: UV4_WAVAX_USDT_TICK_SPACING,
                nativeFlag: UV4_NATIVE_FLAG_OUT,
                hooks: NO_HOOKS,
                hookData: ""
            })
        );
        (ptr, extraDataPtr) = _setRouteUV4(
            route,
            ptr,
            extraDataPtr,
            WAVAX,
            USDC,
            1e4,
            ZERO_FOR_ONE | UV4_ID | CALLBACK,
            ExtraDataUV4({
                fee: UV4_WAVAX_USDC_FEE,
                tickSpacing: UV4_WAVAX_USDC_TICK_SPACING,
                nativeFlag: UV4_NATIVE_FLAG_IN,
                hooks: NO_HOOKS,
                hookData: ""
            })
        );

        vm.startPrank(alice);
        MockERC20(USDT).approve(address(router), maxAmountIn);

        (uint256 totalIn, uint256 totalOut) = router.swapExactOut{value: 0.1e18}(
            address(logic), USDT, USDC, amountOut, maxAmountIn, alice, block.timestamp, route
        );
        vm.stopPrank();

        assertLe(totalIn, maxAmountIn, "test_SwapExactOutTokenToToken::1");
        assertEq(totalOut, amountOut, "test_SwapExactOutTokenToToken::2");
        assertEq(alice.balance, 0.1e18, "test_SwapExactOutTokenToToken::3");
        assertEq(IERC20(USDT).balanceOf(alice), maxAmountIn - totalIn, "test_SwapExactOutTokenToToken::4");
        assertEq(IERC20(USDC).balanceOf(alice), totalOut, "test_SwapExactOutTokenToToken::5");
    }

    function test_SwapExactInNativeToToken() public {
        uint128 amountIn = 35e18;

        vm.deal(alice, amountIn + 0.1e18);

        (bytes memory route, uint256 ptr, uint256 extraDataPtr) =
            _createRoutesWithExtraData(3, 2, UNISWAP_V4_EXTRA_DATA_SIZE * 2);
        ptr = _setIsTransferTaxToken(route, ptr, false);
        ptr = _setToken(route, ptr, WAVAX);
        ptr = _setToken(route, ptr, USDC);
        ptr = _setToken(route, ptr, USDT);

        (ptr, extraDataPtr) = _setRouteUV4(
            route,
            ptr,
            extraDataPtr,
            WAVAX,
            USDC,
            1e4,
            ZERO_FOR_ONE | UV4_ID | CALLBACK,
            ExtraDataUV4({
                fee: UV4_WAVAX_USDC_FEE,
                tickSpacing: UV4_WAVAX_USDC_TICK_SPACING,
                nativeFlag: UV4_NATIVE_FLAG_IN,
                hooks: NO_HOOKS,
                hookData: ""
            })
        );
        (ptr, extraDataPtr) = _setRouteUV4(
            route,
            ptr,
            extraDataPtr,
            USDC,
            USDT,
            1e4,
            ONE_FOR_ZERO | UV4_ID | CALLBACK,
            ExtraDataUV4({
                fee: UV4_USDT_USDC_FEE,
                tickSpacing: UV4_USDT_USDC_TICK_SPACING,
                nativeFlag: UV4_NATIVE_FLAG_NONE,
                hooks: NO_HOOKS,
                hookData: ""
            })
        );

        vm.startPrank(alice);

        (uint256 totalIn, uint256 totalOut) = router.swapExactIn{value: amountIn + 0.1e18}(
            address(logic), address(0), USDT, amountIn, 1, alice, block.timestamp, route
        );
        vm.stopPrank();

        assertEq(totalIn, amountIn, "test_SwapExactInNativeToToken::1");
        assertGt(totalOut, 0, "test_SwapExactInNativeToToken::2");
        assertEq(alice.balance, 0.1e18, "test_SwapExactInNativeToToken::3");
        assertEq(IERC20(USDT).balanceOf(alice), totalOut, "test_SwapExactInNativeToToken::4");
    }

    function test_SwapExactOutNativeToToken() public {
        uint128 amountOut = 1000e6;
        uint256 maxAmountIn = 50e18;

        vm.deal(alice, maxAmountIn + 0.1e18);

        (bytes memory route, uint256 ptr, uint256 extraDataPtr) =
            _createRoutesWithExtraData(3, 2, UNISWAP_V4_EXTRA_DATA_SIZE * 2);
        ptr = _setIsTransferTaxToken(route, ptr, false);
        ptr = _setToken(route, ptr, WAVAX);
        ptr = _setToken(route, ptr, USDT);
        ptr = _setToken(route, ptr, USDC);

        (ptr, extraDataPtr) = _setRouteUV4(
            route,
            ptr,
            extraDataPtr,
            WAVAX,
            USDT,
            1e4,
            ZERO_FOR_ONE | UV4_ID | CALLBACK,
            ExtraDataUV4({
                fee: UV4_WAVAX_USDT_FEE,
                tickSpacing: UV4_WAVAX_USDT_TICK_SPACING,
                nativeFlag: UV4_NATIVE_FLAG_IN,
                hooks: NO_HOOKS,
                hookData: ""
            })
        );
        (ptr, extraDataPtr) = _setRouteUV4(
            route,
            ptr,
            extraDataPtr,
            USDT,
            USDC,
            1e4,
            ZERO_FOR_ONE | UV4_ID | CALLBACK,
            ExtraDataUV4({
                fee: UV4_USDT_USDC_FEE,
                tickSpacing: UV4_USDT_USDC_TICK_SPACING,
                nativeFlag: UV4_NATIVE_FLAG_NONE,
                hooks: NO_HOOKS,
                hookData: ""
            })
        );

        vm.startPrank(alice);
        MockERC20(USDT).approve(address(router), maxAmountIn);

        (uint256 totalIn, uint256 totalOut) = router.swapExactOut{value: maxAmountIn + 0.1e18}(
            address(logic), address(0), USDC, amountOut, maxAmountIn, alice, block.timestamp, route
        );
        vm.stopPrank();

        assertLe(totalIn, maxAmountIn, "test_SwapExactOutNativeToToken::1");
        assertEq(totalOut, amountOut, "test_SwapExactOutNativeToToken::2");
        assertEq(alice.balance, maxAmountIn + 0.1e18 - totalIn, "test_SwapExactOutNativeToToken::3");
        assertEq(IERC20(USDC).balanceOf(alice), totalOut, "test_SwapExactOutNativeToToken::4");
    }

    function test_SwapExactInTokenToNative() public {
        uint128 amountIn = 1000e6;

        vm.deal(alice, 0.1e18);
        deal(USDC, alice, amountIn);

        (bytes memory route, uint256 ptr, uint256 extraDataPtr) =
            _createRoutesWithExtraData(3, 2, UNISWAP_V4_EXTRA_DATA_SIZE * 2);
        ptr = _setIsTransferTaxToken(route, ptr, false);
        ptr = _setToken(route, ptr, USDC);
        ptr = _setToken(route, ptr, USDT);
        ptr = _setToken(route, ptr, WAVAX);

        (ptr, extraDataPtr) = _setRouteUV4(
            route,
            ptr,
            extraDataPtr,
            USDC,
            USDT,
            1e4,
            ONE_FOR_ZERO | UV4_ID | CALLBACK,
            ExtraDataUV4({
                fee: UV4_USDT_USDC_FEE,
                tickSpacing: UV4_USDT_USDC_TICK_SPACING,
                nativeFlag: UV4_NATIVE_FLAG_NONE,
                hooks: NO_HOOKS,
                hookData: ""
            })
        );
        (ptr, extraDataPtr) = _setRouteUV4(
            route,
            ptr,
            extraDataPtr,
            USDT,
            WAVAX,
            1e4,
            ONE_FOR_ZERO | UV4_ID | CALLBACK,
            ExtraDataUV4({
                fee: UV4_WAVAX_USDT_FEE,
                tickSpacing: UV4_WAVAX_USDT_TICK_SPACING,
                nativeFlag: UV4_NATIVE_FLAG_OUT,
                hooks: NO_HOOKS,
                hookData: ""
            })
        );

        vm.startPrank(alice);
        MockERC20(USDC).approve(address(router), amountIn);

        (uint256 totalIn, uint256 totalOut) = router.swapExactIn{value: 0.1e18}(
            address(logic), USDC, address(0), amountIn, 1, alice, block.timestamp, route
        );
        vm.stopPrank();

        assertEq(totalIn, amountIn, "test_SwapExactInTokenToNative::1");
        assertGt(totalOut, 0, "test_SwapExactInTokenToNative::2");
        assertEq(IERC20(USDC).balanceOf(alice), 0, "test_SwapExactInTokenToNative::3");
        assertEq(alice.balance, 0.1e18 + totalOut, "test_SwapExactInTokenToNative::4");
    }

    function test_SwapExactOutTokenToNative() public {
        uint128 amountOut = 35e18;
        uint256 maxAmountIn = 1500e6;

        vm.deal(alice, 0.1e18);
        deal(USDT, alice, maxAmountIn);

        (bytes memory route, uint256 ptr, uint256 extraDataPtr) =
            _createRoutesWithExtraData(3, 2, UNISWAP_V4_EXTRA_DATA_SIZE * 2);
        ptr = _setIsTransferTaxToken(route, ptr, false);
        ptr = _setToken(route, ptr, USDT);
        ptr = _setToken(route, ptr, USDC);
        ptr = _setToken(route, ptr, WAVAX);

        (ptr, extraDataPtr) = _setRouteUV4(
            route,
            ptr,
            extraDataPtr,
            USDT,
            USDC,
            1e4,
            ZERO_FOR_ONE | UV4_ID | CALLBACK,
            ExtraDataUV4({
                fee: UV4_USDT_USDC_FEE,
                tickSpacing: UV4_USDT_USDC_TICK_SPACING,
                nativeFlag: UV4_NATIVE_FLAG_NONE,
                hooks: NO_HOOKS,
                hookData: ""
            })
        );
        (ptr, extraDataPtr) = _setRouteUV4(
            route,
            ptr,
            extraDataPtr,
            USDC,
            WAVAX,
            1e4,
            ONE_FOR_ZERO | UV4_ID | CALLBACK,
            ExtraDataUV4({
                fee: UV4_WAVAX_USDC_FEE,
                tickSpacing: UV4_WAVAX_USDC_TICK_SPACING,
                nativeFlag: UV4_NATIVE_FLAG_OUT,
                hooks: NO_HOOKS,
                hookData: ""
            })
        );

        vm.startPrank(alice);
        MockERC20(USDT).approve(address(router), maxAmountIn);

        (uint256 totalIn, uint256 totalOut) = router.swapExactOut{value: 0.1e18}(
            address(logic), USDT, address(0), amountOut, maxAmountIn, alice, block.timestamp, route
        );
        vm.stopPrank();

        assertLe(totalIn, maxAmountIn, "test_SwapExactOutTokenToNative::1");
        assertGe(totalOut, amountOut, "test_SwapExactOutTokenToNative::2");
        assertEq(IERC20(USDT).balanceOf(alice), maxAmountIn - totalIn, "test_SwapExactOutTokenToNative::3");
        assertEq(alice.balance, 0.1e18 + totalOut, "test_SwapExactOutTokenToNative::4");
    }
}
