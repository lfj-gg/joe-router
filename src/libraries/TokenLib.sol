// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title TokenLib
 * @dev Helper library for token operations, such as balanceOf, transfer, transferFrom, wrap, and unwrap.
 */
library TokenLib {
    error TokenLib__BalanceOfFailed();
    error TokenLib__WrapFailed();
    error TokenLib__UnwrapFailed();
    error TokenLib__NativeTransferFailed();
    error TokenLib__TransferFromFailed();
    error TokenLib__TransferFailed();

    /**
     * @dev Returns the balance of a token for an account.
     *
     * Requirements:
     * - The call must succeed.
     * - The target contract must return at least 32 bytes.
     */
    function balanceOf(address token, address account) internal view returns (uint256 amount) {
        uint256 success;
        uint256 returnDataSize;

        assembly ("memory-safe") {
            mstore(0, 0x70a08231) // balanceOf(address)
            mstore(32, account)

            success := staticcall(gas(), token, 28, 36, 0, 32)

            returnDataSize := returndatasize()

            amount := mload(0)
        }

        if (success == 0) _tryRevertWithReason();

        // If call failed, and it didn't already bubble up the revert reason, then the return data size must be 0,
        // which will revert here with a generic error message
        if (returnDataSize < 32) revert TokenLib__BalanceOfFailed();
    }

    /**
     * @dev Returns the balance of a token for an account, or the native balance of the account if the token is the native token.
     *
     * Requirements:
     * - The call must succeed (if the token is not the native token).
     * - The target contract must return at least 32 bytes (if the token is not the native token).
     */
    function universalBalanceOf(address token, address account) internal view returns (uint256 amount) {
        return token == address(0) ? account.balance : balanceOf(token, account);
    }

    /**
     * @dev Transfers native tokens to an account.
     *
     * Requirements:
     * - The call must succeed.
     */
    function transferNative(address to, uint256 amount) internal {
        uint256 success;

        assembly ("memory-safe") {
            success := call(gas(), to, amount, 0, 0, 0, 0)
        }

        if (success == 0) {
            _tryRevertWithReason();
            revert TokenLib__NativeTransferFailed();
        }
    }

    /**
     * @dev Transfers tokens from an account to another account.
     * This function does not check if the target contract has code, this should be done before calling this function
     *
     * Requirements:
     * - The call must succeed.
     */
    function wrap(address wnative, uint256 amount) internal {
        uint256 success;

        assembly ("memory-safe") {
            mstore(0, 0xd0e30db0) // deposit()

            success := call(gas(), wnative, amount, 28, 4, 0, 0)
        }

        if (success == 0) {
            _tryRevertWithReason();
            revert TokenLib__WrapFailed();
        }
    }

    /**
     * @dev Transfers tokens from an account to another account.
     * This function does not check if the target contract has code, this should be done before calling this function
     *
     * Requirements:
     * - The call must succeed.
     */
    function unwrap(address wnative, uint256 amount) internal {
        uint256 success;

        assembly ("memory-safe") {
            mstore(0, 0x2e1a7d4d) // withdraw(uint256)
            mstore(32, amount)

            success := call(gas(), wnative, 0, 28, 36, 0, 0)
        }

        if (success == 0) {
            _tryRevertWithReason();
            revert TokenLib__UnwrapFailed();
        }
    }

    /**
     * @dev Transfers tokens from an account to another account.
     *
     * Requirements:
     * - The call must succeed
     * - The target contract must either return true or no value.
     * - The target contract must have code.
     */
    function transfer(address token, address to, uint256 amount) internal {
        uint256 success;
        uint256 returnSize;
        uint256 returnValue;

        assembly ("memory-safe") {
            let m0x40 := mload(0x40)

            mstore(0, 0xa9059cbb) // transfer(address,uint256)
            mstore(32, to)
            mstore(64, amount)

            success := call(gas(), token, 0, 28, 68, 0, 32)

            returnSize := returndatasize()
            returnValue := mload(0)

            mstore(0x40, m0x40)
        }

        if (success == 0) {
            _tryRevertWithReason();
            revert TokenLib__TransferFailed();
        }

        if (returnSize == 0 ? address(token).code.length == 0 : returnValue != 1) revert TokenLib__TransferFailed();
    }

    /**
     * @dev Transfers tokens from an account to another account.
     *
     * Requirements:
     * - The call must succeed.
     * - The target contract must either return true or no value.
     * - The target contract must have code.
     */
    function transferFrom(address token, address from, address to, uint256 amount) internal {
        uint256 success;
        uint256 returnSize;
        uint256 returnValue;

        assembly ("memory-safe") {
            let m0x40 := mload(0x40)
            let m0x60 := mload(0x60)

            mstore(0, 0x23b872dd) // transferFrom(address,address,uint256)
            mstore(32, from)
            mstore(64, to)
            mstore(96, amount)

            success := call(gas(), token, 0, 28, 100, 0, 32)

            returnSize := returndatasize()
            returnValue := mload(0)

            mstore(0x40, m0x40)
            mstore(0x60, m0x60)
        }

        if (success == 0) {
            _tryRevertWithReason();
            revert TokenLib__TransferFromFailed();
        }

        if (returnSize == 0 ? address(token).code.length == 0 : returnValue != 1) revert TokenLib__TransferFromFailed();
    }

    /**
     * @dev Tries to bubble up the revert reason.
     * This function needs to be called only if the call has failed, and will revert if there is a revert reason.
     * This function might no revert if there is no revert reason, always use it in conjunction with a revert.
     */
    function _tryRevertWithReason() private pure {
        assembly ("memory-safe") {
            if returndatasize() {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }
        }
    }
}
