// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IRouterLogic {
    function swapExactIn(
        address tokenIn,
        address tokenOut,
        address from,
        address to,
        uint256 amountIn,
        uint256 amountOutMin,
        bytes calldata routes
    ) external returns (uint256 totalIn, uint256 totalOut);

    function swapExactOut(
        address tokenIn,
        address tokenOut,
        address from,
        address to,
        uint256 amountInMax,
        uint256 amountOut,
        bytes calldata routes
    ) external payable returns (uint256 totalIn, uint256 totalOut);
}
