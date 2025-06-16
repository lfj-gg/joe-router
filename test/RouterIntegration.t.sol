// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import "../src/Router.sol";
import "../src/RouterLogic.sol";
import "./PackedRouteHelper.sol";
import "./mocks/MockERC20.sol";

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
    address feeReceiver = makeAddr("FeeReceiver");
    address thirdPartyFeeReceiver = makeAddr("thirdPartyFeeReceiver");

    uint16 FEE_BIPS = 0.15e4; // 15%

    function setUp() public virtual {
        vm.createSelectFork(StdChains.getChain("avalanche").rpcUrl, 50448676);

        router = new Router(WAVAX, address(this));
        logic = new RouterLogic(address(router), LB0_ROUTER, feeReceiver, FEE_BIPS);

        router.updateRouterLogic(address(logic), true);

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

        (bytes memory route, uint256 ptr) = _createRoutes(5, 13);

        ptr = _setIsTransferTaxToken(route, ptr, false);
        ptr = _setToken(route, ptr, WETH);
        ptr = _setToken(route, ptr, WAVAX);
        ptr = _setToken(route, ptr, BTCB);
        ptr = _setToken(route, ptr, USDC);
        ptr = _setToken(route, ptr, USDT);

        ptr = _setRoute(route, ptr, WETH, WAVAX, UV3_WETH_AVAX, 0.2e4, UV3_ID | CALLBACK | ZERO_FOR_ONE);
        ptr = _setRoute(route, ptr, WETH, BTCB, LB2_WETH_BTCB, 0.3e4, LB12_ID | ZERO_FOR_ONE);
        ptr = _setRoute(route, ptr, WETH, WAVAX, LB1_WETH_AVAX, 1.0e4, LB12_ID | ZERO_FOR_ONE);
        ptr = _setRoute(route, ptr, BTCB, WAVAX, LB2_AVAX_BTCB, 0.4e4, LB12_ID | ONE_FOR_ZERO);
        ptr = _setRoute(route, ptr, BTCB, WAVAX, LB1_BTCB_AVAX, 0.4e4, LB12_ID | ZERO_FOR_ONE);
        ptr = _setRoute(route, ptr, WAVAX, USDC, UV3_AVAX_USDC, 0.3e4, UV3_ID | CALLBACK | ZERO_FOR_ONE);
        ptr = _setRoute(route, ptr, WAVAX, USDC, TJ1_AVAX_USDC, 0.6e4, TJ1_ID | ZERO_FOR_ONE);
        ptr = _setRoute(route, ptr, WAVAX, USDC, LB0_AVAX_USDC, 0.0001e4, LB0_ID | ZERO_FOR_ONE);
        ptr = _setRoute(route, ptr, WAVAX, USDC, LB1_AVAX_USDC, 1.0e4, LB12_ID | ZERO_FOR_ONE);
        ptr = _setRoute(route, ptr, BTCB, USDC, UV3_BTCB_USDC, 0.6e4, UV3_ID | CALLBACK | ZERO_FOR_ONE);
        ptr = _setRoute(route, ptr, BTCB, USDC, LB2_BTCB_USDC, 1.0e4, LB12_ID | ZERO_FOR_ONE);
        ptr = _setRoute(route, ptr, USDC, USDT, UV3_USDT_USDC, 0.4e4, UV3_ID | CALLBACK | ONE_FOR_ZERO);
        ptr = _setRoute(route, ptr, USDC, USDT, LB2_USDT_USDC, 1.0e4, LB12_ID | ONE_FOR_ZERO);

        vm.startPrank(alice);
        IERC20(WETH).approve(address(router), amountIn);

        uint256 expectedOut;
        {
            bytes[] memory multiRoutes = new bytes[](3);

            multiRoutes[0] = route;
            multiRoutes[1] = route;

            (, bytes memory data) = address(router).call{value: 0.1e18}(
                abi.encodeWithSelector(
                    IRouter.simulate.selector, logic, WETH, USDT, amountIn, 1, alice, true, multiRoutes
                )
            );

            uint256[] memory values;

            assembly ("memory-safe") {
                values := add(data, 68)
            }

            assertEq(values.length, 3, "test_SwapExactInTokenToToken::1");
            assertEq(values[0], values[1], "test_SwapExactInTokenToToken::2");
            assertEq(values[2], 0, "test_SwapExactInTokenToToken::3");

            expectedOut = values[0];
        }

        (uint256 totalIn, uint256 totalOut) =
            router.swapExactIn{value: 0.1e18}(address(logic), WETH, USDT, amountIn, 1, alice, block.timestamp, route);
        vm.stopPrank();

        assertEq(totalIn, amountIn, "test_SwapExactInTokenToToken::4");
        assertGt(totalOut, 0, "test_SwapExactInTokenToToken::5");
        assertEq(totalOut, expectedOut, "test_SwapExactInTokenToToken::6");
        assertEq(alice.balance, 0.1e18, "test_SwapExactInTokenToToken::7");
        assertEq(IERC20(WETH).balanceOf(alice), 0, "test_SwapExactInTokenToToken::8");
        assertEq(IERC20(USDT).balanceOf(alice), totalOut, "test_SwapExactInTokenToToken::9");
    }

    function test_SwapExactInTokenToTokenWithFeeIn() public {
        uint128 amountIn = 1e18;

        vm.deal(alice, 0.1e18);
        deal(WETH, alice, amountIn);

        (bytes memory route, uint256 ptr) = _createRoutes(5, 14);

        ptr = _setIsTransferTaxToken(route, ptr, false);
        ptr = _setToken(route, ptr, WETH);
        ptr = _setToken(route, ptr, WAVAX);
        ptr = _setToken(route, ptr, BTCB);
        ptr = _setToken(route, ptr, USDC);
        ptr = _setToken(route, ptr, USDT);

        ptr = _setFeePercentIn(route, ptr, thirdPartyFeeReceiver, 0.1e4); // 10% fee
        ptr = _setRoute(route, ptr, WETH, WAVAX, UV3_WETH_AVAX, 0.2e4, UV3_ID | CALLBACK | ZERO_FOR_ONE);
        ptr = _setRoute(route, ptr, WETH, BTCB, LB2_WETH_BTCB, 0.3e4, LB12_ID | ZERO_FOR_ONE);
        ptr = _setRoute(route, ptr, WETH, WAVAX, LB1_WETH_AVAX, 1.0e4, LB12_ID | ZERO_FOR_ONE);
        ptr = _setRoute(route, ptr, BTCB, WAVAX, LB2_AVAX_BTCB, 0.4e4, LB12_ID | ONE_FOR_ZERO);
        ptr = _setRoute(route, ptr, BTCB, WAVAX, LB1_BTCB_AVAX, 0.4e4, LB12_ID | ZERO_FOR_ONE);
        ptr = _setRoute(route, ptr, WAVAX, USDC, UV3_AVAX_USDC, 0.3e4, UV3_ID | CALLBACK | ZERO_FOR_ONE);
        ptr = _setRoute(route, ptr, WAVAX, USDC, TJ1_AVAX_USDC, 0.6e4, TJ1_ID | ZERO_FOR_ONE);
        ptr = _setRoute(route, ptr, WAVAX, USDC, LB0_AVAX_USDC, 0.0001e4, LB0_ID | ZERO_FOR_ONE);
        ptr = _setRoute(route, ptr, WAVAX, USDC, LB1_AVAX_USDC, 1.0e4, LB12_ID | ZERO_FOR_ONE);
        ptr = _setRoute(route, ptr, BTCB, USDC, UV3_BTCB_USDC, 0.6e4, UV3_ID | CALLBACK | ZERO_FOR_ONE);
        ptr = _setRoute(route, ptr, BTCB, USDC, LB2_BTCB_USDC, 1.0e4, LB12_ID | ZERO_FOR_ONE);
        ptr = _setRoute(route, ptr, USDC, USDT, UV3_USDT_USDC, 0.4e4, UV3_ID | CALLBACK | ONE_FOR_ZERO);
        ptr = _setRoute(route, ptr, USDC, USDT, LB2_USDT_USDC, 1.0e4, LB12_ID | ONE_FOR_ZERO);

        vm.startPrank(alice);
        IERC20(WETH).approve(address(router), amountIn);

        uint256 expectedOut;
        {
            bytes[] memory multiRoutes = new bytes[](3);

            multiRoutes[0] = route;
            multiRoutes[1] = route;

            (, bytes memory data) = address(router).call{value: 0.1e18}(
                abi.encodeWithSelector(
                    IRouter.simulate.selector, logic, WETH, USDT, amountIn, 1, alice, true, multiRoutes
                )
            );

            uint256[] memory values;

            assembly ("memory-safe") {
                values := add(data, 68)
            }

            assertEq(values.length, 3, "test_SwapExactInTokenToTokenWithFee::1");
            assertEq(values[0], values[1], "test_SwapExactInTokenToTokenWithFee::2");
            assertEq(values[2], 0, "test_SwapExactInTokenToTokenWithFee::3");

            expectedOut = values[0];
        }

        (uint256 totalIn, uint256 totalOut) =
            router.swapExactIn{value: 0.1e18}(address(logic), WETH, USDT, amountIn, 1, alice, block.timestamp, route);
        vm.stopPrank();

        uint256 feeAmount = amountIn * 0.1e4 / 1e4;
        uint256 protocolFeeAmount = feeAmount * FEE_BIPS / 1e4;

        assertEq(totalIn, amountIn, "test_SwapExactInTokenToTokenWithFee::4");
        assertGt(totalOut, 0, "test_SwapExactInTokenToTokenWithFee::5");
        assertEq(totalOut, expectedOut, "test_SwapExactInTokenToTokenWithFee::6");
        assertEq(alice.balance, 0.1e18, "test_SwapExactInTokenToTokenWithFee::7");
        assertEq(IERC20(WETH).balanceOf(alice), 0, "test_SwapExactInTokenToTokenWithFee::8");
        assertEq(IERC20(WETH).balanceOf(feeReceiver), protocolFeeAmount, "test_SwapExactInTokenToTokenWithFee::9");
        assertEq(
            IERC20(WETH).balanceOf(thirdPartyFeeReceiver),
            feeAmount - protocolFeeAmount,
            "test_SwapExactInTokenToTokenWithFee::10"
        );
        assertEq(IERC20(USDT).balanceOf(alice), totalOut, "test_SwapExactInTokenToTokenWithFee::11");
    }

    function test_SwapExactInTokenToTokenWithFeeOut() public {
        uint128 amountIn = 1e18;

        vm.deal(alice, 0.1e18);
        deal(WETH, alice, amountIn);

        (bytes memory route, uint256 ptr) = _createRoutes(5, 14);

        ptr = _setIsTransferTaxToken(route, ptr, false);
        ptr = _setToken(route, ptr, WETH);
        ptr = _setToken(route, ptr, WAVAX);
        ptr = _setToken(route, ptr, BTCB);
        ptr = _setToken(route, ptr, USDC);
        ptr = _setToken(route, ptr, USDT);

        ptr = _setFeePercentOut(route, ptr, thirdPartyFeeReceiver, 0.1e4); // 10% fee
        ptr = _setRoute(route, ptr, WETH, WAVAX, UV3_WETH_AVAX, 0.2e4, UV3_ID | CALLBACK | ZERO_FOR_ONE);
        ptr = _setRoute(route, ptr, WETH, BTCB, LB2_WETH_BTCB, 0.3e4, LB12_ID | ZERO_FOR_ONE);
        ptr = _setRoute(route, ptr, WETH, WAVAX, LB1_WETH_AVAX, 1.0e4, LB12_ID | ZERO_FOR_ONE);
        ptr = _setRoute(route, ptr, BTCB, WAVAX, LB2_AVAX_BTCB, 0.4e4, LB12_ID | ONE_FOR_ZERO);
        ptr = _setRoute(route, ptr, BTCB, WAVAX, LB1_BTCB_AVAX, 0.4e4, LB12_ID | ZERO_FOR_ONE);
        ptr = _setRoute(route, ptr, WAVAX, USDC, UV3_AVAX_USDC, 0.3e4, UV3_ID | CALLBACK | ZERO_FOR_ONE);
        ptr = _setRoute(route, ptr, WAVAX, USDC, TJ1_AVAX_USDC, 0.6e4, TJ1_ID | ZERO_FOR_ONE);
        ptr = _setRoute(route, ptr, WAVAX, USDC, LB0_AVAX_USDC, 0.0001e4, LB0_ID | ZERO_FOR_ONE);
        ptr = _setRoute(route, ptr, WAVAX, USDC, LB1_AVAX_USDC, 1.0e4, LB12_ID | ZERO_FOR_ONE);
        ptr = _setRoute(route, ptr, BTCB, USDC, UV3_BTCB_USDC, 0.6e4, UV3_ID | CALLBACK | ZERO_FOR_ONE);
        ptr = _setRoute(route, ptr, BTCB, USDC, LB2_BTCB_USDC, 1.0e4, LB12_ID | ZERO_FOR_ONE);
        ptr = _setRoute(route, ptr, USDC, USDT, UV3_USDT_USDC, 0.4e4, UV3_ID | CALLBACK | ONE_FOR_ZERO);
        ptr = _setRoute(route, ptr, USDC, USDT, LB2_USDT_USDC, 1.0e4, LB12_ID | ONE_FOR_ZERO);

        vm.startPrank(alice);
        IERC20(WETH).approve(address(router), amountIn);

        uint256 expectedOut;
        {
            bytes[] memory multiRoutes = new bytes[](3);

            multiRoutes[0] = route;
            multiRoutes[1] = route;

            (, bytes memory data) = address(router).call{value: 0.1e18}(
                abi.encodeWithSelector(
                    IRouter.simulate.selector, logic, WETH, USDT, amountIn, 1, alice, true, multiRoutes
                )
            );

            uint256[] memory values;

            assembly ("memory-safe") {
                values := add(data, 68)
            }

            assertEq(values.length, 3, "test_SwapExactInTokenToTokenWithFee::1");
            assertEq(values[0], values[1], "test_SwapExactInTokenToTokenWithFee::2");
            assertEq(values[2], 0, "test_SwapExactInTokenToTokenWithFee::3");

            expectedOut = values[0];
        }

        (uint256 totalIn, uint256 totalOut) =
            router.swapExactIn{value: 0.1e18}(address(logic), WETH, USDT, amountIn, 1, alice, block.timestamp, route);
        vm.stopPrank();

        uint256 feeAmount = totalOut * 0.1e4 / 0.9e4;
        uint256 protocolFeeAmount = feeAmount * FEE_BIPS / 1e4;

        assertEq(totalIn, amountIn, "test_SwapExactInTokenToTokenWithFee::4");
        assertGt(totalOut, 0, "test_SwapExactInTokenToTokenWithFee::5");
        assertEq(totalOut, expectedOut, "test_SwapExactInTokenToTokenWithFee::6");
        assertEq(alice.balance, 0.1e18, "test_SwapExactInTokenToTokenWithFee::7");
        assertEq(IERC20(WETH).balanceOf(alice), 0, "test_SwapExactInTokenToTokenWithFee::8");
        assertEq(IERC20(USDT).balanceOf(alice), totalOut, "test_SwapExactInTokenToTokenWithFee::11");
        assertEq(IERC20(USDT).balanceOf(feeReceiver), protocolFeeAmount, "test_SwapExactInTokenToTokenWithFee::9");
        assertEq(
            IERC20(USDT).balanceOf(thirdPartyFeeReceiver),
            feeAmount - protocolFeeAmount,
            "test_SwapExactInTokenToTokenWithFee::10"
        );
    }

    function test_SwapExactOutTokenToToken() public {
        uint128 amountOut = 1000e6;
        uint256 maxAmountIn = 1e18;

        vm.deal(alice, 0.1e18);
        deal(WETH, alice, maxAmountIn);

        (bytes memory route, uint256 ptr) = _createRoutes(5, 13);

        ptr = _setIsTransferTaxToken(route, ptr, false);
        ptr = _setToken(route, ptr, WETH);
        ptr = _setToken(route, ptr, WAVAX);
        ptr = _setToken(route, ptr, BTCB);
        ptr = _setToken(route, ptr, USDC);
        ptr = _setToken(route, ptr, USDT);

        ptr = _setRoute(route, ptr, WETH, WAVAX, LB1_WETH_AVAX, 1.0e4, LB12_ID | ZERO_FOR_ONE);
        ptr = _setRoute(route, ptr, WETH, BTCB, LB2_WETH_BTCB, 1.0e4, LB12_ID | ZERO_FOR_ONE);
        ptr = _setRoute(route, ptr, WETH, WAVAX, UV3_WETH_AVAX, 0.2e4, UV3_ID | CALLBACK | ZERO_FOR_ONE);
        ptr = _setRoute(route, ptr, BTCB, WAVAX, LB1_BTCB_AVAX, 0.06e4, LB12_ID | ZERO_FOR_ONE);
        ptr = _setRoute(route, ptr, BTCB, WAVAX, LB2_AVAX_BTCB, 0.1e4, LB12_ID | ONE_FOR_ZERO);
        ptr = _setRoute(route, ptr, WAVAX, USDC, LB1_AVAX_USDC, 1.0e4, LB12_ID | ZERO_FOR_ONE);
        ptr = _setRoute(route, ptr, WAVAX, USDC, LB0_AVAX_USDC, 0.0001e4, LB0_ID | ZERO_FOR_ONE);
        ptr = _setRoute(route, ptr, WAVAX, USDC, TJ1_AVAX_USDC, 0.4e4, TJ1_ID | ZERO_FOR_ONE);
        ptr = _setRoute(route, ptr, WAVAX, USDC, UV3_AVAX_USDC, 0.3e4, UV3_ID | CALLBACK | ZERO_FOR_ONE);
        ptr = _setRoute(route, ptr, BTCB, USDC, LB2_BTCB_USDC, 0.06e4, LB12_ID | ZERO_FOR_ONE);
        ptr = _setRoute(route, ptr, BTCB, USDC, UV3_BTCB_USDC, 0.04e4, UV3_ID | CALLBACK | ZERO_FOR_ONE);
        ptr = _setRoute(route, ptr, USDC, USDT, LB2_USDT_USDC, 1.0e4, LB12_ID | ONE_FOR_ZERO);
        ptr = _setRoute(route, ptr, USDC, USDT, UV3_USDT_USDC, 0.4e4, UV3_ID | CALLBACK | ONE_FOR_ZERO);

        vm.startPrank(alice);
        IERC20(WETH).approve(address(router), maxAmountIn);

        uint256 expectedIn;
        {
            bytes[] memory multiRoutes = new bytes[](3);

            multiRoutes[0] = route;
            multiRoutes[1] = route;

            (, bytes memory data) = address(router).call{value: 0.1e18}(
                abi.encodeWithSelector(
                    IRouter.simulate.selector,
                    logic,
                    WETH,
                    USDT,
                    type(uint128).max,
                    amountOut,
                    alice,
                    false,
                    multiRoutes
                )
            );

            uint256[] memory values;

            assembly ("memory-safe") {
                values := add(data, 68)
            }

            assertEq(values.length, 3, "test_SwapExactOutTokenToToken::1");
            assertEq(values[0], values[1], "test_SwapExactOutTokenToToken::2");
            assertEq(values[2], type(uint256).max, "test_SwapExactOutTokenToToken::3");

            expectedIn = values[0];
        }

        (uint256 totalIn, uint256 totalOut) = router.swapExactOut{value: 0.1e18}(
            address(logic), WETH, USDT, amountOut, maxAmountIn, alice, block.timestamp, route
        );
        vm.stopPrank();

        assertLe(totalIn, maxAmountIn, "test_SwapExactOutTokenToToken::4");
        assertEq(totalIn, expectedIn, "test_SwapExactOutTokenToToken::5");
        assertGe(totalOut, amountOut, "test_SwapExactOutTokenToToken::6");
        assertEq(alice.balance, 0.1e18, "test_SwapExactOutTokenToToken::7");
        assertEq(IERC20(WETH).balanceOf(alice), maxAmountIn - totalIn, "test_SwapExactOutTokenToToken::8");
        assertEq(IERC20(USDT).balanceOf(alice), amountOut, "test_SwapExactOutTokenToToken::9");
    }

    function test_SwapExactOutTokenToTokenWithFeeIn() public {
        uint128 amountOut = 1000e6;
        uint256 maxAmountIn = 1e18;

        vm.deal(alice, 0.1e18);
        deal(WETH, alice, maxAmountIn);

        (bytes memory route, uint256 ptr) = _createRoutes(5, 14);

        ptr = _setIsTransferTaxToken(route, ptr, false);
        ptr = _setToken(route, ptr, WETH);
        ptr = _setToken(route, ptr, WAVAX);
        ptr = _setToken(route, ptr, BTCB);
        ptr = _setToken(route, ptr, USDC);
        ptr = _setToken(route, ptr, USDT);

        ptr = _setFeePercentIn(route, ptr, thirdPartyFeeReceiver, 0.1e4); // 10% fee
        ptr = _setRoute(route, ptr, WETH, WAVAX, LB1_WETH_AVAX, 1.0e4, LB12_ID | ZERO_FOR_ONE);
        ptr = _setRoute(route, ptr, WETH, BTCB, LB2_WETH_BTCB, 1.0e4, LB12_ID | ZERO_FOR_ONE);
        ptr = _setRoute(route, ptr, WETH, WAVAX, UV3_WETH_AVAX, 0.2e4, UV3_ID | CALLBACK | ZERO_FOR_ONE);
        ptr = _setRoute(route, ptr, BTCB, WAVAX, LB1_BTCB_AVAX, 0.06e4, LB12_ID | ZERO_FOR_ONE);
        ptr = _setRoute(route, ptr, BTCB, WAVAX, LB2_AVAX_BTCB, 0.1e4, LB12_ID | ONE_FOR_ZERO);
        ptr = _setRoute(route, ptr, WAVAX, USDC, LB1_AVAX_USDC, 1.0e4, LB12_ID | ZERO_FOR_ONE);
        ptr = _setRoute(route, ptr, WAVAX, USDC, LB0_AVAX_USDC, 0.0001e4, LB0_ID | ZERO_FOR_ONE);
        ptr = _setRoute(route, ptr, WAVAX, USDC, TJ1_AVAX_USDC, 0.4e4, TJ1_ID | ZERO_FOR_ONE);
        ptr = _setRoute(route, ptr, WAVAX, USDC, UV3_AVAX_USDC, 0.3e4, UV3_ID | CALLBACK | ZERO_FOR_ONE);
        ptr = _setRoute(route, ptr, BTCB, USDC, LB2_BTCB_USDC, 0.06e4, LB12_ID | ZERO_FOR_ONE);
        ptr = _setRoute(route, ptr, BTCB, USDC, UV3_BTCB_USDC, 0.04e4, UV3_ID | CALLBACK | ZERO_FOR_ONE);
        ptr = _setRoute(route, ptr, USDC, USDT, LB2_USDT_USDC, 1.0e4, LB12_ID | ONE_FOR_ZERO);
        ptr = _setRoute(route, ptr, USDC, USDT, UV3_USDT_USDC, 0.4e4, UV3_ID | CALLBACK | ONE_FOR_ZERO);

        vm.startPrank(alice);
        IERC20(WETH).approve(address(router), maxAmountIn);

        uint256 expectedIn;
        {
            bytes[] memory multiRoutes = new bytes[](3);

            multiRoutes[0] = route;
            multiRoutes[1] = route;

            (, bytes memory data) = address(router).call{value: 0.1e18}(
                abi.encodeWithSelector(
                    IRouter.simulate.selector,
                    logic,
                    WETH,
                    USDT,
                    type(uint128).max,
                    amountOut,
                    alice,
                    false,
                    multiRoutes
                )
            );

            uint256[] memory values;

            assembly ("memory-safe") {
                values := add(data, 68)
            }

            assertEq(values.length, 3, "test_SwapExactOutTokenToTokenWithFee::1");
            assertEq(values[0], values[1], "test_SwapExactOutTokenToTokenWithFee::2");
            assertEq(values[2], type(uint256).max, "test_SwapExactOutTokenToTokenWithFee::3");

            expectedIn = values[0];
        }

        (uint256 totalIn, uint256 totalOut) = router.swapExactOut{value: 0.1e18}(
            address(logic), WETH, USDT, amountOut, maxAmountIn, alice, block.timestamp, route
        );
        vm.stopPrank();

        uint256 feeAmount = totalIn * 0.1e4 / 1e4;
        uint256 protocolFeeAmount = feeAmount * FEE_BIPS / 1e4;

        assertLe(totalIn, maxAmountIn, "test_SwapExactOutTokenToTokenWithFee::4");
        assertEq(totalIn, expectedIn, "test_SwapExactOutTokenToTokenWithFee::5");
        assertGe(totalOut, amountOut, "test_SwapExactOutTokenToTokenWithFee::6");
        assertEq(alice.balance, 0.1e18, "test_SwapExactOutTokenToTokenWithFee::7");
        assertEq(IERC20(WETH).balanceOf(alice), maxAmountIn - totalIn, "test_SwapExactOutTokenToTokenWithFee::8");
        assertEq(IERC20(WETH).balanceOf(feeReceiver), protocolFeeAmount, "test_SwapExactOutTokenToTokenWithFee::9");
        assertEq(
            IERC20(WETH).balanceOf(thirdPartyFeeReceiver),
            feeAmount - protocolFeeAmount,
            "test_SwapExactOutTokenToTokenWithFee::10"
        );
        assertEq(IERC20(USDT).balanceOf(alice), amountOut, "test_SwapExactOutTokenToTokenWithFee::11");
    }

    function test_SwapExactOutTokenToTokenWithFeeOut() public {
        uint128 amountOut = 1000e6;
        uint256 maxAmountIn = 1e18;

        vm.deal(alice, 0.1e18);
        deal(WETH, alice, maxAmountIn);

        (bytes memory route, uint256 ptr) = _createRoutes(5, 14);

        ptr = _setIsTransferTaxToken(route, ptr, false);
        ptr = _setToken(route, ptr, WETH);
        ptr = _setToken(route, ptr, WAVAX);
        ptr = _setToken(route, ptr, BTCB);
        ptr = _setToken(route, ptr, USDC);
        ptr = _setToken(route, ptr, USDT);

        ptr = _setFeePercentOut(route, ptr, thirdPartyFeeReceiver, 0.1e4); // 10% fee
        ptr = _setRoute(route, ptr, WETH, WAVAX, LB1_WETH_AVAX, 1.0e4, LB12_ID | ZERO_FOR_ONE);
        ptr = _setRoute(route, ptr, WETH, BTCB, LB2_WETH_BTCB, 1.0e4, LB12_ID | ZERO_FOR_ONE);
        ptr = _setRoute(route, ptr, WETH, WAVAX, UV3_WETH_AVAX, 0.2e4, UV3_ID | CALLBACK | ZERO_FOR_ONE);
        ptr = _setRoute(route, ptr, BTCB, WAVAX, LB1_BTCB_AVAX, 0.06e4, LB12_ID | ZERO_FOR_ONE);
        ptr = _setRoute(route, ptr, BTCB, WAVAX, LB2_AVAX_BTCB, 0.1e4, LB12_ID | ONE_FOR_ZERO);
        ptr = _setRoute(route, ptr, WAVAX, USDC, LB1_AVAX_USDC, 1.0e4, LB12_ID | ZERO_FOR_ONE);
        ptr = _setRoute(route, ptr, WAVAX, USDC, LB0_AVAX_USDC, 0.0001e4, LB0_ID | ZERO_FOR_ONE);
        ptr = _setRoute(route, ptr, WAVAX, USDC, TJ1_AVAX_USDC, 0.4e4, TJ1_ID | ZERO_FOR_ONE);
        ptr = _setRoute(route, ptr, WAVAX, USDC, UV3_AVAX_USDC, 0.3e4, UV3_ID | CALLBACK | ZERO_FOR_ONE);
        ptr = _setRoute(route, ptr, BTCB, USDC, LB2_BTCB_USDC, 0.06e4, LB12_ID | ZERO_FOR_ONE);
        ptr = _setRoute(route, ptr, BTCB, USDC, UV3_BTCB_USDC, 0.04e4, UV3_ID | CALLBACK | ZERO_FOR_ONE);
        ptr = _setRoute(route, ptr, USDC, USDT, LB2_USDT_USDC, 1.0e4, LB12_ID | ONE_FOR_ZERO);
        ptr = _setRoute(route, ptr, USDC, USDT, UV3_USDT_USDC, 0.4e4, UV3_ID | CALLBACK | ONE_FOR_ZERO);

        vm.startPrank(alice);
        IERC20(WETH).approve(address(router), maxAmountIn);

        uint256 expectedIn;
        {
            bytes[] memory multiRoutes = new bytes[](3);

            multiRoutes[0] = route;
            multiRoutes[1] = route;

            (, bytes memory data) = address(router).call{value: 0.1e18}(
                abi.encodeWithSelector(
                    IRouter.simulate.selector,
                    logic,
                    WETH,
                    USDT,
                    type(uint128).max,
                    amountOut,
                    alice,
                    false,
                    multiRoutes
                )
            );

            uint256[] memory values;

            assembly ("memory-safe") {
                values := add(data, 68)
            }

            assertEq(values.length, 3, "test_SwapExactOutTokenToTokenWithFee::1");
            assertEq(values[0], values[1], "test_SwapExactOutTokenToTokenWithFee::2");
            assertEq(values[2], type(uint256).max, "test_SwapExactOutTokenToTokenWithFee::3");

            expectedIn = values[0];
        }

        (uint256 totalIn, uint256 totalOut) = router.swapExactOut{value: 0.1e18}(
            address(logic), WETH, USDT, amountOut, maxAmountIn, alice, block.timestamp, route
        );
        vm.stopPrank();

        uint256 feeAmount = totalOut * 0.1e4 / 0.9e4;
        uint256 protocolFeeAmount = feeAmount * FEE_BIPS / 1e4;

        assertLe(totalIn, maxAmountIn, "test_SwapExactOutTokenToTokenWithFee::4");
        assertEq(totalIn, expectedIn, "test_SwapExactOutTokenToTokenWithFee::5");
        assertGe(totalOut, amountOut, "test_SwapExactOutTokenToTokenWithFee::6");
        assertEq(alice.balance, 0.1e18, "test_SwapExactOutTokenToTokenWithFee::7");
        assertEq(IERC20(WETH).balanceOf(alice), maxAmountIn - totalIn, "test_SwapExactOutTokenToTokenWithFee::8");
        assertEq(IERC20(USDT).balanceOf(alice), amountOut, "test_SwapExactOutTokenToTokenWithFee::11");
        assertEq(IERC20(USDT).balanceOf(feeReceiver), protocolFeeAmount, "test_SwapExactOutTokenToTokenWithFee::9");
        assertEq(
            IERC20(USDT).balanceOf(thirdPartyFeeReceiver),
            feeAmount - protocolFeeAmount,
            "test_SwapExactOutTokenToTokenWithFee::10"
        );
    }

    function test_SwapExactInNativeToToken() public {
        uint128 amountIn = 1e18;

        vm.deal(alice, amountIn + 0.1e18);

        (bytes memory route, uint256 ptr) = _createRoutes(4, 10);

        ptr = _setIsTransferTaxToken(route, ptr, false);
        ptr = _setToken(route, ptr, WAVAX);
        ptr = _setToken(route, ptr, BTCB);
        ptr = _setToken(route, ptr, USDC);
        ptr = _setToken(route, ptr, USDT);

        ptr = _setRoute(route, ptr, WAVAX, USDC, UV3_AVAX_USDC, 0.2e4, UV3_ID | CALLBACK | ZERO_FOR_ONE);
        ptr = _setRoute(route, ptr, WAVAX, BTCB, LB2_AVAX_BTCB, 0.3e4, LB12_ID | ZERO_FOR_ONE);
        ptr = _setRoute(route, ptr, WAVAX, BTCB, LB1_BTCB_AVAX, 0.4e4, LB12_ID | ONE_FOR_ZERO);
        ptr = _setRoute(route, ptr, WAVAX, USDC, TJ1_AVAX_USDC, 0.5e4, TJ1_ID | ZERO_FOR_ONE);
        ptr = _setRoute(route, ptr, WAVAX, USDC, LB0_AVAX_USDC, 0.0001e4, LB0_ID | ZERO_FOR_ONE);
        ptr = _setRoute(route, ptr, WAVAX, USDC, LB1_AVAX_USDC, 1.0e4, LB12_ID | ZERO_FOR_ONE);
        ptr = _setRoute(route, ptr, BTCB, USDC, UV3_BTCB_USDC, 0.6e4, UV3_ID | CALLBACK | ZERO_FOR_ONE);
        ptr = _setRoute(route, ptr, BTCB, USDC, LB2_BTCB_USDC, 1.0e4, LB12_ID | ZERO_FOR_ONE);
        ptr = _setRoute(route, ptr, USDC, USDT, UV3_USDT_USDC, 0.4e4, UV3_ID | CALLBACK | ONE_FOR_ZERO);
        ptr = _setRoute(route, ptr, USDC, USDT, LB2_USDT_USDC, 1.0e4, LB12_ID | ONE_FOR_ZERO);

        vm.prank(alice);
        (uint256 totalIn, uint256 totalOut) = router.swapExactIn{value: amountIn + 0.1e18}(
            address(logic), address(0), USDT, amountIn, 1, alice, block.timestamp, route
        );

        assertEq(totalIn, amountIn, "test_SwapExactInNativeToToken::1");
        assertGt(totalOut, 0, "test_SwapExactInNativeToToken::2");
        assertEq(alice.balance, 0.1e18, "test_SwapExactInNativeToToken::3");
        assertEq(IERC20(USDT).balanceOf(alice), totalOut, "test_SwapExactInNativeToToken::4");
    }

    function test_SwapExactInNativeToTokenWithFeeIn() public {
        uint128 amountIn = 1e18;

        vm.deal(alice, amountIn + 0.1e18);

        (bytes memory route, uint256 ptr) = _createRoutes(4, 11);

        ptr = _setIsTransferTaxToken(route, ptr, false);
        ptr = _setToken(route, ptr, WAVAX);
        ptr = _setToken(route, ptr, BTCB);
        ptr = _setToken(route, ptr, USDC);
        ptr = _setToken(route, ptr, USDT);

        ptr = _setFeePercentIn(route, ptr, thirdPartyFeeReceiver, 0.1e4); // 10% fee
        ptr = _setRoute(route, ptr, WAVAX, USDC, UV3_AVAX_USDC, 0.2e4, UV3_ID | CALLBACK | ZERO_FOR_ONE);
        ptr = _setRoute(route, ptr, WAVAX, BTCB, LB2_AVAX_BTCB, 0.3e4, LB12_ID | ZERO_FOR_ONE);
        ptr = _setRoute(route, ptr, WAVAX, BTCB, LB1_BTCB_AVAX, 0.4e4, LB12_ID | ONE_FOR_ZERO);
        ptr = _setRoute(route, ptr, WAVAX, USDC, TJ1_AVAX_USDC, 0.5e4, TJ1_ID | ZERO_FOR_ONE);
        ptr = _setRoute(route, ptr, WAVAX, USDC, LB0_AVAX_USDC, 0.0001e4, LB0_ID | ZERO_FOR_ONE);
        ptr = _setRoute(route, ptr, WAVAX, USDC, LB1_AVAX_USDC, 1.0e4, LB12_ID | ZERO_FOR_ONE);
        ptr = _setRoute(route, ptr, BTCB, USDC, UV3_BTCB_USDC, 0.6e4, UV3_ID | CALLBACK | ZERO_FOR_ONE);
        ptr = _setRoute(route, ptr, BTCB, USDC, LB2_BTCB_USDC, 1.0e4, LB12_ID | ZERO_FOR_ONE);
        ptr = _setRoute(route, ptr, USDC, USDT, UV3_USDT_USDC, 0.4e4, UV3_ID | CALLBACK | ONE_FOR_ZERO);
        ptr = _setRoute(route, ptr, USDC, USDT, LB2_USDT_USDC, 1.0e4, LB12_ID | ONE_FOR_ZERO);

        vm.prank(alice);
        (uint256 totalIn, uint256 totalOut) = router.swapExactIn{value: amountIn + 0.1e18}(
            address(logic), address(0), USDT, amountIn, 1, alice, block.timestamp, route
        );

        uint256 feeAmount = amountIn * 0.1e4 / 1e4;
        uint256 protocolFeeAmount = feeAmount * FEE_BIPS / 1e4;

        assertEq(totalIn, amountIn, "test_SwapExactInNativeToTokenWithFee::1");
        assertGt(totalOut, 0, "test_SwapExactInNativeToTokenWithFee::2");
        assertEq(alice.balance, 0.1e18, "test_SwapExactInNativeToTokenWithFee::3");
        assertEq(IERC20(WAVAX).balanceOf(alice), 0, "test_SwapExactInNativeToTokenWithFee::4");
        assertEq(IERC20(WAVAX).balanceOf(feeReceiver), protocolFeeAmount, "test_SwapExactInNativeToTokenWithFee::5");
        assertEq(
            IERC20(WAVAX).balanceOf(thirdPartyFeeReceiver),
            feeAmount - protocolFeeAmount,
            "test_SwapExactInNativeToTokenWithFee::6"
        );
        assertEq(IERC20(USDT).balanceOf(alice), totalOut, "test_SwapExactInNativeToTokenWithFee::7");
    }

    function test_SwapExactInNativeToTokenWithFeeOut() public {
        uint128 amountIn = 1e18;

        vm.deal(alice, amountIn + 0.1e18);

        (bytes memory route, uint256 ptr) = _createRoutes(4, 11);

        ptr = _setIsTransferTaxToken(route, ptr, false);
        ptr = _setToken(route, ptr, WAVAX);
        ptr = _setToken(route, ptr, BTCB);
        ptr = _setToken(route, ptr, USDC);
        ptr = _setToken(route, ptr, USDT);

        ptr = _setFeePercentOut(route, ptr, thirdPartyFeeReceiver, 0.1e4); // 10% fee
        ptr = _setRoute(route, ptr, WAVAX, USDC, UV3_AVAX_USDC, 0.2e4, UV3_ID | CALLBACK | ZERO_FOR_ONE);
        ptr = _setRoute(route, ptr, WAVAX, BTCB, LB2_AVAX_BTCB, 0.3e4, LB12_ID | ZERO_FOR_ONE);
        ptr = _setRoute(route, ptr, WAVAX, BTCB, LB1_BTCB_AVAX, 0.4e4, LB12_ID | ONE_FOR_ZERO);
        ptr = _setRoute(route, ptr, WAVAX, USDC, TJ1_AVAX_USDC, 0.5e4, TJ1_ID | ZERO_FOR_ONE);
        ptr = _setRoute(route, ptr, WAVAX, USDC, LB0_AVAX_USDC, 0.0001e4, LB0_ID | ZERO_FOR_ONE);
        ptr = _setRoute(route, ptr, WAVAX, USDC, LB1_AVAX_USDC, 1.0e4, LB12_ID | ZERO_FOR_ONE);
        ptr = _setRoute(route, ptr, BTCB, USDC, UV3_BTCB_USDC, 0.6e4, UV3_ID | CALLBACK | ZERO_FOR_ONE);
        ptr = _setRoute(route, ptr, BTCB, USDC, LB2_BTCB_USDC, 1.0e4, LB12_ID | ZERO_FOR_ONE);
        ptr = _setRoute(route, ptr, USDC, USDT, UV3_USDT_USDC, 0.4e4, UV3_ID | CALLBACK | ONE_FOR_ZERO);
        ptr = _setRoute(route, ptr, USDC, USDT, LB2_USDT_USDC, 1.0e4, LB12_ID | ONE_FOR_ZERO);

        vm.prank(alice);
        (uint256 totalIn, uint256 totalOut) = router.swapExactIn{value: amountIn + 0.1e18}(
            address(logic), address(0), USDT, amountIn, 1, alice, block.timestamp, route
        );

        uint256 feeAmount = totalOut * 0.1e4 / 0.9e4;
        uint256 protocolFeeAmount = feeAmount * FEE_BIPS / 1e4;

        assertEq(totalIn, amountIn, "test_SwapExactInNativeToTokenWithFee::1");
        assertGt(totalOut, 0, "test_SwapExactInNativeToTokenWithFee::2");
        assertEq(alice.balance, 0.1e18, "test_SwapExactInNativeToTokenWithFee::3");
        assertEq(IERC20(WAVAX).balanceOf(alice), 0, "test_SwapExactInNativeToTokenWithFee::4");
        assertEq(IERC20(USDT).balanceOf(alice), totalOut, "test_SwapExactInNativeToTokenWithFee::7");
        assertEq(IERC20(USDT).balanceOf(feeReceiver), protocolFeeAmount, "test_SwapExactInNativeToTokenWithFee::5");
        assertEq(
            IERC20(USDT).balanceOf(thirdPartyFeeReceiver),
            feeAmount - protocolFeeAmount,
            "test_SwapExactInNativeToTokenWithFee::6"
        );
    }

    function test_SwapExactOutNativeToToken() public {
        uint128 amountOut = 1000e6;
        uint256 maxAmountIn = 100e18;

        vm.deal(alice, maxAmountIn + 0.1e18);

        (bytes memory route, uint256 ptr) = _createRoutes(4, 10);

        ptr = _setIsTransferTaxToken(route, ptr, false);
        ptr = _setToken(route, ptr, WAVAX);
        ptr = _setToken(route, ptr, BTCB);
        ptr = _setToken(route, ptr, USDC);
        ptr = _setToken(route, ptr, USDT);

        ptr = _setRoute(route, ptr, WAVAX, USDC, UV3_AVAX_USDC, 1.0e4, UV3_ID | CALLBACK | ZERO_FOR_ONE);
        ptr = _setRoute(route, ptr, WAVAX, BTCB, LB2_AVAX_BTCB, 1.0e4, LB12_ID | ZERO_FOR_ONE);
        ptr = _setRoute(route, ptr, WAVAX, BTCB, LB1_BTCB_AVAX, 0.4e4, LB12_ID | ONE_FOR_ZERO);
        ptr = _setRoute(route, ptr, WAVAX, USDC, TJ1_AVAX_USDC, 0.6e4, TJ1_ID | ZERO_FOR_ONE);
        ptr = _setRoute(route, ptr, WAVAX, USDC, LB1_AVAX_USDC, 0.5e4, LB12_ID | ZERO_FOR_ONE);
        ptr = _setRoute(route, ptr, WAVAX, USDC, LB0_AVAX_USDC, 0.0001e4, LB0_ID | ZERO_FOR_ONE);
        ptr = _setRoute(route, ptr, BTCB, USDC, UV3_BTCB_USDC, 0.4e4, UV3_ID | CALLBACK | ZERO_FOR_ONE);
        ptr = _setRoute(route, ptr, BTCB, USDC, LB2_BTCB_USDC, 0.3e4, LB12_ID | ZERO_FOR_ONE);
        ptr = _setRoute(route, ptr, USDC, USDT, UV3_USDT_USDC, 1.0e4, UV3_ID | CALLBACK | ONE_FOR_ZERO);
        ptr = _setRoute(route, ptr, USDC, USDT, LB2_USDT_USDC, 0.6e4, LB12_ID | ONE_FOR_ZERO);

        vm.prank(alice);
        (uint256 totalIn, uint256 totalOut) = router.swapExactOut{value: maxAmountIn + 0.1e18}(
            address(logic), address(0), USDT, amountOut, maxAmountIn, alice, block.timestamp, route
        );

        assertLe(totalIn, maxAmountIn, "test_SwapExactOutNativeToToken::1");
        assertGe(totalOut, amountOut, "test_SwapExactOutNativeToToken::2");
        assertEq(alice.balance, maxAmountIn + 0.1e18 - totalIn, "test_SwapExactOutNativeToToken::3");
        assertEq(IERC20(USDT).balanceOf(alice), amountOut, "test_SwapExactOutNativeToToken::4");
    }

    function test_SwapExactOutNativeToTokenWithFeeIn() public {
        uint128 amountOut = 1000e6;
        uint256 maxAmountIn = 100e18;

        vm.deal(alice, maxAmountIn + 0.1e18);

        (bytes memory route, uint256 ptr) = _createRoutes(4, 11);

        ptr = _setIsTransferTaxToken(route, ptr, false);
        ptr = _setToken(route, ptr, WAVAX);
        ptr = _setToken(route, ptr, BTCB);
        ptr = _setToken(route, ptr, USDC);
        ptr = _setToken(route, ptr, USDT);

        ptr = _setFeePercentIn(route, ptr, thirdPartyFeeReceiver, 0.1e4); // 10% fee
        ptr = _setRoute(route, ptr, WAVAX, USDC, UV3_AVAX_USDC, 1.0e4, UV3_ID | CALLBACK | ZERO_FOR_ONE);
        ptr = _setRoute(route, ptr, WAVAX, BTCB, LB2_AVAX_BTCB, 1.0e4, LB12_ID | ZERO_FOR_ONE);
        ptr = _setRoute(route, ptr, WAVAX, BTCB, LB1_BTCB_AVAX, 0.4e4, LB12_ID | ONE_FOR_ZERO);
        ptr = _setRoute(route, ptr, WAVAX, USDC, TJ1_AVAX_USDC, 0.6e4, TJ1_ID | ZERO_FOR_ONE);
        ptr = _setRoute(route, ptr, WAVAX, USDC, LB1_AVAX_USDC, 0.5e4, LB12_ID | ZERO_FOR_ONE);
        ptr = _setRoute(route, ptr, WAVAX, USDC, LB0_AVAX_USDC, 0.0001e4, LB0_ID | ZERO_FOR_ONE);
        ptr = _setRoute(route, ptr, BTCB, USDC, UV3_BTCB_USDC, 0.4e4, UV3_ID | CALLBACK | ZERO_FOR_ONE);
        ptr = _setRoute(route, ptr, BTCB, USDC, LB2_BTCB_USDC, 0.3e4, LB12_ID | ZERO_FOR_ONE);
        ptr = _setRoute(route, ptr, USDC, USDT, UV3_USDT_USDC, 1.0e4, UV3_ID | CALLBACK | ONE_FOR_ZERO);
        ptr = _setRoute(route, ptr, USDC, USDT, LB2_USDT_USDC, 0.6e4, LB12_ID | ONE_FOR_ZERO);

        vm.prank(alice);
        (uint256 totalIn, uint256 totalOut) = router.swapExactOut{value: maxAmountIn + 0.1e18}(
            address(logic), address(0), USDT, amountOut, maxAmountIn, alice, block.timestamp, route
        );

        uint256 feeAmount = totalIn * 0.1e4 / 1e4;
        uint256 protocolFeeAmount = feeAmount * FEE_BIPS / 1e4;

        assertLe(totalIn, maxAmountIn, "test_SwapExactOutNativeToTokenWithFee::1");
        assertGe(totalOut, amountOut, "test_SwapExactOutNativeToTokenWithFee::2");
        assertEq(alice.balance, maxAmountIn + 0.1e18 - totalIn, "test_SwapExactOutNativeToTokenWithFee::3");
        assertEq(IERC20(WAVAX).balanceOf(alice), 0, "test_SwapExactOutNativeToTokenWithFee::4");
        assertEq(IERC20(WAVAX).balanceOf(feeReceiver), protocolFeeAmount, "test_SwapExactOutNativeToTokenWithFee::5");
        assertEq(
            IERC20(WAVAX).balanceOf(thirdPartyFeeReceiver),
            feeAmount - protocolFeeAmount,
            "test_SwapExactOutNativeToTokenWithFee::6"
        );
        assertEq(IERC20(USDT).balanceOf(alice), amountOut, "test_SwapExactOutNativeToTokenWithFee::7");
    }

    function test_SwapExactOutNativeToTokenWithFeeOut() public {
        uint128 amountOut = 1000e6;
        uint256 maxAmountIn = 100e18;

        vm.deal(alice, maxAmountIn + 0.1e18);

        (bytes memory route, uint256 ptr) = _createRoutes(4, 11);

        ptr = _setIsTransferTaxToken(route, ptr, false);
        ptr = _setToken(route, ptr, WAVAX);
        ptr = _setToken(route, ptr, BTCB);
        ptr = _setToken(route, ptr, USDC);
        ptr = _setToken(route, ptr, USDT);

        ptr = _setFeePercentOut(route, ptr, thirdPartyFeeReceiver, 0.1e4); // 10% fee
        ptr = _setRoute(route, ptr, WAVAX, USDC, UV3_AVAX_USDC, 1.0e4, UV3_ID | CALLBACK | ZERO_FOR_ONE);
        ptr = _setRoute(route, ptr, WAVAX, BTCB, LB2_AVAX_BTCB, 1.0e4, LB12_ID | ZERO_FOR_ONE);
        ptr = _setRoute(route, ptr, WAVAX, BTCB, LB1_BTCB_AVAX, 0.4e4, LB12_ID | ONE_FOR_ZERO);
        ptr = _setRoute(route, ptr, WAVAX, USDC, TJ1_AVAX_USDC, 0.6e4, TJ1_ID | ZERO_FOR_ONE);
        ptr = _setRoute(route, ptr, WAVAX, USDC, LB1_AVAX_USDC, 0.5e4, LB12_ID | ZERO_FOR_ONE);
        ptr = _setRoute(route, ptr, WAVAX, USDC, LB0_AVAX_USDC, 0.0001e4, LB0_ID | ZERO_FOR_ONE);
        ptr = _setRoute(route, ptr, BTCB, USDC, UV3_BTCB_USDC, 0.4e4, UV3_ID | CALLBACK | ZERO_FOR_ONE);
        ptr = _setRoute(route, ptr, BTCB, USDC, LB2_BTCB_USDC, 0.3e4, LB12_ID | ZERO_FOR_ONE);
        ptr = _setRoute(route, ptr, USDC, USDT, UV3_USDT_USDC, 1.0e4, UV3_ID | CALLBACK | ONE_FOR_ZERO);
        ptr = _setRoute(route, ptr, USDC, USDT, LB2_USDT_USDC, 0.6e4, LB12_ID | ONE_FOR_ZERO);

        vm.prank(alice);
        (uint256 totalIn, uint256 totalOut) = router.swapExactOut{value: maxAmountIn + 0.1e18}(
            address(logic), address(0), USDT, amountOut, maxAmountIn, alice, block.timestamp, route
        );

        uint256 feeAmount = totalOut * 0.1e4 / 0.9e4;
        uint256 protocolFeeAmount = feeAmount * FEE_BIPS / 1e4;

        assertLe(totalIn, maxAmountIn, "test_SwapExactOutNativeToTokenWithFee::1");
        assertGe(totalOut, amountOut, "test_SwapExactOutNativeToTokenWithFee::2");
        assertEq(alice.balance, maxAmountIn + 0.1e18 - totalIn, "test_SwapExactOutNativeToTokenWithFee::3");
        assertEq(IERC20(WAVAX).balanceOf(alice), 0, "test_SwapExactOutNativeToTokenWithFee::4");
        assertEq(IERC20(USDT).balanceOf(alice), amountOut, "test_SwapExactOutNativeToTokenWithFee::7");
        assertEq(IERC20(USDT).balanceOf(feeReceiver), protocolFeeAmount, "test_SwapExactOutNativeToTokenWithFee::5");
        assertEq(
            IERC20(USDT).balanceOf(thirdPartyFeeReceiver),
            feeAmount - protocolFeeAmount,
            "test_SwapExactOutNativeToTokenWithFee::6"
        );
    }

    function test_SwapExactInTokenToNative() public {
        uint128 amountIn = 1_000e6;

        vm.deal(alice, 0.1e18);
        deal(USDT, alice, amountIn);

        (bytes memory route, uint256 ptr) = _createRoutes(4, 10);

        ptr = _setIsTransferTaxToken(route, ptr, false);
        ptr = _setToken(route, ptr, USDT);
        ptr = _setToken(route, ptr, USDC);
        ptr = _setToken(route, ptr, BTCB);
        ptr = _setToken(route, ptr, WAVAX);

        ptr = _setRoute(route, ptr, USDT, USDC, UV3_USDT_USDC, 0.4e4, UV3_ID | CALLBACK | ZERO_FOR_ONE);
        ptr = _setRoute(route, ptr, USDT, USDC, LB2_USDT_USDC, 1.0e4, LB12_ID | ZERO_FOR_ONE);
        ptr = _setRoute(route, ptr, USDC, BTCB, UV3_BTCB_USDC, 0.2e4, UV3_ID | CALLBACK | ONE_FOR_ZERO);
        ptr = _setRoute(route, ptr, USDC, BTCB, LB2_BTCB_USDC, 0.3e4, LB12_ID | ONE_FOR_ZERO);
        ptr = _setRoute(route, ptr, USDC, WAVAX, TJ1_AVAX_USDC, 0.3e4, TJ1_ID | ONE_FOR_ZERO);
        ptr = _setRoute(route, ptr, USDC, WAVAX, UV3_AVAX_USDC, 0.5e4, UV3_ID | CALLBACK | ONE_FOR_ZERO);
        ptr = _setRoute(route, ptr, BTCB, WAVAX, LB2_AVAX_BTCB, 0.4e4, LB12_ID | ONE_FOR_ZERO);
        ptr = _setRoute(route, ptr, BTCB, WAVAX, LB1_BTCB_AVAX, 1.0e4, LB12_ID | ZERO_FOR_ONE);
        ptr = _setRoute(route, ptr, USDC, WAVAX, LB0_AVAX_USDC, 0.0001e4, LB0_ID | ONE_FOR_ZERO);
        ptr = _setRoute(route, ptr, USDC, WAVAX, LB1_AVAX_USDC, 1.0e4, LB12_ID | ONE_FOR_ZERO);

        vm.startPrank(alice);
        IERC20(USDT).approve(address(router), amountIn);
        (uint256 totalIn, uint256 totalOut) = router.swapExactIn{value: 0.1e18}(
            address(logic), USDT, address(0), amountIn, 1, alice, block.timestamp, route
        );
        vm.stopPrank();

        assertEq(totalIn, amountIn, "test_SwapExactInTokenToNative::1");
        assertGt(totalOut, 0, "test_SwapExactInTokenToNative::2");
        assertEq(alice.balance, 0.1e18 + totalOut, "test_SwapExactInTokenToNative::3");
        assertEq(IERC20(USDT).balanceOf(alice), 0, "test_SwapExactInTokenToNative::4");
    }

    function test_SwapExactInTokenToNativeWithFeeIn() public {
        uint128 amountIn = 1_000e6;

        vm.deal(alice, 0.1e18);
        deal(USDT, alice, amountIn);

        (bytes memory route, uint256 ptr) = _createRoutes(4, 11);

        ptr = _setIsTransferTaxToken(route, ptr, false);
        ptr = _setToken(route, ptr, USDT);
        ptr = _setToken(route, ptr, USDC);
        ptr = _setToken(route, ptr, BTCB);
        ptr = _setToken(route, ptr, WAVAX);

        ptr = _setFeePercentIn(route, ptr, thirdPartyFeeReceiver, 0.1e4); // 10% fee
        ptr = _setRoute(route, ptr, USDT, USDC, UV3_USDT_USDC, 0.4e4, UV3_ID | CALLBACK | ZERO_FOR_ONE);
        ptr = _setRoute(route, ptr, USDT, USDC, LB2_USDT_USDC, 1.0e4, LB12_ID | ZERO_FOR_ONE);
        ptr = _setRoute(route, ptr, USDC, BTCB, UV3_BTCB_USDC, 0.2e4, UV3_ID | CALLBACK | ONE_FOR_ZERO);
        ptr = _setRoute(route, ptr, USDC, BTCB, LB2_BTCB_USDC, 0.3e4, LB12_ID | ONE_FOR_ZERO);
        ptr = _setRoute(route, ptr, USDC, WAVAX, TJ1_AVAX_USDC, 0.3e4, TJ1_ID | ONE_FOR_ZERO);
        ptr = _setRoute(route, ptr, USDC, WAVAX, UV3_AVAX_USDC, 0.5e4, UV3_ID | CALLBACK | ONE_FOR_ZERO);
        ptr = _setRoute(route, ptr, BTCB, WAVAX, LB2_AVAX_BTCB, 0.4e4, LB12_ID | ONE_FOR_ZERO);
        ptr = _setRoute(route, ptr, BTCB, WAVAX, LB1_BTCB_AVAX, 1.0e4, LB12_ID | ZERO_FOR_ONE);
        ptr = _setRoute(route, ptr, USDC, WAVAX, LB0_AVAX_USDC, 0.0001e4, LB0_ID | ONE_FOR_ZERO);
        ptr = _setRoute(route, ptr, USDC, WAVAX, LB1_AVAX_USDC, 1.0e4, LB12_ID | ONE_FOR_ZERO);

        vm.startPrank(alice);
        IERC20(USDT).approve(address(router), amountIn);
        (uint256 totalIn, uint256 totalOut) = router.swapExactIn{value: 0.1e18}(
            address(logic), USDT, address(0), amountIn, 1, alice, block.timestamp, route
        );
        vm.stopPrank();

        uint256 feeAmount = amountIn * 0.1e4 / 1e4;
        uint256 protocolFeeAmount = feeAmount * FEE_BIPS / 1e4;

        assertEq(totalIn, amountIn, "test_SwapExactInTokenToNativeWithFee::1");
        assertGt(totalOut, 0, "test_SwapExactInTokenToNativeWithFee::2");
        assertEq(alice.balance, 0.1e18 + totalOut, "test_SwapExactInTokenToNativeWithFee::3");
        assertEq(IERC20(USDT).balanceOf(alice), 0, "test_SwapExactInTokenToNativeWithFee::4");
        assertEq(IERC20(USDT).balanceOf(feeReceiver), protocolFeeAmount, "test_SwapExactInTokenToNativeWithFee::5");
        assertEq(
            IERC20(USDT).balanceOf(thirdPartyFeeReceiver),
            feeAmount - protocolFeeAmount,
            "test_SwapExactInTokenToNativeWithFee::6"
        );
    }

    function test_SwapExactInTokenToNativeWithFeeOut() public {
        uint128 amountIn = 1_000e6;

        vm.deal(alice, 0.1e18);
        deal(USDT, alice, amountIn);

        (bytes memory route, uint256 ptr) = _createRoutes(4, 11);

        ptr = _setIsTransferTaxToken(route, ptr, false);
        ptr = _setToken(route, ptr, USDT);
        ptr = _setToken(route, ptr, USDC);
        ptr = _setToken(route, ptr, BTCB);
        ptr = _setToken(route, ptr, WAVAX);

        ptr = _setFeePercentOut(route, ptr, thirdPartyFeeReceiver, 0.1e4); // 10% fee
        ptr = _setRoute(route, ptr, USDT, USDC, UV3_USDT_USDC, 0.4e4, UV3_ID | CALLBACK | ZERO_FOR_ONE);
        ptr = _setRoute(route, ptr, USDT, USDC, LB2_USDT_USDC, 1.0e4, LB12_ID | ZERO_FOR_ONE);
        ptr = _setRoute(route, ptr, USDC, BTCB, UV3_BTCB_USDC, 0.2e4, UV3_ID | CALLBACK | ONE_FOR_ZERO);
        ptr = _setRoute(route, ptr, USDC, BTCB, LB2_BTCB_USDC, 0.3e4, LB12_ID | ONE_FOR_ZERO);
        ptr = _setRoute(route, ptr, USDC, WAVAX, TJ1_AVAX_USDC, 0.3e4, TJ1_ID | ONE_FOR_ZERO);
        ptr = _setRoute(route, ptr, USDC, WAVAX, UV3_AVAX_USDC, 0.5e4, UV3_ID | CALLBACK | ONE_FOR_ZERO);
        ptr = _setRoute(route, ptr, BTCB, WAVAX, LB2_AVAX_BTCB, 0.4e4, LB12_ID | ONE_FOR_ZERO);
        ptr = _setRoute(route, ptr, BTCB, WAVAX, LB1_BTCB_AVAX, 1.0e4, LB12_ID | ZERO_FOR_ONE);
        ptr = _setRoute(route, ptr, USDC, WAVAX, LB0_AVAX_USDC, 0.0001e4, LB0_ID | ONE_FOR_ZERO);
        ptr = _setRoute(route, ptr, USDC, WAVAX, LB1_AVAX_USDC, 1.0e4, LB12_ID | ONE_FOR_ZERO);

        vm.startPrank(alice);
        IERC20(USDT).approve(address(router), amountIn);
        (uint256 totalIn, uint256 totalOut) = router.swapExactIn{value: 0.1e18}(
            address(logic), USDT, address(0), amountIn, 1, alice, block.timestamp, route
        );
        vm.stopPrank();

        uint256 feeAmount = totalOut * 0.1e4 / 0.9e4;
        uint256 protocolFeeAmount = feeAmount * FEE_BIPS / 1e4;

        assertEq(totalIn, amountIn, "test_SwapExactInTokenToNativeWithFee::1");
        assertGt(totalOut, 0, "test_SwapExactInTokenToNativeWithFee::2");
        assertEq(alice.balance, 0.1e18 + totalOut, "test_SwapExactInTokenToNativeWithFee::3");
        assertEq(IERC20(USDT).balanceOf(alice), 0, "test_SwapExactInTokenToNativeWithFee::4");
        assertEq(IERC20(WAVAX).balanceOf(feeReceiver), protocolFeeAmount, "test_SwapExactInTokenToNativeWithFee::5");
        assertEq(
            IERC20(WAVAX).balanceOf(thirdPartyFeeReceiver),
            feeAmount - protocolFeeAmount,
            "test_SwapExactInTokenToNativeWithFee::6"
        );
    }

    function test_SwapExactOutTokenToNative() public {
        uint128 amountOut = 1e18;
        uint256 maxAmountIn = 1000e6;

        vm.deal(alice, 0.1e18);
        deal(USDT, alice, maxAmountIn);

        (bytes memory route, uint256 ptr) = _createRoutes(4, 10);

        ptr = _setIsTransferTaxToken(route, ptr, false);
        ptr = _setToken(route, ptr, USDT);
        ptr = _setToken(route, ptr, USDC);
        ptr = _setToken(route, ptr, BTCB);
        ptr = _setToken(route, ptr, WAVAX);

        ptr = _setRoute(route, ptr, USDT, USDC, UV3_USDT_USDC, 1.0e4, UV3_ID | CALLBACK | ZERO_FOR_ONE);
        ptr = _setRoute(route, ptr, USDT, USDC, LB2_USDT_USDC, 0.6e4, LB12_ID | ZERO_FOR_ONE);
        ptr = _setRoute(route, ptr, USDC, BTCB, UV3_BTCB_USDC, 1.0e4, UV3_ID | CALLBACK | ONE_FOR_ZERO);
        ptr = _setRoute(route, ptr, USDC, BTCB, LB2_BTCB_USDC, 0.6e4, LB12_ID | ONE_FOR_ZERO);
        ptr = _setRoute(route, ptr, USDC, WAVAX, TJ1_AVAX_USDC, 1.0e4, TJ1_ID | ONE_FOR_ZERO);
        ptr = _setRoute(route, ptr, USDC, WAVAX, UV3_AVAX_USDC, 0.6e4, UV3_ID | CALLBACK | ONE_FOR_ZERO);
        ptr = _setRoute(route, ptr, BTCB, WAVAX, LB2_AVAX_BTCB, 0.5e4, LB12_ID | ONE_FOR_ZERO);
        ptr = _setRoute(route, ptr, BTCB, WAVAX, LB1_BTCB_AVAX, 0.4e4, LB12_ID | ZERO_FOR_ONE);
        ptr = _setRoute(route, ptr, USDC, WAVAX, LB1_AVAX_USDC, 0.3e4, LB12_ID | ONE_FOR_ZERO);
        ptr = _setRoute(route, ptr, USDC, WAVAX, LB0_AVAX_USDC, 0.0001e4, LB0_ID | ONE_FOR_ZERO);

        vm.startPrank(alice);
        IERC20(USDT).approve(address(router), maxAmountIn);
        (uint256 totalIn, uint256 totalOut) = router.swapExactOut{value: 0.1e18}(
            address(logic), USDT, address(0), amountOut, maxAmountIn, alice, block.timestamp, route
        );
        vm.stopPrank();

        assertLe(totalIn, maxAmountIn, "test_SwapExactOutTokenToNative::1");
        assertGe(totalOut, amountOut, "test_SwapExactOutTokenToNative::2");
        assertEq(alice.balance, 0.1e18 + totalOut, "test_SwapExactOutTokenToNative::3");
        assertEq(IERC20(USDT).balanceOf(alice), maxAmountIn - totalIn, "test_SwapExactOutTokenToNative::4");
    }

    function test_SwapExactOutTokenToNativeWithFeeIn() public {
        uint128 amountOut = 1e18;
        uint256 maxAmountIn = 1000e6;

        vm.deal(alice, 0.1e18);
        deal(USDT, alice, maxAmountIn);

        (bytes memory route, uint256 ptr) = _createRoutes(4, 11);

        ptr = _setIsTransferTaxToken(route, ptr, false);
        ptr = _setToken(route, ptr, USDT);
        ptr = _setToken(route, ptr, USDC);
        ptr = _setToken(route, ptr, BTCB);
        ptr = _setToken(route, ptr, WAVAX);

        ptr = _setFeePercentIn(route, ptr, thirdPartyFeeReceiver, 0.1e4); // 10% fee
        ptr = _setRoute(route, ptr, USDT, USDC, UV3_USDT_USDC, 1.0e4, UV3_ID | CALLBACK | ZERO_FOR_ONE);
        ptr = _setRoute(route, ptr, USDT, USDC, LB2_USDT_USDC, 0.6e4, LB12_ID | ZERO_FOR_ONE);
        ptr = _setRoute(route, ptr, USDC, BTCB, UV3_BTCB_USDC, 1.0e4, UV3_ID | CALLBACK | ONE_FOR_ZERO);
        ptr = _setRoute(route, ptr, USDC, BTCB, LB2_BTCB_USDC, 0.6e4, LB12_ID | ONE_FOR_ZERO);
        ptr = _setRoute(route, ptr, USDC, WAVAX, TJ1_AVAX_USDC, 1.0e4, TJ1_ID | ONE_FOR_ZERO);
        ptr = _setRoute(route, ptr, USDC, WAVAX, UV3_AVAX_USDC, 0.6e4, UV3_ID | CALLBACK | ONE_FOR_ZERO);
        ptr = _setRoute(route, ptr, BTCB, WAVAX, LB2_AVAX_BTCB, 0.5e4, LB12_ID | ONE_FOR_ZERO);
        ptr = _setRoute(route, ptr, BTCB, WAVAX, LB1_BTCB_AVAX, 0.4e4, LB12_ID | ZERO_FOR_ONE);
        ptr = _setRoute(route, ptr, USDC, WAVAX, LB1_AVAX_USDC, 0.3e4, LB12_ID | ONE_FOR_ZERO);
        ptr = _setRoute(route, ptr, USDC, WAVAX, LB0_AVAX_USDC, 0.0001e4, LB0_ID | ONE_FOR_ZERO);

        vm.startPrank(alice);
        IERC20(USDT).approve(address(router), maxAmountIn);
        (uint256 totalIn, uint256 totalOut) = router.swapExactOut{value: 0.1e18}(
            address(logic), USDT, address(0), amountOut, maxAmountIn, alice, block.timestamp, route
        );
        vm.stopPrank();

        uint256 feeAmount = totalIn * 0.1e4 / 1e4;
        uint256 protocolFeeAmount = feeAmount * FEE_BIPS / 1e4;

        assertLe(totalIn, maxAmountIn, "test_SwapExactOutTokenToNativeWithFee::1");
        assertGe(totalOut, amountOut, "test_SwapExactOutTokenToNativeWithFee::2");
        assertEq(alice.balance, 0.1e18 + totalOut, "test_SwapExactOutTokenToNativeWithFee::3");
        assertEq(IERC20(USDT).balanceOf(alice), maxAmountIn - totalIn, "test_SwapExactOutTokenToNativeWithFee::4");
        assertEq(IERC20(USDT).balanceOf(feeReceiver), protocolFeeAmount, "test_SwapExactOutTokenToNativeWithFee::5");
        assertEq(
            IERC20(USDT).balanceOf(thirdPartyFeeReceiver),
            feeAmount - protocolFeeAmount,
            "test_SwapExactOutTokenToNativeWithFee::6"
        );
    }

    function test_SwapExactOutTokenToNativeWithFeeOut() public {
        uint128 amountOut = 1e18;
        uint256 maxAmountIn = 1000e6;

        vm.deal(alice, 0.1e18);
        deal(USDT, alice, maxAmountIn);

        (bytes memory route, uint256 ptr) = _createRoutes(4, 11);

        ptr = _setIsTransferTaxToken(route, ptr, false);
        ptr = _setToken(route, ptr, USDT);
        ptr = _setToken(route, ptr, USDC);
        ptr = _setToken(route, ptr, BTCB);
        ptr = _setToken(route, ptr, WAVAX);

        ptr = _setFeePercentOut(route, ptr, thirdPartyFeeReceiver, 0.1e4); // 10% fee
        ptr = _setRoute(route, ptr, USDT, USDC, UV3_USDT_USDC, 1.0e4, UV3_ID | CALLBACK | ZERO_FOR_ONE);
        ptr = _setRoute(route, ptr, USDT, USDC, LB2_USDT_USDC, 0.6e4, LB12_ID | ZERO_FOR_ONE);
        ptr = _setRoute(route, ptr, USDC, BTCB, UV3_BTCB_USDC, 1.0e4, UV3_ID | CALLBACK | ONE_FOR_ZERO);
        ptr = _setRoute(route, ptr, USDC, BTCB, LB2_BTCB_USDC, 0.6e4, LB12_ID | ONE_FOR_ZERO);
        ptr = _setRoute(route, ptr, USDC, WAVAX, TJ1_AVAX_USDC, 1.0e4, TJ1_ID | ONE_FOR_ZERO);
        ptr = _setRoute(route, ptr, USDC, WAVAX, UV3_AVAX_USDC, 0.6e4, UV3_ID | CALLBACK | ONE_FOR_ZERO);
        ptr = _setRoute(route, ptr, BTCB, WAVAX, LB2_AVAX_BTCB, 0.5e4, LB12_ID | ONE_FOR_ZERO);
        ptr = _setRoute(route, ptr, BTCB, WAVAX, LB1_BTCB_AVAX, 0.4e4, LB12_ID | ZERO_FOR_ONE);
        ptr = _setRoute(route, ptr, USDC, WAVAX, LB1_AVAX_USDC, 0.3e4, LB12_ID | ONE_FOR_ZERO);
        ptr = _setRoute(route, ptr, USDC, WAVAX, LB0_AVAX_USDC, 0.0001e4, LB0_ID | ONE_FOR_ZERO);

        vm.startPrank(alice);
        IERC20(USDT).approve(address(router), maxAmountIn);
        (uint256 totalIn, uint256 totalOut) = router.swapExactOut{value: 0.1e18}(
            address(logic), USDT, address(0), amountOut, maxAmountIn, alice, block.timestamp, route
        );
        vm.stopPrank();

        uint256 feeAmount = totalOut * 0.1e4 / 0.9e4;
        uint256 protocolFeeAmount = feeAmount * FEE_BIPS / 1e4;

        assertLe(totalIn, maxAmountIn, "test_SwapExactOutTokenToNativeWithFee::1");
        assertGe(totalOut, amountOut, "test_SwapExactOutTokenToNativeWithFee::2");
        assertEq(alice.balance, 0.1e18 + totalOut, "test_SwapExactOutTokenToNativeWithFee::3");
        assertEq(IERC20(USDT).balanceOf(alice), maxAmountIn - totalIn, "test_SwapExactOutTokenToNativeWithFee::4");
        assertEq(IERC20(WAVAX).balanceOf(feeReceiver), protocolFeeAmount, "test_SwapExactOutTokenToNativeWithFee::5");
        assertEq(
            IERC20(WAVAX).balanceOf(thirdPartyFeeReceiver),
            feeAmount - protocolFeeAmount,
            "test_SwapExactOutTokenToNativeWithFee::6"
        );
    }

    function test_UV3OutOfLiquidity() public {
        MockERC20 t0 = new MockERC20("T0", "T0", 18);
        MockERC20 t1 = new MockERC20("T1", "T1", 18);

        vm.label(address(t0), "Token0");
        vm.label(address(t1), "Token1");

        address pool = IV3Factory(0x740b1c1de25031C31FF4fC9A62f554A55cdC1baD).createPool(address(t0), address(t1), 3000);
        IV3Pool(pool).initialize(2 ** 96);
        int24 tickSpacing = IV3Pool(pool).tickSpacing();

        int24 tickA = -tickSpacing;
        int24 tickB = tickSpacing;

        IV3Pool(pool).mint(address(this), tickA, tickB, 1e16, abi.encode(t0, t1));

        uint128 amountIn = 1e24;

        MockERC20(t0).mint(alice, amountIn);

        uint16 order = IV3Pool(pool).token0() == address(t0) ? ZERO_FOR_ONE : ONE_FOR_ZERO;

        (bytes memory route, uint256 ptr) = _createRoutes(2, 1);

        ptr = _setIsTransferTaxToken(route, ptr, false);
        ptr = _setToken(route, ptr, address(t0));
        ptr = _setToken(route, ptr, address(t1));
        ptr = _setRoute(route, ptr, address(t0), address(t1), pool, 1e4, UV3_ID | CALLBACK | order);

        vm.startPrank(alice);
        IERC20(address(t0)).approve(address(router), amountIn);

        vm.expectRevert(RouterAdapter.RouterAdapter__UnexpectedAmountIn.selector);
        router.swapExactIn(address(logic), address(t0), address(t1), amountIn, 1, alice, block.timestamp, route);
        vm.stopPrank();
    }

    function test_Edge_3() public {
        address token1 = USDC;
        address wnative = WAVAX;
        address lbPairETH = LB1_AVAX_USDC;
        address bob = makeAddr("Bob");

        uint128 amountIn = 10 ether;
        deal(alice, 100 ether);
        deal(address(token1), address(lbPairETH), IERC20(token1).balanceOf(lbPairETH) + 100e6);
        deal(address(wnative), address(lbPairETH), IERC20(wnative).balanceOf(lbPairETH) + 10e18);

        (bytes memory route, uint256 ptr) = _createRoutes(2, 1);

        ptr = _setIsTransferTaxToken(route, ptr, false);
        ptr = _setToken(route, ptr, address(wnative));
        ptr = _setToken(route, ptr, address(token1));
        ptr =
            _setRoute(route, ptr, address(wnative), address(token1), address(lbPairETH), 1.0e4, LB12_ID | ZERO_FOR_ONE);
        vm.startPrank(alice);
        bytes memory data = abi.encodeCall(
            Router.swapExactIn,
            (address(logic), address(0), address(token1), amountIn, 1, bob, type(uint256).max, route)
        );
        (bool s,) = address(router).call{value: amountIn}(data);
        require(s, "failed");
        vm.stopPrank();
    }

    function test_Swap_Edge2() public {
        uint128 amountIn = 100e6;

        deal(USDC, alice, amountIn);

        (bytes memory route, uint256 ptr) = _createRoutes(4, 3);

        ptr = _setIsTransferTaxToken(route, ptr, false);
        ptr = _setToken(route, ptr, USDC);
        ptr = _setToken(route, ptr, WAVAX);
        ptr = _setToken(route, ptr, WETH);
        ptr = _setToken(route, ptr, USDT);
        ptr = _setRoute(route, ptr, USDC, WAVAX, LB1_AVAX_USDC, 1.0e4, LB12_ID | ONE_FOR_ZERO);
        ptr = _setRoute(route, ptr, WAVAX, WETH, LB1_AVAX_USDC, 1.0e4, LB12_ID | ZERO_FOR_ONE);
        ptr = _setRoute(route, ptr, WETH, USDT, UV3_USDT_USDC, 1.0e4, UV3_ID | CALLBACK | ONE_FOR_ZERO);

        uint256 xord = (uint256(uint160(WETH)) << 96) ^ (uint256(uint160(USDC)) << 96);
        assembly ("memory-safe") {
            let p := add(0x22, mul(2, 20))
            let v := mload(add(route, p))
            log0(add(route, 0x20), mload(route))
            mstore(add(route, p), xor(v, xord))
            log0(add(route, 0x20), mload(route))
        }

        vm.startPrank(alice);
        IERC20(USDC).approve(address(router), amountIn);
        router.swapExactOut(
            address(logic), USDC, USDT, amountIn / 2, type(uint256).max, alice, type(uint256).max, route
        );
        vm.stopPrank();

        IERC20(USDC).balanceOf(address(logic));
        IERC20(WAVAX).balanceOf(address(logic));
        IERC20(USDT).balanceOf(address(logic));
    }

    function uniswapV3MintCallback(uint256 amount0Owed, uint256 amount1Owed, bytes calldata data) external {
        (address token0, address token1) = abi.decode(data, (address, address));
        MockERC20(token0).mint(msg.sender, uint256(amount0Owed));
        MockERC20(token1).mint(msg.sender, uint256(amount1Owed));
    }

    function test_Swap_InvalidCallback() public {
        uint128 amountIn = 100e6;

        deal(USDC, alice, amountIn);
        deal(USDT, address(logic), 1e18); // Mint some USDT to logic contract to try to transfer USDT instead of USDC

        (bytes memory route, uint256 ptr) = _createRoutes(2, 1);

        ptr = _setIsTransferTaxToken(route, ptr, false);
        ptr = _setToken(route, ptr, USDC);
        ptr = _setToken(route, ptr, WETH);
        ptr = _setRoute(route, ptr, USDC, WETH, address(this), 1.0e4, UV3_ID | CALLBACK | ONE_FOR_ZERO);

        vm.startPrank(alice);
        IERC20(USDC).approve(address(router), amountIn);

        _data = abi.encode(1e18, 1e18, address(USDT));

        vm.expectRevert(RouterAdapter.RouterAdapter__UnexpectedCallback.selector);
        router.swapExactIn(address(logic), USDC, WETH, 100e6, 1e18, alice, 1e18, route);
        vm.stopPrank();
    }

    bytes private _data;

    function swap(address, bool, int256, uint160, bytes calldata) external returns (int256, int256) {
        (int256 amount0Delta, int256 amount1Delta, address token) = abi.decode(_data, (int256, int256, address));
        IV3Callback(address(logic)).uniswapV3SwapCallback(amount0Delta, amount1Delta, abi.encode(token));
        return (amount0Delta, amount1Delta);
    }
}

interface IV3Factory {
    function createPool(address tokenA, address tokenB, uint24 fee) external returns (address pool);
}

interface IV3Callback {
    function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata data) external;
}

interface IV3Pool {
    function token0() external view returns (address);
    function initialize(uint160 sqrtPriceX96) external;
    function tickSpacing() external view returns (int24);
    function mint(address recipient, int24 tickLower, int24 tickUpper, uint128 amount, bytes calldata data)
        external
        returns (uint256 amount0, uint256 amount1);
}
