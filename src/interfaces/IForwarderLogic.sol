// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IForwarderLogic {
    error ForwarderLogic__InvalidRouter();
    error ForwarderLogic__NotImplemented();
    error ForwarderLogic__OnlyRouterOwner();
    error ForwarderLogic__NoCode();
    error ForwarderLogic__OnlyRouter();

    function swapExactIn(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOutMin,
        address from,
        address to,
        bytes calldata route
    ) external returns (uint256 totalIn, uint256 totalOut);

    function sweep(address token, address to, uint256 amount) external;
}
