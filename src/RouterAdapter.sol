// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Flags} from "./libraries/Flags.sol";
import {PairInteraction} from "./libraries/PairInteraction.sol";
import {TokenLib} from "./libraries/TokenLib.sol";

/**
 * @title RouterAdapter
 * @notice Router adapter contract for interacting with different types of pairs.
 * Currently supports Uniswap V2, Trader Joe Legacy LB, Trader Joe LB, and Uniswap V3 pairs.
 */
abstract contract RouterAdapter {
    error RouterAdapter__InvalidId();
    error RouterAdapter__InsufficientLBLiquidity();
    error RouterAdapter__UniswapV3SwapCallbackOnly(int256 amount0Delta, int256 amount1Delta);
    error RouterAdapter__UnexpectedCallback();
    error RouterAdapter__UnexpectedAmountIn();

    address private immutable _routerV2_0;

    uint256 private _callbackData = 0xdead;

    /**
     * @dev Constructor for the RouterAdapter contract.
     */
    constructor(address routerV2_0) {
        _routerV2_0 = routerV2_0;
    }

    /**
     * @dev Returns the amount of tokenIn needed to get amountOut from the pair.
     *
     * Requirements:
     * - The id of the flags must be valid.
     */
    function _getAmountIn(address pair, uint256 flags, uint256 amountOut) internal returns (uint256) {
        uint256 id = Flags.id(flags);

        if (id == Flags.UNISWAP_V2_ID) {
            return _getAmountInUV2(pair, flags, amountOut);
        } else if (id == Flags.TRADERJOE_LEGACY_LB_ID) {
            return _getAmountInLegacyLB(pair, flags, amountOut);
        } else if (id == Flags.TRADERJOE_LB_ID) {
            return _getAmountInLB(pair, flags, amountOut);
        } else if (id == Flags.UNISWAP_V3_ID) {
            return _getAmountInUV3(pair, flags, amountOut);
        } else {
            revert RouterAdapter__InvalidId();
        }
    }

    /**
     * @dev Swaps tokens from the sender to the recipient.
     *
     * Requirements:
     * - The id of the flags must be valid.
     */
    function _swap(address pair, address tokenIn, uint256 amountIn, address recipient, uint256 flags)
        internal
        returns (uint256 amountOut)
    {
        uint256 id = Flags.id(flags);

        if (id == Flags.UNISWAP_V2_ID) {
            amountOut = _swapUV2(pair, flags, amountIn, recipient);
        } else if (id == Flags.TRADERJOE_LEGACY_LB_ID) {
            amountOut = _swapLegacyLB(pair, flags, recipient);
        } else if (id == Flags.TRADERJOE_LB_ID) {
            amountOut = _swapLB(pair, flags, recipient);
        } else if (id == Flags.UNISWAP_V3_ID) {
            amountOut = _swapUV3(pair, flags, recipient, amountIn, tokenIn);
        } else {
            revert RouterAdapter__InvalidId();
        }
    }

    /* Uniswap V2 */

    /**
     * @dev Returns the amount of tokenIn needed to get amountOut from the Uniswap V2 pair.
     */
    function _getAmountInUV2(address pair, uint256 flags, uint256 amountOut) internal view returns (uint256) {
        (uint256 reserveIn, uint256 reserveOut) = PairInteraction.getReservesUV2(pair, Flags.zeroForOne(flags));
        return (reserveIn * amountOut * 1000 - 1) / ((reserveOut - amountOut) * 997) + 1;
    }

    /**
     * @dev Swaps tokens from the sender to the recipient using the Uniswap V2 pair.
     */
    function _swapUV2(address pair, uint256 flags, uint256 amountIn, address recipient)
        internal
        returns (uint256 amountOut)
    {
        bool ordered = Flags.zeroForOne(flags);
        (uint256 reserveIn, uint256 reserveOut) = PairInteraction.getReservesUV2(pair, ordered);

        uint256 amountInWithFee = amountIn * 997;
        amountOut = (amountInWithFee * reserveOut) / (reserveIn * 1000 + amountInWithFee);

        (uint256 amount0, uint256 amount1) = ordered ? (uint256(0), amountOut) : (amountOut, uint256(0));
        PairInteraction.swapUV2(pair, amount0, amount1, recipient);
    }

    /* Legacy LB v2.0 */

    /**
     * @dev Returns the amount of tokenIn needed to get amountOut from the Trader Joe Legacy LB pair.
     */
    function _getAmountInLegacyLB(address pair, uint256 flags, uint256 amountOut)
        internal
        view
        returns (uint256 amountIn)
    {
        return PairInteraction.getSwapInLegacyLB(_routerV2_0, pair, amountOut, Flags.zeroForOne(flags));
    }

    /**
     * @dev Swaps tokens from the sender to the recipient using the Trader Joe Legacy LB pair.
     */
    function _swapLegacyLB(address pair, uint256 flags, address recipient) internal returns (uint256 amountOut) {
        return PairInteraction.swapLegacyLB(pair, Flags.zeroForOne(flags), recipient);
    }

    /* LB v2.1 and v2.2 */

    /**
     * @dev Returns the amount of tokenIn needed to get amountOut from the Trader Joe LB pair.
     */
    function _getAmountInLB(address pair, uint256 flags, uint256 amountOut) internal view returns (uint256) {
        (uint256 amountIn, uint256 amountLeft) = PairInteraction.getSwapInLB(pair, amountOut, Flags.zeroForOne(flags));
        if (amountLeft != 0) revert RouterAdapter__InsufficientLBLiquidity();
        return amountIn;
    }

    /**
     * @dev Swaps tokens from the sender to the recipient using the Trader Joe LB pair.
     */
    function _swapLB(address pair, uint256 flags, address recipient) internal returns (uint256 amountOut) {
        return PairInteraction.swapLB(pair, Flags.zeroForOne(flags), recipient);
    }

    /* Uniswap V3 */

    /**
     * @dev Returns the amount of tokenIn needed to get amountOut from the Uniswap V3 pair.
     */
    function _getAmountInUV3(address pair, uint256 flags, uint256 amountOut) internal returns (uint256 amountIn) {
        return PairInteraction.getSwapInUV3(pair, Flags.zeroForOne(flags), amountOut);
    }

    /**
     * @dev Swaps tokens from the sender to the recipient using the Uniswap V3 pair.
     * Will set the callback address to the pair.
     */
    function _swapUV3(address pair, uint256 flags, address recipient, uint256 amountIn, address tokenIn)
        internal
        returns (uint256)
    {
        _callbackData = uint160(pair);

        (uint256 amountOut, uint256 actualAmountIn, uint256 hash) =
            PairInteraction.swapUV3(pair, recipient, Flags.zeroForOne(flags), amountIn, tokenIn);

        if (_callbackData != hash) revert RouterAdapter__UnexpectedCallback();
        if (actualAmountIn != amountIn) revert RouterAdapter__UnexpectedAmountIn();

        _callbackData = 0xdead;

        return amountOut;
    }

    /**
     * @dev Callback function for Uniswap V3 swaps.
     *
     * Requirements:
     * - The caller must be the callback address.
     */
    function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata data) external {
        if (uint160(msg.sender) != _callbackData) {
            revert RouterAdapter__UniswapV3SwapCallbackOnly(amount0Delta, amount1Delta);
        }
        address token = address(uint160(uint256(bytes32(data))));

        _callbackData = PairInteraction.hashUV3(amount0Delta, amount1Delta, token);

        TokenLib.transfer(token, msg.sender, uint256(amount0Delta > 0 ? amount0Delta : amount1Delta));
    }
}
