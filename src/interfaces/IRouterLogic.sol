// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IRouterLogic {
    error RouterLogic__OnlyRouter();
    error RouterLogic__InvalidTokenIn();
    error RouterLogic__InvalidTokenOut();
    error RouterLogic__InvalidRouter();
    error RouterLogic__ExcessBalanceUnused();
    error RouterLogic__InvalidAmount();
    error RouterLogic__ZeroSwap();
    error RouterLogic__InsufficientTokens();
    error RouterLogic__ExceedsMaxAmountIn(uint256 amountIn, uint256 amountInMax);
    error RouterLogic__InsufficientAmountOut(uint256 amountOut, uint256 amountOutMin);
    error RouterLogic__TransferTaxNotSupported();

    function swapExactIn(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOutMin,
        address from,
        address to,
        bytes calldata routes
    ) external returns (uint256 totalIn, uint256 totalOut);

    function swapExactOut(
        address tokenIn,
        address tokenOut,
        uint256 amountInMax,
        uint256 amountOut,
        address from,
        address to,
        bytes calldata routes
    ) external payable returns (uint256 totalIn, uint256 totalOut);
}
