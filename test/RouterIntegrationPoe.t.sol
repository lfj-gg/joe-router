// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Test} from "forge-std/Test.sol";

import {IRouter, Router} from "../src/Router.sol";
import {RouterAdapter} from "../src/RouterAdapter.sol";
import {RouterLogic} from "../src/RouterLogic.sol";
import {PackedRouteHelper} from "./PackedRouteHelper.sol";

/// forge-config: default.evm_version = "cancun"
contract RouterIntegrationPoeTest is Test, PackedRouteHelper {
    Router public router;
    RouterLogic public logic;

    address public WMON = 0x3bd359C1119dA7Da1D913D1C4D2B7c461115433A;
    address public USDC = 0x754704Bc059F8C67012fEd69BC8A327a5aafb603;
    address public AUSD = 0x00000000eFE302BEAA2b3e6e1b18d08D69a9012a;

    address public LB2_MON_AUSD = 0xdd0a93642B0e1e938a75B400f31095Af4C4BECE5;
    address public LB2_MON_USDC = 0x5E60BC3F7a7303BC4dfE4dc2220bdC90bc04fE22;

    address public POE_MON_USDC = 0xB7005aFF8Bd64b3f72D07e85933Bd3beaeFc26f6;
    address public POE_ORACLE = 0x9f16b181103C93a587f1235aA3982A64126f323D;
    address public POE_OWNER = 0x72c5456d731fDd9D3480F997226A631231de61Cc;

    address alice = makeAddr("Alice");
    address feeReceiver = makeAddr("FeeReceiver");

    bytes oracleData = abi.encodePacked(
        bytes4(uint32(0xf31604c7)),
        bytes32(0xd8d4e26dcc8cc6a989374c7898e707001150ffbd2d05c52a99772dfd7a08c46a),
        bytes32(0x00000000000000000000000000000004f4f89140186a00000027d80069434baa)
    );

    function setUp() public {
        vm.createSelectFork("https://rpc1.monad.xyz", 42520931);

        router = new Router(WMON, address(this));
        logic = new RouterLogic(address(router), address(0), address(0), WMON, feeReceiver, 0.15e4);

        router.updateRouterLogic(address(logic), true);

        address operator = IOracle(POE_ORACLE).OPERATOR();
        vm.prank(operator);
        (bool success,) = POE_ORACLE.call(oracleData);
        require(success, "Oracle setup failed");

        vm.label(address(router), "Router");
        vm.label(address(logic), "RouterLogic");
        vm.label(WMON, "WMON");
        vm.label(USDC, "USDC");
        vm.label(AUSD, "AUSD");
        vm.label(LB2_MON_USDC, "LB2_MON_USDC");
        vm.label(LB2_MON_AUSD, "LB2_MON_AUSD");
        vm.label(POE_MON_USDC, "POE_MON_USDC");

        // Provide liquidity to POE pool
        deal(WMON, POE_MON_USDC, 1e24);
        deal(USDC, POE_MON_USDC, 1e12);

        vm.prank(POE_OWNER);
        IPool(POE_MON_USDC).allocate(1e4, 1e4);
    }

    function test_SwapExactInTokenToToken() public {
        uint128 amountIn = 1000e6;

        vm.deal(alice, 0.1e18);
        vm.prank(0x9CaB7Ede13dc56652E44D2404E969C212f22689b); // prank AUSD bridge
        IMintable(AUSD).mint(alice, amountIn);

        (bytes memory route, uint256 ptr) = _createRoutes(3, 3);

        ptr = _setIsTransferTaxToken(route, ptr, false);
        ptr = _setToken(route, ptr, AUSD);
        ptr = _setToken(route, ptr, WMON);
        ptr = _setToken(route, ptr, USDC);

        ptr = _setRoute(route, ptr, AUSD, WMON, LB2_MON_AUSD, 1e4, LB12_ID | ONE_FOR_ZERO);
        ptr = _setRoute(route, ptr, WMON, USDC, LB2_MON_USDC, 0.3e4, LB12_ID | ZERO_FOR_ONE);
        ptr = _setRoute(route, ptr, WMON, USDC, POE_MON_USDC, 1e4, POE_ID | ZERO_FOR_ONE | CALLBACK);

        vm.startPrank(alice);
        IERC20(AUSD).approve(address(router), amountIn);

        uint256 expectedOut;
        {
            bytes[] memory multiRoutes = new bytes[](3);

            multiRoutes[0] = route;
            multiRoutes[1] = route;

            (bool success, bytes memory data) = address(router).call{value: 0.1e18}(
                abi.encodeWithSelector(
                    IRouter.simulate.selector, logic, AUSD, USDC, amountIn, 1, alice, true, multiRoutes
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
            router.swapExactIn{value: 0.1e18}(address(logic), AUSD, USDC, amountIn, 1, alice, block.timestamp, route);
        vm.stopPrank();

        assertEq(totalIn, amountIn, "test_SwapExactInTokenToToken::5");
        assertGt(totalOut, 0, "test_SwapExactInTokenToToken::6");
        assertEq(totalOut, expectedOut, "test_SwapExactInTokenToToken::7");
        assertEq(alice.balance, 0.1e18, "test_SwapExactInTokenToToken::8");
        assertEq(IERC20(AUSD).balanceOf(alice), 0, "test_SwapExactInTokenToToken::9");
        assertEq(IERC20(USDC).balanceOf(alice), totalOut, "test_SwapExactInTokenToToken::10");
    }

    function test_SwapExactOutTokenToToken() public {
        uint128 amountOut = 1000e6;
        uint256 maxAmountIn = 1200e6;

        vm.deal(alice, 0.1e18);
        deal(USDC, alice, maxAmountIn);

        (bytes memory route, uint256 ptr) = _createRoutes(3, 3);

        ptr = _setIsTransferTaxToken(route, ptr, false);
        ptr = _setToken(route, ptr, USDC);
        ptr = _setToken(route, ptr, WMON);
        ptr = _setToken(route, ptr, AUSD);

        ptr = _setRoute(route, ptr, USDC, WMON, POE_MON_USDC, 1e4, POE_ID | ONE_FOR_ZERO | CALLBACK);
        ptr = _setRoute(route, ptr, USDC, WMON, LB2_MON_USDC, 0.3e4, LB12_ID | ONE_FOR_ZERO);
        ptr = _setRoute(route, ptr, WMON, AUSD, LB2_MON_AUSD, 1e4, LB12_ID | ZERO_FOR_ONE);

        vm.startPrank(alice);
        IERC20(USDC).approve(address(router), maxAmountIn);

        vm.expectRevert(RouterAdapter.RouterAdapter__InvalidId.selector);
        router.swapExactOut{value: 0.1e18}(
            address(logic), USDC, AUSD, amountOut, maxAmountIn, alice, block.timestamp, route
        );
        vm.stopPrank();
    }

    function test_SwapExactInNativeToToken() public {
        uint128 amountIn = 1000e18;

        vm.deal(alice, amountIn + 0.1e18);

        (bytes memory route, uint256 ptr) = _createRoutes(2, 1);

        ptr = _setIsTransferTaxToken(route, ptr, false);
        ptr = _setToken(route, ptr, WMON);
        ptr = _setToken(route, ptr, USDC);

        ptr = _setRoute(route, ptr, WMON, USDC, POE_MON_USDC, 1.0e4, POE_ID | ZERO_FOR_ONE | CALLBACK);

        vm.prank(alice);
        (uint256 totalIn, uint256 totalOut) = router.swapExactIn{value: amountIn + 0.1e18}(
            address(logic), address(0), USDC, amountIn, 1, alice, block.timestamp, route
        );

        assertEq(totalIn, amountIn, "test_SwapExactInNativeToToken::1");
        assertGt(totalOut, 0, "test_SwapExactInNativeToToken::2");
        assertEq(alice.balance, 0.1e18, "test_SwapExactInNativeToToken::3");
        assertEq(IERC20(USDC).balanceOf(alice), totalOut, "test_SwapExactInNativeToToken::4");
    }

    function test_SwapExactInTokenToNative() public {
        uint128 amountIn = 1000e6;

        vm.deal(alice, 0.1e18);
        deal(USDC, alice, amountIn);

        (bytes memory route, uint256 ptr) = _createRoutes(2, 1);

        ptr = _setIsTransferTaxToken(route, ptr, false);
        ptr = _setToken(route, ptr, USDC);
        ptr = _setToken(route, ptr, WMON);

        ptr = _setRoute(route, ptr, USDC, WMON, POE_MON_USDC, 1.0e4, POE_ID | ONE_FOR_ZERO | CALLBACK);

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
}

interface IMintable {
    function mint(address to, uint256 amount) external;
}

interface IOracle {
    function OPERATOR() external view returns (address);
}

interface IPool {
    function allocate(uint256, uint256) external;
}
