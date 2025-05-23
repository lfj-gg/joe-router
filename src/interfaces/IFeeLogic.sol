// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IFeeLogic {
    error FeeLogic__InvalidProtocolFeeReceiver();
    error FeeLogic__InvalidProtocolFeeShare();
    error FeeLogic__InvalidFeeReceiver();
    error FeeLogic__InvalidFrom();

    event ProtocolFeeParametersSet(
        address indexed sender, address indexed protocolFeeReceiver, uint96 protocolFeeShare
    );
    event FeeSent(address indexed token, address indexed feeRecipient, uint256 feeAmount, uint256 protocolFeeAmount);

    function getProtocolFeeRecipient() external view returns (address);

    function getProtocolFeeShare() external view returns (uint256);

    function setProtocolFeeParameters(address feeReceiver, uint96 feeShare) external;
}
