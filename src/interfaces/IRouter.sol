// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IRouter {
    error Router__DeadlineExceeded();
    error Router__LogicNotSet();
    error Router__InsufficientAllowance(uint256 allowance, uint256 amount);
    error Router__InsufficientOutputAmount(uint256 outputAmount, uint256 minOutputAmount);
    error Router__InsufficientAmountReceived(uint256 balanceBefore, uint256 balanceAfter, uint256 amountOutMin);
    error Router__InvalidTotalIn(uint256 amountIn, uint256 expectedAmountIn);
    error Router__MaxAmountInExceeded(uint256 amountIn, uint256 maxAmountIn);
    error Router__InvalidTo();
    error Router__NativeTransferFailed();
    error Router__ZeroAmountIn();
    error Router__ZeroAmountOut();
    error Router__ZeroAmount();
    error Router__OnlyWnative();

    event SwapExactIn(
        address indexed sender, address to, address tokenIn, address tokenOut, uint256 amountIn, uint256 amountOut
    );
    event SwapExactOut(
        address indexed sender, address to, address tokenIn, address tokenOut, uint256 amountIn, uint256 amountOut
    );
    event RouterLogicUpdated(address indexed routerLogic);

    function WNATIVE() external view returns (address);
    function swapExactIn(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOutMin,
        address to,
        uint256 deadline,
        bytes memory routes
    ) external payable returns (uint256, uint256);
    function swapExactOut(
        address tokenIn,
        address tokenOut,
        uint256 amountOut,
        uint256 amountInMax,
        address to,
        uint256 deadline,
        bytes memory routes
    ) external payable returns (uint256, uint256);
    function transfer(address token, address from, address to, uint256 amount) external returns (address);
}
