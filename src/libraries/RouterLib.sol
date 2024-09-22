// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./TokenLib.sol";

library RouterLib {
    error RouterLib__ZeroAmount();
    error RouterLib__InsufficientAllowance(uint256 allowance, uint256 amount);
    error RouterLib__LogicNotSet();

    function getAllowanceSlot(
        mapping(bytes32 key => uint256) storage allowances,
        address token,
        address sender,
        address from
    ) internal pure returns (bytes32 s) {
        assembly {
            mstore(0, shl(96, token))
            mstore(20, shl(96, sender))
            mstore(40, shl(96, from)) // Overwrite the last 8 bytes of the free memory pointer with zero, which should always be zeros

            let key := keccak256(0, 60)

            mstore(0, allowances.slot)
            mstore(32, key)

            s := keccak256(0, 64)
        }
    }

    function validateAndTransfer(mapping(bytes32 key => uint256) storage allowances) internal {
        address token;
        address from;
        address to;
        uint256 amount;
        uint256 allowance;

        uint256 success;
        assembly {
            token := shr(96, calldataload(0))
            from := shr(96, calldataload(20))
            to := shr(96, calldataload(40))
            amount := calldataload(60)
        }

        bytes32 allowanceSlot = getAllowanceSlot(allowances, token, msg.sender, from);

        assembly {
            allowance := sload(allowanceSlot)

            if iszero(lt(allowance, amount)) {
                success := 1

                sstore(allowanceSlot, sub(allowance, amount))
            }
        }

        if (amount == 0) revert RouterLib__ZeroAmount(); // Also prevent calldata <= 60
        if (success == 0) revert RouterLib__InsufficientAllowance(allowance, amount);

        from == address(this) ? TokenLib.transfer(token, to, amount) : TokenLib.transferFrom(token, from, to, amount);
    }

    function transfer(address router, address token, address from, address to, uint256 amount) internal {
        assembly {
            let m0x40 := mload(0x40)

            mstore(0, shl(96, token))
            mstore(20, shl(96, from))
            mstore(40, shl(96, to))
            mstore(60, amount)

            if iszero(call(gas(), router, 0, 0, 92, 0, 0)) {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }

            mstore(0x40, m0x40)
        }
    }
    function swap(
        mapping(bytes32 key => uint256) storage allowances,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        address from,
        address to,
        bytes calldata routes,
        bool exactIn,
        address logic
    ) internal returns (uint256 totalIn, uint256 totalOut) {
        if (logic == address(0)) revert RouterLib__LogicNotSet();

        bytes32 allowanceSlot = getAllowanceSlot(allowances, tokenIn, logic, from);

        uint256 length = 256 + routes.length; // 32 * 6 + 32 + 32 + routes.length
        bytes memory data = new bytes(length);

        assembly {
            sstore(allowanceSlot, amountIn)

            switch exactIn
            // swapExactIn(tokenIn, tokenOut, amountIn, amountOut, from, to, routes)
            // swapExactOut(tokenIn, tokenOut, amountOut, amountIn, from, to, routes)
            case 1 { mstore(data, 0xbd084435) }
            default { mstore(data, 0xcb7e0007) }

            mstore(add(data, 32), tokenIn)
            mstore(add(data, 64), tokenOut)
            mstore(add(data, 96), amountIn)
            mstore(add(data, 128), amountOut)
            mstore(add(data, 160), from)
            mstore(add(data, 192), to)
            mstore(add(data, 224), 224) // 32 * 6 + 32
            mstore(add(data, 256), routes.length)
            calldatacopy(add(data, 288), routes.offset, routes.length)

            if iszero(call(gas(), logic, 0, add(data, 28), add(length, 4), 0, 64)) {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }

            totalIn := mload(0)
            totalOut := mload(32)

            sstore(allowanceSlot, 0)
        }
    }
}
