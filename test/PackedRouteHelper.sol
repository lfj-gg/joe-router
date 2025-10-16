// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Flags} from "../src/libraries/Flags.sol";
import {PackedRoute} from "../src/libraries/PackedRoute.sol";

abstract contract PackedRouteHelper {
    uint16 public constant ONE_FOR_ZERO = 0;
    uint16 public constant ZERO_FOR_ONE = uint16(Flags.ZERO_FOR_ONE);
    uint16 public constant CALLBACK = uint16(Flags.CALLBACK);
    uint16 public constant TJ1_ID = uint16(Flags.UNISWAP_V2_ID);
    uint16 public constant LB0_ID = uint16(Flags.LFJ_LEGACY_LIQUIDITY_BOOK_ID);
    uint16 public constant LB12_ID = uint16(Flags.LFJ_LIQUIDITY_BOOK_ID);
    uint16 public constant UV3ID = uint16(Flags.UNISWAP_V3_ID);
    uint16 public constant TM_ID = uint16(Flags.LFJ_TOKEN_MILL_ID);
    uint16 public constant TMV2_ID = uint16(Flags.LFJ_TOKEN_MILL_V2_ID);
    uint16 public constant UV4_ID = uint16(Flags.UNISWAP_V4_ID);

    // [fee: 3][tickSpacing: 3][nativeFlag: 1][hooks: 20][hookData length: 3] (3 + 3 + 1 + 20 + 3 = 30)
    uint16 public constant UNISWAP_V4_EXTRA_DATA_SIZE = 30;
    uint8 public constant UV4NATIVE_FLAG_NONE = 0;
    uint8 public constant UV4NATIVE_FLAG_IN = 1;
    uint8 public constant UV4NATIVE_FLAG_OUT = 2;

    mapping(address => uint256) public _tokenToId;

    function test() public pure {} // To avoid this contract to be included in coverage

    function _createRoutes(uint256 nbTokens, uint256 nbSwaps) internal pure returns (bytes memory b, uint256 ptr) {
        (b, ptr,) = _createRoutesWithExtraData(nbTokens, nbSwaps, 0);
    }

    function _createRoutesWithExtraData(uint256 nbTokens, uint256 nbSwaps, uint256 extraDataLength)
        internal
        pure
        returns (bytes memory b, uint256 ptr, uint256 extraDataPtr)
    {
        if (nbTokens > type(uint8).max) revert("Too many tokens");
        ptr = 1;

        uint256 length =
            PackedRoute.TOKENS_OFFSET + PackedRoute.ADDRESS_SIZE * nbTokens + PackedRoute.ROUTE_SIZE * nbSwaps;
        extraDataPtr = length;

        if (extraDataLength > 0) {
            b = new bytes(length + extraDataLength + 3);
            assembly ("memory-safe") {
                let endPtr := add(add(b, 32), add(length, extraDataLength))
                mstore(endPtr, or(shl(232, extraDataLength), shr(24, shl(24, mload(endPtr)))))
            }
        } else {
            b = new bytes(length);
        }

        assembly ("memory-safe") {
            mstore(add(b, 32), shl(248, nbTokens))
        }
    }

    function _setIsTransferTaxToken(bytes memory b, uint256 ptr, bool isTransferTaxToken)
        internal
        pure
        returns (uint256)
    {
        assembly ("memory-safe") {
            mstore8(add(add(b, 32), ptr), isTransferTaxToken)
        }
        return ptr + 1;
    }

    function _setToken(bytes memory b, uint256 ptr, address token) internal returns (uint256) {
        uint256 id = (ptr - PackedRoute.TOKENS_OFFSET) / PackedRoute.ADDRESS_SIZE;
        if (id > type(uint8).max) revert("Too many tokens");

        _tokenToId[token] = id + 1;

        assembly ("memory-safe") {
            let p := add(add(b, 32), ptr)
            mstore(p, or(shl(96, token), and(mload(p), 0xffffffffffffffffffffffff)))
        }
        return ptr + PackedRoute.ADDRESS_SIZE;
    }

    function _setRoute(
        bytes memory b,
        uint256 ptr,
        address tokenIn,
        address tokenOut,
        address pair,
        uint16 percent,
        uint16 flags
    ) internal view returns (uint256) {
        uint256 tokenInId = _tokenToId[tokenIn] - 1;
        uint256 tokenOutId = _tokenToId[tokenOut] - 1;

        return _setRoute(b, ptr, tokenInId, tokenOutId, pair, percent, flags);
    }

    struct ExtraDataUniswapV4 {
        uint24 fee;
        int24 tickSpacing;
        uint8 nativeFlag;
        address hooks;
        bytes hookData;
    }

    function _setRouteUV4(
        bytes memory b,
        uint256 ptr,
        uint256 extraDataPtr,
        address tokenIn,
        address tokenOut,
        uint16 percent,
        uint16 flags,
        ExtraDataUniswapV4 memory extraData
    ) internal view returns (uint256, uint256) {
        uint256 tokenInId = _tokenToId[tokenIn] - 1;
        uint256 tokenOutId = _tokenToId[tokenOut] - 1;

        ptr = _setRoute(b, ptr, tokenInId, tokenOutId, address(uint160(extraDataPtr)), percent, flags);

        extraDataPtr = _setExtraDataUniswapV4(
            b,
            extraDataPtr,
            extraData.fee,
            extraData.tickSpacing,
            extraData.nativeFlag,
            extraData.hooks,
            extraData.hookData
        );

        return (ptr, extraDataPtr);
    }

    function _setFeePercentIn(bytes memory b, uint256 ptr, address feeRecipient, uint16 feePercent)
        internal
        pure
        returns (uint256)
    {
        return _setRoute(b, ptr, 0, 0, feeRecipient, feePercent, 0);
    }

    function _setFeePercentOut(bytes memory b, uint256 ptr, address feeRecipient, uint16 feePercent)
        internal
        pure
        returns (uint256)
    {
        uint256 nbTokens;
        assembly ("memory-safe") {
            nbTokens := shr(248, mload(add(b, 32)))
        }
        return _setRoute(b, ptr, nbTokens - 1, nbTokens - 1, feeRecipient, feePercent, 0);
    }

    function _setRoute(
        bytes memory b,
        uint256 ptr,
        uint256 tokenInId,
        uint256 tokenOutId,
        address pair,
        uint16 percent,
        uint16 flags
    ) private pure returns (uint256) {
        assembly ("memory-safe") {
            let value :=
                or(shl(96, pair), or(shl(80, percent), or(shl(64, flags), or(shl(56, tokenInId), shl(48, tokenOutId)))))
            let p := add(add(b, 32), ptr)
            mstore(p, or(value, and(mload(p), 0xffffffffffff)))
        }

        ptr += PackedRoute.ROUTE_SIZE;

        if (ptr > b.length) revert("Out of bounds");

        return ptr;
    }

    // [fee: 3][tickSpacing: 3][nativeFlag: 1][hooks: 20][hookData length: 3][hookData: variable]
    function _setExtraDataUniswapV4(
        bytes memory b,
        uint256 ptr,
        uint24 fee,
        int24 tickSpacing,
        uint8 nativeFlag,
        address hooks,
        bytes memory hookData
    ) internal view returns (uint256) {
        assembly ("memory-safe") {
            let value :=
                or(
                    shl(232, fee),
                    or(
                        shl(208, and(tickSpacing, 0xffffff)),
                        or(shl(200, nativeFlag), or(shl(40, hooks), shl(16, and(mload(hookData), 0xffffff))))
                    )
                )
            let p := add(add(b, 32), ptr)
            mstore(p, or(value, and(mload(p), 0xffff)))

            if mload(hookData) {
                // Copy the hook data using the identity precompile (0x04)
                pop(staticcall(gas(), 4, add(hookData, 32), mload(hookData), add(add(b, 62), ptr), mload(hookData)))
            }
        }

        ptr += UNISWAP_V4_EXTRA_DATA_SIZE + hookData.length;

        if (ptr > b.length) revert("Out of bounds");

        return ptr;
    }
}
