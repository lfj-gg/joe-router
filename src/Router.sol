// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable2Step, Ownable} from "@openzeppelin/contracts/access/Ownable2Step.sol";

import {TokenLib} from "./libraries/TokenLib.sol";
import {RouterLib} from "./libraries/RouterLib.sol";
import {IRouter} from "./interfaces/IRouter.sol";

/**
 * @title Router
 * @dev Router contract for swapping tokens using a predefined route.
 * The route must follow the PackedRoute format.
 */
contract Router is Ownable2Step, IRouter {
    address public immutable WNATIVE;

    address private _logic;

    /**
     * @dev The allowances represent the maximum amount of tokens that the logic contract can spend on behalf of the sender.
     * It is always reseted at the end of the swap.
     * The key is calculated as keccak256(abi.encodePacked(token, sender, user)).
     */
    mapping(bytes32 key => uint256 allowance) private _allowances;

    /**
     * @dev Constructor for the Router contract.
     *
     * Requirements:
     * - The wnative address must be a contract with code.
     */
    constructor(address wnative, address initialOwner) Ownable(initialOwner) {
        if (address(wnative).code.length == 0) revert Router__InvalidWnative();

        WNATIVE = wnative;
    }

    /**
     * @dev Only allows native token to be received from unwrapping wnative.
     */
    receive() external payable {
        if (msg.sender != WNATIVE) revert Router__OnlyWnative();
    }

    /**
     * @dev Fallback function to validate and transfer tokens.
     */
    fallback() external {
        RouterLib.validateAndTransfer(_allowances);
    }

    /**
     * @dev Returns the logic contract address.
     */
    function getLogic() external view returns (address) {
        return _logic;
    }

    /**
     * @dev Swaps tokens from the sender to the recipient using the exact input amount.
     *
     * Emits a {SwapExactIn} event.
     *
     * Requirements:
     * - The recipient address must not be zero or the router address.
     * - The deadline must not have passed.
     * - The input token and output token must not be the same.
     * - If the amountIn is zero, the entire balance of the input token will be used and it must not be zero.
     * - The entire amountIn of the input token must be spent.
     * - The actual amount of tokenOut received must be greater than or equal to the amountOutMin.
     */
    function swapExactIn(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOutMin,
        address to,
        uint256 deadline,
        bytes calldata route
    ) external payable returns (uint256 totalIn, uint256 totalOut) {
        if (amountIn == 0) amountIn = tokenIn == address(0) ? msg.value : TokenLib.balanceOf(tokenIn, msg.sender);

        _verifyParameters(tokenIn, tokenOut, amountIn, to, deadline);

        (totalIn, totalOut) = _swap(tokenIn, tokenOut, amountIn, amountOutMin, msg.sender, to, route, true);

        emit SwapExactIn(msg.sender, to, tokenIn, tokenOut, totalIn, totalOut);
    }

    /**
     * @dev Swaps tokens from the sender to the recipient using the exact output amount.
     *
     * Emits a {SwapExactOut} event.
     *
     * Requirements:
     * - The recipient address must not be zero or the router address.
     * - The deadline must not have passed.
     * - The input token and output token must not be the same.
     * - If the amountInMax is zero, the entire balance of the input token will be used and it must not be zero.
     * - The actual amount of tokenIn spent must be less than or equal to the amountInMax.
     * - The actual amount of tokenOut received must be greater than or equal to the amountOut.
     */
    function swapExactOut(
        address tokenIn,
        address tokenOut,
        uint256 amountOut,
        uint256 amountInMax,
        address to,
        uint256 deadline,
        bytes calldata route
    ) external payable returns (uint256 totalIn, uint256 totalOut) {
        _verifyParameters(tokenIn, tokenOut, amountOut, to, deadline);

        (totalIn, totalOut) = _swap(tokenIn, tokenOut, amountInMax, amountOut, msg.sender, to, route, false);

        emit SwapExactOut(msg.sender, to, tokenIn, tokenOut, totalIn, totalOut);
    }

    /**
     * @dev Simulates the swap of tokens using multiple routes.
     * The simulation will revert with an array of amounts if the swap is valid.
     */
    function simulate(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        bool exactIn,
        bytes[] calldata multiRoutes
    ) external payable {
        uint256 length = multiRoutes.length;

        uint256[] memory amounts = new uint256[](length);
        for (uint256 i; i < length;) {
            (, bytes memory data) = address(this).delegatecall(
                abi.encodeWithSelector(
                    IRouter.simulateSingle.selector, tokenIn, tokenOut, amountIn, amountOut, exactIn, multiRoutes[i++]
                )
            );

            if (bytes4(data) == IRouter.Router__SimulateSingle.selector) {
                assembly ("memory-safe") {
                    mstore(add(amounts, mul(i, 32)), mload(add(data, 36)))
                }
            } else {
                amounts[i - 1] = exactIn ? 0 : type(uint256).max;
            }
        }

        revert Router__Simulations(amounts);
    }

    /**
     * @dev Simulates the swap of tokens using a single route.
     * The simulation will revert with the total amount of tokenIn or tokenOut if the swap is valid.
     */
    function simulateSingle(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        bool exactIn,
        bytes calldata route
    ) external payable {
        (uint256 totalIn, uint256 totalOut) =
            _swap(tokenIn, tokenOut, amountIn, amountOut, msg.sender, msg.sender, route, exactIn);

        revert Router__SimulateSingle(exactIn ? totalOut : totalIn);
    }

    /**
     * @dev Updates the logic contract address.
     *
     * Emits a {RouterLogicUpdated} event.
     *
     * Requirements:
     * - The caller must be the owner.
     */
    function updateRouterLogic(address logic) external onlyOwner {
        _logic = logic;

        emit RouterLogicUpdated(logic);
    }

    /**
     * @dev Helper function to verify the input parameters of a swap.
     *
     * Requirements:
     * - The recipient address must not be zero or the router address.
     * - The deadline must not have passed.
     * - The input token and output token must not be the same.
     * - The amount must not be zero.
     */
    function _verifyParameters(address tokenIn, address tokenOut, uint256 amount, address to, uint256 deadline)
        internal
        view
    {
        if (to == address(0) || to == address(this)) revert Router__InvalidTo();
        if (block.timestamp > deadline) revert Router__DeadlineExceeded();
        if (tokenIn == tokenOut) revert Router__IdenticalTokens();
        if (amount == 0) revert Router__ZeroAmount();
    }

    /**
     * @dev Helper function to verify the output of a swap.
     *
     * Requirements:
     * - The actual amount of tokenOut returned by the logic contract must be greater than the amountOutMin.
     * - The actual balance increase of the recipient must be greater than the amountOutMin.
     */
    function _verifySwap(address tokenOut, address to, uint256 balance, uint256 amountOutMin, uint256 amountOut)
        internal
        view
        returns (uint256)
    {
        if (amountOut < amountOutMin) revert Router__InsufficientOutputAmount(amountOut, amountOutMin);

        uint256 balanceAfter = TokenLib.universalBalanceOf(tokenOut, to);

        if (balanceAfter < balance + amountOutMin) {
            revert Router__InsufficientAmountReceived(balance, balanceAfter, amountOutMin);
        }

        unchecked {
            return balanceAfter - balance;
        }
    }

    /**
     * @dev Helper function to call the logic contract to swap tokens.
     * This function will wrap the input token if it is native and unwrap the output token if it is native.
     * It will also refund the sender if there is any excess amount of native token.
     * It will allow the logic contract to spend at most amountIn of the input token from the sender, and reset
     * the allowance after the swap, see {RouterLib.swap}.
     *
     * Requirements:
     * - If the swap is exactIn, the totalIn must be equal to the amountIn.
     * - If the swap is exactOut, the totalIn must be less than or equal to the amountIn.
     */
    function _swap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        address from,
        address to,
        bytes calldata route,
        bool exactIn
    ) internal returns (uint256 totalIn, uint256 totalOut) {
        uint256 balance = TokenLib.universalBalanceOf(tokenOut, to);

        address recipient;
        (recipient, tokenOut) = tokenOut == address(0) ? (address(this), WNATIVE) : (to, tokenOut);

        if (tokenIn == address(0)) {
            tokenIn = WNATIVE;
            from = address(this);
            TokenLib.wrap(WNATIVE, amountIn);
        }

        (totalIn, totalOut) =
            RouterLib.swap(_allowances, tokenIn, tokenOut, amountIn, amountOut, from, recipient, route, exactIn, _logic);

        if (recipient == address(this)) {
            TokenLib.unwrap(WNATIVE, totalOut);
            TokenLib.transferNative(to, totalOut);

            totalOut = _verifySwap(address(0), to, balance, amountOut, totalOut);
        } else {
            totalOut = _verifySwap(tokenOut, to, balance, amountOut, totalOut);
        }

        unchecked {
            uint256 refund;
            if (from == address(this)) {
                uint256 unwrap = amountIn - totalIn;
                if (unwrap > 0) TokenLib.unwrap(WNATIVE, unwrap);

                refund = msg.value + unwrap - amountIn;
            } else {
                refund = msg.value;
            }

            if (refund > 0) TokenLib.transferNative(msg.sender, refund);
        }
    }
}
