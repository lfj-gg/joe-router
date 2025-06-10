// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {FeeLogic} from "./FeeLogic.sol";
import {RouterAdapter} from "./RouterAdapter.sol";
import {IRouterLogic} from "./interfaces/IRouterLogic.sol";
import {Flags} from "./libraries/Flags.sol";
import {PackedRoute} from "./libraries/PackedRoute.sol";
import {RouterLib} from "./libraries/RouterLib.sol";
import {TokenLib} from "./libraries/TokenLib.sol";

/**
 * @title RouterLogic
 * @notice Router logic contract for swapping tokens using a route.
 * The route must follow the PackedRoute format.
 */
contract RouterLogic is FeeLogic, RouterAdapter, IRouterLogic {
    address private immutable _router;

    /**
     * @dev Constructor for the RouterLogic contract.
     *
     * Requirements:
     * - The router address must be a contract with code.
     * - The fee receiver address must not be the zero address.
     */
    constructor(address router, address routerV2_0, address feeReceiver, uint96 feeShare)
        RouterAdapter(routerV2_0)
        FeeLogic(feeReceiver, feeShare)
    {
        if (router.code.length == 0) revert RouterLogic__InvalidRouter();
        _router = router;
    }

    /**
     * @dev Swaps an exact amount of tokenIn for as much tokenOut as possible.
     *
     * Requirements:
     * - The caller must be the router.
     * - The route must be a valid route, following the PackedRoute format.
     * - The route must have at least two tokens.
     * - The route must have at least one swap.
     * - The tokenIn must be the first token in the route.
     * - The tokenOut must be the last token in the route.
     * - Each swap amountIn and amountOut must be greater than zero and less than 2^128.
     * - The entire balance of all tokens must have been swapped to the last token.
     * - The actual amountOut must be greater than or equal to the amountOutMin.
     * - If the route has a fee, it should be the first route and the data must use the valid format:
     *   `(feeRecipient, feePercent, Flags.FEE_ID, 0, 0)`
     */
    function swapExactIn(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOutMin,
        address from,
        address to,
        bytes calldata route
    ) external override returns (uint256, uint256) {
        (uint256 feePtr, uint256 ptr, uint256 nbTokens, uint256 nbSwaps) = _startAndVerify(route, tokenIn, tokenOut);

        (address feeToken, address feeRecipient, uint256 feePercent) = _getFeePercent(route, feePtr, nbTokens);

        uint256 amountInWithoutFee = amountIn;
        if (feeToken == tokenIn) {
            unchecked {
                uint256 feeAmount = (amountIn * feePercent) / BPS;
                amountInWithoutFee -= feeAmount;
                _sendFee(feeToken, from, from, feeRecipient, feeAmount);
            }
        }

        uint256[] memory balances = new uint256[](nbTokens);

        balances[0] = amountInWithoutFee;
        uint256 total = amountInWithoutFee;

        bytes32 value;
        address recipient = feeToken == tokenOut ? address(this) : to;
        for (uint256 i; i < nbSwaps; i++) {
            (ptr, value) = PackedRoute.next(route, ptr);

            unchecked {
                total += _swapExactInSingle(route, balances, from, recipient, value);
            }
        }

        uint256 amountOut = balances[nbTokens - 1];
        if (total != amountOut) revert RouterLogic__ExcessBalanceUnused();

        if (feeToken == tokenOut) {
            unchecked {
                uint256 feeAmount = (amountOut * feePercent) / BPS;
                amountOut -= feeAmount;
                _sendFee(feeToken, address(this), from, feeRecipient, feeAmount);
                TokenLib.transfer(tokenOut, to, amountOut);
            }
        }

        if (amountOut < amountOutMin) revert RouterLogic__InsufficientAmountOut(amountOut, amountOutMin);

        return (amountIn, amountOut);
    }

    /**
     * @dev Swaps an exact amount of tokenOut for as little tokenIn as possible.
     * Due to roundings, the actual amountOut might actually be greater than the amountOut.
     *
     * Requirements:
     * - The caller must be the router.
     * - The route must be a valid route, following the PackedRoute format.
     * - The route must have at least two tokens.
     * - The route must have at least one swap.
     * - The tokenIn must be the first token in the route.
     * - The tokenOut must be the last token in the route.
     * - Each swap amountIn and amountOut must be greater than zero and less than 2^128.
     * - The entire balance of all tokens must have been used to calculate the amountIn.
     *   (due to potential rounding, some dust might be left in the contract after the swap)
     * - The actual amountIn must be less than or equal to the amountInMax.
     * - If the route has a fee, it should be the first route and the data must use the valid format:
     *   `(feeRecipient, feePercent, Flags.FEE_ID, 0, 0)`
     */
    function swapExactOut(
        address tokenIn,
        address tokenOut,
        uint256 amountInMax,
        uint256 amountOut,
        address from,
        address to,
        bytes calldata route
    ) external override returns (uint256 totalIn, uint256 totalOut) {
        (uint256 feePtr, uint256 ptr, uint256 nbTokens, uint256 nbSwaps) = _startAndVerify(route, tokenIn, tokenOut);

        if (PackedRoute.isTransferTax(route)) revert RouterLogic__TransferTaxNotSupported();

        (address feeToken, address feeRecipient, uint256 feePercent) = _getFeePercent(route, feePtr, nbTokens);

        address recipient;
        uint256 amountOutWithFee = amountOut;
        if (feeToken == tokenOut) {
            recipient = address(this);
            unchecked {
                amountOutWithFee = amountOutWithFee * BPS / (BPS - feePercent);
            }
        } else {
            recipient = to;
        }

        (uint256 amountInWithFee, uint256[] memory amountsIn) =
            _getAmountsIn(route, amountOutWithFee, nbTokens, nbSwaps);

        if (feeToken == tokenIn) {
            unchecked {
                uint256 feeAmount = amountInWithFee * feePercent / (BPS - feePercent);
                amountInWithFee += feeAmount;
                _sendFee(tokenIn, from, from, feeRecipient, feeAmount);
            }
        }

        if (amountInWithFee > amountInMax) revert RouterLogic__ExceedsMaxAmountIn(amountInWithFee, amountInMax);

        bytes32 value;
        for (uint256 i; i < nbSwaps; i++) {
            (ptr, value) = PackedRoute.next(route, ptr);

            _swapExactOutSingle(route, nbTokens, from, recipient, value, amountsIn[i]);
        }

        if (feeToken == tokenOut) {
            unchecked {
                uint256 feeAmount = amountOutWithFee - amountOut;
                _sendFee(feeToken, address(this), from, feeRecipient, feeAmount);
                TokenLib.transfer(tokenOut, to, amountOut);
            }
        }

        return (amountInWithFee, amountOut);
    }

    /**
     * @dev Sweeps tokens from the contract to the recipient.
     *
     * Requirements:
     * - The caller must be the router owner.
     */
    function sweep(address token, address to, uint256 amount) external override {
        _checkSender();

        token == address(0) ? TokenLib.transferNative(to, amount) : TokenLib.transfer(token, to, amount);
    }

    /**
     * @dev Checks if the sender is the router's owner.
     *
     * Requirements:
     * - The sender must be the router's owner.
     */
    function _checkSender() internal view override {
        if (msg.sender != Ownable(_router).owner()) revert RouterLogic__OnlyRouterOwner();
    }

    /**
     * @dev Helper function to check if the amount is valid.
     *
     * Requirements:
     * - The amount must be greater than zero and less than 2^128.
     */
    function _checkAmount(uint256 amount) private pure {
        if (amount == 0 || amount > type(uint128).max) revert RouterLogic__InvalidAmount();
    }

    /**
     * @dev Helper function to start and verify the route.
     *
     * Requirements:
     * - The caller must be the router.
     * - The route must have at least two tokens.
     * - The route must have at least one swap.
     * - The tokenIn must be the first token in the route.
     * - The tokenOut must be the last token in the route.
     */
    function _startAndVerify(bytes calldata route, address tokenIn, address tokenOut)
        private
        view
        returns (uint256 feePtr, uint256 ptr, uint256 nbTokens, uint256 nbSwaps)
    {
        if (msg.sender != _router) revert RouterLogic__OnlyRouter();

        (ptr, nbTokens, nbSwaps) = PackedRoute.start(route);

        if (nbTokens < 2) revert RouterLogic__InsufficientTokens();

        (uint256 nextPtr, bytes32 value) = PackedRoute.next(route, ptr);
        uint256 flags = PackedRoute.getFlags(value);

        if (Flags.id(flags) == Flags.FEE_ID) {
            if (nbSwaps < 2) revert RouterLogic__ZeroSwap();
            unchecked {
                --nbSwaps;
            }
            feePtr = ptr;
            ptr = nextPtr;
        } else {
            if (nbSwaps == 0) revert RouterLogic__ZeroSwap();
        }

        if (PackedRoute.token(route, 0) != tokenIn) revert RouterLogic__InvalidTokenIn();
        if (PackedRoute.token(route, nbTokens - 1) != tokenOut) revert RouterLogic__InvalidTokenOut();
    }

    /**
     * @dev Returns the fee amount added on the swap.
     * The fee is calculated as follows:
     * - if `isSwapExactIn`, the fee is calculated as `(amountIn * feePercent) / BPS`
     *   else, the fee is calculated as `(amountIn * BPS) / (BPS - feePercent)`
     *
     * Requirements:
     * - The data must use the valid format:
     *   - If the fee is in tokenIn, `(feeRecipient, feePercent, Flags.FEE_ID, 0, 0)`
     *   - If the fee is in tokenOut, `(feeRecipient, feePercent, Flags.FEE_ID, nbTokens - 1, nbTokens - 1)`
     * - The feePercent must be greater than 0 and less than BPS.
     */
    function _getFeePercent(bytes calldata route, uint256 feePtr, uint256 nbTokens)
        private
        pure
        returns (address feeToken, address feeRecipient, uint256 feePercent)
    {
        if (feePtr > 0) {
            (, bytes32 value) = PackedRoute.next(route, feePtr);

            (address recipient, uint256 percent, uint256 flags, uint256 feeTokenId, uint256 feeTokenId_) =
                PackedRoute.decode(value);

            if ((flags | (feeTokenId ^ feeTokenId_)) != 0 || (feeTokenId != 0 && feeTokenId != nbTokens - 1)) {
                revert RouterLogic__InvalidFeeData();
            }
            if (percent == 0 || percent >= BPS) revert RouterLogic__InvalidFeePercent();

            return (PackedRoute.token(route, feeTokenId), recipient, percent);
        }
    }

    /**
     * @dev Helper function to return the amountIn for each swap in the route and the amountIn of the first token.
     * The function will most likely revert if the same pair is used twice, or if the output of a pair is changed
     * between the calculation and the actual swap (for example, before swap hooks).
     *
     * Requirements:
     * - The route must be a valid route, following the PackedRoute format.
     * - Each swap amountIn and amountOut must be greater than zero and less than 2^128.
     * - The entire balance of all tokens must have been used to calculate the amountIn.
     */
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

    /**
     * @dev Helper function to swap an exact amount of tokenIn for as much tokenOut as possible.
     *
     * Requirements:
     * - The route must be a valid route, following the PackedRoute format.
     * - Each swap amountIn and amountOut must be greater than zero and less than 2^128.
     */
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
            _transferFromTokenId(route, tokenInId, from, Flags.callback(flags) ? address(this) : pair, amountIn);

        address recipient = tokenOutId == balances.length - 1 ? to : address(this);

        _checkAmount(actualAmountIn);
        uint256 amountOut = _swap(pair, tokenIn, actualAmountIn, recipient, flags);
        _checkAmount(amountOut);

        balances[tokenOutId] += amountOut;

        unchecked {
            return amountOut - amountIn;
        }
    }

    /**
     * @dev Helper function to swap an exact amount of tokenOut for as little tokenIn as possible.
     *
     * Requirements:
     * - The route must be a valid route, following the PackedRoute format.
     */
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
            _transferFromTokenId(route, tokenInId, from, Flags.callback(flags) ? address(this) : pair, amountIn);

        address recipient = tokenOutId == nbTokens - 1 ? to : address(this);

        _swap(pair, tokenIn, actualAmountIn, recipient, flags);
    }

    /**
     * @dev Helper function to transfer tokens.
     * If the token is the first token of the route, it will transfer the token from the user to the recipient using
     * the transfer function of the router. If the token is flagged as a transfer tax, it will return the actual amount
     * received by the recipient.
     * Else, it will transfer the token from this contract to the recipient, unless the recipient is this contract.
     *
     * Requirements:
     * - The route must be a valid route, following the PackedRoute format.
     */
    function _transferFromTokenId(bytes calldata route, uint256 tokenId, address from, address to, uint256 amount)
        private
        returns (address, uint256)
    {
        address token = PackedRoute.token(route, tokenId);

        if (tokenId == 0) {
            bool isTransferTax = PackedRoute.isTransferTax(route);

            uint256 balance = isTransferTax ? TokenLib.balanceOf(token, to) : 0;
            RouterLib.transfer(_router, token, from, to, amount);
            amount = isTransferTax ? TokenLib.balanceOf(token, to) - balance : amount;
        } else if (to != address(this)) {
            TokenLib.transfer(token, to, amount);
        }

        return (token, amount);
    }

    /**
     * @dev Helper function to transfer the fee to the fee recipient.
     */
    function _transferFee(address token, address from, address to, uint256 amount) internal override {
        if (from == address(this)) {
            TokenLib.transfer(token, to, amount);
        } else {
            RouterLib.transfer(_router, token, from, to, amount);
        }
    }
}
