// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import "../src/Router.sol";
import "../src/RouterLogic.sol";

contract RouterIntegrationTest is Test {
    Router public router;
    RouterLogic public logic;

    uint16 public ONE_FOR_ZERO = 0;
    uint16 public ZERO_FOR_ONE = uint16(Flags.ZERO_FOR_ONE);
    uint16 public CALLBACK = uint16(Flags.CALLBACK);

    address public WAVAX = 0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7;
    address public WETH = 0x49D5c2BdFfac6CE2BFdB6640F4F80f226bc10bAB;
    address public USDC = 0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E;
    address public USDT = 0x9702230A8Ea53601f5cD2dc00fDBc13d4dF4A8c7;

    uint16 public TJ1_ID = uint16(Flags.UNISWAP_V2_ID);
    address public TJ1_WETH_AVAX = 0xFE15c2695F1F920da45C30AAE47d11dE51007AF9;
    address public TJ1_AVAX_USDC = 0xf4003F4efBE8691B60249E6afbD307aBE7758adb;
    address public TJ1_USDT_USDC = 0x8D5dB5D48F5C46A4263DC46112B5d2e3c5626423;

    uint16 public LB0_ID = uint16(Flags.TRADERJOE_LEGACY_LB_ID);
    address public LB0_WETH_AVAX = 0x42Be75636374dfA0e57EB96fA7F68fE7FcdAD8a3;
    address public LB0_AVAX_USDC = 0xB5352A39C11a81FE6748993D586EC448A01f08b5;
    address public LB0_USDT_USDC = 0x1D7A1a79e2b4Ef88D2323f3845246D24a3c20F1d;
    address public LB0_ROUTER = 0xE3Ffc583dC176575eEA7FD9dF2A7c65F7E23f4C3;

    uint16 public LB12_ID = uint16(Flags.TRADERJOE_LB_ID);
    address public LB1_WETH_AVAX = 0x1901011a39B11271578a1283D620373aBeD66faA;
    address public LB1_AVAX_USDC = 0xD446eb1660F766d533BeCeEf890Df7A69d26f7d1;
    address public LB2_USDT_USDC = 0x2823299af89285fF1a1abF58DB37cE57006FEf5D;

    uint16 public UV3_ID = uint16(Flags.UNISWAP_V3_ID);
    address public UV3_WETH_AVAX = 0x7b602f98D71715916E7c963f51bfEbC754aDE2d0;
    address public UV3_AVAX_USDC = 0xfAe3f424a0a47706811521E3ee268f00cFb5c45E;
    address public UV3_USDT_USDC = 0x804226cA4EDb38e7eF56D16d16E92dc3223347A0;

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
        vm.label(UV3_WETH_AVAX, "UV3_WETH_AVAX");
        vm.label(UV3_AVAX_USDC, "UV3_AVAX_USDC");
        vm.label(UV3_USDT_USDC, "UV3_USDT_USDC");
    }

    function test_SwapExactIn() public {
        // WETH -> AVAX -> USDC -> USDT
        uint128 amountIn = 1e18;

        deal(WETH, alice, amountIn);

        bytes memory routes = abi.encodePacked(
            abi.encodePacked(uint8(4), false, WETH, WAVAX, USDC, USDT),
            abi.encodePacked(UV3_WETH_AVAX, uint16(0.2e4), UV3_ID | CALLBACK | ZERO_FOR_ONE, uint8(0), uint8(1)),
            abi.encodePacked(LB1_WETH_AVAX, uint16(1.0e4), LB12_ID | ZERO_FOR_ONE, uint8(0), uint8(1)),
            abi.encodePacked(UV3_AVAX_USDC, uint16(0.3e4), UV3_ID | CALLBACK | ZERO_FOR_ONE, uint8(1), uint8(2)),
            abi.encodePacked(TJ1_AVAX_USDC, uint16(0.6e4), TJ1_ID | ZERO_FOR_ONE, uint8(1), uint8(2)),
            abi.encodePacked(LB1_AVAX_USDC, uint16(1.0e4), LB12_ID | ZERO_FOR_ONE, uint8(1), uint8(2)),
            abi.encodePacked(UV3_USDT_USDC, uint16(0.4e4), UV3_ID | CALLBACK | ONE_FOR_ZERO, uint8(2), uint8(3)),
            abi.encodePacked(LB2_USDT_USDC, uint16(1.0e4), LB12_ID | ONE_FOR_ZERO, uint8(2), uint8(3))
        );

        vm.startPrank(alice);
        IERC20(WETH).approve(address(router), amountIn);
        (uint256 totalIn, uint256 totalOut) =
            router.swapExactIn(WETH, USDT, amountIn, 0, alice, block.timestamp, routes);
        vm.stopPrank();

        assertEq(totalIn, amountIn, "test_SwapExactIn::2");
        assertGt(totalOut, 0, "test_SwapExactIn::3");
        assertEq(IERC20(WETH).balanceOf(alice), 0, "test_SwapExactIn::4");
        assertEq(IERC20(USDT).balanceOf(alice), totalOut, "test_SwapExactIn::5");
    }

    function test_SwapExactOut() public {
        // WETH -> AVAX -> USDC -> USDT
        uint128 amountOut = 1000e6;
        uint256 maxAmountIn = 1e18;

        deal(WETH, alice, maxAmountIn);

        bytes memory routes = abi.encodePacked(
            abi.encodePacked(uint8(4), true, WETH, WAVAX, USDC, USDT),
            abi.encodePacked(UV3_USDT_USDC, uint16(0.4e4), UV3_ID | CALLBACK | ONE_FOR_ZERO, uint8(2), uint8(3)),
            abi.encodePacked(LB2_USDT_USDC, uint16(1.0e4), LB12_ID | ONE_FOR_ZERO, uint8(2), uint8(3)),
            abi.encodePacked(UV3_AVAX_USDC, uint16(0.3e4), UV3_ID | CALLBACK | ZERO_FOR_ONE, uint8(1), uint8(2)),
            abi.encodePacked(TJ1_AVAX_USDC, uint16(0.6e4), TJ1_ID | ZERO_FOR_ONE, uint8(1), uint8(2)),
            abi.encodePacked(LB1_AVAX_USDC, uint16(1.0e4), LB12_ID | ZERO_FOR_ONE, uint8(1), uint8(2)),
            abi.encodePacked(UV3_WETH_AVAX, uint16(0.2e4), UV3_ID | CALLBACK | ZERO_FOR_ONE, uint8(0), uint8(1)),
            abi.encodePacked(LB1_WETH_AVAX, uint16(1.0e4), LB12_ID | ZERO_FOR_ONE, uint8(0), uint8(1))
        );

        vm.startPrank(alice);
        IERC20(WETH).approve(address(router), maxAmountIn);
        (uint256 totalIn, uint256 totalOut) =
            router.swapExactOut(WETH, USDT, amountOut, maxAmountIn, alice, block.timestamp, routes);
        vm.stopPrank();

        assertLe(totalIn, maxAmountIn, "test_SwapExactOut::2");
        assertGe(totalOut, amountOut, "test_SwapExactOut::3");
        assertEq(IERC20(WETH).balanceOf(alice), maxAmountIn - totalIn, "test_SwapExactOut::4");
        assertEq(IERC20(USDT).balanceOf(alice), amountOut, "test_SwapExactOut::5");
    }

    // function test_SwapExactInMixingDexes() public {
    //     // WETH -> AVAX -> USDC -> USDT
    //     uint128 amountIn0 = 0.3e18;
    //     uint128 amountIn1 = 0.33e18;
    //     uint128 amountIn2 = 0.36e18;
    //     uint128 amountIn3 = 0.01e18;

    //     uint128 amountIn = amountIn0 + amountIn1 + amountIn2 + amountIn3;

    //     deal(WETH, alice, amountIn);

    //     bytes[] memory routes = new bytes[](4);

    //     routes[0] = bytes.concat(
    //         abi.encodePacked(amountIn0),
    //         abi.encodePacked(TJ1_WETH_AVAX, WAVAX, TJ1_ID, ZERO_FOR_ONE),
    //         abi.encodePacked(LB1_AVAX_USDC, USDC, LB12_ID, ZERO_FOR_ONE),
    //         abi.encodePacked(UV3_USDT_USDC, USDT, UV3_ID, ONE_FOR_ZERO | CALLBACK)
    //     );

    //     routes[1] = bytes.concat(
    //         abi.encodePacked(amountIn1),
    //         abi.encodePacked(LB1_WETH_AVAX, WAVAX, LB12_ID, ZERO_FOR_ONE),
    //         abi.encodePacked(UV3_AVAX_USDC, USDC, UV3_ID, ZERO_FOR_ONE | CALLBACK),
    //         abi.encodePacked(TJ1_USDT_USDC, USDT, TJ1_ID, ONE_FOR_ZERO)
    //     );

    //     routes[2] = bytes.concat(
    //         abi.encodePacked(amountIn2),
    //         abi.encodePacked(UV3_WETH_AVAX, WAVAX, UV3_ID, ZERO_FOR_ONE | CALLBACK),
    //         abi.encodePacked(TJ1_AVAX_USDC, USDC, TJ1_ID, ZERO_FOR_ONE),
    //         abi.encodePacked(LB2_USDT_USDC, USDT, LB12_ID, ONE_FOR_ZERO)
    //     );

    //     routes[3] = bytes.concat(
    //         abi.encodePacked(amountIn3),
    //         abi.encodePacked(UV3_WETH_AVAX, WAVAX, UV3_ID, ZERO_FOR_ONE | CALLBACK),
    //         abi.encodePacked(LB0_AVAX_USDC, USDC, LB0_ID, ZERO_FOR_ONE),
    //         abi.encodePacked(UV3_USDT_USDC, USDT, UV3_ID, ONE_FOR_ZERO | CALLBACK)
    //     );

    //     vm.startPrank(alice);
    //     IERC20(WETH).approve(address(router), amountIn);
    //     (uint256 totalIn, uint256 totalOut) =
    //         router.swapExactIn(WETH, USDT, amountIn, 0, alice, block.timestamp, routes);
    //     vm.stopPrank();

    //     assertEq(totalIn, amountIn, "test_SwapExactInMixingDexes::2");
    //     assertGt(totalOut, 0, "test_SwapExactInMixingDexes::3");
    //     assertEq(IERC20(WETH).balanceOf(alice), 0, "test_SwapExactInMixingDexes::4");
    //     assertEq(IERC20(USDT).balanceOf(alice), totalOut, "test_SwapExactInMixingDexes::5");
    // }

    // function test_SwapExactOutMixingDexes() public {
    //     // WETH -> AVAX -> USDC -> USDT
    //     uint128 amountOut0 = 400e6;
    //     uint128 amountOut1 = 90e6;
    //     uint128 amountOut2 = 500e6;
    //     uint128 amountOut3 = 10e6;

    //     uint128 amountOut = amountOut0 + amountOut1 + amountOut2 + amountOut3;
    //     uint256 maxAmountIn = 1e18;

    //     deal(WETH, alice, maxAmountIn);

    //     bytes[] memory routes = new bytes[](4);

    //     routes[0] = bytes.concat(
    //         abi.encodePacked(amountOut0),
    //         abi.encodePacked(TJ1_WETH_AVAX, WAVAX, TJ1_ID, ZERO_FOR_ONE),
    //         abi.encodePacked(LB1_AVAX_USDC, USDC, LB12_ID, ZERO_FOR_ONE),
    //         abi.encodePacked(UV3_USDT_USDC, USDT, UV3_ID, ONE_FOR_ZERO | CALLBACK)
    //     );

    //     routes[1] = bytes.concat(
    //         abi.encodePacked(amountOut1),
    //         abi.encodePacked(LB1_WETH_AVAX, WAVAX, LB12_ID, ZERO_FOR_ONE),
    //         abi.encodePacked(UV3_AVAX_USDC, USDC, UV3_ID, ZERO_FOR_ONE | CALLBACK),
    //         abi.encodePacked(TJ1_USDT_USDC, USDT, TJ1_ID, ONE_FOR_ZERO)
    //     );

    //     routes[2] = bytes.concat(
    //         abi.encodePacked(amountOut2),
    //         abi.encodePacked(UV3_WETH_AVAX, WAVAX, UV3_ID, ZERO_FOR_ONE | CALLBACK),
    //         abi.encodePacked(TJ1_AVAX_USDC, USDC, TJ1_ID, ZERO_FOR_ONE),
    //         abi.encodePacked(LB2_USDT_USDC, USDT, LB12_ID, ONE_FOR_ZERO)
    //     );

    //     routes[3] = bytes.concat(
    //         abi.encodePacked(amountOut3),
    //         abi.encodePacked(UV3_WETH_AVAX, WAVAX, UV3_ID, ZERO_FOR_ONE | CALLBACK),
    //         abi.encodePacked(LB0_AVAX_USDC, USDC, LB0_ID, ZERO_FOR_ONE),
    //         abi.encodePacked(UV3_USDT_USDC, USDT, UV3_ID, ONE_FOR_ZERO | CALLBACK)
    //     );

    //     vm.startPrank(alice);
    //     IERC20(WETH).approve(address(router), maxAmountIn);
    //     (uint256 totalIn, uint256 totalOut) =
    //         router.swapExactOut(WETH, USDT, amountOut, maxAmountIn, alice, block.timestamp, routes);
    //     vm.stopPrank();

    //     assertLe(totalIn, maxAmountIn, "test_SwapExactOutMixingDexes::2");
    //     assertGe(totalOut, amountOut, "test_SwapExactOutMixingDexes::3");
    //     assertEq(IERC20(WETH).balanceOf(alice), maxAmountIn - totalIn, "test_SwapExactOutMixingDexes::4");
    //     assertEq(IERC20(USDT).balanceOf(alice), amountOut, "test_SwapExactOutMixingDexes::5");
    // }

    // function test_SwapExactInMixingDexesNativeIn() public {
    //     // AVAX -> USDC -> USDT
    //     uint128 amountIn0 = 30e18;
    //     uint128 amountIn1 = 33e18;
    //     uint128 amountIn2 = 36e18;
    //     uint128 amountIn3 = 1e18;

    //     uint128 amountIn = amountIn0 + amountIn1 + amountIn2 + amountIn3;

    //     payable(alice).transfer(amountIn);

    //     bytes[] memory routes = new bytes[](4);

    //     routes[0] = bytes.concat(
    //         abi.encodePacked(amountIn0),
    //         abi.encodePacked(LB1_AVAX_USDC, USDC, LB12_ID, ZERO_FOR_ONE),
    //         abi.encodePacked(UV3_USDT_USDC, USDT, UV3_ID, ONE_FOR_ZERO | CALLBACK)
    //     );

    //     routes[1] = bytes.concat(
    //         abi.encodePacked(amountIn1),
    //         abi.encodePacked(UV3_AVAX_USDC, USDC, UV3_ID, ZERO_FOR_ONE | CALLBACK),
    //         abi.encodePacked(TJ1_USDT_USDC, USDT, TJ1_ID, ONE_FOR_ZERO)
    //     );

    //     routes[2] = bytes.concat(
    //         abi.encodePacked(amountIn2),
    //         abi.encodePacked(TJ1_AVAX_USDC, USDC, TJ1_ID, ZERO_FOR_ONE),
    //         abi.encodePacked(LB2_USDT_USDC, USDT, LB12_ID, ONE_FOR_ZERO)
    //     );

    //     routes[3] = bytes.concat(
    //         abi.encodePacked(amountIn3),
    //         abi.encodePacked(LB0_AVAX_USDC, USDC, LB0_ID, ZERO_FOR_ONE),
    //         abi.encodePacked(UV3_USDT_USDC, USDT, UV3_ID, ONE_FOR_ZERO | CALLBACK)
    //     );

    //     vm.startPrank(alice);
    //     (uint256 totalIn, uint256 totalOut) =
    //         router.swapExactIn{value: amountIn}(address(0), USDT, amountIn, 0, alice, block.timestamp, routes);
    //     vm.stopPrank();

    //     assertEq(totalIn, amountIn, "test_SwapExactInMixingDexesNativeIn::2");
    //     assertGt(totalOut, 0, "test_SwapExactInMixingDexesNativeIn::3");
    //     assertEq(alice.balance, 0, "test_SwapExactInMixingDexesNativeIn::4");
    //     assertEq(IERC20(USDT).balanceOf(alice), totalOut, "test_SwapExactInMixingDexesNativeIn::5");
    // }

    // function test_SwapExactOutMixingDexesNativeIn() public {
    //     // AVAX -> USDC -> USDT
    //     uint128 amountOut0 = 400e6;
    //     uint128 amountOut1 = 90e6;
    //     uint128 amountOut2 = 500e6;
    //     uint128 amountOut3 = 10e6;

    //     uint128 amountOut = amountOut0 + amountOut1 + amountOut2 + amountOut3;
    //     uint256 maxAmountIn = 100e18;

    //     payable(alice).transfer(maxAmountIn);

    //     bytes[] memory routes = new bytes[](4);

    //     routes[0] = bytes.concat(
    //         abi.encodePacked(amountOut0),
    //         abi.encodePacked(LB1_AVAX_USDC, USDC, LB12_ID, ZERO_FOR_ONE),
    //         abi.encodePacked(UV3_USDT_USDC, USDT, UV3_ID, ONE_FOR_ZERO | CALLBACK)
    //     );

    //     routes[1] = bytes.concat(
    //         abi.encodePacked(amountOut1),
    //         abi.encodePacked(UV3_AVAX_USDC, USDC, UV3_ID, ZERO_FOR_ONE | CALLBACK),
    //         abi.encodePacked(TJ1_USDT_USDC, USDT, TJ1_ID, ONE_FOR_ZERO)
    //     );

    //     routes[2] = bytes.concat(
    //         abi.encodePacked(amountOut2),
    //         abi.encodePacked(TJ1_AVAX_USDC, USDC, TJ1_ID, ZERO_FOR_ONE),
    //         abi.encodePacked(LB2_USDT_USDC, USDT, LB12_ID, ONE_FOR_ZERO)
    //     );

    //     routes[3] = bytes.concat(
    //         abi.encodePacked(amountOut3),
    //         abi.encodePacked(LB0_AVAX_USDC, USDC, LB0_ID, ZERO_FOR_ONE),
    //         abi.encodePacked(UV3_USDT_USDC, USDT, UV3_ID, ONE_FOR_ZERO | CALLBACK)
    //     );

    //     vm.startPrank(alice);
    //     (uint256 totalIn, uint256 totalOut) = router.swapExactOut{value: maxAmountIn}(
    //         address(0), USDT, amountOut, maxAmountIn, alice, block.timestamp, routes
    //     );
    //     vm.stopPrank();

    //     assertLe(totalIn, maxAmountIn, "test_SwapExactOutMixingDexesNativeIn::2");
    //     assertGe(totalOut, amountOut, "test_SwapExactOutMixingDexesNativeIn::3");
    //     assertEq(alice.balance, maxAmountIn - totalIn, "test_SwapExactOutMixingDexesNativeIn::4");
    //     assertEq(IERC20(USDT).balanceOf(alice), amountOut, "test_SwapExactOutMixingDexesNativeIn::5");
    // }

    // function test_SwapExactInMixingDexesNativeOut() public {
    //     // USDT -> USDC -> AVAX
    //     uint128 amountIn0 = 450e6;
    //     uint128 amountIn1 = 50e6;
    //     uint128 amountIn2 = 500e6;

    //     uint128 amountIn = amountIn0 + amountIn1 + amountIn2;

    //     deal(USDT, alice, amountIn);

    //     bytes[] memory routes = new bytes[](3);

    //     routes[0] = bytes.concat(
    //         abi.encodePacked(amountIn0),
    //         abi.encodePacked(UV3_USDT_USDC, USDC, UV3_ID, ZERO_FOR_ONE | CALLBACK),
    //         abi.encodePacked(LB1_AVAX_USDC, WAVAX, LB12_ID, ONE_FOR_ZERO)
    //     );

    //     routes[1] = bytes.concat(
    //         abi.encodePacked(amountIn1),
    //         abi.encodePacked(TJ1_USDT_USDC, USDC, TJ1_ID, ZERO_FOR_ONE),
    //         abi.encodePacked(UV3_AVAX_USDC, WAVAX, UV3_ID, ONE_FOR_ZERO | CALLBACK)
    //     );

    //     routes[2] = bytes.concat(
    //         abi.encodePacked(amountIn2),
    //         abi.encodePacked(LB2_USDT_USDC, USDC, LB12_ID, ZERO_FOR_ONE),
    //         abi.encodePacked(TJ1_AVAX_USDC, WAVAX, TJ1_ID, ONE_FOR_ZERO)
    //     );

    //     vm.startPrank(alice);
    //     IERC20(USDT).approve(address(router), amountIn);
    //     (uint256 totalIn, uint256 totalOut) =
    //         router.swapExactIn(USDT, address(0), amountIn, 0, alice, block.timestamp, routes);
    //     vm.stopPrank();

    //     assertEq(totalIn, amountIn, "test_SwapExactInMixingDexesNativeOut::2");
    //     assertGt(totalOut, 0, "test_SwapExactInMixingDexesNativeOut::3");
    //     assertEq(IERC20(USDT).balanceOf(alice), 0, "test_SwapExactInMixingDexesNativeOut::4");
    //     assertEq(alice.balance, totalOut, "test_SwapExactInMixingDexesNativeOut::5");
    // }

    // function test_SwapExactOutMixingDexesNativeOut() public {
    //     // USDT -> USDC -> AVAX
    //     uint128 amountOut0 = 18e18;
    //     uint128 amountOut1 = 2e18;
    //     uint128 amountOut2 = 20e18;

    //     uint128 amountOut = amountOut0 + amountOut1 + amountOut2;
    //     uint256 maxAmountIn = 3000e6;

    //     deal(USDT, alice, maxAmountIn);

    //     bytes[] memory routes = new bytes[](3);

    //     routes[0] = bytes.concat(
    //         abi.encodePacked(amountOut0),
    //         abi.encodePacked(UV3_USDT_USDC, USDC, UV3_ID, ZERO_FOR_ONE | CALLBACK),
    //         abi.encodePacked(LB1_AVAX_USDC, WAVAX, LB12_ID, ONE_FOR_ZERO)
    //     );

    //     routes[1] = bytes.concat(
    //         abi.encodePacked(amountOut1),
    //         abi.encodePacked(TJ1_USDT_USDC, USDC, TJ1_ID, ZERO_FOR_ONE),
    //         abi.encodePacked(UV3_AVAX_USDC, WAVAX, UV3_ID, ONE_FOR_ZERO | CALLBACK)
    //     );

    //     routes[2] = bytes.concat(
    //         abi.encodePacked(amountOut2),
    //         abi.encodePacked(LB2_USDT_USDC, USDC, LB12_ID, ZERO_FOR_ONE),
    //         abi.encodePacked(TJ1_AVAX_USDC, WAVAX, TJ1_ID, ONE_FOR_ZERO)
    //     );

    //     vm.startPrank(alice);
    //     IERC20(USDT).approve(address(router), maxAmountIn);
    //     (uint256 totalIn, uint256 totalOut) =
    //         router.swapExactOut(USDT, address(0), amountOut, maxAmountIn, alice, block.timestamp, routes);
    //     vm.stopPrank();

    //     assertLe(totalIn, maxAmountIn, "test_SwapExactOutMixingDexesNativeOut::2");
    //     assertGe(totalOut, amountOut, "test_SwapExactOutMixingDexesNativeOut::3");
    //     assertEq(IERC20(USDT).balanceOf(alice), maxAmountIn - totalIn, "test_SwapExactOutMixingDexesNativeOut::4");
    //     assertEq(alice.balance, totalOut, "test_SwapExactOutMixingDexesNativeOut::5");
    // }
}
