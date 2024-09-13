// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {PackedRoute} from "./libraries/PackedRoute.sol";
import {Flags} from "./libraries/Flags.sol";
import {IRouter} from "./interfaces/IRouter.sol";
import {IRouterLogic} from "./interfaces/IRouterLogic.sol";
import {IV1Pair} from "./interfaces/IV1Pair.sol";
import {IV2_0Router} from "./interfaces/IV2_0Router.sol";
import {IV2_0Pair} from "./interfaces/IV2_0Pair.sol";
import {IV2_1Pair} from "./interfaces/IV2_1Pair.sol";
import {IUniswapV3Pool} from "./interfaces/IUniswapV3Pool.sol";
import {IWNative} from "./interfaces/IWNative.sol";

contract RouterLogic is IRouterLogic {
    using SafeERC20 for IERC20;

    error RouterLogic__OnlyRouter();
    error RouterLogic__InsufficientLBLiquidity();
    error RouterLogic__InvalidId();
    error RouterLogic__InvalidTokenOut();
    error RouterLogic__InvalidAmount();
    error RouterLogic__InvalidRevertReason();
    error RouterLogic__UniswapV3SwapCallbackOnly(int256 amount0Delta, int256 amount1Delta);
    error RouterLogic__ZeroRoute();

    address private immutable _router;
    address private immutable _routerV2_0;

    uint160 internal constant MIN_SWAP_SQRT_RATIO_UV3 = 4295128739 + 1;
    uint160 internal constant MAX_SWAP_SQRT_RATIO_UV3 = 1461446703485210103287273052203988822378723970342 - 1;

    address private _callback = address(0xdead);

    constructor(address router, address routerV2_0) {
        _router = router;

        _routerV2_0 = routerV2_0;
    }

    function swapExactIn(address tokenIn, address tokenOut, address from, address to, bytes[] calldata routes)
        external
        returns (uint256 totalIn, uint256 totalOut)
    {
        _onlyRouter();

        uint256 nbRoutes = routes.length;

        for (uint256 i; i < nbRoutes; ++i) {
            (uint256 amountIn, uint256 amountOut) = _swapExactInRoute(tokenIn, tokenOut, from, to, routes[i]);

            totalIn += amountIn;
            totalOut += amountOut;
        }
    }

    function swapExactOut(address tokenIn, address tokenOut, address from, address to, bytes[] calldata routes)
        external
        payable
        returns (uint256 totalIn, uint256 totalOut)
    {
        _onlyRouter();

        uint256 nbRoutes = routes.length;

        for (uint256 i; i < nbRoutes; ++i) {
            (uint256 amountIn, uint256 amountOut) = _swapExactOutRoute(tokenIn, tokenOut, from, to, routes[i]);

            totalIn += amountIn;
            totalOut += amountOut;
        }
    }

    function _onlyRouter() private view {
        if (msg.sender != _router) revert RouterLogic__OnlyRouter();
    }

    function _checkAmount(uint256 amount) private pure {
        if (amount == 0 || amount > type(uint128).max) revert RouterLogic__InvalidAmount();
    }

    function _balanceOf(address token, address account) private view returns (uint256 amount) {
        uint256 success;

        assembly {
            mstore(0, 0x70a08231) // balanceOf(address)
            mstore(32, account)

            success := staticcall(gas(), token, 28, 36, 0, 32)

            success := and(success, gt(returndatasize(), 31))
            amount := mload(0)
        }
    }

    function _getAmountInRoute(bytes calldata route, uint256 amountOut) private returns (uint256) {
        address pair;
        uint256 flags;
        uint256 ptr = route.length;
        while (ptr > PackedRoute.HEADER_SIZE) {
            (ptr, pair,, flags) = PackedRoute.previous(route, ptr);

            amountOut = _getAmountInSingle(pair, flags, amountOut);
        }

        return amountOut;
    }

    function _getAmountInSingle(address pair, uint256 flags, uint256 amountOut) private returns (uint256) {
        uint256 id = Flags.id(flags);

        if (id == Flags.UNISWAP_V2_ID) {
            return _getAmountInUV2(pair, flags, amountOut);
        } else if (id == Flags.TRADERJOE_LB0_ID) {
            return _getAmountInLB2_0(pair, flags, amountOut);
        } else if (id == Flags.TRADERJOE_LB12_ID) {
            return _getAmountInLB2_1(pair, flags, amountOut);
        } else if (id == Flags.UNISWAP_V3_ID) {
            return _getAmountInUV3(pair, flags, amountOut);
        } else {
            revert RouterLogic__InvalidId();
        }
    }

    function _getAmountInUV2(address pair, uint256 flags, uint256 amountOut) private view returns (uint256) {
        (uint256 reserveIn, uint256 reserveOut,) = IV1Pair(pair).getReserves();
        (reserveIn, reserveOut) = Flags.zeroForOne(flags) ? (reserveIn, reserveOut) : (reserveOut, reserveIn);

        return (reserveIn * amountOut * 1000 - 1) / ((reserveOut - amountOut) * 997) + 1;
    }

    function _getAmountInLB2_0(address pair, uint256 flags, uint256 amountOut)
        private
        view
        returns (uint256 amountIn)
    {
        (amountIn,) = IV2_0Router(_routerV2_0).getSwapIn(pair, amountOut, Flags.zeroForOne(flags));
    }

    function _getAmountInLB2_1(address pair, uint256 flags, uint256 amountOut)
        private
        view
        returns (uint256 amountIn)
    {
        uint256 amountLeft;
        (amountIn, amountLeft,) = IV2_1Pair(pair).getSwapIn(uint128(amountOut), Flags.zeroForOne(flags));
        if (amountLeft != 0) revert RouterLogic__InsufficientLBLiquidity();
    }

    function _getAmountInUV3(address pair, uint256 flags, uint256 amountOut) private returns (uint256 amountIn) {
        bool zeroForOne = Flags.zeroForOne(flags);

        try IUniswapV3Pool(pair).swap(
            address(this),
            zeroForOne,
            -int256(amountOut),
            zeroForOne ? MIN_SWAP_SQRT_RATIO_UV3 : MAX_SWAP_SQRT_RATIO_UV3,
            new bytes(0)
        ) {} catch (bytes memory reason) {
            if (reason.length != 68) revert RouterLogic__InvalidRevertReason();

            assembly {
                switch zeroForOne
                case 1 { amountIn := mload(add(reason, 36)) }
                default { amountIn := mload(add(reason, 68)) }
            }
        }
    }

    function _swapExactInRoute(address tokenIn, address tokenOut, address from, address to, bytes calldata route)
        private
        returns (uint256, uint256)
    {
        uint256 length = PackedRoute.length(route);

        (uint256 ptr, uint256 amountIn) = PackedRoute.start(route);

        return (amountIn, _swapRoute(tokenIn, tokenOut, from, to, route, length, ptr, amountIn));
    }

    function _swapExactOutRoute(address tokenIn, address tokenOut, address from, address to, bytes calldata route)
        private
        returns (uint256, uint256)
    {
        uint256 length = PackedRoute.length(route);

        (uint256 ptr, uint256 amountOut) = PackedRoute.start(route);
        uint256 amountIn = _getAmountInRoute(route, amountOut);

        return (amountIn, _swapRoute(tokenIn, tokenOut, from, to, route, length, ptr, amountIn));
    }

    function _swapRoute(
        address tokenIn,
        address tokenOut,
        address from,
        address to,
        bytes calldata route,
        uint256 length,
        uint256 ptr,
        uint256 amount
    ) private returns (uint256) {
        if (length == 0) revert RouterLogic__ZeroRoute();

        _checkAmount(amount);

        address pair;
        address token1;
        uint256 flags;

        (ptr, pair, token1, flags) = PackedRoute.next(route, ptr);

        address token0 =
            IRouter(msg.sender).transfer(tokenIn, from, Flags.callback(flags) ? address(this) : pair, amount);

        address nextPair;
        address nextToken;
        uint256 nextFlags;
        for (uint256 i; i++ < length;) {
            address recipient;
            if (i == length) {
                recipient = to;
            } else {
                (ptr, nextPair, nextToken, nextFlags) = PackedRoute.next(route, ptr);

                if (Flags.callback(nextFlags)) recipient = address(this);
                else recipient = nextPair;
            }

            amount = _swapSingle(pair, token0, token1, flags, amount, recipient);

            token0 = token1;

            pair = nextPair;
            token1 = nextToken;
            flags = nextFlags;
        }

        if (token1 != tokenOut) revert RouterLogic__InvalidTokenOut();

        _checkAmount(amount);

        return amount;
    }

    function _swapSingle(
        address pair,
        address tokenIn,
        address tokenOut,
        uint256 flags,
        uint256 amount,
        address recipient
    ) private returns (uint256 amountOut) {
        bool isTransferTaxToken = Flags.transferTaxToken(flags);
        uint256 balance = isTransferTaxToken ? _balanceOf(tokenOut, recipient) : 0;

        uint256 id = Flags.id(flags);

        if (id == Flags.UNISWAP_V2_ID) {
            amountOut = _swapUV2(pair, flags, amount, recipient);
        } else if (id == Flags.TRADERJOE_LB0_ID) {
            amountOut = _swapLB0(pair, flags, recipient);
        } else if (id == Flags.TRADERJOE_LB12_ID) {
            amountOut = _swapLB12(pair, flags, recipient);
        } else if (id == Flags.UNISWAP_V3_ID) {
            amountOut = _swapUV3(pair, tokenIn, flags, amount, recipient);
        } else {
            revert RouterLogic__InvalidId();
        }

        return isTransferTaxToken ? _balanceOf(tokenOut, recipient) - balance : amountOut;
    }

    function _swapUV2(address pair, uint256 flags, uint256 amountIn, address recipient)
        private
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

    function _swapLB0(address pair, uint256 flags, address recipient) private returns (uint256 amountOut) {
        bool swapForY = Flags.zeroForOne(flags);
        (uint256 amountXOut, uint256 amountYOut) = IV2_0Pair(pair).swap(swapForY, recipient);

        return swapForY ? amountYOut : amountXOut;
    }

    function _swapLB12(address pair, uint256 flags, address recipient) private returns (uint256 amountOut) {
        bool swapForY = Flags.zeroForOne(flags);
        bytes32 amounts = IV2_1Pair(pair).swap(swapForY, recipient);

        return swapForY ? uint256(amounts >> 128) : uint256(uint256(amounts) & type(uint128).max);
    }

    function _swapUV3(address pair, address tokenIn, uint256 flags, uint256 amountIn, address recipient)
        private
        returns (uint256 amountOut)
    {
        bool zeroForOne = Flags.zeroForOne(flags);

        _callback = pair;

        (int256 amount0, int256 amount1) = IUniswapV3Pool(pair).swap(
            recipient,
            zeroForOne,
            int256(amountIn),
            zeroForOne ? MIN_SWAP_SQRT_RATIO_UV3 : MAX_SWAP_SQRT_RATIO_UV3,
            abi.encodePacked(tokenIn)
        );

        return uint256(-(zeroForOne ? amount1 : amount0));
    }

    function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata data) external {
        if (msg.sender != _callback) revert RouterLogic__UniswapV3SwapCallbackOnly(amount0Delta, amount1Delta);
        _callback = address(0xdead);

        address tokenIn = address(uint160(bytes20(data[0:20])));
        uint256 amount = uint256(amount0Delta > 0 ? amount0Delta : amount1Delta);

        IERC20(tokenIn).safeTransfer(msg.sender, amount);
    }
}
