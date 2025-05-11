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
    error RouterLogic__OnlyRouterOwner();
    error RouterLogic__InvalidFeeData();
    error RouterLogic__InvalidFeePercent();
    error RouterLogic__InvalidFeeReceiver();

    event FeeSent(address indexed token, address indexed from, address indexed to, uint256 amount);
    event FeeReceiverSet(address indexed feeReceiver);

    function getFeeReceiver() external view returns (address);

    function swapExactIn(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOutMin,
        address from,
        address to,
        bytes calldata route
    ) external returns (uint256 totalIn, uint256 totalOut);

    function swapExactOut(
        address tokenIn,
        address tokenOut,
        uint256 amountInMax,
        uint256 amountOut,
        address from,
        address to,
        bytes calldata route
    ) external returns (uint256 totalIn, uint256 totalOut);

    function sweep(address token, address to, uint256 amount) external;

    function setFeeReceiver(address feeReceiver) external;
}
