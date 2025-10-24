// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Test} from "forge-std/Test.sol";

import {IRouter, Router} from "../src/Router.sol";
import {RouterAdapter} from "../src/RouterAdapter.sol";
import {RouterLogic} from "../src/RouterLogic.sol";
import {PackedRouteHelper} from "./PackedRouteHelper.sol";

/// forge-config: default.evm_version = "shanghai"
contract RouterIntegrationByRealTest is Test, PackedRouteHelper {
    Router public router;
    RouterLogic public logic;

    address public WMNT = 0x78c1b0C915c4FAA5FffA6CAbf0219DA63d7f4cb8;
    address public USDT = 0x201EBa5CC46D216Ce6DC03F6a759e8E766e956aE;
    address public USDE = 0x5d3a1Ff2b6BAb83b63cd9AD0787074081a52ef34;

    address public LB2_USDE_MNT = 0x5d54d430D1FD9425976147318E6080479bffC16D;
    address public LB2_MNT_USDT = 0xf6C9020c9E915808481757779EDB53DACEaE2415;

    address public BYREAL_MNT_USDT = 0xB97C6E980f6e57785D7ef0BE394F33618D44D641;

    address alice = makeAddr("Alice");
    address feeReceiver = makeAddr("FeeReceiver");

    function setUp() public {
        vm.createSelectFork("https://rpc.mantle.xyz", 86371508);

        router = new Router(WMNT, address(this));
        logic = new RouterLogic(address(router), address(0), address(0), WMNT, feeReceiver, 0.15e4);

        router.updateRouterLogic(address(logic), true);

        vm.label(address(router), "Router");
        vm.label(address(logic), "RouterLogic");
        vm.label(WMNT, "WMNT");
        vm.label(USDT, "USDT");
        vm.label(USDE, "USDE");
        vm.label(LB2_MNT_USDT, "LB2_MNT_USDT");
        vm.label(LB2_USDE_MNT, "LB2_USDE_MNT");
        vm.label(BYREAL_MNT_USDT, "BYREAL_MNT_USDT");

        // Provide liquidity to ByReal pool
        deal(WMNT, BYREAL_MNT_USDT, 1e24);
        deal(USDT, BYREAL_MNT_USDT, 1e12);
    }

    function test_SwapExactInTokenToToken() public {
        uint128 amountIn = 1000e18;

        vm.deal(alice, 0.1e18);
        deal(USDE, alice, amountIn);

        (bytes memory route, uint256 ptr) = _createRoutes(3, 3);

        ptr = _setIsTransferTaxToken(route, ptr, false);
        ptr = _setToken(route, ptr, USDE);
        ptr = _setToken(route, ptr, WMNT);
        ptr = _setToken(route, ptr, USDT);

        ptr = _setRoute(route, ptr, USDE, WMNT, LB2_USDE_MNT, 1e4, LB12_ID | ZERO_FOR_ONE);
        ptr = _setRoute(route, ptr, WMNT, USDT, LB2_MNT_USDT, 0.3e4, LB12_ID | ZERO_FOR_ONE);
        ptr = _setRoute(route, ptr, WMNT, USDT, BYREAL_MNT_USDT, 1e4, BYREAL_ID | ZERO_FOR_ONE | CALLBACK);

        vm.startPrank(alice);
        IERC20(USDE).approve(address(router), amountIn);

        uint256 expectedOut;
        {
            bytes[] memory multiRoutes = new bytes[](3);

            multiRoutes[0] = route;
            multiRoutes[1] = route;

            (bool success, bytes memory data) = address(router).call{value: 0.1e18}(
                abi.encodeWithSelector(
                    IRouter.simulate.selector, logic, USDE, USDT, amountIn, 1, alice, true, multiRoutes
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
            router.swapExactIn{value: 0.1e18}(address(logic), USDE, USDT, amountIn, 1, alice, block.timestamp, route);
        vm.stopPrank();

        assertEq(totalIn, amountIn, "test_SwapExactInTokenToToken::5");
        assertGt(totalOut, 0, "test_SwapExactInTokenToToken::6");
        assertEq(totalOut, expectedOut, "test_SwapExactInTokenToToken::7");
        assertEq(alice.balance, 0.1e18, "test_SwapExactInTokenToToken::8");
        assertEq(IERC20(USDE).balanceOf(alice), 0, "test_SwapExactInTokenToToken::9");
        assertEq(IERC20(USDT).balanceOf(alice), totalOut, "test_SwapExactInTokenToToken::10");
    }

    function test_SwapExactOutTokenToToken() public {
        uint128 amountOut = 1000e18;
        uint256 maxAmountIn = 1200e6;

        vm.deal(alice, 0.1e18);
        deal(USDT, alice, maxAmountIn);

        (bytes memory route, uint256 ptr) = _createRoutes(3, 3);

        ptr = _setIsTransferTaxToken(route, ptr, false);
        ptr = _setToken(route, ptr, USDT);
        ptr = _setToken(route, ptr, WMNT);
        ptr = _setToken(route, ptr, USDE);

        ptr = _setRoute(route, ptr, USDT, WMNT, BYREAL_MNT_USDT, 1e4, BYREAL_ID | ONE_FOR_ZERO | CALLBACK);
        ptr = _setRoute(route, ptr, USDT, WMNT, LB2_MNT_USDT, 0.3e4, LB12_ID | ONE_FOR_ZERO);
        ptr = _setRoute(route, ptr, WMNT, USDE, LB2_USDE_MNT, 1e4, LB12_ID | ONE_FOR_ZERO);

        vm.startPrank(alice);
        IERC20(USDT).approve(address(router), maxAmountIn);

        vm.expectRevert(RouterAdapter.RouterAdapter__InvalidId.selector);
        router.swapExactOut{value: 0.1e18}(
            address(logic), USDT, USDE, amountOut, maxAmountIn, alice, block.timestamp, route
        );
        vm.stopPrank();
    }

    function test_SwapExactInNativeToToken() public {
        uint128 amountIn = 1e18;

        vm.deal(alice, amountIn + 0.1e18);

        (bytes memory route, uint256 ptr) = _createRoutes(2, 1);

        ptr = _setIsTransferTaxToken(route, ptr, false);
        ptr = _setToken(route, ptr, WMNT);
        ptr = _setToken(route, ptr, USDT);

        ptr = _setRoute(route, ptr, WMNT, USDT, BYREAL_MNT_USDT, 1.0e4, BYREAL_ID | ZERO_FOR_ONE | CALLBACK);

        vm.prank(alice);
        (uint256 totalIn, uint256 totalOut) = router.swapExactIn{value: amountIn + 0.1e18}(
            address(logic), address(0), USDT, amountIn, 1, alice, block.timestamp, route
        );

        assertEq(totalIn, amountIn, "test_SwapExactInNativeToToken::1");
        assertGt(totalOut, 0, "test_SwapExactInNativeToToken::2");
        assertEq(alice.balance, 0.1e18, "test_SwapExactInNativeToToken::3");
        assertEq(IERC20(USDT).balanceOf(alice), totalOut, "test_SwapExactInNativeToToken::4");
    }

    function test_SwapExactInTokenToNative() public {
        uint128 amountIn = 1000e6;

        vm.deal(alice, 0.1e18);
        deal(USDT, alice, amountIn);

        (bytes memory route, uint256 ptr) = _createRoutes(2, 1);

        ptr = _setIsTransferTaxToken(route, ptr, false);
        ptr = _setToken(route, ptr, USDT);
        ptr = _setToken(route, ptr, WMNT);

        ptr = _setRoute(route, ptr, USDT, WMNT, BYREAL_MNT_USDT, 1.0e4, BYREAL_ID | ONE_FOR_ZERO | CALLBACK);

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
}
