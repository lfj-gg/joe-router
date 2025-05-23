// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import "../src/Router.sol";
import "../src/RouterLogic.sol";
import "./PackedRouteHelper.sol";
import "./mocks/MockERC20.sol";

/// forge-config: default.evm_version = "shanghai"
contract RouterIntegrationPancakeSwapV3Test is Test, PackedRouteHelper {
    Router public router;
    RouterLogic public logic;

    address public WETH = 0xB5a30b0FDc5EA94A52fDc42e3E9760Cb8449Fb37;
    address public WMON = 0x760AfE86e5de5fa0Ee542fc7B7B713e1c5425701;
    address public USDC = 0xf817257fed379853cDe0fa4F97AB987181B1E5Ea;

    address public PSV2_MON_WETH = 0xaFb3763a2C9576996037CabeE2517c09a1218DA2;

    address public PSV3_MON_USDC = 0xb39E5Fa485CAC152d9e62d3A20E6a6efb3F9DA69;

    address alice = makeAddr("Alice");
    address feeReceiver = makeAddr("FeeReceiver");

    function setUp() public {
        vm.createSelectFork("https://testnet-rpc.monad.xyz", 16399750);

        router = new Router(WMON, address(this));
        logic = new RouterLogic(address(router), address(0), feeReceiver, 0.15e4);

        router.updateRouterLogic(address(logic), true);

        vm.label(address(router), "Router");
        vm.label(address(logic), "RouterLogic");
        vm.label(WMON, "WMON");
        vm.label(WETH, "WETH");
        vm.label(USDC, "USDC");
        vm.label(PSV2_MON_WETH, "PSV2_MON_WETH");
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

        ptr = _setRoute(route, ptr, WETH, WMON, PSV2_MON_WETH, 1e4, TJ1_ID | ONE_FOR_ZERO);
        ptr = _setRoute(route, ptr, WMON, USDC, PSV3_MON_USDC, 1e4, UV3_ID | ZERO_FOR_ONE | CALLBACK);

        vm.startPrank(alice);
        IERC20(WETH).approve(address(router), amountIn);

        uint256 expectedOut;
        {
            bytes[] memory multiRoutes = new bytes[](3);

            multiRoutes[0] = route;
            multiRoutes[1] = route;

            (, bytes memory data) = address(router).call{value: 0.1e18}(
                abi.encodeWithSelector(
                    IRouter.simulate.selector, logic, WETH, USDC, amountIn, 1, alice, true, multiRoutes
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
            router.swapExactIn{value: 0.1e18}(address(logic), WETH, USDC, amountIn, 1, alice, block.timestamp, route);
        vm.stopPrank();

        assertEq(totalIn, amountIn, "test_SwapExactInTokenToToken::4");
        assertGt(totalOut, 0, "test_SwapExactInTokenToToken::5");
        assertEq(totalOut, expectedOut, "test_SwapExactInTokenToToken::6");
        assertEq(alice.balance, 0.1e18, "test_SwapExactInTokenToToken::7");
        assertEq(IERC20(WETH).balanceOf(alice), 0, "test_SwapExactInTokenToToken::8");
        assertEq(IERC20(USDC).balanceOf(alice), totalOut, "test_SwapExactInTokenToToken::9");
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

        ptr = _setRoute(route, ptr, USDC, WMON, PSV3_MON_USDC, 1.0e4, UV3_ID | ONE_FOR_ZERO | CALLBACK);
        ptr = _setRoute(route, ptr, WMON, WETH, PSV2_MON_WETH, 1.0e4, TJ1_ID | ZERO_FOR_ONE);

        vm.startPrank(alice);
        IERC20(USDC).approve(address(router), maxAmountIn);

        uint256 expectedIn;
        {
            bytes[] memory multiRoutes = new bytes[](3);

            multiRoutes[0] = route;
            multiRoutes[1] = route;

            (, bytes memory data) = address(router).call{value: 0.1e18}(
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
            address(logic), USDC, WETH, amountOut, maxAmountIn, alice, block.timestamp, route
        );
        vm.stopPrank();

        assertLe(totalIn, maxAmountIn, "test_SwapExactOutTokenToToken::4");
        assertEq(totalIn, expectedIn, "test_SwapExactOutTokenToToken::5");
        assertGe(totalOut, amountOut, "test_SwapExactOutTokenToToken::6");
        assertEq(alice.balance, 0.1e18, "test_SwapExactOutTokenToToken::7");
        assertEq(IERC20(USDC).balanceOf(alice), maxAmountIn - totalIn, "test_SwapExactOutTokenToToken::8");
        assertEq(IERC20(WETH).balanceOf(alice), amountOut, "test_SwapExactOutTokenToToken::9");
    }

    function test_SwapExactInNativeToToken() public {
        uint128 amountIn = 0.1e18;

        vm.deal(alice, amountIn + 0.2e18);

        (bytes memory route, uint256 ptr) = _createRoutes(2, 1);

        ptr = _setIsTransferTaxToken(route, ptr, false);
        ptr = _setToken(route, ptr, WMON);
        ptr = _setToken(route, ptr, USDC);

        ptr = _setRoute(route, ptr, WMON, USDC, PSV3_MON_USDC, 1.0e4, UV3_ID | ZERO_FOR_ONE | CALLBACK);

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
        uint256 maxAmountIn = 1e18;

        vm.deal(alice, maxAmountIn + 0.2e18);

        (bytes memory route, uint256 ptr) = _createRoutes(2, 1);

        ptr = _setIsTransferTaxToken(route, ptr, false);
        ptr = _setToken(route, ptr, WMON);
        ptr = _setToken(route, ptr, USDC);

        ptr = _setRoute(route, ptr, WMON, USDC, PSV3_MON_USDC, 1.0e4, UV3_ID | ZERO_FOR_ONE | CALLBACK);

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

        ptr = _setRoute(route, ptr, USDC, WMON, PSV3_MON_USDC, 1.0e4, UV3_ID | ONE_FOR_ZERO | CALLBACK);

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

        ptr = _setRoute(route, ptr, USDC, WMON, PSV3_MON_USDC, 1.0e4, UV3_ID | ONE_FOR_ZERO | CALLBACK);

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
