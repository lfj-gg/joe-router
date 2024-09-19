// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// flags = [zeroForOne? | callback? | id]
// The zeroForOne flag is the first bit of the flags variable
// The callback flag is the second bit of the flags variable
// The id is the last 8 bits of the flags variable
library Flags {
    uint256 internal constant ZERO_FOR_ONE = 1;
    uint256 internal constant CALLBACK = 2;

    uint256 internal constant ID_OFFSET = 8;
    uint256 internal constant ID_MASK = 0xff00;

    uint256 internal constant UNISWAP_V2_ID = 1 << 8;
    uint256 internal constant TRADERJOE_LEGACY_LB_ID = 2 << 8;
    uint256 internal constant TRADERJOE_LB_ID = 3 << 8; // v2.1 and v2.2 have the same ABI for swaps
    uint256 internal constant UNISWAP_V3_ID = 4 << 8;

    function id(uint256 flags) internal pure returns (uint256 idx) {
        return flags & ID_MASK;
    }

    function zeroForOne(uint256 flags) internal pure returns (bool) {
        return flags & ZERO_FOR_ONE == ZERO_FOR_ONE;
    }

    function callback(uint256 flags) internal pure returns (bool) {
        return flags & CALLBACK == CALLBACK;
    }
}
