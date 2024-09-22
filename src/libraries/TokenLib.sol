// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library TokenLib {
    error TokenLib__BalanceOfFailed();
    error TokenLib__WrapFailed();
    error TokenLib__UnwrapFailed();
    error TokenLib__NativeTransferFailed();
    error TokenLib__TransferFromFailed();
    error TokenLib__TransferFailed();
    error TokenLib__NoCode(address target);
    error TokenLib__RouterTransferFailed();

    function balanceOf(address token, address account) internal view returns (uint256 amount) {
        uint256 success;
        uint256 returnDataSize;

        assembly {
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
    function universalBalanceOf(address token, address account) internal view returns (uint256 amount) {
        return token == address(0) ? account.balance : balanceOf(token, account);
    }

    function transferNative(address to, uint256 amount) internal {
        uint256 success;

        assembly {
            success := call(gas(), to, amount, 0, 0, 0, 0)
        }

        if (success == 0) {
            _tryRevertWithReason();
            revert TokenLib__NativeTransferFailed();
        }
    }

    function wrap(address wnative, uint256 amount) internal {
        uint256 success;

        assembly {
            mstore(0, 0xd0e30db0) // deposit()

            success := call(gas(), wnative, amount, 28, 4, 0, 0)
        }

        if (success == 0) {
            _tryRevertWithReason();
            revert TokenLib__WrapFailed();
        }
    }

    function unwrap(address wnative, uint256 amount) internal {
        uint256 success;

        assembly {
            mstore(0, 0x2e1a7d4d) // withdraw(uint256)
            mstore(32, amount)

            success := call(gas(), wnative, 0, 28, 36, 0, 0)
        }

        if (success == 0) {
            _tryRevertWithReason();
            revert TokenLib__UnwrapFailed();
        }
    }

    function transfer(address token, address to, uint256 amount) internal {
        uint256 success;
        uint256 returnSize;
        uint256 returnValue;

        assembly {
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

    function transferFrom(address token, address from, address to, uint256 amount) internal {
        uint256 success;
        uint256 returnSize;
        uint256 returnValue;

        assembly {
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

    function _tryRevertWithReason() private pure {
        assembly {
            if returndatasize() {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }
        }
    }

    function _validCall(address target) private view {
        uint256 success = 1;
        assembly {
            if iszero(returndatasize()) { if iszero(extcodesize(target)) { success := 0 } }
        }

        if (success == 0) revert TokenLib__NoCode(target);
    }
}
