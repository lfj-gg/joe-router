// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {TokenLib} from "./libraries/TokenLib.sol";
import {RouterLib} from "./libraries/RouterLib.sol";
import {RouterAdapter} from "./RouterAdapter.sol";
import {PackedRoute} from "./libraries/PackedRoute.sol";
import {Flags} from "./libraries/Flags.sol";
import {IRouterLogic} from "./interfaces/IRouterLogic.sol";

contract RouterLogic is RouterAdapter, IRouterLogic {
    address private immutable _router;

    uint256 internal constant BPS = 10000;

    constructor(address router, address routerV2_0) RouterAdapter(routerV2_0) {
        if (router.code.length == 0) revert RouterLogic__InvalidRouter();

        _router = router;
    }

    function swapExactIn(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOutMin,
        address from,
        address to,
        bytes calldata route
    ) external override returns (uint256, uint256) {
        (uint256 ptr, uint256 nbTokens, uint256 nbSwaps) = _startAndVerify(route, tokenIn, tokenOut);

        uint256[] memory balances = new uint256[](nbTokens);

        balances[0] = amountIn;
        uint256 total = amountIn;

        bytes32 value;
        {
            address from_ = from;
            address to_ = to;
            for (uint256 i; i < nbSwaps; i++) {
                (ptr, value) = PackedRoute.next(route, ptr);

                unchecked {
                    total += _swapExactInSingle(route, balances, from_, to_, value);
                }
            }
        }

        uint256 amountOut = balances[nbTokens - 1];
        if (total != amountOut) revert RouterLogic__ExcessBalanceUnused();

        if (amountOut < amountOutMin) revert RouterLogic__InsufficientAmountOut(amountOut, amountOutMin);

        return (amountIn, amountOut);
    }

    function swapExactOut(
        address tokenIn,
        address tokenOut,
        uint256 amountInMax,
        uint256 amountOut,
        address from,
        address to,
        bytes calldata route
    ) external payable override returns (uint256 totalIn, uint256 totalOut) {
        (uint256 ptr, uint256 nbTokens, uint256 nbSwaps) = _startAndVerify(route, tokenIn, tokenOut);

        if (PackedRoute.isTransferTax(route)) revert RouterLogic__TransferTaxNotSupported();

        (uint256 amountIn, uint256[] memory amountsIn) = _getAmountsIn(route, amountOut, nbTokens, nbSwaps);

        if (amountIn > amountInMax) revert RouterLogic__ExceedsMaxAmountIn(amountIn, amountInMax);

        bytes32 value;
        address from_ = from;
        address to_ = to;
        for (uint256 i; i < nbSwaps; i++) {
            (ptr, value) = PackedRoute.next(route, ptr);

            _swapExactOutSingle(route, nbTokens, from_, to_, value, amountsIn[i]);
        }

        return (amountIn, amountOut);
    }

    function _checkAmount(uint256 amount) private pure {
        if (amount == 0 || amount > type(uint128).max) revert RouterLogic__InvalidAmount();
    }

    function _startAndVerify(bytes calldata route, address tokenIn, address tokenOut)
        private
        view
        returns (uint256 ptr, uint256 nbTokens, uint256 nbSwaps)
    {
        if (msg.sender != _router) revert RouterLogic__OnlyRouter();

        (ptr, nbTokens, nbSwaps) = PackedRoute.start(route);

        if (nbTokens < 2) revert RouterLogic__InsufficientTokens();
        if (nbSwaps == 0) revert RouterLogic__ZeroSwap();

        if (PackedRoute.token(route, 0) != tokenIn) revert RouterLogic__InvalidTokenIn();
        if (PackedRoute.token(route, nbTokens - 1) != tokenOut) revert RouterLogic__InvalidTokenOut();
    }

    function _getAmountsIn(bytes calldata route, uint256 amountOut, uint256 nbTokens, uint256 nbSwaps)
        private
        returns (uint256 amountIn, uint256[] memory)
    {
        uint256 ptr = route.length;

        uint256[] memory amountsIn = new uint256[](nbSwaps);
        uint256[] memory balances = new uint256[](nbTokens);

        balances[nbTokens - 1] = amountOut;
        uint256 total = amountOut;

        bytes32 value;
        for (uint256 i = nbSwaps; i > 0;) {
            (ptr, value) = PackedRoute.previous(route, ptr);

            (address pair, uint256 percent, uint256 flags, uint256 tokenOutId, uint256 tokenInId) =
                PackedRoute.decode(value);

            uint256 amount = balances[tokenInId] * percent / BPS;
            balances[tokenInId] -= amount;

            _checkAmount(amount);
            amountIn = _getAmountIn(pair, flags, amount);
            balances[tokenOutId] += amountIn;
            _checkAmount(amountIn);

            amountsIn[--i] = amountIn;

            unchecked {
                total += amountIn - amount;
            }
        }

        amountIn = balances[0];
        if (total != amountIn) revert RouterLogic__ExcessBalanceUnused();

        return (amountIn, amountsIn);
    }

    function _swapExactInSingle(
        bytes calldata route,
        uint256[] memory balances,
        address from,
        address to,
        bytes32 value
    ) private returns (uint256) {
        (address pair, uint256 percent, uint256 flags, uint256 tokenInId, uint256 tokenOutId) =
            PackedRoute.decode(value);

        uint256 amountIn = balances[tokenInId] * percent / BPS;
        balances[tokenInId] -= amountIn;

        (address tokenIn, uint256 actualAmountIn) =
            _transfer(route, tokenInId, from, Flags.callback(flags) ? address(this) : pair, amountIn);

        address recipient = tokenOutId == balances.length - 1 ? to : address(this);

        _checkAmount(actualAmountIn);
        uint256 amountOut = _swap(pair, tokenIn, actualAmountIn, recipient, flags);
        _checkAmount(amountOut);

        balances[tokenOutId] += amountOut;

        unchecked {
            return amountOut - amountIn;
        }
    }

    function _swapExactOutSingle(
        bytes calldata route,
        uint256 nbTokens,
        address from,
        address to,
        bytes32 value,
        uint256 amountIn
    ) private {
        (address pair,, uint256 flags, uint256 tokenInId, uint256 tokenOutId) = PackedRoute.decode(value);

        (address tokenIn, uint256 actualAmountIn) =
            _transfer(route, tokenInId, from, Flags.callback(flags) ? address(this) : pair, amountIn);

        address recipient = tokenOutId == nbTokens - 1 ? to : address(this);

        _swap(pair, tokenIn, actualAmountIn, recipient, flags);
    }

    function _transfer(bytes calldata route, uint256 tokenId, address from, address to, uint256 amount)
        private
        returns (address, uint256)
    {
        address token = PackedRoute.token(route, tokenId);

        if (tokenId == 0) {
            bool isTransferTax = PackedRoute.isTransferTax(route);

            uint256 balance = isTransferTax ? TokenLib.balanceOf(token, to) : 0;
            RouterLib.transfer(_router, token, from, to, amount); // todo change name?
            amount = isTransferTax ? TokenLib.balanceOf(token, to) - balance : amount;
        } else if (to != address(this)) {
            TokenLib.transfer(token, to, amount);
        }

        return (token, amount);
    }
}
