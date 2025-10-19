// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {PackedRoute} from "./PackedRoute.sol";
import {SafeCast} from "./SafeCast.sol";
import {TokenLib} from "./TokenLib.sol";

/**
 * @title PairInteraction
 * @dev Library for interacting with Uniswap V2, LFJ, and Uniswap V3 pairs.
 */
library PairInteraction {
    using SafeCast for uint256;
    using SafeCast for int256;

    error PairInteraction__InvalidReturnData();
    error PairInteraction__CallFailed();
    error PairInteraction__InvalidState();

    uint256 internal constant MASK_UINT112 = 0xffffffffffffffffffffffffffff;
    uint256 internal constant MIN_SWAP_SQRT_RATIO = 4295128739 + 1;
    uint256 internal constant MAX_SWAP_SQRT_RATIO = 1461446703485210103287273052203988822378723970342 - 1;

    /**
     * @dev Returns the ordered reserves of a Uniswap V2 pair.
     * If ordered is true, the reserves are returned as (reserve0, reserve1), otherwise as (reserve1, reserve0).
     *
     * Requirements:
     * - The call must succeed.
     * - The pair must have code.
     * - The return data must be at least 64 bytes.
     */
    function getReservesUV2(address pair, bool ordered) internal view returns (uint256 reserveIn, uint256 reserveOut) {
        uint256 returnDataSize;
        assembly ("memory-safe") {
            mstore(0, 0x0902f1ac) // getReserves()

            if staticcall(gas(), pair, 28, 4, 0, 64) { returnDataSize := returndatasize() }

            switch ordered
            case 0 {
                reserveIn := and(mload(32), MASK_UINT112)
                reserveOut := and(mload(0), MASK_UINT112)
            }
            default {
                reserveIn := and(mload(0), MASK_UINT112)
                reserveOut := and(mload(32), MASK_UINT112)
            }
        }

        if (returnDataSize < 64) revert PairInteraction__InvalidReturnData();
    }

    /**
     * @dev Returns the amount of tokenIn required to get amountOut from a Uniswap V2 pair.
     * The function doesn't check that the pair has any code, `getReservesUV2` should be called first to ensure that.
     *
     * Requirements:
     * - The call must succeed.
     */
    function swapUV2(address pair, uint256 amount0, uint256 amount1, address recipient) internal {
        uint256 success;
        assembly ("memory-safe") {
            let ptr := mload(0x40)

            mstore(ptr, 0x022c0d9f) // swap(uint256,uint256,address,bytes)
            mstore(add(ptr, 32), amount0)
            mstore(add(ptr, 64), amount1)
            mstore(add(ptr, 96), recipient)
            mstore(add(ptr, 128), 128)
            mstore(add(ptr, 160), 0)

            mstore(0x40, add(ptr, 160)) // update free memory pointer to 160 because 160:192 is 0

            success := call(gas(), pair, 0, add(ptr, 28), 164, 0, 0)
        }
        _bubbleRevert(success);
    }

    /**
     * @dev Returns the amount of tokenIn required to get amountOut from a LFJ Legacy LB pair.
     * It uses the router v2.0 helper function `getSwapIn` to get the amount required.
     *
     * Requirements:
     * - The call must succeed.
     * - The router must have code.
     * - The return data must be at least 32 bytes.
     */
    function getSwapInLegacyLB(address router, address pair, uint256 amountOut, bool swapForY)
        internal
        view
        returns (uint256 amountIn)
    {
        uint256 returnDataSize;
        uint256 success;
        assembly ("memory-safe") {
            let ptr := mload(0x40)

            mstore(ptr, 0x5bdd4b7c) // getSwapIn(address,uint256,bool)
            mstore(add(ptr, 32), pair)
            mstore(add(ptr, 64), amountOut)
            mstore(add(ptr, 96), swapForY)

            mstore(0x40, add(ptr, 128))

            success := staticcall(gas(), router, add(ptr, 28), 100, 0, 32)

            returnDataSize := returndatasize()

            amountIn := mload(0)
        }
        _bubbleRevert(success);

        if (returnDataSize < 32) revert PairInteraction__InvalidReturnData();
    }

    /**
     * @dev Swaps tokenIn for tokenOut in a LFJ Legacy LB pair.
     *
     * Requirements:
     * - The call must succeed.
     * - The pair must have code.
     * - The return data must be at least 64 bytes.
     */
    function swapLegacyLB(address pair, bool swapForY, address recipient) internal returns (uint256 amountOut) {
        uint256 returnDataSize;
        uint256 success;

        assembly ("memory-safe") {
            let m0x40 := mload(0x40)

            mstore(0, 0x53c059a0) // swap(bool,address)
            mstore(32, swapForY)
            mstore(64, recipient)

            success := call(gas(), pair, 0, 28, 68, 0, 64)

            returnDataSize := returndatasize()

            switch swapForY
            case 0 { amountOut := mload(0) }
            default { amountOut := mload(32) }

            mstore(0x40, m0x40)
        }
        _bubbleRevert(success);

        if (returnDataSize < 64) revert PairInteraction__InvalidReturnData();
    }

    /**
     * @dev Returns the amount of tokenIn required to get amountOut from a LFJ LB pair (v2.0 and v2.1).
     *
     * Requirements:
     * - The call must succeed.
     * - The pair must have code.
     * - The return data must be at least 64 bytes.
     */
    function getSwapInLB(address pair, uint256 amountOut, bool swapForY)
        internal
        view
        returns (uint256 amountIn, uint256 amountLeft)
    {
        uint256 returnDataSize;
        uint256 success;
        assembly ("memory-safe") {
            let m0x40 := mload(0x40)

            mstore(0, 0xabcd7830) // getSwapIn(uint128,bool)
            mstore(32, amountOut)
            mstore(64, swapForY)

            success := staticcall(gas(), pair, 28, 68, 0, 64)

            returnDataSize := returndatasize()

            amountIn := mload(0)
            amountLeft := mload(32)

            mstore(0x40, m0x40)
        }
        _bubbleRevert(success);

        if (returnDataSize < 64) revert PairInteraction__InvalidReturnData();
    }

    /**
     * @dev Swaps tokenIn for tokenOut in a LFJ LB pair (v2.0 and v2.1).
     *
     * Requirements:
     * - The call must succeed.
     * - The pair must have code.
     * - The return data must be at least 32 bytes.
     */
    function swapLB(address pair, bool swapForY, address recipient) internal returns (uint256 amountOut) {
        uint256 returnDataSize;
        uint256 success;

        assembly ("memory-safe") {
            let m0x40 := mload(0x40)

            mstore(0, 0x53c059a0) // swap(bool,address)
            mstore(32, swapForY)
            mstore(64, recipient)

            success := call(gas(), pair, 0, 28, 68, 0, 32)

            returnDataSize := returndatasize()

            switch swapForY
            case 0 { amountOut := shr(128, mload(16)) }
            default { amountOut := shr(128, mload(0)) }

            mstore(0x40, m0x40)
        }
        _bubbleRevert(success);

        if (returnDataSize < 32) revert PairInteraction__InvalidReturnData();
    }

    /**
     * @dev Returns the amount of tokenIn required to get amountOut from a Uniswap V3 pair.
     * The function actually tries to swap token but revert before having to send any token.
     *
     * Requirements:
     * - The call must succeed.
     * - The pair must have code.
     * - The return data must match the expected format, which is to revert with a
     *   `UniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta)` error.
     */
    function getSwapInUV3(address pair, bool zeroForOne, uint256 amountOut) internal returns (uint256 amountIn) {
        (uint256 success, uint256 ptr) = callSwapUV3(pair, address(this), zeroForOne, -amountOut.toInt256(), address(0));

        assembly ("memory-safe") {
            // data = [selector: 4][amount0: 32][amount1: 32][data_ptr: 32][data_length: 32][data_value: 32]
            switch and(iszero(success), eq(returndatasize(), 164))
            case 0 {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }
            default {
                switch zeroForOne
                case 0 { amountIn := mload(add(ptr, 36)) }
                default { amountIn := mload(add(ptr, 4)) }
            }
        }
    }

    /**
     * @dev Swaps tokenIn for tokenOut in a Uniswap V3 pair.
     *
     * Requirements:
     * - The call must succeed.
     * - The pair must have code.
     * - The return data must be at least 64 bytes.
     */
    function swapUV3(address pair, address recipient, bool zeroForOne, uint256 amountIn, address tokenIn)
        internal
        returns (uint256 actualAmountOut, uint256 actualAmountIn, uint256 expectedHash)
    {
        (uint256 success, uint256 ptr) = callSwapUV3(pair, recipient, zeroForOne, amountIn.toInt256(), tokenIn);
        _bubbleRevert(success);

        uint256 returnDataSize;

        assembly ("memory-safe") {
            returnDataSize := returndatasize()

            mstore(add(ptr, 64), tokenIn)
            expectedHash := keccak256(ptr, 96)

            switch zeroForOne
            case 0 {
                actualAmountOut := mload(ptr)
                actualAmountIn := mload(add(ptr, 32))
            }
            default {
                actualAmountIn := mload(ptr)
                actualAmountOut := mload(add(ptr, 32))
            }

            actualAmountOut := sub(0, actualAmountOut) // Invert the sign
        }

        if (returnDataSize < 64) revert PairInteraction__InvalidReturnData();
    }

    /**
     * @dev Returns the hash of the amount deltas and token address for a Uniswap V3 pair.
     * The hash is used to check that the callback contains the expected data.
     */
    function hashUV3(int256 amount0Delta, int256 amount1Delta, address token) internal pure returns (uint256 hash) {
        assembly ("memory-safe") {
            let ptr := mload(0x40)

            mstore(0, amount0Delta)
            mstore(32, amount1Delta)
            mstore(64, token)

            hash := keccak256(0, 96)

            mstore(0x40, ptr)
        }
    }

    /**
     * @dev Decodes the amount deltas and token address from the callback data of a Uniswap V3 pair.
     *
     * Requirements:
     * - The data must be exactly 164 bytes.
     */
    function decodeUV3CallbackData(bytes calldata data)
        internal
        pure
        returns (int256 amount0Delta, int256 amount1Delta, address token)
    {
        // data = [selector: 4][amount0: 32][amount1: 32][data_ptr: 32][data_length: 32][data_value: 32]
        if (data.length != 164) revert PairInteraction__InvalidReturnData();

        assembly ("memory-safe") {
            amount0Delta := calldataload(4)
            amount1Delta := calldataload(36)
            token := calldataload(132)
        }
    }

    /**
     * @dev Calls the `swap` function of a Uniswap V3 pair.
     * This function doesn't revert on failure, it returns a success flag instead.
     * It also returns the pointer to the return data.
     *
     * Requirements:
     * - The call must succeed.
     */
    function callSwapUV3(address pair, address recipient, bool zeroForOne, int256 deltaAmount, address tokenIn)
        internal
        returns (uint256 success, uint256 ptr)
    {
        uint256 priceLimit = zeroForOne ? MIN_SWAP_SQRT_RATIO : MAX_SWAP_SQRT_RATIO;

        assembly ("memory-safe") {
            ptr := mload(0x40)

            mstore(ptr, 0x128acb08) // swap(address,bool,int256,uint160,bytes)
            mstore(add(ptr, 32), recipient)
            mstore(add(ptr, 64), zeroForOne)
            mstore(add(ptr, 96), deltaAmount)
            mstore(add(ptr, 128), priceLimit)
            mstore(add(ptr, 160), 160)
            mstore(add(ptr, 192), 32)
            mstore(add(ptr, 224), tokenIn)

            mstore(0x40, add(ptr, 256))

            success := call(gas(), pair, 0, add(ptr, 28), 228, ptr, 68)
        }
    }

    /**
     * @dev Returns the amount of tokenIn required to get amountOut from a LFJ Token Mill pair.
     *
     * Requirements:
     * - The call must succeed.
     * - The pair must have code.
     * - The return data must be at least 32 bytes.
     */
    function getSwapInTM(address pair, uint256 amountOut, bool swapForY)
        internal
        view
        returns (uint256 amountIn, uint256 actualAmountOut)
    {
        uint256 returnDataSize;
        uint256 success;
        assembly ("memory-safe") {
            let m0x40 := mload(0x40)

            mstore(0, 0xcd56aadc) // getDeltaAmounts(int256,bool)
            mstore(32, sub(0, amountOut))
            mstore(64, swapForY)

            success := staticcall(gas(), pair, 28, 68, 0, 64)

            returnDataSize := returndatasize()

            switch swapForY
            case 0 {
                amountIn := mload(32)
                actualAmountOut := mload(0)
            }
            default {
                amountIn := mload(0)
                actualAmountOut := mload(32)
            }

            amountIn := add(amountIn, 1) // Add 1 wei to account for rounding errors
            actualAmountOut := sub(0, actualAmountOut) // Invert the sign

            mstore(0x40, m0x40)
        }
        _bubbleRevert(success);

        if (returnDataSize < 64) revert PairInteraction__InvalidReturnData();
    }

    /**
     * @dev Swaps tokenIn for tokenOut in a LFJ Token Mill pair.
     *
     * Requirements:
     * - The call must succeed.
     * - The pair must have code.
     * - The return data must be at least 64 bytes.
     */
    function swapTM(address pair, address recipient, uint256 amountIn, bool swapForY)
        internal
        returns (uint256 amountOut, uint256 actualAmountIn)
    {
        uint256 returnDataSize;
        uint256 success;

        assembly ("memory-safe") {
            let ptr := mload(0x40)

            mstore(ptr, 0xdc35ff77) // swap(address,int256,bool,bytes,address)
            mstore(add(ptr, 32), recipient)
            mstore(add(ptr, 64), amountIn)
            mstore(add(ptr, 96), swapForY)
            mstore(add(ptr, 128), 160)
            mstore(add(ptr, 160), 0)
            mstore(add(ptr, 192), 0)

            mstore(0x40, add(ptr, 160)) // update free memory pointer to 160 because 160:224 is 0

            success := call(gas(), pair, 0, add(ptr, 28), 196, 0, 64)
            returnDataSize := returndatasize()

            switch swapForY
            case 0 {
                actualAmountIn := mload(32)
                amountOut := mload(0)
            }
            default {
                actualAmountIn := mload(0)
                amountOut := mload(32)
            }

            amountOut := sub(0, amountOut) // Invert the sign
        }
        _bubbleRevert(success);

        if (returnDataSize < 64) revert PairInteraction__InvalidReturnData();
    }

    /**
     * @dev Returns the limit price bounds of a LFJ Token Mill V2 pair depending on the swap direction.
     *
     * Requirements:
     * - The call must succeed.
     * - The pair must have code.
     * - The return data must be at least 96 bytes.
     */
    function getSqrtLimitPriceInTMV2(address pair, bool swapForY) internal view returns (uint256 sqrtLimitPriceX96) {
        uint256 returnDataSize;
        assembly ("memory-safe") {
            let ptr := mload(0x40)

            mstore(0, 0xa0b6ea01) // getSqrtRatiosBounds()

            if staticcall(gas(), pair, 28, 4, 0, 96) { returnDataSize := returndatasize() }

            switch swapForY
            case 0 { sqrtLimitPriceX96 := mload(64) }
            default { sqrtLimitPriceX96 := mload(0) }

            mstore(0x40, ptr)
        }

        if (returnDataSize < 96) revert PairInteraction__InvalidReturnData();
    }

    /**
     * @dev Returns the amount of tokenIn required to get amountOut from a LFJ Token Mill V2 pair.
     *
     * Requirements:
     * - The call must succeed.
     * - The pair must have code.
     * - The return data must be at least 64 bytes.
     */
    function getSwapInTMV2(address pair, uint256 amountOut, bool swapForY)
        internal
        view
        returns (uint256 amountIn, uint256 actualAmountOut)
    {
        uint256 sqrtLimitPriceX96 = getSqrtLimitPriceInTMV2(pair, swapForY);

        uint256 returnDataSize;
        uint256 success;
        assembly ("memory-safe") {
            let ptr := mload(0x40)

            mstore(ptr, 0x3419341c) // getDeltaAmounts(bool,int256,uint256)
            mstore(add(ptr, 32), swapForY)
            mstore(add(ptr, 64), sub(0, amountOut))
            mstore(add(ptr, 96), sqrtLimitPriceX96)

            mstore(0x40, add(ptr, 128))

            success := staticcall(gas(), pair, add(ptr, 28), 100, 0, 64)
            returnDataSize := returndatasize()

            switch swapForY
            case 0 {
                amountIn := mload(32)
                actualAmountOut := mload(0)
            }
            default {
                amountIn := mload(0)
                actualAmountOut := mload(32)
            }

            actualAmountOut := sub(0, actualAmountOut) // Invert the sign
        }
        _bubbleRevert(success);

        if (returnDataSize < 64) revert PairInteraction__InvalidReturnData();
    }

    /**
     * @dev Swaps tokenIn for tokenOut in a LFJ Token Mill V2 pair.
     *
     * Requirements:
     * - The call must succeed.
     * - The pair must have code.
     * - The return data must be at least 64 bytes.
     */
    function swapTMV2(address pair, address recipient, uint256 amountIn, bool swapForY)
        internal
        returns (uint256 amountOut, uint256 actualAmountIn)
    {
        uint256 sqrtLimitPriceX96 = getSqrtLimitPriceInTMV2(pair, swapForY);

        uint256 returnDataSize;
        uint256 success;
        assembly ("memory-safe") {
            let ptr := mload(0x40)

            mstore(ptr, 0xabb1db2a) // swap(address,bool,int256,uint256)
            mstore(add(ptr, 32), recipient)
            mstore(add(ptr, 64), swapForY)
            mstore(add(ptr, 96), amountIn)
            mstore(add(ptr, 128), sqrtLimitPriceX96)

            mstore(0x40, add(ptr, 160))

            success := call(gas(), pair, 0, add(ptr, 28), 132, 0, 64)

            returnDataSize := returndatasize()

            switch swapForY
            case 0 {
                actualAmountIn := mload(32)
                amountOut := mload(0)
            }
            default {
                actualAmountIn := mload(0)
                amountOut := mload(32)
            }

            amountOut := sub(0, amountOut) // Invert the sign
        }
        _bubbleRevert(success);

        if (returnDataSize < 64) revert PairInteraction__InvalidReturnData();
    }

    /**
     * @dev Decodes the extra data for a Uniswap V4 pool from the route.
     * The dataOffset is the offset in the route where the extra data starts in the route.
     * The extraData must have an even length.
     * Requirements:
     * - The extra data must be formatted as follows:
     *   [fee: 3][tickSpacing: 3][nativeFlag: 1][hooks: 20][hookData length: 3][hookData: variable]
     *   (30 bytes + hookData length)
     *   - The fee is the fee of the pool in hundredths of a bip, i.e. 1e-6. If the highest bit is 1,
     *     the pool has a dynamic fee and must be exactly equal to 0x800000
     *   - The tickSpacing is the pool tick spacing.
     *   - The nativeFlag indicates if one of the tokens is native
     *     (1: tokenIn is native, 2: tokenOut is native, otherwise both are ERC20).
     *   - The hooks is the address of the hooks contract.
     *   - The hookData length is the length of the hookData in bytes (must be an even number for safety)
     *   - The hookData is the data to be passed to the hooks contract (can be empty).
     */
    function prepareDataUV4(
        bytes calldata route,
        bytes32 value,
        uint256 dataOffset,
        bool zeroForOne,
        int256 deltaAmount
    ) internal pure returns (bytes memory data) {
        unchecked {
            uint256 nativeFlag;
            uint256 extraDataOffset;
            assembly ("memory-safe") {
                extraDataOffset := add(route.offset, dataOffset)
                nativeFlag := shr(248, calldataload(add(extraDataOffset, 6)))
            }

            // 1 -> tokenIn is native, tokenOut is ERC20
            // 2 -> tokenIn is ERC20, tokenOut is native
            // any other value -> both tokens are ERC20
            address token0 = nativeFlag == 1 ? address(0) : PackedRoute.token(route, PackedRoute.tokenInId(value));
            address token1 = nativeFlag == 2 ? address(0) : PackedRoute.token(route, PackedRoute.tokenOutId(value));
            (token0, token1) = token0 < token1 ? (token0, token1) : (token1, token0);

            uint256 priceLimit = zeroForOne ? MIN_SWAP_SQRT_RATIO : MAX_SWAP_SQRT_RATIO;

            // data = [offset: 32][length: 32]
            //        {PoolKey: [token0: 32][token1: 32][fee: 32][tickSpacing: 32][hooks: 32]}
            //        {SwapParams: [zeroForOne: 32][amountSpecified: 32][priceLimit: 32]}
            //        {HookData: [offset: 32][length: 32][data: variable]}
            // Total length = 32 * 2 + 32 * 5 + 32 * 3 + 32 * 2 + hookData length = 64 + 320 + hookData length
            assembly ("memory-safe") {
                let hookDataLength := shr(232, calldataload(add(extraDataOffset, 27)))
                // Round up to the next complete word (320 + 31 = 351)
                let dataLength := shl(5, shr(5, add(hookDataLength, 351)))

                data := mload(0x40)
                mstore(0x40, add(data, add(96, dataLength))) // update free memory pointer

                mstore(data, add(64, dataLength)) // length
                mstore(add(data, 32), 0x20) // offset
                mstore(add(data, 64), dataLength) // length

                mstore(add(data, 96), token0) // PoolKey.token0
                mstore(add(data, 128), token1) // PoolKey.token1
                mstore(add(data, 160), shr(232, calldataload(extraDataOffset))) // PoolKey.fee
                mstore(add(data, 192), sar(232, calldataload(add(extraDataOffset, 3)))) // PoolKey.tickSpacing
                mstore(add(data, 224), shr(96, calldataload(add(extraDataOffset, 7)))) // PoolKey.hooks

                mstore(add(data, 256), zeroForOne) // SwapParams.zeroForOne
                mstore(add(data, 288), deltaAmount) // SwapParams.amountSpecified
                mstore(add(data, 320), priceLimit) // SwapParams.priceLimit

                mstore(add(data, 352), 288) // HookData.offset
                mstore(add(data, 384), hookDataLength) // HookData.length
                calldatacopy(add(data, 416), add(extraDataOffset, 30), hookDataLength) // HookData.data
            }
        }
    }

    /**
     * @dev Returns the amount of tokenIn required to get amountOut from a Uniswap V4 pool.
     * The function actually tries to swap token but revert before having to send any token.
     *
     * Requirements:
     * - The call must revert with `(int256 amount0Delta, int256 amount1Delta)` data.
     */
    function getSwapInUV4(
        bytes calldata route,
        bytes32 value,
        address manager,
        address dataOffset,
        bool zeroForOne,
        uint256 amountOut
    ) internal returns (uint256 amountIn) {
        (uint256 success, int256 deltaIn,) =
            callSwapUV4(route, value, manager, dataOffset, zeroForOne, amountOut.toInt256());
        if (success != 0) revert PairInteraction__InvalidState(); // Revert if the call succeeded (invalid state)
        unchecked {
            return (-deltaIn).toUint256(); // Invert the sign
        }
    }

    /**
     * @dev Swaps tokenIn for tokenOut in a Uniswap V4 pool.
     *
     * Requirements:
     * - The call must succeed.
     * - The pair must have code.
     */
    function swapUV4(
        bytes calldata route,
        bytes32 value,
        address manager,
        address dataOffset,
        bool zeroForOne,
        uint256 amountIn
    ) internal returns (uint256 amountOut, uint256 actualAmountIn) {
        (uint256 success, int256 deltaIn, int256 deltaOut) =
            callSwapUV4(route, value, manager, dataOffset, zeroForOne, -amountIn.toInt256());
        _bubbleRevert(success);
        unchecked {
            return (deltaOut.toUint256(), (-deltaIn).toUint256()); // Invert the sign of deltaIn
        }
    }

    /**
     * @dev Calls the `unlock` function of a Uniswap V4 pool.
     * This function doesn't revert on failure, it returns a success flag instead.
     * It also returns the actual amount in and out of the swap.
     * Requirements:
     * - The call must return exactly 64 bytes of data.
     */
    function callSwapUV4(
        bytes calldata route,
        bytes32 value,
        address manager,
        address dataOffset,
        bool zeroForOne,
        int256 deltaAmount
    ) private returns (uint256 success, int256 deltaIn, int256 deltaOut) {
        bytes memory data = prepareDataUV4(route, value, uint256(uint160(dataOffset)), zeroForOne, deltaAmount);

        uint256 returnDataSize;

        assembly ("memory-safe") {
            let length := mload(data)
            mstore(data, 0x48c89491) // unlock(bytes)

            success := call(gas(), manager, 0, add(data, 28), add(length, 4), data, 128)

            returnDataSize := returndatasize()

            switch zeroForOne
            case 0 {
                deltaIn := mload(add(data, 96))
                deltaOut := mload(add(data, 64))
            }
            default {
                deltaIn := mload(add(data, 64))
                deltaOut := mload(add(data, 96))
            }
        }

        if (returnDataSize != 128) revert PairInteraction__InvalidReturnData();
    }

    /**
     * @dev Callback function for Uniswap V4 swaps.
     * This function should be called after the `unlock` callback from the Uniswap V4 manager.
     * This function will then call the swap function and settle the amounts.
     *
     * Requirements:
     * - The call must succeed.
     * - The caller must be the Uniswap V4 manager.
     */
    function swapUV4Callback(bytes calldata data, address recipient, address wnative)
        internal
        returns (int256 amount0, int256 amount1)
    {
        address token0;
        address token1;

        uint256 success;
        uint256 returnDataSize;
        assembly ("memory-safe") {
            let ptr := mload(0x40)

            mstore(ptr, 0xf3cd914c) // swap((address,address,uint24,int24,address),(bool,int256,uint160),bytes)
            calldatacopy(add(ptr, 32), add(data.offset, 68), sub(data.length, 68))

            mstore(0x40, shl(5, shr(5, sub(add(ptr, data.length), 37)))) // Round up to the next complete word

            success := call(gas(), caller(), 0, add(ptr, 28), sub(data.length, 64), 0, 32)
            returnDataSize := returndatasize()

            let amounts := mload(0)
            amount0 := sar(128, amounts)
            amount1 := signextend(15, amounts)

            // Revert with amounts to decode them within getSwapInUV4
            if iszero(recipient) {
                mstore(0, 0x20)
                mstore(32, 0x40)
                mstore(64, amount0)
                mstore(96, amount1)
                revert(0, 128)
            }

            token0 := mload(add(ptr, 32))
            token1 := mload(add(ptr, 64))
        }
        _bubbleRevert(success);
        if (returnDataSize != 32) revert PairInteraction__InvalidReturnData();

        settleOrTakeUV4(token0, recipient, amount0, wnative);
        settleOrTakeUV4(token1, recipient, amount1, wnative);
    }

    /**
     * @dev Settles or takes the amount for a token in a Uniswap V4 swap.
     * If delta is negative, it means we need to settle the amount (send it to the pair).
     * If delta is positive, it means we need to take the amount (receive it from the pair).
     *
     * Requirements:
     * - The call must succeed.
     * - The caller must be the Uniswap V4 manager.
     */
    function settleOrTakeUV4(address token, address recipient, int256 delta, address wnative) internal {
        if (delta < 0) {
            uint256 success;
            // Settle the amount by calling sync, then transferring the tokens and finally calling settle
            assembly ("memory-safe") {
                delta := sub(0, delta)

                mstore(0, 0xa5841194) // sync(address)
                mstore(32, token)
                success := call(gas(), caller(), 0, 28, 64, 0, 0)
            }
            _bubbleRevert(success);

            uint256 nativeValue;
            if (token == address(0)) {
                // The token is native, unwrap wnative and send it
                TokenLib.unwrap(wnative, (nativeValue = delta.toUint256()));
            } else {
                TokenLib.transfer(token, msg.sender, delta.toUint256());
            }

            uint256 amount;
            uint256 returnDataSize;
            assembly ("memory-safe") {
                mstore(0, 0x11da60b4) // settle()
                success := call(gas(), caller(), nativeValue, 28, 4, 0, 32)
                returnDataSize := returndatasize()
                amount := mload(0)
            }
            _bubbleRevert(success);
            if (returnDataSize != 32) revert PairInteraction__InvalidReturnData();
        } else if (delta > 0) {
            // Take the amount by calling take, if token is native it will be wrapped after being received
            // (within the receive function)
            address to = token == address(0) ? address(this) : recipient;
            uint256 success;
            assembly ("memory-safe") {
                let ptr := mload(0x40)

                mstore(ptr, 0x0b0d9c09) // take(address,address,uint256)
                mstore(add(ptr, 32), token)
                mstore(add(ptr, 64), to)
                mstore(add(ptr, 96), delta)

                success := call(gas(), caller(), 0, add(ptr, 28), 100, 0, 0)

                mstore(0x40, add(ptr, 128))
            }
            _bubbleRevert(success);
            if (to != recipient) {
                // If the token is native, use this as a temporary address to receive the native token
                // then wrap it, and send it to the actual recipient
                TokenLib.transfer(wnative, recipient, delta.toUint256());
            }
        }
    }

    /**
     * @dev Returns the amount of tokenIn required to get amountOut from a ByReal pair.
     *
     * Requirements:
     * - The call must succeed.
     * - The pair must have code.
     * - The return data must be exactly 32 bytes.
     */
    function getSwapInByReal(address pair, uint256 amountIn, address tokenIn)
        internal
        view
        returns (uint256 amountOut)
    {
        uint256 returnDataSize;
        uint256 success;
        assembly ("memory-safe") {
            let m0x40 := mload(0x40)

            mstore(0, 0x1125f13f) // getAmountIn(uint256,address)
            mstore(32, amountIn)
            mstore(64, tokenIn)

            success := staticcall(gas(), pair, 28, 68, 0, 32)

            returnDataSize := returndatasize()

            amountOut := mload(0)

            mstore(0x40, m0x40)
        }
        _bubbleRevert(success);

        if (returnDataSize != 32) revert PairInteraction__InvalidReturnData();
    }

    /**
     * @dev Swaps tokenIn for tokenOut in a ByReal pair.
     * The function doesn't check that the pair has any code, `getSwapInOrOutByReal` should be called first to ensure
     * that.
     *
     * Requirements:
     * - The call must succeed.
     */
    function swapByReal(address pair, address recipient, uint256 amountIn, address tokenIn)
        internal
        returns (uint256 amountOut)
    {
        uint256 returnDataSize;
        uint256 success;
        assembly ("memory-safe") {
            let ptr := mload(0x40)

            mstore(ptr, 0xf946c2a2) // swap(address,bool,uint256,address)
            mstore(add(ptr, 32), tokenIn)
            mstore(add(ptr, 64), 1) // always givenIn = true
            mstore(add(ptr, 96), amountIn)
            mstore(add(ptr, 128), recipient)

            success := call(gas(), pair, 0, add(ptr, 28), 132, 0, 32)

            returnDataSize := returndatasize()

            amountOut := mload(0)

            mstore(0x40, add(ptr, 160))
        }
        _bubbleRevert(success);

        if (returnDataSize != 32) revert PairInteraction__InvalidReturnData();
    }

    /**
     * @dev Bubbles up a revert if the success flag is false.
     * It copies the return data to memory and reverts with it.
     * If there is no return data, it reverts with a `PairInteraction__CallFailed` error.
     */
    function _bubbleRevert(uint256 success) private pure {
        assembly ("memory-safe") {
            if iszero(success) {
                if returndatasize() {
                    returndatacopy(0, 0, returndatasize())
                    revert(0, returndatasize())
                }

                mstore(0, 0x824d2235) // PairInteraction__CallFailed()
                revert(0x1c, 4)
            }
        }
    }
}
