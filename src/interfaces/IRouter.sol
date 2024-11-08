// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IRouter {
    error Router__DeadlineExceeded();
    error Router__InsufficientOutputAmount(uint256 outputAmount, uint256 minOutputAmount);
    error Router__InsufficientAmountReceived(uint256 balanceBefore, uint256 balanceAfter, uint256 amountOutMin);
    error Router__InvalidTo();
    error Router__ZeroAmount();
    error Router__OnlyWnative();
    error Router__InvalidWnative();
    error Router__IdenticalTokens();
    error Router__LogicAlreadyAdded(address routerLogic);
    error Router__LogicNotFound(address routerLogic);
    error Router__UntrustedLogic(address routerLogic);
    error Router__Simulations(uint256[] amounts);
    error Router__SimulateSingle(uint256 amount);

    event SwapExactIn(
        address indexed sender, address to, address tokenIn, address tokenOut, uint256 amountIn, uint256 amountOut
    );
    event SwapExactOut(
        address indexed sender, address to, address tokenIn, address tokenOut, uint256 amountIn, uint256 amountOut
    );
    event RouterLogicUpdated(address indexed routerLogic, bool added);

    function WNATIVE() external view returns (address);
    function getTrustedLogicAt(uint256 index) external view returns (address);
    function getTrustedLogicLength() external view returns (uint256);
    function updateRouterLogic(address routerLogic, bool added) external;
    function swapExactIn(
        address logic,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOutMin,
        address to,
        uint256 deadline,
        bytes memory route
    ) external payable returns (uint256, uint256);
    function swapExactOut(
        address logic,
        address tokenIn,
        address tokenOut,
        uint256 amountOut,
        uint256 amountInMax,
        address to,
        uint256 deadline,
        bytes memory route
    ) external payable returns (uint256, uint256);
    function simulate(
        address logic,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        bool exactIn,
        bytes[] calldata route
    ) external payable;
    function simulateSingle(
        address logic,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        bool exactIn,
        bytes calldata route
    ) external payable;
}
