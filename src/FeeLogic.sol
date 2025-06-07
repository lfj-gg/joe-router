// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IFeeLogic} from "./interfaces/IFeeLogic.sol";
import {TokenLib} from "./libraries/TokenLib.sol";

/**
 * @title FeeLogic
 * @notice This contract handles the fee logic for the router.
 * It allows setting the protocol fee parameters and sending fees to the protocol fee recipient.
 * When sending fees, it splits the fee between the protocol fee recipient and the fee recipient
 * based on the protocol fee share. E.g. if the protocol fee share is 10% and the fee amount is 100,
 * then 10 will be sent to the protocol fee recipient and 90 will be sent to the fee recipient.
 */
abstract contract FeeLogic is IFeeLogic {
    uint256 internal constant BPS = 10_000;

    address private _protocolFeeRecipient;
    uint96 private _protocolFeeShare;

    constructor(address feeReceiver, uint96 feeShare) {
        _setProtocolFeeParameters(feeReceiver, feeShare);
    }

    /**
     * @dev Returns the protocol fee recipient address.
     */
    function getProtocolFeeRecipient() external view override returns (address) {
        return _protocolFeeRecipient;
    }

    /**
     * @dev Returns the protocol fee share.
     */
    function getProtocolFeeShare() external view override returns (uint256) {
        return _protocolFeeShare;
    }

    /**
     * @dev Sets the protocol fee parameters.
     *
     * Requirements:
     * - The caller must be authorized.
     * - The fee receiver address must not be zero.
     * - The fee share must be less than or equal to 10_000 (100%).
     */
    function setProtocolFeeParameters(address feeReceiver, uint96 feeShare) external override {
        _checkSender();
        _setProtocolFeeParameters(feeReceiver, feeShare);
    }

    /**
     * @dev Internal function to set the protocol fee parameters.
     *
     * Requirements:
     * - The fee receiver address must not be zero.
     * - The fee share must be less than or equal to 10_000 (100%).
     */
    function _setProtocolFeeParameters(address protocolFeeReceiver, uint96 protocolFeeShare) internal {
        if (protocolFeeReceiver == address(0)) revert FeeLogic__InvalidProtocolFeeReceiver();
        if (protocolFeeShare > BPS) revert FeeLogic__InvalidProtocolFeeShare();

        _protocolFeeRecipient = protocolFeeReceiver;
        _protocolFeeShare = protocolFeeShare;

        emit ProtocolFeeParametersSet(msg.sender, protocolFeeReceiver, protocolFeeShare);
    }

    /**
     * @dev Internal function to send the fee to the fee recipient.
     * The user parameter is only used for event logging.
     *
     * Requirements:
     * - The fee amount must be greater than zero.
     */
    function _sendFee(address token, address payer, address user, address feeRecipient, uint256 feeAmount) internal {
        if (feeAmount > 0) {
            if (feeRecipient == address(0)) revert FeeLogic__InvalidFeeReceiver();

            uint256 protocolFeeAmount = (feeAmount * _protocolFeeShare) / BPS;
            _transferFee(token, payer, feeRecipient, feeAmount - protocolFeeAmount);
            if (protocolFeeAmount > 0) _transferFee(token, payer, _protocolFeeRecipient, protocolFeeAmount);

            emit FeeSent(token, user, feeRecipient, feeAmount, protocolFeeAmount);
        }
    }

    /**
     * @dev Internal function to transfer tokens from the contract to the recipient.
     *
     * Requirements:
     * - The sender must be the contract itself.
     */
    function _transferFee(address token, address from, address to, uint256 amount) internal virtual {
        if (from != address(this)) revert FeeLogic__InvalidFrom();
        TokenLib.transfer(token, to, amount);
    }

    /**
     * @dev Internal function to check if the sender is authorized.
     * Must be implemented in the derived contract.
     */
    function _checkSender() internal view virtual;
}
