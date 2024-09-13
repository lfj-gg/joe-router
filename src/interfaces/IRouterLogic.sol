// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IRouterLogic {
    function swapExactIn(address tokenIn, address tokenOut, address from, address to, bytes[] calldata routes)
        external
        returns (uint256 totalIn, uint256 totalOut);

    function swapExactOut(address tokenIn, address tokenOut, address from, address to, bytes[] calldata routes)
        external
        payable
        returns (uint256 totalIn, uint256 totalOut);
}
