// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import "../../src/libraries/TokenLib.sol";
import "../mocks/MockERC20.sol";
import "../mocks/WNative.sol";

contract TokenLibTest is Test {
    error CustomError();

    MockERC20 token0;
    MockERC20 token1;
    WNative wnative;

    uint256 _mem0x40;
    uint256 _mem0x60;
    uint256 _mem0x80;

    bool _revert;
    bytes _data;

    modifier verifyMemory() {
        assembly {
            sstore(_mem0x40.slot, 0x40)
            sstore(_mem0x60.slot, 0x60)
            sstore(_mem0x80.slot, 0x80)
        }

        _;

        uint256 mem0x40;
        uint256 mem0x60;
        uint256 mem0x80;

        assembly {
            mem0x40 := sload(_mem0x40.slot)
            mem0x60 := sload(_mem0x60.slot)
            mem0x80 := sload(_mem0x80.slot)
        }

        assertEq(mem0x40, _mem0x40, "::0");
        assertEq(mem0x60, _mem0x60, "::1");
        assertEq(mem0x80, _mem0x80, "::2");
    }

    fallback(bytes calldata) external payable returns (bytes memory) {
        return _fallback();
    }

    receive() external payable {
        _fallback();
    }

    function _fallback() internal view returns (bytes memory) {
        bytes memory data = _data;

        if (_revert) {
            assembly {
                revert(add(data, 0x20), mload(data))
            }
        }

        return data;
    }

    function setUp() public {
        token0 = new MockERC20("Token0", "T0", 18);
        token1 = new MockERC20("Token1", "T1", 6);
        wnative = new WNative();
    }

    function test_Fuzz_BalanceOf(uint256 balance0, uint256 balance1) public {
        token0.mint(address(this), balance0);
        token1.mint(address(this), balance1);

        assertEq(this.balanceOf(address(token0), address(this)), balance0, "test_Fuzz_BalanceOf::1");
        assertEq(this.balanceOf(address(token1), address(this)), balance1, "test_Fuzz_BalanceOf::2");
    }

    function test_Revert_BalanceOf() public verifyMemory {
        vm.expectRevert(TokenLib.TokenLib__BalanceOfFailed.selector);
        this.balanceOf(address(this), address(this));

        _data = new bytes(31);

        vm.expectRevert(TokenLib.TokenLib__BalanceOfFailed.selector);
        this.balanceOf(address(this), address(this));

        _revert = true;
        _data = abi.encodeWithSelector(CustomError.selector);

        vm.expectRevert(CustomError.selector);
        this.balanceOf(address(this), address(this));

        _data = bytes("String error");

        vm.expectRevert("String error");
        this.balanceOf(address(this), address(this));
    }

    function test_Fuzz_UniversalBalanceOf(uint256 balance0, uint256 balance1, uint256 nativeBalance) public {
        token0.mint(address(this), balance0);
        token1.mint(address(this), balance1);
        deal(address(this), nativeBalance);

        assertEq(this.universalBalanceOf(address(token0), address(this)), balance0, "test_Fuzz_UniversalBalanceOf::1");
        assertEq(this.universalBalanceOf(address(token1), address(this)), balance1, "test_Fuzz_UniversalBalanceOf::2");
        assertEq(this.universalBalanceOf(address(0), address(this)), nativeBalance, "test_Fuzz_UniversalBalanceOf::3");
    }

    function test_Fuzz_TransferNative(uint256 amount) public {
        deal(address(this), amount);
        deal(address(0), 0);

        this.transferNative(address(0), amount);

        assertEq(address(0).balance, amount, "test_Fuzz_TransferNative::1");
    }

    function test_Revert_TransferNative() public verifyMemory {
        deal(address(this), 1e18);

        vm.expectRevert(TokenLib.TokenLib__NativeTransferFailed.selector);
        this.transferNative(address(0), 1e18 + 1);

        _revert = true;

        vm.expectRevert(TokenLib.TokenLib__NativeTransferFailed.selector);
        this.transferNative(address(this), 1e18);

        _data = abi.encodeWithSelector(CustomError.selector);

        vm.expectRevert(CustomError.selector);
        this.transferNative(address(this), 1e18);

        _data = bytes("String error");

        vm.expectRevert("String error");
        this.transferNative(address(this), 1e18);
    }

    function test_Fuzz_Wrap(uint256 amount) public {
        deal(address(this), amount);

        this.wrap(address(wnative), amount);

        assertEq(wnative.balanceOf(address(this)), amount, "test_Fuzz_Wrap::1");
    }

    function test_Revert_Wrap() public verifyMemory {
        deal(address(this), 1e18);

        vm.expectRevert(TokenLib.TokenLib__WrapFailed.selector);
        this.wrap(address(wnative), 1e18 + 1);

        _revert = true;

        vm.expectRevert(TokenLib.TokenLib__WrapFailed.selector);
        this.wrap(address(this), 1e18);

        _data = abi.encodeWithSelector(CustomError.selector);

        vm.expectRevert(CustomError.selector);
        this.wrap(address(this), 1e18);

        _data = bytes("String error");

        vm.expectRevert("String error");
        this.wrap(address(this), 1e18);
    }

    function test_Fuzz_Unwrap(uint256 amount) public {
        deal(address(this), amount);
        TokenLib.wrap(address(wnative), amount);

        this.unwrap(address(wnative), amount);

        assertEq(wnative.balanceOf(address(this)), 0, "test_Fuzz_Unwrap::1");
    }

    function test_Revert_Unwrap() public verifyMemory {
        deal(address(this), 1e18);
        TokenLib.wrap(address(wnative), 1e18);

        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, address(this), 1e18, 1e18 + 1)
        );
        this.unwrap(address(wnative), 1e18 + 1);

        _revert = true;

        vm.expectRevert(TokenLib.TokenLib__UnwrapFailed.selector);
        this.unwrap(address(this), 1e18);

        _data = abi.encodeWithSelector(CustomError.selector);

        vm.expectRevert(CustomError.selector);
        this.unwrap(address(this), 1e18);

        _data = bytes("String error");

        vm.expectRevert("String error");
        this.unwrap(address(this), 1e18);
    }

    function test_Fuzz_Transfer(address to0, address to1, uint256 amount0, uint256 amount1) public {
        vm.assume(to0 != to1 && to0 != address(0) && to1 != address(0));

        token0.mint(address(this), amount0);
        token1.mint(address(this), amount1);

        this.transfer(address(token0), to0, amount0);
        this.transfer(address(token1), to1, amount1);

        assertEq(token0.balanceOf(to0), amount0, "test_Fuzz_Transfer::1");
        assertEq(token1.balanceOf(to1), amount1, "test_Fuzz_Transfer::2");
    }

    function test_Revert_Transfer() public verifyMemory {
        token0.mint(address(this), 1e18);

        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, address(this), 1e18, 1e18 + 1)
        );
        this.transfer(address(token0), address(this), 1e18 + 1);

        vm.expectRevert(TokenLib.TokenLib__TransferFailed.selector);
        this.transfer(address(0), address(this), 1e18);

        _data = abi.encode(false);

        vm.expectRevert(TokenLib.TokenLib__TransferFailed.selector);
        this.transfer(address(this), address(this), 1e18);

        _revert = true;
        delete _data;

        vm.expectRevert(TokenLib.TokenLib__TransferFailed.selector);
        this.transfer(address(this), address(this), 1e18);

        _data = abi.encodeWithSelector(CustomError.selector);

        vm.expectRevert(CustomError.selector);
        this.transfer(address(this), address(this), 1e18);

        _data = bytes("String error");

        vm.expectRevert("String error");
        this.transfer(address(this), address(this), 1e18);
    }

    function test_Fuzz_TransferFrom(
        address from0,
        address from1,
        address to0,
        address to1,
        uint256 amount0,
        uint256 amount1
    ) public {
        vm.assume(
            from0 != to0 && from0 != address(0) && to0 != address(0) && from1 != to1 && from1 != address(0)
                && to1 != address(0)
        );

        token0.mint(from0, amount0);
        token1.mint(from1, amount1);

        vm.prank(from0);
        token0.approve(address(this), amount0);

        vm.prank(from1);
        token1.approve(address(this), amount1);

        this.transferFrom(address(token0), from0, to0, amount0);
        this.transferFrom(address(token1), from1, to1, amount1);

        assertEq(token0.balanceOf(to0), amount0, "test_Fuzz_TransferFrom::1");
        assertEq(token1.balanceOf(to1), amount1, "test_Fuzz_TransferFrom::2");
    }

    function test_Revert_TransferFrom() public verifyMemory {
        token0.mint(address(this), 1e18);
        token0.approve(address(this), type(uint256).max);

        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, address(this), 1e18, 1e18 + 1)
        );
        this.transferFrom(address(token0), address(this), address(this), 1e18 + 1);

        vm.expectRevert(TokenLib.TokenLib__TransferFromFailed.selector);
        this.transferFrom(address(0), address(this), address(this), 1e18);

        _data = abi.encode(false);

        vm.expectRevert(TokenLib.TokenLib__TransferFromFailed.selector);
        this.transferFrom(address(this), address(this), address(this), 1e18);

        _revert = true;
        delete _data;

        vm.expectRevert(TokenLib.TokenLib__TransferFromFailed.selector);
        this.transferFrom(address(this), address(this), address(this), 1e18);

        _data = abi.encodeWithSelector(CustomError.selector);

        vm.expectRevert(CustomError.selector);
        this.transferFrom(address(this), address(this), address(this), 1e18);

        _data = bytes("String error");

        vm.expectRevert("String error");
        this.transferFrom(address(this), address(this), address(this), 1e18);
    }

    function balanceOf(address token, address account) external verifyMemory returns (uint256) {
        return TokenLib.balanceOf(token, account);
    }

    function universalBalanceOf(address token, address account) external verifyMemory returns (uint256) {
        return TokenLib.universalBalanceOf(token, account);
    }

    function transferNative(address to, uint256 amount) external verifyMemory {
        TokenLib.transferNative(to, amount);
    }

    function wrap(address wnative_, uint256 amount) external verifyMemory {
        TokenLib.wrap(wnative_, amount);
    }

    function unwrap(address wnative_, uint256 amount) external verifyMemory {
        TokenLib.unwrap(wnative_, amount);
    }

    function transfer(address token, address to, uint256 amount) external verifyMemory {
        TokenLib.transfer(token, to, amount);
    }

    function transferFrom(address token, address from, address to, uint256 amount) external verifyMemory {
        TokenLib.transferFrom(token, from, to, amount);
    }
}
