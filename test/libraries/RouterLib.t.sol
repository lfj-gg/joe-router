// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import "../../src/libraries/RouterLib.sol";
import "../../src/interfaces/IRouterLogic.sol";
import "../mocks/MockERC20.sol";

contract RouterLibTest is Test {
    error CustomError();

    mapping(bytes32 key => uint256) _allowances;

    MockERC20 token0;
    MockERC20 token1;

    uint256 _mem0x40;
    uint256 _mem0x60;
    uint256 _mem0x80;

    uint256 _case;
    bytes _data;

    uint256 _allowance;

    modifier verifyMemory() {
        assembly ("memory-safe") {
            sstore(_mem0x40.slot, 0x40)
            sstore(_mem0x60.slot, 0x60)
            sstore(_mem0x80.slot, 0x80)
        }

        _;

        uint256 mem0x40;
        uint256 mem0x60;
        uint256 mem0x80;

        assembly ("memory-safe") {
            mem0x40 := sload(_mem0x40.slot)
            mem0x60 := sload(_mem0x60.slot)
            mem0x80 := sload(_mem0x80.slot)
        }

        assertEq(mem0x40, _mem0x40, "::0");
        assertEq(mem0x60, _mem0x60, "::1");
        assertEq(mem0x80, _mem0x80, "::2");
    }

    function setUp() public {
        token0 = new MockERC20("Token0", "T0", 18);
        token1 = new MockERC20("Token1", "T1", 6);

        vm.label(address(token0), "Token0");
        vm.label(address(token1), "Token1");
    }

    fallback() external {
        uint256 c = _case;
        if (c == 0) {
            RouterLib.validateAndTransfer(_allowances);
        } else if (c == 1) {
            _data = msg.data;

            bytes32 key;

            assembly ("memory-safe") {
                mstore(0, calldataload(16))
                mstore(20, shl(96, caller()))
                calldatacopy(40, 144, 20)

                log0(0, 60)

                key := keccak256(0, 60)
            }

            _allowance = _allowances[key];
        } else {
            bytes memory data = _data;
            assembly ("memory-safe") {
                revert(add(data, 32), mload(data))
            }
        }
    }

    function test_Fuzz_GetAllowanceSlot(address token, address sender, address from) public {
        bytes32 slot = RouterLib.getAllowanceSlot(_allowances, token, sender, from);

        assembly ("memory-safe") {
            sstore(slot, 1)
        }

        assertEq(_allowances[keccak256(abi.encodePacked(token, sender, from))], 1, "test_Fuzz_GetAllowanceSlot::1");
    }

    function test_Fuzz_Transfer(
        address from,
        address to,
        uint256 amount0_0,
        uint256 amount0_1,
        uint256 amount1_0,
        uint256 amount1_1
    ) public {
        vm.assume(from != to && from != address(0) && to != address(0));

        amount0_0 = bound(amount0_0, 1, type(uint256).max - 1);
        amount0_1 = bound(amount0_1, 1, type(uint256).max - amount0_0);
        amount1_0 = bound(amount1_0, 1, type(uint256).max - 1);
        amount1_1 = bound(amount1_1, 1, type(uint256).max - amount1_0);

        vm.startPrank(from);
        token0.mint(from, amount0_0 + amount0_1);
        token1.mint(from, amount1_0 + amount1_1);

        token0.approve(address(this), type(uint256).max);
        token1.approve(address(this), type(uint256).max);
        vm.stopPrank();

        bytes32 key0 = keccak256(abi.encodePacked(token0, address(this), from));
        bytes32 key1 = keccak256(abi.encodePacked(token1, address(this), from));

        _allowances[key0] = amount0_0 + amount0_1;
        _allowances[key1] = amount1_0 + amount1_1;

        this.transfer(address(token0), from, to, amount0_0);

        assertEq(token0.balanceOf(from), amount0_1, "test_Fuzz_Transfer::1");
        assertEq(token0.balanceOf(to), amount0_0, "test_Fuzz_Transfer::2");
        assertEq(_allowances[key0], amount0_1, "test_Fuzz_Transfer::3");

        this.transfer(address(token1), from, to, amount1_0);

        assertEq(token1.balanceOf(from), amount1_1, "test_Fuzz_Transfer::4");
        assertEq(token1.balanceOf(to), amount1_0, "test_Fuzz_Transfer::5");
        assertEq(_allowances[key1], amount1_1, "test_Fuzz_Transfer::6");

        this.transfer(address(token0), from, to, amount0_1);

        assertEq(token0.balanceOf(from), 0, "test_Fuzz_Transfer::7");
        assertEq(token0.balanceOf(to), amount0_0 + amount0_1, "test_Fuzz_Transfer::8");
        assertEq(_allowances[key0], 0, "test_Fuzz_Transfer::9");

        this.transfer(address(token1), from, to, amount1_1);

        assertEq(token1.balanceOf(from), 0, "test_Fuzz_Transfer::10");
        assertEq(token1.balanceOf(to), amount1_0 + amount1_1, "test_Fuzz_Transfer::11");
        assertEq(_allowances[key1], 0, "test_Fuzz_Transfer::12");
    }

    function test_Fuzz_Revert_Transfer(address token, address from, address to, uint256 amount) public {
        vm.expectRevert(RouterLib.RouterLib__ZeroAmount.selector);
        this.transfer(token, from, to, 0);

        bytes memory data = abi.encode(type(uint256).max, type(uint256).max, type(uint256).max); // 96

        uint256 length = bound(amount, 0, 64);

        assembly ("memory-safe") {
            mstore(data, length)
        }

        vm.expectRevert(RouterLib.RouterLib__ZeroAmount.selector);
        this.callSelf(data);

        length = bound(amount, 65, 96);

        assembly ("memory-safe") {
            mstore(data, length)
        }

        uint256 shift = (96 - length) * 8;
        vm.expectRevert(
            abi.encodeWithSelector(
                RouterLib.RouterLib__InsufficientAllowance.selector, 0, (type(uint256).max >> shift) << shift
            )
        );
        this.callSelf(data);

        amount = bound(amount, 1, type(uint256).max - 1);

        bytes32 key = keccak256(abi.encodePacked(token, address(this), from));

        _allowances[key] = amount;

        vm.expectRevert(abi.encodeWithSelector(RouterLib.RouterLib__InsufficientAllowance.selector, amount, amount + 1));
        this.transfer(token, from, to, amount + 1);
    }

    function test_Fuzz_Swap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        address from,
        address to,
        bytes calldata route,
        bool exactIn
    ) public {
        _case = 1;

        amountIn = bound(amountIn, 0, type(uint256).max - 1);

        bytes32 key = keccak256(abi.encodePacked(tokenIn, address(this), from));

        _allowances[key] = type(uint256).max;

        this.swap(tokenIn, tokenOut, amountIn, amountOut, from, to, route, exactIn);

        assertEq(_allowances[key], 0, "test_Fuzz_Swap::1");
        assertEq(_allowance, amountIn, "test_Fuzz_Swap::2");

        bytes memory expectedData = exactIn
            ? abi.encodeCall(IRouterLogic.swapExactIn, (tokenIn, tokenOut, amountIn, amountOut, from, to, route))
            : abi.encodeCall(IRouterLogic.swapExactOut, (tokenIn, tokenOut, amountIn, amountOut, from, to, route));

        uint256 length = _data.length;

        assembly ("memory-safe") {
            mstore(expectedData, length)
        }

        assertGt(length, 0, "test_Fuzz_Swap::3");
        assertEq(length, 4 + 32 * 8 + route.length, "test_Fuzz_Swap::4");
        assertEq(_data, expectedData, "test_Fuzz_Swap::5");
    }

    function test_Revert_Swap(bytes calldata route) public {
        vm.expectRevert(RouterLib.RouterLib__LogicNotSet.selector);
        RouterLib.swap(_allowances, address(0), address(0), 0, 0, address(0), address(0), route, true, address(0));

        _case = 2;

        vm.expectRevert(new bytes(0));
        this.swap(address(0), address(0), 0, 0, address(0), address(0), route, true);

        _data = abi.encodeWithSelector(CustomError.selector);
        vm.expectRevert(CustomError.selector);
        this.callSelf(_data);

        _data = "String error";
        vm.expectRevert("String error");
        this.callSelf(_data);
    }

    function transfer(address token, address from, address to, uint256 amount) external verifyMemory {
        RouterLib.transfer(address(this), token, from, to, amount);
    }

    function callSelf(bytes memory data) public verifyMemory {
        (bool success,) = address(this).call(data);
        if (!success) {
            assembly ("memory-safe") {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }
        }
    }

    function swap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        address from,
        address to,
        bytes calldata route,
        bool exactIn
    ) public verifyMemory {
        RouterLib.swap(_allowances, tokenIn, tokenOut, amountIn, amountOut, from, to, route, exactIn, address(this));
    }
}
