// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import "../src/Router.sol";
import "../src/RouterLogic.sol";
import "./PackedRouteHelper.sol";

contract RouterIntegrationTest is Test, PackedRouteHelper {
    Router public router;
    RouterLogic public logic;

    address public WAVAX = 0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7;
    address public WETH = 0x49D5c2BdFfac6CE2BFdB6640F4F80f226bc10bAB;
    address public USDC = 0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E;
    address public USDT = 0x9702230A8Ea53601f5cD2dc00fDBc13d4dF4A8c7;
    address public BTCB = 0x152b9d0FdC40C096757F570A51E494bd4b943E50;

    address public TJ1_WETH_AVAX = 0xFE15c2695F1F920da45C30AAE47d11dE51007AF9;
    address public TJ1_AVAX_USDC = 0xf4003F4efBE8691B60249E6afbD307aBE7758adb;
    address public TJ1_USDT_USDC = 0x8D5dB5D48F5C46A4263DC46112B5d2e3c5626423;

    address public LB0_WETH_AVAX = 0x42Be75636374dfA0e57EB96fA7F68fE7FcdAD8a3;
    address public LB0_AVAX_USDC = 0xB5352A39C11a81FE6748993D586EC448A01f08b5;
    address public LB0_USDT_USDC = 0x1D7A1a79e2b4Ef88D2323f3845246D24a3c20F1d;
    address public LB0_ROUTER = 0xE3Ffc583dC176575eEA7FD9dF2A7c65F7E23f4C3;

    address public LB1_WETH_AVAX = 0x1901011a39B11271578a1283D620373aBeD66faA;
    address public LB1_AVAX_USDC = 0xD446eb1660F766d533BeCeEf890Df7A69d26f7d1;
    address public LB2_USDT_USDC = 0x2823299af89285fF1a1abF58DB37cE57006FEf5D;
    address public LB1_BTCB_AVAX = 0xD9fa522F5BC6cfa40211944F2C8DA785773Ad99D;
    address public LB2_AVAX_BTCB = 0x856b38Bf1e2E367F747DD4d3951DDA8a35F1bF60;
    address public LB2_BTCB_USDC = 0x4224f6F4C9280509724Db2DbAc314621e4465C29;
    address public LB2_WETH_BTCB = 0x632349B44Af299Ab83cB9F21F65c218122fD4772;

    address public UV3_WETH_AVAX = 0x7b602f98D71715916E7c963f51bfEbC754aDE2d0;
    address public UV3_AVAX_USDC = 0xfAe3f424a0a47706811521E3ee268f00cFb5c45E;
    address public UV3_USDT_USDC = 0x804226cA4EDb38e7eF56D16d16E92dc3223347A0;
    address public UV3_BTCB_USDC = 0xD1356d360F37932059E5b89b7992692aA234EDA6;

    address alice = makeAddr("Alice");

    function setUp() public {
        vm.createSelectFork(StdChains.getChain("avalanche").rpcUrl, 50448676);

        router = new Router(WAVAX, address(this));
        logic = new RouterLogic(address(router), LB0_ROUTER);

        router.updateRouterLogic(address(logic));

        vm.label(address(router), "Router");
        vm.label(address(logic), "RouterLogic");
        vm.label(WAVAX, "WAVAX");
        vm.label(WETH, "WETH");
        vm.label(USDC, "USDC");
        vm.label(USDT, "USDT");
        vm.label(BTCB, "BTCB");
        vm.label(TJ1_WETH_AVAX, "TJ1_WETH_AVAX");
        vm.label(TJ1_AVAX_USDC, "TJ1_AVAX_USDC");
        vm.label(TJ1_USDT_USDC, "TJ1_USDT_USDC");
        vm.label(LB0_WETH_AVAX, "LB0_WETH_AVAX");
        vm.label(LB0_AVAX_USDC, "LB0_AVAX_USDC");
        vm.label(LB0_USDT_USDC, "LB0_USDT_USDC");
        vm.label(LB0_ROUTER, "LB0_ROUTER");
        vm.label(LB1_WETH_AVAX, "LB1_WETH_AVAX");
        vm.label(LB1_AVAX_USDC, "LB1_AVAX_USDC");
        vm.label(LB2_USDT_USDC, "LB2_USDT_USDC");
        vm.label(LB1_BTCB_AVAX, "LB1_BTCB_AVAX");
        vm.label(LB2_AVAX_BTCB, "LB2_AVAX_BTCB");
        vm.label(LB2_BTCB_USDC, "LB2_BTCB_USDC");
        vm.label(LB2_WETH_BTCB, "LB2_WETH_BTCB");
        vm.label(UV3_WETH_AVAX, "UV3_WETH_AVAX");
        vm.label(UV3_AVAX_USDC, "UV3_AVAX_USDC");
        vm.label(UV3_USDT_USDC, "UV3_USDT_USDC");
        vm.label(UV3_BTCB_USDC, "UV3_BTCB_USDC");
    }

    function test_SwapExactInTokenToToken() public {
        uint128 amountIn = 1e18;

        vm.deal(alice, 0.1e18);
        deal(WETH, alice, amountIn);

        (bytes memory routes, uint256 ptr) = _createRoutes(5, 13);

        ptr = _setIsTransferTaxToken(routes, ptr, false);
        ptr = _setToken(routes, ptr, WETH);
        ptr = _setToken(routes, ptr, WAVAX);
        ptr = _setToken(routes, ptr, BTCB);
        ptr = _setToken(routes, ptr, USDC);
        ptr = _setToken(routes, ptr, USDT);

        ptr = _setRoute(routes, ptr, WETH, WAVAX, UV3_WETH_AVAX, 0.2e4, UV3_ID | CALLBACK | ZERO_FOR_ONE);
        ptr = _setRoute(routes, ptr, WETH, BTCB, LB2_WETH_BTCB, 0.3e4, LB12_ID | ZERO_FOR_ONE);
        ptr = _setRoute(routes, ptr, WETH, WAVAX, LB1_WETH_AVAX, 1.0e4, LB12_ID | ZERO_FOR_ONE);
        ptr = _setRoute(routes, ptr, BTCB, WAVAX, LB2_AVAX_BTCB, 0.4e4, LB12_ID | ONE_FOR_ZERO);
        ptr = _setRoute(routes, ptr, BTCB, WAVAX, LB1_BTCB_AVAX, 0.4e4, LB12_ID | ZERO_FOR_ONE);
        ptr = _setRoute(routes, ptr, WAVAX, USDC, UV3_AVAX_USDC, 0.3e4, UV3_ID | CALLBACK | ZERO_FOR_ONE);
        ptr = _setRoute(routes, ptr, WAVAX, USDC, TJ1_AVAX_USDC, 0.6e4, TJ1_ID | ZERO_FOR_ONE);
        ptr = _setRoute(routes, ptr, WAVAX, USDC, LB0_AVAX_USDC, 0.0001e4, LB0_ID | ZERO_FOR_ONE);
        ptr = _setRoute(routes, ptr, WAVAX, USDC, LB1_AVAX_USDC, 1.0e4, LB12_ID | ZERO_FOR_ONE);
        ptr = _setRoute(routes, ptr, BTCB, USDC, UV3_BTCB_USDC, 0.6e4, UV3_ID | CALLBACK | ZERO_FOR_ONE);
        ptr = _setRoute(routes, ptr, BTCB, USDC, LB2_BTCB_USDC, 1.0e4, LB12_ID | ZERO_FOR_ONE);
        ptr = _setRoute(routes, ptr, USDC, USDT, UV3_USDT_USDC, 0.4e4, UV3_ID | CALLBACK | ONE_FOR_ZERO);
        ptr = _setRoute(routes, ptr, USDC, USDT, LB2_USDT_USDC, 1.0e4, LB12_ID | ONE_FOR_ZERO);

        vm.startPrank(alice);
        IERC20(WETH).approve(address(router), amountIn);

        bytes[] memory multiRoutes = new bytes[](3);

        multiRoutes[0] = routes;
        multiRoutes[1] = routes;

        (, bytes memory data) = address(router).call{value: 0.1e18}(
            abi.encodeWithSelector(IRouter.simulate.selector, WETH, USDT, amountIn, 0, true, multiRoutes)
        );

        uint256 expectedOut;
        {
            uint256[] memory values;

            assembly {
                values := add(data, 68)
            }

            assertEq(values.length, 3, "test_SwapExactInTokenToToken::1");
            assertEq(values[0], values[1], "test_SwapExactInTokenToToken::2");
            assertEq(values[2], 0, "test_SwapExactInTokenToToken::3");

            expectedOut = values[0];
        }

        (uint256 totalIn, uint256 totalOut) =
            router.swapExactIn{value: 0.1e18}(WETH, USDT, amountIn, 0, alice, block.timestamp, routes);
        vm.stopPrank();

        assertEq(totalIn, amountIn, "test_SwapExactInTokenToToken::3");
        assertGt(totalOut, 0, "test_SwapExactInTokenToToken::4");
        assertEq(totalOut, expectedOut, "test_SwapExactInTokenToToken::5");
        assertEq(alice.balance, 0.1e18, "test_SwapExactInTokenToToken::6");
        assertEq(IERC20(WETH).balanceOf(alice), 0, "test_SwapExactInTokenToToken::7");
        assertEq(IERC20(USDT).balanceOf(alice), totalOut, "test_SwapExactInTokenToToken::8");
    }

    function test_SwapExactOutTokenToToken() public {
        uint128 amountOut = 1000e6;
        uint256 maxAmountIn = 1e18;

        vm.deal(alice, 0.1e18);
        deal(WETH, alice, maxAmountIn);

        (bytes memory routes, uint256 ptr) = _createRoutes(5, 13);

        ptr = _setIsTransferTaxToken(routes, ptr, false);
        ptr = _setToken(routes, ptr, WETH);
        ptr = _setToken(routes, ptr, WAVAX);
        ptr = _setToken(routes, ptr, BTCB);
        ptr = _setToken(routes, ptr, USDC);
        ptr = _setToken(routes, ptr, USDT);

        ptr = _setRoute(routes, ptr, WETH, WAVAX, LB1_WETH_AVAX, 1.0e4, LB12_ID | ZERO_FOR_ONE);
        ptr = _setRoute(routes, ptr, WETH, BTCB, LB2_WETH_BTCB, 1.0e4, LB12_ID | ZERO_FOR_ONE);
        ptr = _setRoute(routes, ptr, WETH, WAVAX, UV3_WETH_AVAX, 0.2e4, UV3_ID | CALLBACK | ZERO_FOR_ONE);
        ptr = _setRoute(routes, ptr, BTCB, WAVAX, LB1_BTCB_AVAX, 0.06e4, LB12_ID | ZERO_FOR_ONE);
        ptr = _setRoute(routes, ptr, BTCB, WAVAX, LB2_AVAX_BTCB, 0.1e4, LB12_ID | ONE_FOR_ZERO);
        ptr = _setRoute(routes, ptr, WAVAX, USDC, LB1_AVAX_USDC, 1.0e4, LB12_ID | ZERO_FOR_ONE);
        ptr = _setRoute(routes, ptr, WAVAX, USDC, LB0_AVAX_USDC, 0.0001e4, LB0_ID | ZERO_FOR_ONE);
        ptr = _setRoute(routes, ptr, WAVAX, USDC, TJ1_AVAX_USDC, 0.4e4, TJ1_ID | ZERO_FOR_ONE);
        ptr = _setRoute(routes, ptr, WAVAX, USDC, UV3_AVAX_USDC, 0.3e4, UV3_ID | CALLBACK | ZERO_FOR_ONE);
        ptr = _setRoute(routes, ptr, BTCB, USDC, LB2_BTCB_USDC, 0.06e4, LB12_ID | ZERO_FOR_ONE);
        ptr = _setRoute(routes, ptr, BTCB, USDC, UV3_BTCB_USDC, 0.04e4, UV3_ID | CALLBACK | ZERO_FOR_ONE);
        ptr = _setRoute(routes, ptr, USDC, USDT, LB2_USDT_USDC, 1.0e4, LB12_ID | ONE_FOR_ZERO);
        ptr = _setRoute(routes, ptr, USDC, USDT, UV3_USDT_USDC, 0.4e4, UV3_ID | CALLBACK | ONE_FOR_ZERO);

        vm.startPrank(alice);
        IERC20(WETH).approve(address(router), maxAmountIn);

        bytes[] memory multiRoutes = new bytes[](3);

        multiRoutes[0] = routes;
        multiRoutes[1] = routes;

        (, bytes memory data) = address(router).call{value: 0.1e18}(
            abi.encodeWithSelector(
                IRouter.simulate.selector, WETH, USDT, type(uint128).max, amountOut, false, multiRoutes
            )
        );

        uint256 expectedIn;
        {
            uint256[] memory values;

            assembly {
                values := add(data, 68)
            }

            assertEq(values.length, 3, "test_SwapExactInTokenToToken::1");
            assertEq(values[0], values[1], "test_SwapExactInTokenToToken::2");
            assertEq(values[2], type(uint256).max, "test_SwapExactInTokenToToken::3");

            expectedIn = values[0];
        }

        (uint256 totalIn, uint256 totalOut) =
            router.swapExactOut{value: 0.1e18}(WETH, USDT, amountOut, maxAmountIn, alice, block.timestamp, routes);
        vm.stopPrank();

        assertLe(totalIn, maxAmountIn, "test_SwapExactOutTokenToToken::1");
        assertEq(totalIn, expectedIn, "test_SwapExactOutTokenToToken::3");
        assertGe(totalOut, amountOut, "test_SwapExactOutTokenToToken::2");
        assertEq(alice.balance, 0.1e18, "test_SwapExactOutTokenToToken::3");
        assertEq(IERC20(WETH).balanceOf(alice), maxAmountIn - totalIn, "test_SwapExactOutTokenToToken::4");
        assertEq(IERC20(USDT).balanceOf(alice), amountOut, "test_SwapExactOutTokenToToken::5");
    }

    function test_SwapExactInNativeToToken() public {
        uint128 amountIn = 1e18;

        vm.deal(alice, amountIn + 0.1e18);

        (bytes memory routes, uint256 ptr) = _createRoutes(4, 10);

        ptr = _setIsTransferTaxToken(routes, ptr, false);
        ptr = _setToken(routes, ptr, WAVAX);
        ptr = _setToken(routes, ptr, BTCB);
        ptr = _setToken(routes, ptr, USDC);
        ptr = _setToken(routes, ptr, USDT);

        ptr = _setRoute(routes, ptr, WAVAX, USDC, UV3_AVAX_USDC, 0.2e4, UV3_ID | CALLBACK | ZERO_FOR_ONE);
        ptr = _setRoute(routes, ptr, WAVAX, BTCB, LB2_AVAX_BTCB, 0.3e4, LB12_ID | ZERO_FOR_ONE);
        ptr = _setRoute(routes, ptr, WAVAX, BTCB, LB1_BTCB_AVAX, 0.4e4, LB12_ID | ONE_FOR_ZERO);
        ptr = _setRoute(routes, ptr, WAVAX, USDC, TJ1_AVAX_USDC, 0.5e4, TJ1_ID | ZERO_FOR_ONE);
        ptr = _setRoute(routes, ptr, WAVAX, USDC, LB0_AVAX_USDC, 0.0001e4, LB0_ID | ZERO_FOR_ONE);
        ptr = _setRoute(routes, ptr, WAVAX, USDC, LB1_AVAX_USDC, 1.0e4, LB12_ID | ZERO_FOR_ONE);
        ptr = _setRoute(routes, ptr, BTCB, USDC, UV3_BTCB_USDC, 0.6e4, UV3_ID | CALLBACK | ZERO_FOR_ONE);
        ptr = _setRoute(routes, ptr, BTCB, USDC, LB2_BTCB_USDC, 1.0e4, LB12_ID | ZERO_FOR_ONE);
        ptr = _setRoute(routes, ptr, USDC, USDT, UV3_USDT_USDC, 0.4e4, UV3_ID | CALLBACK | ONE_FOR_ZERO);
        ptr = _setRoute(routes, ptr, USDC, USDT, LB2_USDT_USDC, 1.0e4, LB12_ID | ONE_FOR_ZERO);

        vm.prank(alice);
        (uint256 totalIn, uint256 totalOut) =
            router.swapExactIn{value: amountIn + 0.1e18}(address(0), USDT, amountIn, 0, alice, block.timestamp, routes);

        assertEq(totalIn, amountIn, "test_SwapExactInNativeToToken::1");
        assertGt(totalOut, 0, "test_SwapExactInNativeToToken::2");
        assertEq(alice.balance, 0.1e18, "test_SwapExactInNativeToToken::3");
        assertEq(IERC20(USDT).balanceOf(alice), totalOut, "test_SwapExactInNativeToToken::4");
    }

    function test_SwapExactOutNativeToToken() public {
        uint128 amountOut = 1000e6;
        uint256 maxAmountIn = 100e18;

        vm.deal(alice, maxAmountIn + 0.1e18);

        (bytes memory routes, uint256 ptr) = _createRoutes(4, 10);

        ptr = _setIsTransferTaxToken(routes, ptr, false);
        ptr = _setToken(routes, ptr, WAVAX);
        ptr = _setToken(routes, ptr, BTCB);
        ptr = _setToken(routes, ptr, USDC);
        ptr = _setToken(routes, ptr, USDT);

        ptr = _setRoute(routes, ptr, WAVAX, USDC, UV3_AVAX_USDC, 1.0e4, UV3_ID | CALLBACK | ZERO_FOR_ONE);
        ptr = _setRoute(routes, ptr, WAVAX, BTCB, LB2_AVAX_BTCB, 1.0e4, LB12_ID | ZERO_FOR_ONE);
        ptr = _setRoute(routes, ptr, WAVAX, BTCB, LB1_BTCB_AVAX, 0.4e4, LB12_ID | ONE_FOR_ZERO);
        ptr = _setRoute(routes, ptr, WAVAX, USDC, TJ1_AVAX_USDC, 0.6e4, TJ1_ID | ZERO_FOR_ONE);
        ptr = _setRoute(routes, ptr, WAVAX, USDC, LB1_AVAX_USDC, 0.5e4, LB12_ID | ZERO_FOR_ONE);
        ptr = _setRoute(routes, ptr, WAVAX, USDC, LB0_AVAX_USDC, 0.0001e4, LB0_ID | ZERO_FOR_ONE);
        ptr = _setRoute(routes, ptr, BTCB, USDC, UV3_BTCB_USDC, 0.4e4, UV3_ID | CALLBACK | ZERO_FOR_ONE);
        ptr = _setRoute(routes, ptr, BTCB, USDC, LB2_BTCB_USDC, 0.3e4, LB12_ID | ZERO_FOR_ONE);
        ptr = _setRoute(routes, ptr, USDC, USDT, UV3_USDT_USDC, 1.0e4, UV3_ID | CALLBACK | ONE_FOR_ZERO);
        ptr = _setRoute(routes, ptr, USDC, USDT, LB2_USDT_USDC, 0.6e4, LB12_ID | ONE_FOR_ZERO);

        vm.prank(alice);
        (uint256 totalIn, uint256 totalOut) = router.swapExactOut{value: maxAmountIn + 0.1e18}(
            address(0), USDT, amountOut, maxAmountIn, alice, block.timestamp, routes
        );

        assertLe(totalIn, maxAmountIn, "test_SwapExactOutNativeToToken::1");
        assertGe(totalOut, amountOut, "test_SwapExactOutNativeToToken::2");
        assertEq(alice.balance, maxAmountIn + 0.1e18 - totalIn, "test_SwapExactOutNativeToToken::3");
        assertEq(IERC20(USDT).balanceOf(alice), amountOut, "test_SwapExactOutNativeToToken::4");
    }

    function test_SwapExactInTokenToNative() public {
        uint128 amountIn = 1_000e6;

        vm.deal(alice, 0.1e18);
        deal(USDT, alice, amountIn);

        (bytes memory routes, uint256 ptr) = _createRoutes(4, 10);

        ptr = _setIsTransferTaxToken(routes, ptr, false);
        ptr = _setToken(routes, ptr, USDT);
        ptr = _setToken(routes, ptr, USDC);
        ptr = _setToken(routes, ptr, BTCB);
        ptr = _setToken(routes, ptr, WAVAX);

        ptr = _setRoute(routes, ptr, USDT, USDC, UV3_USDT_USDC, 0.4e4, UV3_ID | CALLBACK | ZERO_FOR_ONE);
        ptr = _setRoute(routes, ptr, USDT, USDC, LB2_USDT_USDC, 1.0e4, LB12_ID | ZERO_FOR_ONE);
        ptr = _setRoute(routes, ptr, USDC, BTCB, UV3_BTCB_USDC, 0.2e4, UV3_ID | CALLBACK | ONE_FOR_ZERO);
        ptr = _setRoute(routes, ptr, USDC, BTCB, LB2_BTCB_USDC, 0.3e4, LB12_ID | ONE_FOR_ZERO);
        ptr = _setRoute(routes, ptr, USDC, WAVAX, TJ1_AVAX_USDC, 0.3e4, TJ1_ID | ONE_FOR_ZERO);
        ptr = _setRoute(routes, ptr, USDC, WAVAX, UV3_AVAX_USDC, 0.5e4, UV3_ID | CALLBACK | ONE_FOR_ZERO);
        ptr = _setRoute(routes, ptr, BTCB, WAVAX, LB2_AVAX_BTCB, 0.4e4, LB12_ID | ONE_FOR_ZERO);
        ptr = _setRoute(routes, ptr, BTCB, WAVAX, LB1_BTCB_AVAX, 1.0e4, LB12_ID | ZERO_FOR_ONE);
        ptr = _setRoute(routes, ptr, USDC, WAVAX, LB0_AVAX_USDC, 0.0001e4, LB0_ID | ONE_FOR_ZERO);
        ptr = _setRoute(routes, ptr, USDC, WAVAX, LB1_AVAX_USDC, 1.0e4, LB12_ID | ONE_FOR_ZERO);

        vm.startPrank(alice);
        IERC20(USDT).approve(address(router), amountIn);
        (uint256 totalIn, uint256 totalOut) =
            router.swapExactIn{value: 0.1e18}(USDT, address(0), amountIn, 0, alice, block.timestamp, routes);
        vm.stopPrank();

        assertEq(totalIn, amountIn, "test_SwapExactInTokenToNative::1");
        assertGt(totalOut, 0, "test_SwapExactInTokenToNative::2");
        assertEq(alice.balance, 0.1e18 + totalOut, "test_SwapExactInTokenToNative::3");
        assertEq(IERC20(USDT).balanceOf(alice), 0, "test_SwapExactInTokenToNative::4");
    }

    function test_SwapExactOutTokenToNative() public {
        uint128 amountOut = 1e18;
        uint256 maxAmountIn = 1000e6;

        vm.deal(alice, 0.1e18);
        deal(USDT, alice, maxAmountIn);

        (bytes memory routes, uint256 ptr) = _createRoutes(4, 10);

        ptr = _setIsTransferTaxToken(routes, ptr, false);
        ptr = _setToken(routes, ptr, USDT);
        ptr = _setToken(routes, ptr, USDC);
        ptr = _setToken(routes, ptr, BTCB);
        ptr = _setToken(routes, ptr, WAVAX);

        ptr = _setRoute(routes, ptr, USDT, USDC, UV3_USDT_USDC, 1.0e4, UV3_ID | CALLBACK | ZERO_FOR_ONE);
        ptr = _setRoute(routes, ptr, USDT, USDC, LB2_USDT_USDC, 0.6e4, LB12_ID | ZERO_FOR_ONE);
        ptr = _setRoute(routes, ptr, USDC, BTCB, UV3_BTCB_USDC, 1.0e4, UV3_ID | CALLBACK | ONE_FOR_ZERO);
        ptr = _setRoute(routes, ptr, USDC, BTCB, LB2_BTCB_USDC, 0.6e4, LB12_ID | ONE_FOR_ZERO);
        ptr = _setRoute(routes, ptr, USDC, WAVAX, TJ1_AVAX_USDC, 1.0e4, TJ1_ID | ONE_FOR_ZERO);
        ptr = _setRoute(routes, ptr, USDC, WAVAX, UV3_AVAX_USDC, 0.6e4, UV3_ID | CALLBACK | ONE_FOR_ZERO);
        ptr = _setRoute(routes, ptr, BTCB, WAVAX, LB2_AVAX_BTCB, 0.5e4, LB12_ID | ONE_FOR_ZERO);
        ptr = _setRoute(routes, ptr, BTCB, WAVAX, LB1_BTCB_AVAX, 0.4e4, LB12_ID | ZERO_FOR_ONE);
        ptr = _setRoute(routes, ptr, USDC, WAVAX, LB1_AVAX_USDC, 0.3e4, LB12_ID | ONE_FOR_ZERO);
        ptr = _setRoute(routes, ptr, USDC, WAVAX, LB0_AVAX_USDC, 0.0001e4, LB0_ID | ONE_FOR_ZERO);

        vm.startPrank(alice);
        IERC20(USDT).approve(address(router), maxAmountIn);
        (uint256 totalIn, uint256 totalOut) =
            router.swapExactOut{value: 0.1e18}(USDT, address(0), amountOut, maxAmountIn, alice, block.timestamp, routes);
        vm.stopPrank();

        assertLe(totalIn, maxAmountIn, "test_SwapExactOutTokenToNative::1");
        assertGe(totalOut, amountOut, "test_SwapExactOutTokenToNative::2");
        assertEq(alice.balance, 0.1e18 + totalOut, "test_SwapExactOutTokenToNative::3");
        assertEq(IERC20(USDT).balanceOf(alice), maxAmountIn - totalIn, "test_SwapExactOutTokenToNative::4");
    }
}
