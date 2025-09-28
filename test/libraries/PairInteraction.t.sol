// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";

import {PairInteraction} from "../../src/libraries/PairInteraction.sol";
import {TokenLib} from "../../src/libraries/TokenLib.sol";
import {PackedRoute, PackedRouteHelper} from "../PackedRouteHelper.sol";
import {ILBPair} from "../interfaces/ILBPair.sol";
import {ILegacyLBPair} from "../interfaces/ILegacyLBPair.sol";
import {ITMPair} from "../interfaces/ITMPair.sol";
import {ITMPairV2} from "../interfaces/ITMPairV2.sol";
import {IUV2Pair} from "../interfaces/IUV2Pair.sol";
import {IUV3Pair} from "../interfaces/IUV3Pair.sol";
import {IUV4Manager} from "../interfaces/IUV4Manager.sol";

import {MockERC20} from "../mocks/MockERC20.sol";
import {MockV4Manager} from "../mocks/MockV4Manager.sol";
import {WNative} from "../mocks/WNative.sol";

contract PairInteractionTest is Test, PackedRouteHelper {
    error CustomError();

    uint256 _case;

    bytes _data;
    bytes _msgData;

    address wnative;
    address tokenA;
    address tokenB;

    address payable uniswapV4;
    address to;

    receive() external payable {
        if (msg.sender != wnative) TokenLib.wrap(wnative, msg.value);
    }

    fallback() external {
        uint256 c = _case;

        if (c == 0) {
            _msgData = msg.data;
            c = 1;
        }

        if (c == 1) {
            bytes memory data = _data;

            assembly ("memory-safe") {
                return(add(data, 0x20), mload(data))
            }
        }

        if (c == 2) {
            bytes memory data = _data;

            assembly ("memory-safe") {
                revert(add(data, 0x20), mload(data))
            }
        }

        if (c == 3 || c == 4) {
            (bytes memory b0, bytes memory b1) = abi.decode(_data, (bytes, bytes));

            if (msg.sig == ITMPairV2.getSqrtRatiosBounds.selector || msg.sig == IUV4Manager.sync.selector) {
                assembly ("memory-safe") {
                    return(add(b0, 0x20), mload(b0))
                }
            } else {
                if (b1.length == 0) revert CustomError();
                else if (b1.length == 1) revert("Error String");

                if (c == 4) _msgData = msg.data;

                assembly ("memory-safe") {
                    return(add(b1, 0x20), mload(b1))
                }
            }
        }

        if (c == 5) {
            (int256 amount0, int256 amount1) = PairInteraction.swapUV4Callback(msg.data, to, wnative);
            bytes memory returnData = abi.encodePacked(uint256(0x20), uint256(0x40), amount0, amount1);
            assembly ("memory-safe") {
                return(add(returnData, 0x20), mload(returnData))
            }
        }
    }

    function setUp() public {
        wnative = address(new WNative());
        tokenA = address(new MockERC20("TokenA", "TK0", 18));
        tokenB = address(new MockERC20("TokenB", "TK1", 6));
        uniswapV4 = payable(address(new MockV4Manager()));
    }

    function test_Fuzz_GetOrderedReservesUV2(bool zeroForOne, uint112 reserve0, uint112 reserve1) public {
        _case = 1;
        _data = abi.encode(reserve0, reserve1);

        (uint256 reserveIn, uint256 reserveOut) = this.getReservesUV2(address(this), zeroForOne);

        (uint256 expectedReserveIn, uint256 expectedReserveOut) =
            zeroForOne ? (reserve0, reserve1) : (reserve1, reserve0);

        assertEq(reserveIn, expectedReserveIn, "test_Fuzz_GetOrderedReservesUV2::1");
        assertEq(reserveOut, expectedReserveOut, "test_Fuzz_GetOrderedReservesUV2::2");
    }

    function test_Fuzz_Revert_GetOrderedReservesUV2(bool zeroForOne) public {
        _case = 2;
        _data = new bytes(64);

        vm.expectRevert(PairInteraction.PairInteraction__InvalidReturnData.selector);
        this.getReservesUV2(address(this), zeroForOne);

        _data = new bytes(63);

        vm.expectRevert(PairInteraction.PairInteraction__InvalidReturnData.selector);
        this.getReservesUV2(address(this), zeroForOne);

        _case = 1;

        vm.expectRevert(PairInteraction.PairInteraction__InvalidReturnData.selector);
        this.getReservesUV2(address(this), zeroForOne);
    }

    function test_Fuzz_SwapUV2(uint256 amount0, uint256 amount1, address recipient) public {
        _case = 0;

        this.swapUV2(address(this), amount0, amount1, recipient);

        assertEq(
            _msgData,
            abi.encodeWithSelector(IUV2Pair.swap.selector, amount0, amount1, recipient, new bytes(0)),
            "test_Fuzz_SwapUV2::1"
        );
    }

    function test_Fuzz_Revert_SwapUV2(uint256 amount0, uint256 amount1, address recipient) public {
        _case = 2;
        _data = abi.encodeWithSelector(CustomError.selector);

        vm.expectRevert(CustomError.selector);
        this.swapUV2(address(this), amount0, amount1, recipient);

        _data = "Error String";

        vm.expectRevert("Error String");
        this.swapUV2(address(this), amount0, amount1, recipient);
    }

    function test_Fuzz_GetSwapInLegacyLB(address pair, uint256 amountOut, bool swapForY, uint256 amountIn) public {
        _case = 1;
        _data = abi.encode(amountIn);

        uint256 amount = this.getSwapInLegacyLB(address(this), pair, amountOut, swapForY);

        assertEq(amount, amountIn, "test_Fuzz_GetSwapInLegacyLB::1");
    }

    function test_Fuzz_Revert_GetSwapInLegacyLB(address pair, uint256 amountOut, bool swapForY) public {
        _case = 1;
        _data = new bytes(31);

        vm.expectRevert(PairInteraction.PairInteraction__InvalidReturnData.selector);
        this.getSwapInLegacyLB(address(this), pair, amountOut, swapForY);

        _case = 2;
        _data = abi.encodeWithSelector(CustomError.selector);

        vm.expectRevert(CustomError.selector);
        this.getSwapInLegacyLB(address(this), pair, amountOut, swapForY);

        _data = "Error String";

        vm.expectRevert("Error String");
        this.getSwapInLegacyLB(address(this), pair, amountOut, swapForY);
    }

    function test_Fuzz_SwapLegacyLB(bool swapForY, address recipient, uint256 amountX, uint256 amountY) public {
        _case = 0;
        _data = abi.encode(amountX, amountY);

        (uint256 amountOut) = this.swapLegacyLB(address(this), swapForY, recipient);

        assertEq(amountOut, swapForY ? amountY : amountX, "test_Fuzz_SwapLegacyLB::1");

        assertEq(
            _msgData,
            abi.encodeWithSelector(ILegacyLBPair.swap.selector, swapForY, recipient),
            "test_Fuzz_SwapLegacyLB::2"
        );
    }

    function test_Fuzz_Revert_SwapLegacyLB(bool swapForY, address recipient) public {
        _case = 1;
        _data = new bytes(63);

        vm.expectRevert(PairInteraction.PairInteraction__InvalidReturnData.selector);
        this.swapLegacyLB(address(this), swapForY, recipient);

        _case = 2;
        _data = abi.encodeWithSelector(CustomError.selector);

        vm.expectRevert(CustomError.selector);
        this.swapLegacyLB(address(this), swapForY, recipient);

        _data = "Error String";

        vm.expectRevert("Error String");
        this.swapLegacyLB(address(this), swapForY, recipient);
    }

    function test_Fuzz_GetSwapInLB(uint256 amountOut, bool swapForY, uint256 amountIn, uint256 amountLeft) public {
        _case = 1;
        _data = abi.encode(amountIn, amountLeft);

        (uint256 amount, uint256 left) = this.getSwapInLB(address(this), amountOut, swapForY);

        assertEq(amount, amountIn, "test_Fuzz_GetSwapInLB::1");
        assertEq(left, amountLeft, "test_Fuzz_GetSwapInLB::2");
    }

    function test_Fuzz_Revert_GetSwapInLB(uint256 amountOut, bool swapForY) public {
        _case = 1;
        _data = new bytes(63);

        vm.expectRevert(PairInteraction.PairInteraction__InvalidReturnData.selector);
        this.getSwapInLB(address(this), amountOut, swapForY);

        _case = 2;
        _data = abi.encodeWithSelector(CustomError.selector);

        vm.expectRevert(CustomError.selector);
        this.getSwapInLB(address(this), amountOut, swapForY);

        _data = "Error String";

        vm.expectRevert("Error String");
        this.getSwapInLB(address(this), amountOut, swapForY);
    }

    function test_Fuzz_SwapLB(bool swapForY, address recipient, uint128 amountX, uint128 amountY) public {
        _case = 0;
        _data = abi.encodePacked(amountY, amountX);

        (uint256 amountOut) = this.swapLB(address(this), swapForY, recipient);

        assertEq(amountOut, swapForY ? amountY : amountX, "test_Fuzz_SwapLB::1");

        assertEq(_msgData, abi.encodeWithSelector(ILBPair.swap.selector, swapForY, recipient), "test_Fuzz_SwapLB::2");
    }

    function test_Fuzz_Revert_SwapLB(bool swapForY, address recipient) public {
        _case = 1;
        _data = new bytes(31);

        vm.expectRevert(PairInteraction.PairInteraction__InvalidReturnData.selector);
        this.swapLB(address(this), swapForY, recipient);

        _case = 2;
        _data = abi.encodeWithSelector(CustomError.selector);

        vm.expectRevert(CustomError.selector);
        this.swapLB(address(this), swapForY, recipient);

        _data = "Error String";

        vm.expectRevert("Error String");
        this.swapLB(address(this), swapForY, recipient);
    }

    function test_Fuzz_GetSwapInUV3(bool zeroForOne, uint256 amountOut, int256 amount0, int256 amount1) public {
        _case = 2;
        _data = abi.encodeWithSelector(bytes4(0xaabbccdd), amount0, amount1, abi.encode(address(this)));

        uint256 amount = this.getSwapInUV3(address(this), zeroForOne, amountOut);

        assertEq(amount, zeroForOne ? uint256(amount0) : uint256(amount1), "test_Fuzz_GetSwapInUV3::1");
    }

    function test_Fuzz_Revert_GetSwapInUV3(bool zeroForOne, uint256 amountOut, int256 amount0, int256 amount1) public {
        _case = 1;
        _data = abi.encodeWithSelector(bytes4(0xaabbccdd), amount0, amount1, abi.encode(address(this)));

        vm.expectRevert(_data);
        this.getSwapInUV3(address(this), zeroForOne, amountOut);

        _case = 2;
        _data = abi.encodePacked(bytes4(0xaabbccdd), new bytes(159));

        vm.expectRevert(_data);
        this.getSwapInUV3(address(this), zeroForOne, amountOut);

        _case = 2;
        _data = abi.encodePacked(bytes4(0xaabbccdd), new bytes(161));

        vm.expectRevert(_data);
        this.getSwapInUV3(address(this), zeroForOne, amountOut);

        vm.expectRevert(_data);
        this.getSwapInUV3(address(this), zeroForOne, amountOut);

        _data = abi.encodeWithSelector(CustomError.selector);

        vm.expectRevert(CustomError.selector);
        this.getSwapInUV3(address(this), zeroForOne, amountOut);

        _data = "Error String";

        vm.expectRevert("Error String");
        this.getSwapInUV3(address(this), zeroForOne, amountOut);
    }

    function test_Fuzz_SwapUV3(
        address tokenIn,
        bool zeroForOne,
        uint256 amountIn,
        int256 amount0,
        int256 amount1,
        address recipient
    ) public {
        _case = 0;
        _data = abi.encode(amount0, amount1);

        (uint256 amount, uint256 actualAmountIn, uint256 hash) =
            this.swapUV3(address(this), recipient, zeroForOne, amountIn, tokenIn);

        unchecked {
            assertEq(amount, zeroForOne ? uint256(-amount1) : uint256(-amount0), "test_Fuzz_SwapUV3::1");
            assertEq(actualAmountIn, zeroForOne ? uint256(amount0) : uint256(amount1), "test_Fuzz_SwapUV3::2");
        }

        assertEq(hash, uint256(keccak256(abi.encode(amount0, amount1, tokenIn))), "test_Fuzz_SwapUV3::3");

        assertEq(
            _msgData,
            abi.encodeWithSelector(
                IUV3Pair.swap.selector,
                recipient,
                zeroForOne,
                amountIn,
                zeroForOne ? PairInteraction.MIN_SWAP_SQRT_RATIO : PairInteraction.MAX_SWAP_SQRT_RATIO,
                abi.encode(tokenIn)
            ),
            "test_Fuzz_SwapUV3::4"
        );
    }

    function test_Fuzz_Revert_SwapUV3(address tokenIn, bool zeroForOne, uint256 amountIn, address recipient) public {
        _case = 1;
        _data = new bytes(63);

        vm.expectRevert(PairInteraction.PairInteraction__InvalidReturnData.selector);
        this.swapUV3(address(this), tokenIn, zeroForOne, amountIn, recipient);

        _case = 2;
        _data = abi.encodeWithSelector(CustomError.selector);

        vm.expectRevert(CustomError.selector);
        this.swapUV3(address(this), tokenIn, zeroForOne, amountIn, recipient);

        _data = "Error String";

        vm.expectRevert("Error String");
        this.swapUV3(address(this), tokenIn, zeroForOne, amountIn, recipient);
    }

    function test_Fuzz_GetSwapInTM(uint256 amountOut, bool swapForY, uint256 actualAmountIn, uint256 actualAmountOut)
        public
    {
        amountOut = bound(amountOut, 0, uint256(type(int256).max));
        actualAmountIn = bound(actualAmountIn, 0, uint256(type(int256).max));
        actualAmountOut = bound(actualAmountOut, 0, uint256(type(int256).max));

        _case = 1;
        _data = swapForY
            ? abi.encode(actualAmountIn, -int256(actualAmountOut))
            : abi.encode(-int256(actualAmountOut), actualAmountIn);

        (uint256 amountIn_, uint256 amountOut_) = this.getSwapInTM(address(this), amountOut, swapForY);

        assertEq(amountIn_, actualAmountIn + 1, "test_Fuzz_GetSwapInTM::1");
        assertEq(amountOut_, actualAmountOut, "test_Fuzz_GetSwapInTM::2");
    }

    function test_Fuzz_Revert_GetSwapInTM(uint256 amountOut, bool swapForY) public {
        _case = 1;
        _data = new bytes(63);

        vm.expectRevert(PairInteraction.PairInteraction__InvalidReturnData.selector);
        this.getSwapInTM(address(this), amountOut, swapForY);

        _case = 2;
        _data = abi.encodeWithSelector(CustomError.selector);

        vm.expectRevert(CustomError.selector);
        this.getSwapInTM(address(this), amountOut, swapForY);

        _data = "Error String";

        vm.expectRevert("Error String");
        this.getSwapInTM(address(this), amountOut, swapForY);
    }

    function test_Fuzz_SwapTM(
        uint256 amountIn,
        bool swapForY,
        uint256 actualAmountIn,
        uint256 actualAmountOut,
        address recipient
    ) public {
        amountIn = bound(amountIn, 0, uint256(type(int256).max));
        actualAmountIn = bound(actualAmountIn, 0, uint256(type(int256).max));
        actualAmountOut = bound(actualAmountOut, 0, uint256(type(int256).max));

        _case = 0;
        _data = swapForY
            ? abi.encode(actualAmountIn, -int256(actualAmountOut))
            : abi.encode(-int256(actualAmountOut), actualAmountIn);

        (uint256 amountOut_, uint256 actualAmountIn_) = this.swapTM(address(this), recipient, amountIn, swapForY);

        assertEq(amountOut_, actualAmountOut, "test_Fuzz_SwapTM::1");
        assertEq(actualAmountIn_, actualAmountIn, "test_Fuzz_SwapTM::2");

        assertEq(
            _msgData,
            abi.encodeWithSelector(ITMPair.swap.selector, recipient, amountIn, swapForY, "", address(0)),
            "test_Fuzz_SwapTM::3"
        );
    }

    function test_Fuzz_Revert_SwapTM(uint256 amountOut, bool swapForY, address recipient) public {
        _case = 1;
        _data = new bytes(63);

        vm.expectRevert(PairInteraction.PairInteraction__InvalidReturnData.selector);
        this.swapTM(address(this), recipient, amountOut, swapForY);

        _case = 2;
        _data = abi.encodeWithSelector(CustomError.selector);

        vm.expectRevert(CustomError.selector);
        this.swapTM(address(this), recipient, amountOut, swapForY);

        _data = "Error String";

        vm.expectRevert("Error String");
        this.swapTM(address(this), recipient, amountOut, swapForY);
    }

    function test_Fuzz_GetSqrtLimitPriceInTMV2(bool swapForY, uint256 sqrtPrice) public {
        sqrtPrice = bound(sqrtPrice, 1, type(uint256).max);
        _case = 1;
        _data = swapForY ? abi.encode(sqrtPrice, 0, 0) : abi.encode(0, 0, sqrtPrice);

        uint256 price = this.getSqrtLimitPriceInTMV2(address(this), swapForY);

        assertEq(price, sqrtPrice, "test_Fuzz_GetSqrtLimitPriceInTMV2::1");
    }

    function test_Fuzz_Revert_GetSqrtLimitPriceInTMV2(bool swapForY) public {
        _case = 1;
        _data = new bytes(95);

        vm.expectRevert(PairInteraction.PairInteraction__InvalidReturnData.selector);
        this.getSqrtLimitPriceInTMV2(address(this), swapForY);

        _case = 2;
        _data = abi.encodeWithSelector(CustomError.selector);

        vm.expectRevert(PairInteraction.PairInteraction__InvalidReturnData.selector);
        this.getSqrtLimitPriceInTMV2(address(this), swapForY);

        _data = "Error String";

        vm.expectRevert(PairInteraction.PairInteraction__InvalidReturnData.selector);
        this.getSqrtLimitPriceInTMV2(address(this), swapForY);
    }

    function test_Fuzz_GetSwapInTMV2(
        uint256 amountOut,
        bool swapForY,
        uint256 sqrtLimitPrice,
        uint256 actualAmountIn,
        uint256 actualAmountOut
    ) public {
        sqrtLimitPrice = bound(sqrtLimitPrice, 1, type(uint256).max);
        amountOut = bound(amountOut, 0, uint256(type(int256).max));
        actualAmountIn = bound(actualAmountIn, 0, uint256(type(int256).max));
        actualAmountOut = bound(actualAmountOut, 0, uint256(type(int256).max));

        _case = 3;

        bytes memory priceData = swapForY ? abi.encode(sqrtLimitPrice, 0, 0) : abi.encode(0, 0, sqrtLimitPrice);
        bytes memory swapData = swapForY
            ? abi.encode(actualAmountIn, -int256(actualAmountOut))
            : abi.encode(-int256(actualAmountOut), actualAmountIn);
        _data = abi.encode(priceData, swapData);

        (uint256 amountIn_, uint256 amountOut_) = this.getSwapInTMV2(address(this), amountOut, swapForY);

        assertEq(amountIn_, actualAmountIn, "test_Fuzz_GetSwapInTMV2::1");
        assertEq(amountOut_, actualAmountOut, "test_Fuzz_GetSwapInTMV2::2");
    }

    function test_Fuzz_Revert_GetSwapInTMV2(uint256 amountOut, bool swapForY) public {
        _case = 3;
        _data = abi.encode(new bytes(95), new bytes(64));

        vm.expectRevert(PairInteraction.PairInteraction__InvalidReturnData.selector);
        this.getSwapInTMV2(address(this), amountOut, swapForY);

        _data = abi.encode(new bytes(96), new bytes(63));

        vm.expectRevert(PairInteraction.PairInteraction__InvalidReturnData.selector);
        this.getSwapInTMV2(address(this), amountOut, swapForY);

        _data = abi.encode(new bytes(96), new bytes(0));

        vm.expectRevert(CustomError.selector);
        this.getSwapInTMV2(address(this), amountOut, swapForY);

        _data = abi.encode(new bytes(96), new bytes(1));

        vm.expectRevert("Error String");
        this.getSwapInTMV2(address(this), amountOut, swapForY);
    }

    function test_Fuzz_SwapTMV2(
        uint256 amountIn,
        bool swapForY,
        uint256 sqrtLimitPrice,
        uint256 actualAmountIn,
        uint256 actualAmountOut,
        address recipient
    ) public {
        amountIn = bound(amountIn, 0, uint256(type(int256).max));
        actualAmountIn = bound(actualAmountIn, 0, uint256(type(int256).max));
        actualAmountOut = bound(actualAmountOut, 0, uint256(type(int256).max));

        _case = 4;
        bytes memory priceData = swapForY ? abi.encode(sqrtLimitPrice, 0, 0) : abi.encode(0, 0, sqrtLimitPrice);
        bytes memory swapData = swapForY
            ? abi.encode(actualAmountIn, -int256(actualAmountOut))
            : abi.encode(-int256(actualAmountOut), actualAmountIn);
        _data = abi.encode(priceData, swapData);

        (uint256 amountOut_, uint256 actualAmountIn_) = this.swapTMV2(address(this), recipient, amountIn, swapForY);

        assertEq(amountOut_, actualAmountOut, "test_Fuzz_SwapTMV2::1");
        assertEq(actualAmountIn_, actualAmountIn, "test_Fuzz_SwapTMV2::2");

        assertEq(
            _msgData,
            abi.encodeWithSelector(ITMPairV2.swap.selector, recipient, swapForY, amountIn, sqrtLimitPrice),
            "test_Fuzz_SwapTMV2::3"
        );
    }

    function test_Fuzz_Revert_SwapTMV2(uint256 amountOut, bool swapForY, address recipient) public {
        _case = 3;
        _data = abi.encode(new bytes(95), new bytes(64));

        vm.expectRevert(PairInteraction.PairInteraction__InvalidReturnData.selector);
        this.swapTMV2(address(this), recipient, amountOut, swapForY);

        _data = abi.encode(new bytes(96), new bytes(63));

        vm.expectRevert(PairInteraction.PairInteraction__InvalidReturnData.selector);
        this.swapTMV2(address(this), recipient, amountOut, swapForY);

        _data = abi.encode(new bytes(96), new bytes(0));

        vm.expectRevert(CustomError.selector);
        this.swapTMV2(address(this), recipient, amountOut, swapForY);

        _data = abi.encode(new bytes(96), new bytes(1));

        vm.expectRevert("Error String");
        this.swapTMV2(address(this), recipient, amountOut, swapForY);
    }

    function _buildV4Route(
        address tokenIn,
        address tokenOut,
        address hooks,
        uint24 fee,
        int24 tickSpacing,
        bool zeroForOne,
        bytes memory hookData
    ) internal returns (bytes memory route, uint256 ptr, uint256 extraDataPtr) {
        uint8 nativeFlag = 0;
        if (tokenIn == address(0)) {
            nativeFlag = 1;
            tokenIn = wnative;
        }
        if (tokenOut == address(0)) {
            nativeFlag = 2;
            tokenOut = wnative;
        }

        uint256 length = hookData.length > 256 ? 256 : hookData.length;
        length = length % 2 == 0 ? length : length + 1; // length must be even
        assembly ("memory-safe") {
            mstore(hookData, length)
        }

        (route, ptr) = _createRoutes(2, 1);
        ptr = _setIsTransferTaxToken(route, ptr, false);
        ptr = _setToken(route, ptr, tokenIn);
        ptr = _setToken(route, ptr, tokenOut);
        extraDataPtr = route.length;
        _setRoute(
            route,
            ptr,
            tokenIn,
            tokenOut,
            address(uint160(extraDataPtr)),
            1e4,
            UV4ID | CALLBACK | (zeroForOne ? ZERO_FOR_ONE : ONE_FOR_ZERO)
        );
        route = abi.encodePacked(
            route,
            uint24(fee),
            uint24(tickSpacing),
            uint8(nativeFlag),
            address(hooks),
            uint24(hookData.length),
            hookData,
            uint24(3 + 3 + 1 + 20 + 3 + hookData.length)
        );

        // Safety check
        (uint256 startPtr, uint256 nbTokens, uint256 nbSwaps) = this.start(route);
        assertEq(startPtr, ptr, "_buildV4Route::1");
        assertEq(nbTokens, 2, "_buildV4Route::2");
        assertEq(nbSwaps, 1, "_buildV4Route::3");
    }

    function test_Fuzz_PrepareDataUV4(
        address tokenIn,
        address tokenOut,
        address hooks,
        uint24 fee,
        int24 tickSpacing,
        bool zeroForOne,
        int256 deltaAmount,
        bytes memory hookData
    ) public {
        if (tokenIn == tokenOut) tokenOut = address(uint160(tokenOut) + 1);

        (bytes memory route, uint256 ptr, uint256 extraDataPtr) =
            _buildV4Route(tokenIn, tokenOut, hooks, fee, tickSpacing, zeroForOne, hookData);

        (, bytes32 value) = this.next(route, ptr);
        bytes memory data = this.prepareDataUV4(route, value, extraDataPtr, zeroForOne, deltaAmount);

        (address currency0, address currency1) = tokenIn < tokenOut ? (tokenIn, tokenOut) : (tokenOut, tokenIn);

        IUV4Manager.PoolKey memory key = IUV4Manager.PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: fee,
            tickSpacing: tickSpacing,
            hooks: hooks
        });
        IUV4Manager.SwapParams memory params = IUV4Manager.SwapParams({
            zeroForOne: zeroForOne,
            amountSpecified: deltaAmount,
            sqrtPriceLimitX96: uint160(
                zeroForOne ? PairInteraction.MIN_SWAP_SQRT_RATIO : PairInteraction.MAX_SWAP_SQRT_RATIO
            )
        });
        bytes memory expectedData = abi.encode(key, params, hookData);
        expectedData = abi.encodePacked(uint256(0x20), expectedData.length, expectedData);

        assertEq(expectedData, data, "test_Fuzz_PrepareDataUV4::1");
    }

    function test_Fuzz_GetSwapInUV4(
        address tokenIn,
        address tokenOut,
        address hooks,
        uint24 fee,
        int24 tickSpacing,
        bool zeroForOne,
        uint256 amountIn,
        uint256 amountOut,
        bytes memory hookData
    ) public {
        unchecked {
            if (tokenIn == tokenOut) tokenOut = address(uint160(tokenOut) + 1);
        }
        amountIn = bound(amountIn, 1, uint256(int256(type(int128).max)));
        amountOut = bound(amountOut, 1, uint256(int256(type(int128).max)));

        (bytes memory route, uint256 ptr, uint256 extraDataPtr) =
            _buildV4Route(tokenIn, tokenOut, hooks, fee, tickSpacing, zeroForOne, hookData);
        (, bytes32 value) = this.next(route, ptr);

        unchecked {
            (int256 delta0, int256 delta1) =
                zeroForOne ? (-int256(amountIn), int256(amountOut)) : (int256(amountOut), -int256(amountIn));
            MockV4Manager(uniswapV4).set(int128(delta0), int128(delta1));
        }

        _case = 5;

        actualIn = this.getSwapInUV4(route, value, uniswapV4, address(uint160(extraDataPtr)), zeroForOne, amountOut);
        assertEq(actualIn, amountIn, "test_Fuzz_GetSwapInUV4::1");
    }

    struct SwapInput {
        uint256 tokens;
        address hooks;
        uint24 fee;
        int24 tickSpacing;
        uint256 amountIn;
        uint256 amountOut;
    }

    uint256 actualIn;
    uint256 actualOut;

    function test_Fuzz_SwapUV4(SwapInput memory input, bytes memory hookData) public {
        input.amountIn = bound(input.amountIn, 1, uint256(int256(type(int128).max)));
        input.amountOut = bound(input.amountOut, 1, uint256(int256(type(int128).max)));

        address tokenIn;
        address tokenOut;
        {
            uint256 tokens = input.tokens % 6;
            if (tokens == 0) {
                tokenIn = tokenA;
                tokenOut = tokenB;
            } else if (tokens == 1) {
                tokenIn = tokenB;
                tokenOut = tokenA;
            } else if (tokens == 2) {
                tokenIn = address(0);
                tokenOut = tokenA;
            } else if (tokens == 3) {
                tokenIn = tokenA;
                tokenOut = address(0);
            } else if (tokens == 4) {
                tokenIn = address(0);
                tokenOut = tokenB;
            } else {
                tokenIn = tokenB;
                tokenOut = address(0);
            }
        }

        bool zeroForOne = tokenIn < tokenOut;

        if (tokenIn == address(0)) {
            vm.deal(address(this), input.amountIn);
            TokenLib.wrap(wnative, input.amountIn);
        } else if (tokenIn == tokenA) {
            MockERC20(tokenA).mint(address(this), input.amountIn);
        } else {
            MockERC20(tokenB).mint(address(this), input.amountIn);
        }

        if (tokenOut == address(0)) vm.deal(uniswapV4, input.amountOut);
        else if (tokenOut == tokenA) MockERC20(tokenA).mint(uniswapV4, input.amountOut);
        else MockERC20(tokenB).mint(uniswapV4, input.amountOut);

        bytes memory route;
        uint256 extraDataPtr;
        bytes32 value;
        {
            uint256 ptr;
            (route, ptr, extraDataPtr) =
                _buildV4Route(tokenIn, tokenOut, input.hooks, input.fee, input.tickSpacing, zeroForOne, hookData);
            (, value) = this.next(route, ptr);

            (int256 delta0, int256 delta1) = zeroForOne
                ? (-int256(input.amountIn), int256(input.amountOut))
                : (int256(input.amountOut), -int256(input.amountIn));
            MockV4Manager(uniswapV4).set(int128(delta0), int128(delta1));
        }

        _case = 5;
        to = address(this);

        assertEq(
            TokenLib.balanceOf(tokenIn == address(0) ? wnative : tokenIn, address(this)),
            input.amountIn,
            "test_Fuzz_SwapUV4::1"
        );
        assertEq(TokenLib.universalBalanceOf(tokenOut, uniswapV4), input.amountOut, "test_Fuzz_SwapUV4::2");

        (actualOut, actualIn) =
            this.swapUV4(route, value, uniswapV4, address(uint160(extraDataPtr)), zeroForOne, input.amountIn);

        assertEq(actualIn, input.amountIn, "test_Fuzz_SwapUV4::3");
        assertEq(actualOut, input.amountOut, "test_Fuzz_SwapUV4::4");
        assertEq(TokenLib.universalBalanceOf(tokenIn, uniswapV4), input.amountIn, "test_Fuzz_SwapUV4::5");
        assertEq(
            TokenLib.balanceOf(tokenOut == address(0) ? wnative : tokenOut, address(this)),
            input.amountOut,
            "test_Fuzz_SwapUV4::6"
        );
    }

    function test_Fuzz_Revert_GetSwapInUV4(uint256 returnDataSize) public {
        (bytes memory route, uint256 ptr, uint256 extraDataPtr) =
            _buildV4Route(tokenA, tokenB, address(0), 1, 1, true, new bytes(0));
        (, bytes32 value) = this.next(route, ptr);

        // Should revert if call doesn't fail
        _case = 1;
        _data = new bytes(128);
        vm.expectRevert(PairInteraction.PairInteraction__InvalidState.selector);
        this.getSwapInUV4(route, value, address(this), address(uint160(extraDataPtr)), true, 1);

        // Should revert if error size is not 128
        _case = 2;
        _data = new bytes(bound(returnDataSize, 0, 127));
        vm.expectRevert(PairInteraction.PairInteraction__InvalidReturnData.selector);
        this.getSwapInUV4(route, value, address(this), address(uint160(extraDataPtr)), true, 1);

        _data = new bytes(bound(returnDataSize, 129, 256));
        vm.expectRevert(PairInteraction.PairInteraction__InvalidReturnData.selector);
        this.getSwapInUV4(route, value, address(this), address(uint160(extraDataPtr)), true, 1);
    }

    function test_Fuzz_Revert_SwapUV4(uint256 returnDataSize) public {
        (bytes memory route, uint256 ptr, uint256 extraDataPtr) =
            _buildV4Route(tokenA, tokenB, address(0), 1, 1, true, new bytes(0));
        (, bytes32 value) = this.next(route, ptr);

        // Should revert if data size is not 128
        _case = 1;
        _data = new bytes(bound(returnDataSize, 0, 127));
        vm.expectRevert(PairInteraction.PairInteraction__InvalidReturnData.selector);
        this.swapUV4(route, value, address(this), address(uint160(extraDataPtr)), true, 1);

        _data = new bytes(bound(returnDataSize, 129, 256));
        vm.expectRevert(PairInteraction.PairInteraction__InvalidReturnData.selector);
        this.swapUV4(route, value, address(this), address(uint160(extraDataPtr)), true, 1);

        // Should revert if call fail
        _case = 2;
        _data = new bytes(128);
        vm.expectRevert(new bytes(128));
        this.swapUV4(route, value, address(this), address(uint160(extraDataPtr)), true, 1);
    }

    function test_Fuzz_Revert_SwapUV4Callback(uint256 returnDataSize) public {
        // Should revert if call fail
        _case = 2;
        _data = abi.encodeWithSelector(CustomError.selector);
        vm.expectRevert(CustomError.selector);
        this.swapUV4Callback(new bytes(68), address(this), wnative);

        // Should revert if data size is not 32
        _case = 1;
        _data = new bytes(bound(returnDataSize, 0, 31));
        vm.expectRevert(PairInteraction.PairInteraction__InvalidReturnData.selector);
        this.swapUV4Callback(new bytes(68), address(this), wnative);

        _data = new bytes(bound(returnDataSize, 33, 64));
        vm.expectRevert(PairInteraction.PairInteraction__InvalidReturnData.selector);
        this.swapUV4Callback(new bytes(68), address(this), wnative);
    }

    function test_Fuzz_Revert_SettleUV4(int256 delta, uint256 returnDataSize) public {
        delta = bound(delta, type(int256).min, -1);

        // Should revert if sync fail
        _case = 2;
        _data = abi.encodeWithSelector(CustomError.selector);
        vm.expectRevert(CustomError.selector);
        this.settleOrTakeUV4(tokenA, address(this), delta, wnative);
        _data = new bytes(0);
        vm.expectRevert(PairInteraction.PairInteraction__CallFailed.selector);
        this.settleOrTakeUV4(tokenA, address(this), delta, wnative);

        unchecked {
            MockERC20(tokenA).mint(address(this), uint256(-delta));
        }

        // Should revert if settle fails
        _case = 3;
        _data = abi.encode(new bytes(0), new bytes(0));
        vm.expectRevert(CustomError.selector);
        this.settleOrTakeUV4(tokenA, address(this), delta, wnative);

        // Should revert if settle returns data of size not 32
        _data = abi.encode(new bytes(0), new bytes(bound(returnDataSize, 2, 31)));
        vm.expectRevert(PairInteraction.PairInteraction__InvalidReturnData.selector);
        this.settleOrTakeUV4(tokenA, address(this), delta, wnative);

        _data = abi.encode(new bytes(0), new bytes(bound(returnDataSize, 33, 64)));
        vm.expectRevert(PairInteraction.PairInteraction__InvalidReturnData.selector);
        this.settleOrTakeUV4(tokenA, address(this), delta, wnative);
    }

    function test_Fuzz_Revert_TakeUV4(int256 delta) public {
        delta = bound(delta, 1, type(int256).max);

        // Should revert if take fails
        _case = 2;
        _data = abi.encodeWithSelector(CustomError.selector);
        vm.expectRevert(CustomError.selector);
        this.settleOrTakeUV4(tokenA, address(this), delta, wnative);

        _data = new bytes(0);
        vm.expectRevert(PairInteraction.PairInteraction__CallFailed.selector);
        this.settleOrTakeUV4(tokenA, address(this), delta, wnative);
    }

    // Helper functions

    function getReservesUV2(address pair, bool ordered) external view returns (uint256, uint256) {
        return PairInteraction.getReservesUV2(pair, ordered);
    }

    function swapUV2(address pair, uint256 amount0, uint256 amount1, address recipient) external {
        PairInteraction.swapUV2(pair, amount0, amount1, recipient);
    }

    function getSwapInLegacyLB(address router, address pair, uint256 amountOut, bool zeroForOne)
        external
        view
        returns (uint256)
    {
        return PairInteraction.getSwapInLegacyLB(router, pair, amountOut, zeroForOne);
    }

    function swapLegacyLB(address pair, bool zeroForOne, address recipient) external returns (uint256) {
        return PairInteraction.swapLegacyLB(pair, zeroForOne, recipient);
    }

    function getSwapInLB(address pair, uint256 amountOut, bool zeroForOne) external view returns (uint256, uint256) {
        return PairInteraction.getSwapInLB(pair, amountOut, zeroForOne);
    }

    function swapLB(address pair, bool zeroForOne, address recipient) external returns (uint256) {
        return PairInteraction.swapLB(pair, zeroForOne, recipient);
    }

    function getSwapInUV3(address pair, bool zeroForOne, uint256 amountOut) external returns (uint256) {
        return PairInteraction.getSwapInUV3(pair, zeroForOne, amountOut);
    }

    function swapUV3(address pair, address recipient, bool zeroForOne, uint256 amountIn, address tokenIn)
        external
        returns (uint256 amountOut, uint256 actualAmountIn, uint256 hash)
    {
        return PairInteraction.swapUV3(pair, recipient, zeroForOne, amountIn, tokenIn);
    }

    function getSwapInTM(address pair, uint256 amountOut, bool zeroForOne) external view returns (uint256, uint256) {
        return PairInteraction.getSwapInTM(pair, amountOut, zeroForOne);
    }

    function swapTM(address pair, address recipient, uint256 amountIn, bool swapForY)
        external
        returns (uint256, uint256)
    {
        return PairInteraction.swapTM(pair, recipient, amountIn, swapForY);
    }

    function getSqrtLimitPriceInTMV2(address pair, bool swapForY) external view returns (uint256) {
        return PairInteraction.getSqrtLimitPriceInTMV2(pair, swapForY);
    }

    function getSwapInTMV2(address pair, uint256 amountOut, bool swapForY) external view returns (uint256, uint256) {
        return PairInteraction.getSwapInTMV2(pair, amountOut, swapForY);
    }

    function swapTMV2(address pair, address recipient, uint256 amountIn, bool swapForY)
        external
        returns (uint256, uint256)
    {
        return PairInteraction.swapTMV2(pair, recipient, amountIn, swapForY);
    }

    function start(bytes calldata route) external pure returns (uint256 ptr, uint256 nbTokens, uint256 nbSwaps) {
        return PackedRoute.start(route);
    }

    function next(bytes calldata route, uint256 ptr) external pure returns (uint256 newPtr, bytes32 value) {
        return PackedRoute.next(route, ptr);
    }

    function prepareDataUV4(
        bytes calldata route,
        bytes32 value,
        uint256 dataOffset,
        bool zeroForOne,
        int256 deltaAmount
    ) external pure returns (bytes memory data) {
        return PairInteraction.prepareDataUV4(route, value, dataOffset, zeroForOne, deltaAmount);
    }

    function getSwapInUV4(
        bytes calldata route,
        bytes32 value,
        address manager,
        address dataOffset,
        bool zeroForOne,
        uint256 amountOut
    ) external returns (uint256 amountIn) {
        return PairInteraction.getSwapInUV4(route, value, manager, dataOffset, zeroForOne, amountOut);
    }

    function swapUV4(
        bytes calldata route,
        bytes32 value,
        address manager,
        address dataOffset,
        bool zeroForOne,
        uint256 amountIn
    ) external returns (uint256 actualAmountOut, uint256 actualAmountIn) {
        return PairInteraction.swapUV4(route, value, manager, dataOffset, zeroForOne, amountIn);
    }

    function swapUV4Callback(bytes calldata data, address recipient, address wnative_)
        external
        returns (int256 delta0, int256 delta1)
    {
        return PairInteraction.swapUV4Callback(data, recipient, wnative_);
    }

    function settleOrTakeUV4(address token, address recipient, int256 delta, address wnative_) external {
        PairInteraction.settleOrTakeUV4(token, recipient, delta, wnative_);
    }
}
