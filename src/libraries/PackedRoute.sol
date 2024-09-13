// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// [amount, pair01, token1, flags01, pair12, token2, flags02, ..., pairN-1N, tokenN, flagsN-1N]
library PackedRoute {
    error PackedRoute__InvalidLength();

    uint256 internal constant HEADER_SIZE = 16;

    function length(bytes calldata route) internal pure returns (uint256 l) {
        l = route.length / 44;
        if (route.length % 44 != 16) revert PackedRoute__InvalidLength();
    }

    function start(bytes calldata route) internal pure returns (uint256 ptr, uint256 amount) {
        assembly {
            amount := shr(128, calldataload(route.offset))
            ptr := 16
        }
    }

    function next(bytes calldata route, uint256 ptr)
        internal
        pure
        returns (uint256 nextPtr, address pair, address token, uint256 flags)
    {
        (pair, token, flags) = _get(route, ptr);

        unchecked {
            nextPtr = ptr + 44;
        }
    }

    function previous(bytes calldata route, uint256 ptr)
        internal
        pure
        returns (uint256 previousPtr, address pair, address token, uint256 flags)
    {
        unchecked {
            previousPtr = ptr - 44;
        }
        (pair, token, flags) = _get(route, previousPtr);
    }

    function _get(bytes calldata route, uint256 ptr)
        private
        pure
        returns (address pair, address token, uint256 flags)
    {
        assembly {
            pair := shr(96, calldataload(add(route.offset, ptr)))

            let value := calldataload(add(route.offset, add(ptr, 20)))

            token := shr(96, value)
            flags := and(shr(64, value), 0xffffffff)
        }
    }
}
