// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library PairInteraction {
    error PairInteraction__InvalidReturnData();

    uint256 internal constant MASK_UINT112 = 0xffffffffffffffffffffffffffff;
    uint256 internal constant MIN_SWAP_SQRT_RATIO_UV3 = 4295128739 + 1;
    uint256 internal constant MAX_SWAP_SQRT_RATIO_UV3 = 1461446703485210103287273052203988822378723970342 - 1;

    function getOrderedReservesUV2(address pair, bool ordered)
        internal
        view
        returns (uint256 reserveIn, uint256 reserveOut)
    {
        uint256 returnDataSize;
        assembly {
            mstore(0, 0x0902f1ac) // getReserves()
            pop(staticcall(gas(), pair, 28, 4, 0, 64))

            returnDataSize := returndatasize()

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

    function swapUV2(address pair, uint256 amount0, uint256 amount1, address recipient) internal {
        assembly {
            let ptr := mload(0x40)

            mstore(ptr, 0x022c0d9f) // swap(uint256,uint256,address,bytes)
            mstore(add(ptr, 32), amount0)
            mstore(add(ptr, 64), amount1)
            mstore(add(ptr, 96), recipient)
            mstore(add(ptr, 128), 128)
            mstore(add(ptr, 160), 0)

            mstore(0x40, add(ptr, 160)) // update free memory pointer to 160 because 160:192 is 0

            if iszero(call(gas(), pair, 0, add(ptr, 28), 164, 0, 0)) {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }
        }
    }

    function getSwapInLegacyLB(address router, address pair, uint256 amountOut, bool swapForY)
        internal
        view
        returns (uint256 amountIn)
    {
        uint256 returnDataSize;
        assembly {
            let ptr := mload(0x40)

            mstore(ptr, 0x5bdd4b7c) // getSwapIn(address,uint256,bool)
            mstore(add(ptr, 32), pair)
            mstore(add(ptr, 64), amountOut)
            mstore(add(ptr, 96), swapForY)

            mstore(0x40, add(ptr, 128))

            if iszero(staticcall(gas(), router, add(ptr, 28), 100, 0, 32)) {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }

            returnDataSize := returndatasize()

            amountIn := mload(0)
        }

        if (returnDataSize < 32) revert PairInteraction__InvalidReturnData();
    }

    function swapLegacyLB(address pair, bool swapForY, address recipient) internal returns (uint256 amountOut) {
        uint256 returnDataSize;

        assembly {
            let m0x40 := mload(0x40)

            mstore(0, 0x53c059a0) // swap(bool,address)
            mstore(32, swapForY)
            mstore(64, recipient)

            if iszero(call(gas(), pair, 0, 28, 68, 0, 64)) {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }

            returnDataSize := returndatasize()

            switch swapForY
            case 0 { amountOut := mload(0) }
            default { amountOut := mload(32) }

            mstore(0x40, m0x40)
        }

        if (returnDataSize < 32) revert PairInteraction__InvalidReturnData();
    }

    function getSwapInLB(address pair, uint256 amountOut, bool swapForY)
        internal
        view
        returns (uint256 amountIn, uint256 amountLeft)
    {
        uint256 returnDataSize;
        assembly {
            let m0x40 := mload(0x40)

            mstore(0, 0xabcd7830) // getSwapIn(uint128,bool)
            mstore(32, amountOut)
            mstore(64, swapForY)

            if iszero(staticcall(gas(), pair, 28, 68, 0, 64)) {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }

            returnDataSize := returndatasize()

            amountIn := mload(0)
            amountLeft := mload(32)

            mstore(0x40, m0x40)
        }

        if (returnDataSize < 64) revert PairInteraction__InvalidReturnData();
    }

    function swapLB(address pair, bool swapForY, address recipient) internal returns (uint256 amountOut) {
        uint256 returnDataSize;

        assembly {
            let m0x40 := mload(0x40)

            mstore(0, 0x53c059a0) // swap(bool,address)
            mstore(32, swapForY)
            mstore(64, recipient)

            if iszero(call(gas(), pair, 0, 28, 68, 0, 32)) {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }

            returnDataSize := returndatasize()

            switch swapForY
            case 0 { amountOut := shr(128, mload(16)) }
            default { amountOut := shr(128, mload(0)) }

            mstore(0x40, m0x40)
        }

        if (returnDataSize < 32) revert PairInteraction__InvalidReturnData();
    }

    function getSwapInUV3(address pair, bool zeroForOne, uint256 amountOut) internal returns (uint256 amountIn) {
        (uint256 success, uint256 ptr) = callSwapUV3(pair, address(this), zeroForOne, -int256(amountOut), address(0));

        uint256 returnDataSize;

        assembly {
            // RouterAdapter__UniswapV3SwapCallbackOnly(int256,int256)
            if and(eq(shr(224, mload(ptr)), 0xcbdb9bb5), iszero(success)) {
                returnDataSize := returndatasize()

                switch zeroForOne
                case 1 { amountIn := mload(add(ptr, 4)) }
                default { amountIn := mload(add(ptr, 36)) }
            }
        }

        if (returnDataSize < 68) revert PairInteraction__InvalidReturnData();
    }

    function swapUV3(address pair, address recipient, bool zeroForOne, uint256 amountIn, address tokenIn)
        internal
        returns (uint256 amount)
    {
        (uint256 success, uint256 ptr) = callSwapUV3(pair, recipient, zeroForOne, int256(amountIn), tokenIn);

        uint256 returnDataSize;

        assembly {
            if iszero(success) {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }

            returnDataSize := returndatasize()

            switch zeroForOne
            case 1 { amount := mload(add(ptr, 32)) }
            default { amount := mload(ptr) }

            amount := sub(0, amount) // Invert the sign
        }

        if (returnDataSize < 64) revert PairInteraction__InvalidReturnData();
    }

    function callSwapUV3(address pair, address recipient, bool zeroForOne, int256 deltaAmount, address tokenIn)
        internal
        returns (uint256 success, uint256 ptr)
    {
        uint256 priceLimit = zeroForOne ? MIN_SWAP_SQRT_RATIO_UV3 : MAX_SWAP_SQRT_RATIO_UV3;

        assembly {
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

            success := call(gas(), pair, 0, add(ptr, 28), 260, ptr, 68)
        }
    }
}
