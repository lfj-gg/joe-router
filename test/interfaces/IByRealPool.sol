// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IByRealPool {
    struct OracleData {
        uint256 price; // In 1e9
        uint256 validUntil; // Timestamp
        uint256 unknown0;
        uint256 unknown1;
    }

    // Quote functions
    function getAmountOut(uint256 amountIn, address tokenIn) external view returns (uint256);
    function getAmountIn(uint256 amountOut, address tokenOut) external view returns (uint256);

    // Swap function
    function swap(address token, bool givenIn, uint256 amount, address to) external returns (uint256);

    // Oracle functions
    function getOraclePrice() external view returns (uint256);
    function getOracleValidUntil() external view returns (uint256);
    function getAllOracleData() external view returns (OracleData memory);

    // Pool info
    function token0() external view returns (address);
    function token1() external view returns (address);
    function oracle() external view returns (address);
}
