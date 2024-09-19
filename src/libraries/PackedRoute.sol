// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title RouteDecoder
 * @dev Helper library to decode packed route data
 * Route data is a byte array following the format:
 * [nb tokens]
 * [isTransferTax, token0, token1, token2, ..., tokenN-1, tokenN]
 * [{pairAB, percentAB, flagsAB, tokenA_id, tokenB_id}, {pairBC, percentBC, flagsBC, tokenB_id, tokenC_id}, ...]
 *
 * The number of tokens is encoded on the first byte, it must be less or equal to 255.
 * The isTransferTax is a boolean flag that indicates if the token0 is a transfer tax token.
 * The tokens are encoded as 20 bytes addresses.
 *     The token0 must be the tokenIn and the tokenN must be the tokenOut.
 * The pairs are encoded as 20 bytes addresses.
 * The percent is a 16 bits unsigned integer, it must be less or equal to 10 000 (100%).
 *     It represents the percentage of the remaining amount use for the swap. Therefore, the last swap must be 100%.
 *     Thus, the sum of all percents will exceed 100% if there are more than 1 swap.
 * The flags are encoded as 16 bits unsigned integer. They contain the dex id and information for the swap. See the
 *     Flags library for more information.
 * The token ids are encoded as 8 bits unsigned integer. They must match the id of the token in the token list.
 * All the values are packed in a bytes array each time using the least amount of bytes possible (in solidity, use abi.encodePacked).
 *
 * Example:
 *
 *                          WETH
 *                  0.8       |     0.2
 *                   -----------------
 *                   |               |
 *         UNIV3-WETH/WAVAX     LB2.1-WETH/USDC
 *                   |               |
 *                 WAVAX             |
 *            0.3    |      0.7      |
 *            -----------------      |
 *            |               |      |
 *            |    UNIV2-WAVAX/USDC  |
 *            |               |      |
 *            |               --------
 *            |                    |
 *            |                  USDC
 * LB2.0-WAVAX/USDT         0.4    |     0.6
 *            |              --------------
 *            |              |            |
 *            |              |   UNIV3-BTC/USDC
 *            |              |            |
 *            |              |           BTC
 *            |    LB2.2-USDC/USDT        |
 *            |              |   UNIV2-BTC/USDT
 *            |              |            |
 *            -----------------------------
 *                           |
 *                          USDT
 *
 * Encoding:
 * Here:
 *              0     1     2     3     4
 * [5][false, WETH, WAVAX, USDC, BTC, USDT] // 5 tokens, WETH is not a transfer tax token
 * {UNIV3-WETH/WAVAX,  8000, UNIV3_ID | CALLBACK | ZERO_FOR_ONE, 0, 1}
 * {LB2.1-WETH/USDC,  10000,            LB2_1_ID | ZERO_FOR_ONE, 0, 2}
 * {UNIV2-WAVAX/USDC,  7000,            UNIV2_ID | ZERO_FOR_ONE, 1, 2}
 * {UNIV3-BTC/USDC,    6000, UNIV3_ID | CALLBACK | ZERO_FOR_ONE, 1, 3}
 * {UNIV2-BTC/USDT,   10000,            UNIV2_ID | ZERO_FOR_ONE, 3, 4}
 * {LB2.2-WAVAX/USDT, 10000,            LB2_0_ID | ONE_FOR_ZERO, 1, 4}
 * {LB2.1-USDC/USDT,  10000,            LB2_2_ID | ONE_FOR_ZERO, 2, 4}
 */
library PackedRoute {
    error PackedRoute__InvalidLength();

    uint256 internal constant IS_TRANSFER_TAX_OFFSET = 1;
    uint256 internal constant TOKENS_OFFSET = 2;
    uint256 internal constant ROUTE_SIZE = 26;
    uint256 internal constant ADDRESS_SIZE = 20;

    uint256 internal constant IS_TRANSFER_TAX_SHIFT = 248;
    uint256 internal constant ADDRESS_SHIFT = 96;
    uint256 internal constant PERCENT_SHIFT = 80;
    uint256 internal constant FLAGS_SHIFT = 64;
    uint256 internal constant TOKEN_IN_SHIFT = 56;
    uint256 internal constant TOKEN_OUT_SHIFT = 48;
    uint256 internal constant UINT16_MASK = 0xffff;
    uint256 internal constant UINT8_MASK = 0xff;

    function isTransferTax(bytes calldata route) internal pure returns (bool b) {
        assembly {
            b := iszero(iszero(shr(IS_TRANSFER_TAX_SHIFT, calldataload(add(route.offset, IS_TRANSFER_TAX_OFFSET)))))
        }
    }

    function token(bytes calldata route, uint256 id) internal pure returns (address t) {
        assembly {
            t := shr(ADDRESS_SHIFT, calldataload(add(route.offset, add(TOKENS_OFFSET, mul(id, ADDRESS_SIZE)))))
        }
    }

    function start(bytes calldata route) internal pure returns (uint256 ptr, uint256 nbTokens, uint256 nbSwaps) {
        assembly {
            nbTokens := shr(248, calldataload(route.offset))
        }

        unchecked {
            uint256 length = route.length;

            ptr = TOKENS_OFFSET + nbTokens * ADDRESS_SIZE;
            uint256 swapLength = length - ptr;

            nbSwaps = swapLength / ROUTE_SIZE;
            if (length < ptr || swapLength % ROUTE_SIZE != 0) revert PackedRoute__InvalidLength();
        }
    }

    function next(bytes calldata route, uint256 ptr) internal pure returns (uint256 nextPtr, bytes32 value) {
        assembly {
            value := calldataload(add(route.offset, ptr))
            nextPtr := add(ptr, ROUTE_SIZE)
        }
    }

    function previous(bytes calldata route, uint256 ptr) internal pure returns (uint256 previousPtr, bytes32 value) {
        assembly {
            previousPtr := sub(ptr, ROUTE_SIZE)
            value := calldataload(add(route.offset, previousPtr))
        }
    }

    function decode(bytes32 value)
        internal
        pure
        returns (address pair, uint256 percent, uint256 flags, uint256 tokenInId, uint256 tokenOutId)
    {
        assembly {
            pair := shr(ADDRESS_SHIFT, value)
            percent := and(shr(PERCENT_SHIFT, value), UINT16_MASK)
            flags := and(shr(FLAGS_SHIFT, value), UINT16_MASK)
            tokenInId := and(shr(TOKEN_IN_SHIFT, value), UINT8_MASK)
            tokenOutId := and(shr(TOKEN_OUT_SHIFT, value), UINT8_MASK)
        }
    }
}
