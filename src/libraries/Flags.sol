// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// flags = [zeroForOne? | callback? | transferTaxToken? | (id >> 16)]
// Each flag is a bit in the flags variable
// The id is the last 16 bits of the flags variable
library Flags {
    uint256 internal constant ZERO_FOR_ONE = 1;
    uint256 internal constant CALLBACK = 2;
    uint256 internal constant TRANSFER_TAX_TOKEN = 4;
    uint256 internal constant ID_OFFSET = 16;
    uint256 internal constant ID_MASK = 0xffff;

    uint256 internal constant UNISWAP_V2_ID = 1;
    uint256 internal constant TRADERJOE_LB0_ID = 2;
    uint256 internal constant TRADERJOE_LB12_ID = 3; // v2.1 and v2.2 have the same ABI for swaps
    uint256 internal constant UNISWAP_V3_ID = 4;

    function id(uint256 flags) internal pure returns (uint256 idx) {
        return (flags >> ID_OFFSET) & ID_MASK;
    }

    function zeroForOne(uint256 flags) internal pure returns (bool) {
        return flags & ZERO_FOR_ONE == ZERO_FOR_ONE;
    }

    function callback(uint256 flags) internal pure returns (bool) {
        return flags & CALLBACK == CALLBACK;
    }

    function transferTaxToken(uint256 flags) internal pure returns (bool) {
        return flags & TRANSFER_TAX_TOKEN == TRANSFER_TAX_TOKEN;
    }
}
