// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";

import {PackedRoute} from "../../src/libraries/PackedRoute.sol";

contract PackedRouteTest is Test {
    PackedRouteLib lib;

    function setUp() public {
        lib = new PackedRouteLib();
    }

    function test_Fuzz_ExtraDataLength(uint256 swapLength, uint256 extraDataLength) public view {
        swapLength = bound(swapLength, 4, 2048);
        extraDataLength = bound(extraDataLength, 0, 1024) * 2; // extraDataLength must be even

        bytes memory route = abi.encodePacked(new bytes(swapLength + extraDataLength), uint24(extraDataLength));

        assertEq(lib.extraDataLength(route, swapLength), extraDataLength, "test_Fuzz_ExtraDataLength::1");
    }

    function test_Fuzz_Revert_ExtraDataLength(uint256 swapLength, uint256 extraDataLength) public {
        swapLength = bound(swapLength, 4, 2048);
        extraDataLength = bound(extraDataLength, 0, 1024) * 2 + 1; // uneven extraDataLength

        bytes memory route = abi.encodePacked(new bytes(swapLength + extraDataLength), uint24(extraDataLength));

        vm.expectRevert(PackedRoute.PackedRoute__InvalidExtraDataLength.selector);
        lib.extraDataLength(route, swapLength);
    }

    function test_Fuzz_Start(uint256 nbTokens, uint256 nbSwaps) public view {
        nbTokens = bound(nbTokens, 0, 255);
        nbSwaps = bound(nbSwaps, 0, 255);

        bytes memory route = abi.encodePacked(
            uint8(nbTokens),
            new bytes(
                PackedRoute.IS_TRANSFER_TAX_OFFSET + PackedRoute.ADDRESS_SIZE * nbTokens
                    + PackedRoute.ROUTE_SIZE * nbSwaps
            )
        );

        (uint256 ptr, uint256 nbTokens_, uint256 nbSwaps_) = lib.start(route);

        assertEq(ptr, PackedRoute.TOKENS_OFFSET + PackedRoute.ADDRESS_SIZE * nbTokens, "test_Fuzz_Start::1");
        assertEq(nbTokens_, nbTokens, "test_Fuzz_Start::2");
        assertEq(nbSwaps_, nbSwaps, "test_Fuzz_Start::3");
    }

    function test_Fuzz_Start_With_ExtraData(uint256 nbTokens, uint256 nbSwaps, uint256 extraDataLength) public view {
        nbTokens = bound(nbTokens, 0, 255);
        nbSwaps = bound(nbSwaps, nbTokens == 0 ? 1 : 0, 255);
        extraDataLength = bound(extraDataLength, 0, 1024) * 24; // extraDataLength must be even

        bytes memory route = abi.encodePacked(
            uint8(nbTokens),
            new bytes(
                PackedRoute.IS_TRANSFER_TAX_OFFSET + PackedRoute.ADDRESS_SIZE * nbTokens
                    + PackedRoute.ROUTE_SIZE * nbSwaps + extraDataLength
            ),
            uint24(extraDataLength)
        );

        (uint256 ptr, uint256 nbTokens_, uint256 nbSwaps_) = lib.start(route);

        assertEq(
            ptr, PackedRoute.TOKENS_OFFSET + PackedRoute.ADDRESS_SIZE * nbTokens, "test_Fuzz_Start_With_ExtraData::1"
        );
        assertEq(nbTokens_, nbTokens, "test_Fuzz_Start_With_ExtraData::2");
        assertEq(nbSwaps_, nbSwaps, "test_Fuzz_Start_With_ExtraData::3");
        assertEq(
            lib.extraDataLength(route, route.length - (PackedRoute.TOKENS_OFFSET + PackedRoute.ADDRESS_SIZE * nbTokens)),
            extraDataLength,
            "test_Fuzz_Start_With_ExtraData::4"
        );
    }

    function test_Fuzz_Revert_Start(uint256 nbTokens, uint256 length) public {
        nbTokens = bound(nbTokens, 0, 255);
        uint256 minLength = PackedRoute.TOKENS_OFFSET - 1 + PackedRoute.ADDRESS_SIZE * nbTokens;

        uint256 badLength = bound(length, 0, minLength - 1);
        bytes memory route = abi.encodePacked(uint8(nbTokens), new bytes(badLength));

        vm.expectRevert(PackedRoute.PackedRoute__InvalidLength.selector);
        lib.start(route);

        badLength = bound(length, minLength + 1, minLength + 2048);
        badLength = (badLength - minLength) % PackedRoute.ROUTE_SIZE != 0 ? badLength : badLength + 1;
        badLength = (badLength - minLength) % PackedRoute.ROUTE_SIZE == PackedRoute.EXTRA_DATA_LENGTH_SIZE
            ? badLength + 1
            : badLength;

        route = abi.encodePacked(uint8(nbTokens), new bytes(badLength));

        vm.expectRevert(PackedRoute.PackedRoute__InvalidLength.selector);
        lib.start(route);
    }

    function test_Fuzz_Revert_Start_WithExtraData(uint256 nbTokens, uint256 length, uint256 extraDataLength) public {
        nbTokens = bound(nbTokens, 1, 16);
        uint256 minDataLength = PackedRoute.TOKENS_OFFSET + PackedRoute.ADDRESS_SIZE * nbTokens - 1;

        uint256 badLength = bound(length, 0, minDataLength - 1);
        bytes memory route = abi.encodePacked(uint8(nbTokens), new bytes(badLength));

        vm.expectRevert(PackedRoute.PackedRoute__InvalidLength.selector);
        lib.start(route);

        length = minDataLength + bound(length, 1, 10) * 26; // Valid length
        uint256 badExtraDataLength = bound(extraDataLength, 0, 10) * 26 + 1; // uneven extraDataLength

        route = abi.encodePacked(
            uint8(nbTokens), new bytes(length), new bytes(badExtraDataLength), uint24(badExtraDataLength)
        );

        vm.expectRevert(PackedRoute.PackedRoute__InvalidExtraDataLength.selector);
        lib.start(route);

        extraDataLength = bound(extraDataLength, 1, 10) * 26; // Valid extraDataLength

        route = abi.encodePacked(
            uint8(nbTokens), new bytes(length), new bytes(extraDataLength + 1), uint24(extraDataLength)
        );

        vm.expectRevert(PackedRoute.PackedRoute__InvalidLength.selector);
        lib.start(route);

        route = abi.encodePacked(
            uint8(nbTokens), new bytes(length), new bytes(extraDataLength - 1), uint24(extraDataLength)
        );

        vm.expectRevert(PackedRoute.PackedRoute__InvalidLength.selector);
        lib.start(route);
    }

    function test_Fuzz_IsTransferTax(bool isTransferTax, bytes memory data) public view {
        bytes memory route = abi.encodePacked(uint8(0), isTransferTax, data);

        assertEq(lib.isTransferTax(route), isTransferTax, "test_Fuzz_IsTransferTax::1");
    }

    function test_Fuzz_NextPrevious(address[] memory tokens, bytes26[] memory details) public view {
        if (tokens.length > 32) {
            assembly ("memory-safe") {
                mstore(tokens, 32)
            }
        }

        if (details.length > 32) {
            assembly ("memory-safe") {
                mstore(details, 32)
            }
        }

        uint256 length = PackedRoute.ADDRESS_SIZE * tokens.length + PackedRoute.ROUTE_SIZE * details.length;

        bytes memory route = abi.encodePacked(uint8(tokens.length), uint8(0), new bytes(length));

        unchecked {
            uint256 ptr_ = PackedRoute.TOKENS_OFFSET;
            for (uint256 i = 0; i < tokens.length; i++) {
                assembly ("memory-safe") {
                    mstore(add(add(route, 32), ptr_), shl(96, mload(add(tokens, add(32, mul(i, 32))))))
                }
                ptr_ += PackedRoute.ADDRESS_SIZE;
            }

            for (uint256 i = 0; i < details.length; i++) {
                assembly ("memory-safe") {
                    mstore(add(add(route, 32), ptr_), mload(add(details, add(32, mul(i, 32)))))
                }
                ptr_ += PackedRoute.ROUTE_SIZE;
            }
        }

        this._nextPrevious(tokens, details, route);
    }

    function _nextPrevious(address[] calldata tokens, bytes26[] calldata details, bytes calldata route) public pure {
        (uint256 ptr, uint256 nbTokens, uint256 nbSwaps) = PackedRoute.start(route);

        assertEq(nbTokens, tokens.length, "_nextPrevious::1");
        assertEq(nbSwaps, details.length, "_nextPrevious::2");
        assertEq(ptr, PackedRoute.TOKENS_OFFSET + PackedRoute.ADDRESS_SIZE * nbTokens, "_nextPrevious::3");

        uint256 startPtr = ptr;

        for (uint256 i = 0; i < tokens.length; i++) {
            assertEq(PackedRoute.token(route, i), tokens[i], "_nextPrevious::4");
        }

        bytes32 value;
        for (uint256 i = 0; i < details.length; i++) {
            (ptr, value) = PackedRoute.next(route, ptr);

            assertEq(ptr, startPtr + PackedRoute.ROUTE_SIZE * (i + 1), "_nextPrevious::5");
            assertEq(
                value & 0xffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000,
                details[i],
                "_nextPrevious::6"
            );

            (address pair, uint256 percent, uint256 flags, uint256 tokenInId, uint256 tokenOutId) = (
                PackedRoute.pair(value),
                PackedRoute.percent(value),
                PackedRoute.flags(value),
                PackedRoute.tokenInId(value),
                PackedRoute.tokenOutId(value)
            );

            uint256 detail = uint256(bytes32(details[i]));

            assertEq(pair, address(uint160(detail >> 96)), "_nextPrevious::7");
            assertEq(percent, uint16(detail >> 80), "_nextPrevious::8");
            assertEq(flags, uint16(detail >> 64), "_nextPrevious::9");
            assertEq(tokenInId, uint8(detail >> 56), "_nextPrevious::10");
            assertEq(tokenOutId, uint8(detail >> 48), "_nextPrevious::11");
        }

        assertEq(PackedRoute.endPtr(startPtr, nbSwaps), ptr, "_nextPrevious::12");

        for (uint256 i = details.length; i > 0; i--) {
            (ptr, value) = PackedRoute.previous(route, ptr);

            assertEq(ptr, startPtr + PackedRoute.ROUTE_SIZE * (i - 1), "_nextPrevious::13");
            assertEq(
                value & 0xffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000,
                details[i - 1],
                "_nextPrevious::14"
            );

            (address pair, uint256 percent, uint256 flags, uint256 tokenInId, uint256 tokenOutId) = (
                PackedRoute.pair(value),
                PackedRoute.percent(value),
                PackedRoute.flags(value),
                PackedRoute.tokenInId(value),
                PackedRoute.tokenOutId(value)
            );

            uint256 detail = uint256(bytes32(details[i - 1]));

            assertEq(pair, address(uint160(detail >> 96)), "_nextPrevious::15");
            assertEq(percent, uint16(detail >> 80), "_nextPrevious::16");
            assertEq(flags, uint16(detail >> 64), "_nextPrevious::17");
            assertEq(tokenInId, uint8(detail >> 56), "_nextPrevious::18");
            assertEq(tokenOutId, uint8(detail >> 48), "_nextPrevious::19");
        }
    }
}

contract PackedRouteLib {
    function test() public pure {} // To avoid this contract to be included in coverage

    function token(bytes calldata route, uint256 id) external pure returns (address t) {
        return PackedRoute.token(route, id);
    }

    function isTransferTax(bytes calldata route) external pure returns (bool b) {
        return PackedRoute.isTransferTax(route);
    }

    function start(bytes calldata route) external pure returns (uint256 ptr, uint256 nbTokens, uint256 nbSwaps) {
        return PackedRoute.start(route);
    }

    function next(bytes calldata route, uint256 ptr) external pure returns (uint256 nextPtr, bytes32 value) {
        return PackedRoute.next(route, ptr);
    }

    function previous(bytes calldata route, uint256 ptr) external pure returns (uint256 previousPtr, bytes32 value) {
        return PackedRoute.previous(route, ptr);
    }

    function extraDataLength(bytes calldata route, uint256 swapLength) external pure returns (uint256 length) {
        return PackedRoute.extraDataLength(route, swapLength);
    }
}
