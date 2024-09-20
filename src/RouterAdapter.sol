// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {Flags} from "./libraries/Flags.sol";
import {IV1Pair} from "./interfaces/IV1Pair.sol";
import {IV2_0Router} from "./interfaces/IV2_0Router.sol";
import {IV2_0Pair} from "./interfaces/IV2_0Pair.sol";
import {IV2_1Pair} from "./interfaces/IV2_1Pair.sol";
import {IUniswapV3Pool} from "./interfaces/IUniswapV3Pool.sol";
import {IWNative} from "./interfaces/IWNative.sol";

abstract contract RouterAdapter {
    using SafeERC20 for IERC20;

    error RouterAdapter__InvalidId();
    error RouterAdapter__InsufficientLBLiquidity();
    error RouterAdapter__InvalidRevertReason();
    error RouterAdapter__UniswapV3SwapCallbackOnly(int256 amount0Delta, int256 amount1Delta);

    uint160 internal constant MIN_SWAP_SQRT_RATIO_UV3 = 4295128739 + 1;
    uint160 internal constant MAX_SWAP_SQRT_RATIO_UV3 = 1461446703485210103287273052203988822378723970342 - 1;

    address private immutable _routerV2_0;

    address private _callback = address(0xdead);

    constructor(address routerV2_0) {
        _routerV2_0 = routerV2_0;
    }

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
            amountOut = _swapUV3(pair, tokenIn, flags, amountIn, recipient);
        } else {
            revert RouterAdapter__InvalidId();
        }
    }

    /* Uniswap V2 */

    function _getAmountInUV2(address pair, uint256 flags, uint256 amountOut) internal view returns (uint256) {
        (uint256 reserveIn, uint256 reserveOut,) = IV1Pair(pair).getReserves();
        (reserveIn, reserveOut) = Flags.zeroForOne(flags) ? (reserveIn, reserveOut) : (reserveOut, reserveIn);

        return (reserveIn * amountOut * 1000 - 1) / ((reserveOut - amountOut) * 997) + 1;
    }

    function _swapUV2(address pair, uint256 flags, uint256 amountIn, address recipient)
        internal
        returns (uint256 amountOut)
    {
        bool ordered = Flags.zeroForOne(flags);

        (uint256 reserveIn, uint256 reserveOut,) = IV1Pair(pair).getReserves();
        (reserveIn, reserveOut) = ordered ? (reserveIn, reserveOut) : (reserveOut, reserveIn);

        uint256 amountInWithFee = amountIn * 997;
        amountOut = (amountInWithFee * reserveOut) / (reserveIn * 1000 + amountInWithFee);

        (uint256 amount0, uint256 amount1) = ordered ? (uint256(0), amountOut) : (amountOut, uint256(0));
        IV1Pair(pair).swap(amount0, amount1, recipient, new bytes(0));
    }

    /* Legacy LB v2.0 */

    function _getAmountInLegacyLB(address pair, uint256 flags, uint256 amountOut)
        internal
        view
        returns (uint256 amountIn)
    {
        (amountIn,) = IV2_0Router(_routerV2_0).getSwapIn(pair, amountOut, Flags.zeroForOne(flags));
    }

    function _swapLegacyLB(address pair, uint256 flags, address recipient) internal returns (uint256 amountOut) {
        bool swapForY = Flags.zeroForOne(flags);
        (uint256 amountXOut, uint256 amountYOut) = IV2_0Pair(pair).swap(swapForY, recipient);

        return swapForY ? amountYOut : amountXOut;
    }

    /* LB v2.1 and v2.2 */

    function _getAmountInLB(address pair, uint256 flags, uint256 amountOut) internal view returns (uint256 amountIn) {
        uint256 amountLeft;
        (amountIn, amountLeft,) = IV2_1Pair(pair).getSwapIn(uint128(amountOut), Flags.zeroForOne(flags));
        if (amountLeft != 0) revert RouterAdapter__InsufficientLBLiquidity();
    }

    function _swapLB(address pair, uint256 flags, address recipient) internal returns (uint256 amountOut) {
        bool swapForY = Flags.zeroForOne(flags);
        bytes32 amounts = IV2_1Pair(pair).swap(swapForY, recipient);

        return swapForY ? uint256(amounts >> 128) : uint256(uint256(amounts) & type(uint128).max);
    }

    /* Uniswap V3 */

    function _getAmountInUV3(address pair, uint256 flags, uint256 amountOut) internal returns (uint256 amountIn) {
        bool zeroForOne = Flags.zeroForOne(flags);

        uint160 priceLimit = zeroForOne ? MIN_SWAP_SQRT_RATIO_UV3 : MAX_SWAP_SQRT_RATIO_UV3;

        try IUniswapV3Pool(pair).swap(address(this), zeroForOne, -int256(amountOut), priceLimit, new bytes(0)) {
            revert RouterAdapter__InvalidRevertReason();
        } catch (bytes memory reason) {
            if (reason.length != 68 || bytes4(reason) != RouterAdapter__UniswapV3SwapCallbackOnly.selector) {
                revert RouterAdapter__InvalidRevertReason();
            }

            assembly {
                switch zeroForOne
                case 1 { amountIn := mload(add(reason, 36)) }
                default { amountIn := mload(add(reason, 68)) }
            }
        }
    }

    function _swapUV3(address pair, address tokenIn, uint256 flags, uint256 amountIn, address recipient)
        internal
        returns (uint256 amountOut)
    {
        bool zeroForOne = Flags.zeroForOne(flags);

        uint160 priceLimit = zeroForOne ? MIN_SWAP_SQRT_RATIO_UV3 : MAX_SWAP_SQRT_RATIO_UV3;

        _callback = pair;

        (int256 amount0, int256 amount1) =
            IUniswapV3Pool(pair).swap(recipient, zeroForOne, int256(amountIn), priceLimit, abi.encodePacked(tokenIn));

        return uint256(-(zeroForOne ? amount1 : amount0));
    }

    function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata data) external {
        if (msg.sender != _callback) revert RouterAdapter__UniswapV3SwapCallbackOnly(amount0Delta, amount1Delta);
        _callback = address(0xdead);

        address tokenIn = address(uint160(bytes20(data[0:20])));
        uint256 amount = uint256(amount0Delta > 0 ? amount0Delta : amount1Delta);

        IERC20(tokenIn).safeTransfer(msg.sender, amount);
    }
}
