// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable2Step, Ownable} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IWNative} from "./interfaces/IWNative.sol";
import {IRouterLogic} from "./interfaces/IRouterLogic.sol";
import {IRouter} from "./interfaces/IRouter.sol";

contract Router is Ownable2Step, IRouter {
    using SafeERC20 for IERC20;

    address public immutable WNATIVE;

    address private _logic;

    mapping(bytes32 key => uint256 allowance) private _allowances;

    receive() external payable {
        if (msg.sender != WNATIVE) revert Router__OnlyWnative();
    }

    constructor(address wnative, address initialOwner) Ownable(initialOwner) {
        WNATIVE = wnative;
    }

    function getLogic() external view returns (address) {
        return _logic;
    }

    function transfer(address token, address from, address to, uint256 amount) external returns (address) {
        if (amount == 0) revert Router__ZeroAmount();

        bytes32 key = _getKey(token, msg.sender, from);

        uint256 allowance = _allowances[key];

        unchecked {
            if (allowance < amount) revert Router__InsufficientAllowance(allowance, amount);
            _allowances[key] = allowance - amount;
        }

        if (token == address(0)) {
            from = address(this);
            token = WNATIVE;

            _wrap(amount);
        }

        from == address(this)
            ? IERC20(token).safeTransfer(to, amount)
            : IERC20(token).safeTransferFrom(from, to, amount);

        return token;
    }

    function swapExactIn(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOutMin,
        address to,
        uint256 deadline,
        bytes[] calldata routes
    ) external payable returns (uint256, uint256) {
        if (to == address(0) || to == address(this)) revert Router__InvalidTo();
        if (block.timestamp > deadline) revert Router__DeadlineExceeded();

        if (amountIn == 0) {
            amountIn = tokenIn == address(0) ? msg.value : IERC20(tokenIn).balanceOf(msg.sender);
            if (amountIn == 0) revert Router__ZeroAmountIn();
        }

        uint256 balance = _balanceOf(tokenOut, to);

        (uint256 totalIn, uint256 totalOut) = _swapExactIn(tokenIn, tokenOut, msg.sender, to, amountIn, routes);

        if (totalIn != amountIn) revert Router__InvalidTotalIn(totalIn, amountIn);

        _verify(tokenOut, to, balance, amountOutMin, totalOut);

        emit SwapExactIn(msg.sender, to, tokenIn, tokenOut, totalIn, totalOut);

        if (tokenIn == address(0)) {
            uint256 refund = msg.value - totalIn;
            if (refund > 0) _transferNative(msg.sender, refund);
        }

        return (totalIn, totalOut);
    }

    // TODO Add swap supporting fee on transfer tokens
    // TODO Add simulate and batchSimulate functions

    function swapExactOut(
        address tokenIn,
        address tokenOut,
        uint256 amountOut,
        uint256 amountInMax,
        address to,
        uint256 deadline,
        bytes[] calldata routes
    ) external payable returns (uint256, uint256) {
        if (to == address(0) || to == address(this)) revert Router__InvalidTo();
        if (block.timestamp > deadline) revert Router__DeadlineExceeded();

        if (amountOut == 0) revert Router__ZeroAmountOut();

        uint256 balance = _balanceOf(tokenOut, to);

        (uint256 totalIn, uint256 totalOut) = _swapExactOut(tokenIn, tokenOut, amountInMax, msg.sender, to, routes);

        if (totalIn > amountInMax) revert Router__MaxAmountInExceeded(totalIn, amountInMax);

        _verify(tokenOut, to, balance, amountOut, totalOut);

        emit SwapExactOut(msg.sender, to, tokenIn, tokenOut, totalIn, totalOut);

        if (tokenIn == address(0)) {
            uint256 refund = msg.value - totalIn;
            if (refund > 0) _transferNative(msg.sender, refund);
        }

        return (totalIn, totalOut);
    }

    function updateRouterLogic(address logic) external onlyOwner {
        _logic = logic;

        emit RouterLogicUpdated(logic);
    }

    function _verify(address tokenOut, address to, uint256 balance, uint256 amountOutMin, uint256 amountOut)
        internal
        view
    {
        if (amountOut < amountOutMin) revert Router__InsufficientOutputAmount(amountOut, amountOutMin);

        uint256 balanceAfter = _balanceOf(tokenOut, to);

        if (balanceAfter < balance + amountOutMin) {
            revert Router__InsufficientAmountReceived(balance, balanceAfter, amountOutMin);
        }
    }

    function _swapExactIn(
        address tokenIn,
        address tokenOut,
        address from,
        address to,
        uint256 amountIn,
        bytes[] calldata routes
    ) internal returns (uint256 totalIn, uint256 totalOut) {
        address logic = _logic;
        if (logic == address(0)) revert Router__LogicNotSet();

        address recipient;
        (recipient, tokenOut) = tokenOut == address(0) ? (address(this), WNATIVE) : (to, tokenOut);

        if (tokenIn == address(0)) {
            tokenIn = WNATIVE;
            from = address(this);
            _wrap(amountIn);
        }

        bytes32 key = _getKey(tokenIn, logic, from);

        _allowances[key] = amountIn;

        (totalIn, totalOut) = IRouterLogic(logic).swapExactIn(tokenIn, tokenOut, from, recipient, routes);

        _allowances[key] = 0;

        if (recipient == address(this)) {
            _unwrap(totalOut);
            _transferNative(to, totalOut);
        }
    }

    function _swapExactOut(
        address tokenIn,
        address tokenOut,
        uint256 amountInMax,
        address from,
        address to,
        bytes[] calldata routes
    ) internal returns (uint256 totalIn, uint256 totalOut) {
        address logic = _logic;
        if (logic == address(0)) revert Router__LogicNotSet();

        address recipient;
        (recipient, tokenOut) = tokenOut == address(0) ? (address(this), WNATIVE) : (to, tokenOut);

        if (tokenIn == address(0)) from = address(this);

        bytes32 key = _getKey(tokenIn, logic, from);

        _allowances[key] = amountInMax;

        (totalIn, totalOut) = IRouterLogic(logic).swapExactOut(tokenIn, tokenOut, from, recipient, routes);

        _allowances[key] = 0;

        if (recipient == address(this)) {
            _unwrap(totalOut);
            _transferNative(to, totalOut);
        }
    }

    function _balanceOf(address token, address user) internal view returns (uint256) {
        return token == address(0) ? user.balance : IERC20(token).balanceOf(user);
    }

    function _wrap(uint256 amount) internal {
        IWNative(WNATIVE).deposit{value: amount}();
    }

    function _unwrap(uint256 amount) internal {
        IWNative(WNATIVE).withdraw(amount);
    }

    function _transferNative(address to, uint256 amount) internal {
        (bool s,) = to.call{value: amount}(new bytes(0));
        if (!s) revert Router__NativeTransferFailed();
    }

    function _getKey(address token, address sender, address from) internal pure returns (bytes32 key) {
        // [00:20]: token
        // [20:40]: from
        // [40:60]: sender
        assembly {
            mstore(0, shl(96, token))
            mstore(20, shl(96, sender))
            mstore(40, shl(96, from)) // Overwrite the last 8 bytes of the free memory pointer with zero, which should always be zeros

            key := keccak256(0, 60)
        }
    }
}
