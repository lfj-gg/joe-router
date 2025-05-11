// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IForwarderLogic {
    error ForwarderLogic__InvalidRouter();
    error ForwarderLogic__NotImplemented();
    error ForwarderLogic__OnlyRouterOwner();
    error ForwarderLogic__NoCode();
    error ForwarderLogic__OnlyRouter();
    error ForwarderLogic__RouterUpdateFailed();
    error ForwarderLogic__UntrustedRouter();
    error ForwarderLogic__Blacklisted();
    error ForwarderLogic__InvalidFeeReceiver();

    event TrustedRouterUpdated(address indexed router, bool trusted);
    event BlacklistUpdated(address indexed account, bool blacklisted);
    event FeeReceiverSet(address indexed feeReceiver);
    event FeeSent(address indexed token, address indexed from, address indexed to, uint256 amount);

    function getTrustedRouterLength() external view returns (uint256);

    function getTrustedRouterAt(uint256 index) external view returns (address);

    function isBlacklisted(address account) external view returns (bool);

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

    function sweep(address token, address to, uint256 amount) external;

    function updateTrustedRouter(address router, bool add) external;

    function updateBlacklist(address account, bool blacklisted) external;

    function setFeeReceiver(address feeReceiver) external;
}
