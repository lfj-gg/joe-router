// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Flags} from "./libraries/Flags.sol";
import {PackedRoute} from "./libraries/PackedRoute.sol";
import {PairInteraction} from "./libraries/PairInteraction.sol";
import {TokenLib} from "./libraries/TokenLib.sol";

/**
 * @title RouterAdapter
 * @notice Router adapter contract for interacting with different types of pairs.
 * Currently supports Uniswap V2, LFJ Legacy LB, LFJ LB, Uniswap V3 pairs and LFJ Token Mill.
 */
abstract contract RouterAdapter {
    error RouterAdapter__InvalidId();
    error RouterAdapter__InsufficientLBLiquidity();
    error RouterAdapter__InsufficientTMLiquidity();
    error RouterAdapter__InsufficientTMV2Liquidity();
    error RouterAdapter__UnexpectedCallback();
    error RouterAdapter__UnexpectedAmountIn();
    error RouterAdapter__OnlyWnative();

    address private immutable ROUTER_V2_0;
    address private immutable UNISWAP_V4_MANAGER;
    address private immutable WNATIVE;

    uint256 private _callbackData = 0xdead;

    /**
     * @dev Constructor for the RouterAdapter contract.
     */
    constructor(address routerV2_0, address uniswapV4Manager, address wnative) {
        ROUTER_V2_0 = routerV2_0;
        WNATIVE = wnative;
        UNISWAP_V4_MANAGER = uniswapV4Manager;
    }

    /**
     * @dev Allows the contract to receive native tokens and wrap them, unless it's from the wrapped native
     * token contract itself, then it just accepts the native tokens.
     */
    receive() external payable {
        if (msg.sender != WNATIVE) TokenLib.wrap(WNATIVE, msg.value);
    }

    /**
     * @dev Fallback function to handle callbacks from pairs.
     *
     * Requirements:
     * - The callback data must have been set to `pair << 96 | PAIR_ID` before the callback, otherwise revert with
     * `RouterAdapter__UnexpectedCallback()`.
     */
    fallback(bytes calldata data) external returns (bytes memory) {
        uint256 callbackData = _callbackData;
        uint256 id = Flags.id(callbackData);
        // forge-lint: disable-next-line(unsafe-typecast)
        address account = address(uint160(callbackData >> 96));

        if (id == Flags.UNISWAP_V3_ID && msg.sender == account) {
            return _uniswapV3SwapCallback(data);
        } else if (id == Flags.UNISWAP_V4_ID && msg.sender == UNISWAP_V4_MANAGER) {
            return _uniswapV4UnlockCallback(data, account);
        }

        assembly ("memory-safe") {
            calldatacopy(0, 0, calldatasize())
            revert(0, calldatasize())
        }
    }

    /**
     * @dev Returns the amount of tokenIn needed to get amountOut from the pair.
     *
     * Requirements:
     * - The id of the flags must be valid and not the FEE_ID.
     */
    function _getAmountIn(bytes calldata, bytes32 value, uint256 amountOut) internal returns (uint256 amountIn) {
        address pair = PackedRoute.pair(value);
        uint256 flags = PackedRoute.flags(value);

        uint256 id = Flags.id(flags);

        if (id == Flags.UNISWAP_V2_ID) amountIn = _getAmountInUV2(pair, flags, amountOut);
        else if (id == Flags.LFJ_LEGACY_LIQUIDITY_BOOK_ID) amountIn = _getAmountInLegacyLB(pair, flags, amountOut);
        else if (id == Flags.LFJ_LIQUIDITY_BOOK_ID) amountIn = _getAmountInLB(pair, flags, amountOut);
        else if (id == Flags.UNISWAP_V3_ID) amountIn = _getAmountInUV3(pair, flags, amountOut);
        else if (id == Flags.LFJ_TOKEN_MILL_ID) amountIn = _getAmountInTM(pair, flags, amountOut);
        else if (id == Flags.LFJ_TOKEN_MILL_V2_ID) amountIn = _getAmountInTMV2(pair, flags, amountOut);
        // else if (id == Flags.UNISWAP_V4_ID) amountIn = _getAmountInUV4(route, value, pair, flags, amountOut);
        // Not supported yet because of a rounding issue in the getAmountIn vs getAmountOut functions
        // else if (id == Flags.BYREAL_ID) amountIn = _getSwapInByReal(route, pair, amountOut, value);
        else revert RouterAdapter__InvalidId();
    }

    /**
     * @dev Swaps tokens from the sender to the recipient.
     *
     * Requirements:
     * - The id of the flags must be valid and not the FEE_ID.
     */
    function _swap(bytes calldata, bytes32 value, address tokenIn, uint256 amountIn, address recipient, uint256 flags)
        internal
        returns (uint256 amountOut)
    {
        address pair = PackedRoute.pair(value);
        uint256 id = Flags.id(flags);

        if (id == Flags.UNISWAP_V2_ID) amountOut = _swapUV2(pair, flags, amountIn, recipient);
        else if (id == Flags.LFJ_LEGACY_LIQUIDITY_BOOK_ID) amountOut = _swapLegacyLB(pair, flags, recipient);
        else if (id == Flags.LFJ_LIQUIDITY_BOOK_ID) amountOut = _swapLB(pair, flags, recipient);
        else if (id == Flags.UNISWAP_V3_ID) amountOut = _swapUV3(pair, flags, recipient, amountIn, tokenIn);
        else if (id == Flags.LFJ_TOKEN_MILL_ID) amountOut = _swapTM(pair, flags, recipient, amountIn);
        else if (id == Flags.LFJ_TOKEN_MILL_V2_ID) amountOut = _swapTMV2(pair, flags, recipient, amountIn);
        // else if (id == Flags.UNISWAP_V4_ID) amountOut = _swapUV4(route, value, pair, flags, recipient, amountIn);
        else if (id == Flags.BYREAL_ID) amountOut = _swapByReal(pair, recipient, amountIn, tokenIn);
        else revert RouterAdapter__InvalidId();
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
     * @dev Returns the amount of tokenIn needed to get amountOut from the LFJ Legacy LB pair.
     */
    function _getAmountInLegacyLB(address pair, uint256 flags, uint256 amountOut)
        internal
        view
        returns (uint256 amountIn)
    {
        return PairInteraction.getSwapInLegacyLB(ROUTER_V2_0, pair, amountOut, Flags.zeroForOne(flags));
    }

    /**
     * @dev Swaps tokens from the sender to the recipient using the LFJ Legacy LB pair.
     */
    function _swapLegacyLB(address pair, uint256 flags, address recipient) internal returns (uint256 amountOut) {
        return PairInteraction.swapLegacyLB(pair, Flags.zeroForOne(flags), recipient);
    }

    /* LB v2.1 and v2.2 */

    /**
     * @dev Returns the amount of tokenIn needed to get amountOut from the LFJ LB pair.
     */
    function _getAmountInLB(address pair, uint256 flags, uint256 amountOut) internal view returns (uint256) {
        (uint256 amountIn, uint256 amountLeft) = PairInteraction.getSwapInLB(pair, amountOut, Flags.zeroForOne(flags));
        if (amountLeft != 0) revert RouterAdapter__InsufficientLBLiquidity();
        return amountIn;
    }

    /**
     * @dev Swaps tokens from the sender to the recipient using the LFJ LB pair.
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
        _callbackData = (uint256(uint160(pair)) << 96) | Flags.UNISWAP_V3_ID;

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
    function _uniswapV3SwapCallback(bytes calldata data) internal returns (bytes memory) {
        (int256 amount0Delta, int256 amount1Delta, address token) = PairInteraction.decodeUV3CallbackData(data);

        _callbackData = PairInteraction.hashUV3(amount0Delta, amount1Delta, token);

        TokenLib.transfer(token, msg.sender, uint256(amount0Delta > 0 ? amount0Delta : amount1Delta));
        return new bytes(0);
    }

    /* Token Mill */

    /**
     * @dev Returns the amount of tokenIn needed to get amountOut from the LFJ Token Mill pair.
     */
    function _getAmountInTM(address pair, uint256 flags, uint256 amountOut) internal view returns (uint256) {
        (uint256 amountIn, uint256 actualAmountOut) =
            PairInteraction.getSwapInTM(pair, amountOut, Flags.zeroForOne(flags));
        if (actualAmountOut != amountOut) revert RouterAdapter__InsufficientTMLiquidity();
        return amountIn;
    }

    /**
     * @dev Swaps tokens from the sender to the recipient using the LFJ Token Mill pair.
     */
    function _swapTM(address pair, uint256 flags, address recipient, uint256 amountIn) internal returns (uint256) {
        (uint256 amountOut, uint256 actualAmountIn) =
            PairInteraction.swapTM(pair, recipient, amountIn, Flags.zeroForOne(flags));

        if (actualAmountIn != amountIn) revert RouterAdapter__InsufficientTMLiquidity();
        return amountOut;
    }

    /* Token Mill V2 */

    /**
     * @dev Returns the amount of tokenIn needed to get amountOut from the LFJ Token Mill V2 pair.
     */
    function _getAmountInTMV2(address pair, uint256 flags, uint256 amountOut) internal view returns (uint256) {
        (uint256 amountIn, uint256 actualAmountOut) =
            PairInteraction.getSwapInTMV2(pair, amountOut, Flags.zeroForOne(flags));
        if (actualAmountOut != amountOut) revert RouterAdapter__InsufficientTMV2Liquidity();
        return amountIn;
    }

    /**
     * @dev Swaps tokens from the sender to the recipient using the LFJ Token Mill V2 pair.
     */
    function _swapTMV2(address pair, uint256 flags, address recipient, uint256 amountIn) internal returns (uint256) {
        (uint256 amountOut, uint256 actualAmountIn) =
            PairInteraction.swapTMV2(pair, recipient, amountIn, Flags.zeroForOne(flags));

        if (actualAmountIn != amountIn) revert RouterAdapter__InsufficientTMV2Liquidity();
        return amountOut;
    }

    /* Uniswap V4 */

    /**
     * @dev Returns the amount of tokenIn needed to get amountOut from the Uniswap V4 pair.
     * Will set the callback address to the Uniswap V4 manager.
     */
    function _getAmountInUV4(bytes calldata route, bytes32 value, address pair, uint256 flags, uint256 amountOut)
        internal
        returns (uint256)
    {
        _callbackData = Flags.UNISWAP_V4_ID;

        // Use pair as the dataOffset
        return PairInteraction.getSwapInUV4(route, value, UNISWAP_V4_MANAGER, pair, Flags.zeroForOne(flags), amountOut);
    }

    /**
     * @dev Swaps tokens from the sender to the recipient using the Uniswap V4 pair.
     * Will set the callback address to the recipient.
     */
    function _swapUV4(
        bytes calldata route,
        bytes32 value,
        address pair,
        uint256 flags,
        address recipient,
        uint256 amountIn
    ) internal returns (uint256) {
        _callbackData = (uint256(uint160(recipient)) << 96) | Flags.UNISWAP_V4_ID;

        (uint256 amountOut, uint256 actualAmountIn) =
            PairInteraction.swapUV4(route, value, UNISWAP_V4_MANAGER, pair, Flags.zeroForOne(flags), amountIn);

        _callbackData = 0xdead;

        if (actualAmountIn != amountIn) revert RouterAdapter__UnexpectedAmountIn();

        return amountOut;
    }

    /**
     * @dev Callback function for Uniswap V4 unlocks.
     *
     * Requirements:
     * - The caller must be the callback address.
     */
    function _uniswapV4UnlockCallback(bytes calldata data, address recipient) internal returns (bytes memory) {
        (int256 delta0, int256 delta1) = PairInteraction.swapUV4Callback(data, recipient, WNATIVE);
        return abi.encode(0x20, 0x40, delta0, delta1);
    }

    /**
     * @dev Returns the amount of tokenIn needed to get amountOut from the ByReal pair.
     */
    function _getSwapInByReal(bytes calldata route, address pair, uint256 amountOut, bytes32 value)
        internal
        view
        returns (uint256)
    {
        address tokenOut = PackedRoute.token(route, PackedRoute.tokenOutId(value));
        return PairInteraction.getSwapInByReal(pair, amountOut, tokenOut);
    }

    /**
     * @dev Swaps tokens from the sender to the recipient using the ByReal pair.
     */
    function _swapByReal(address pair, address recipient, uint256 amountIn, address tokenIn)
        internal
        returns (uint256 amountOut)
    {
        TokenLib.forceApprove(tokenIn, pair, amountIn);
        return PairInteraction.swapByReal(pair, recipient, amountIn, tokenIn);
    }
}
