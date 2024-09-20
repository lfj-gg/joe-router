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
        if (address(wnative).code.length == 0) revert Router__InvalidWnative();

        WNATIVE = wnative;
    }

    function getLogic() external view returns (address) {
        return _logic;
    }

    function transfer(address token, address from, address to, uint256 amount) external {
        if (amount == 0) revert Router__ZeroAmount();

        bytes32 key = _getKey(token, msg.sender, from);

        uint256 allowance = _allowances[key];

        unchecked {
            if (allowance < amount) revert Router__InsufficientAllowance(allowance, amount);
            _allowances[key] = allowance - amount;
        }

        from == address(this)
            ? IERC20(token).safeTransfer(to, amount)
            : IERC20(token).safeTransferFrom(from, to, amount);
    }

    function swapExactIn(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOutMin,
        address to,
        uint256 deadline,
        bytes calldata routes
    ) external payable returns (uint256 totalIn, uint256 totalOut) {
        if (amountIn == 0) amountIn = tokenIn == address(0) ? msg.value : IERC20(tokenIn).balanceOf(msg.sender);
        _verifyParameters(tokenIn, tokenOut, amountIn, to, deadline);

        (totalIn, totalOut) = _swapExact(tokenIn, tokenOut, amountIn, amountOutMin, msg.sender, to, routes, true);

        emit SwapExactIn(msg.sender, to, tokenIn, tokenOut, totalIn, totalOut);
    }

    function swapExactOut(
        address tokenIn,
        address tokenOut,
        uint256 amountOut,
        uint256 amountInMax,
        address to,
        uint256 deadline,
        bytes calldata routes
    ) external payable returns (uint256 totalIn, uint256 totalOut) {
        _verifyParameters(tokenIn, tokenOut, amountOut, to, deadline);

        (totalIn, totalOut) = _swapExact(tokenIn, tokenOut, amountInMax, amountOut, msg.sender, to, routes, false);

        emit SwapExactOut(msg.sender, to, tokenIn, tokenOut, totalIn, totalOut);
    }

    function simulate(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        bool exactIn,
        bytes[] calldata multiRoutes
    ) external payable {
        uint256 length = multiRoutes.length;

        uint256[] memory amounts = new uint256[](length);
        for (uint256 i; i < length;) {
            (, bytes memory data) = address(this).delegatecall(
                abi.encodeWithSelector(
                    IRouter.simulateSingle.selector, tokenIn, tokenOut, amountIn, amountOut, exactIn, multiRoutes[i++]
                )
            );

            if (bytes4(data) == IRouter.Router__SimulateSingle.selector) {
                assembly {
                    mstore(add(amounts, mul(i, 32)), mload(add(data, 36)))
                }
            } else {
                amounts[i - 1] = exactIn ? 0 : type(uint256).max;
            }
        }

        revert Router__Simulations(amounts);
    }

    function simulateSingle(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        bool exactIn,
        bytes calldata routes
    ) external payable {
        (uint256 totalIn, uint256 totalOut) =
            _swapExact(tokenIn, tokenOut, amountIn, amountOut, msg.sender, msg.sender, routes, exactIn);

        revert Router__SimulateSingle(exactIn ? totalOut : totalIn);
    }

    function updateRouterLogic(address logic) external onlyOwner {
        _logic = logic;

        emit RouterLogicUpdated(logic);
    }

    function _verifyParameters(address tokenIn, address tokenOut, uint256 amount, address to, uint256 deadline)
        internal
        view
    {
        if (to == address(0) || to == address(this)) revert Router__InvalidTo();
        if (block.timestamp > deadline) revert Router__DeadlineExceeded();
        if (tokenIn == tokenOut) revert Router__IdenticalTokens();
        if (amount == 0) revert Router__ZeroAmount();
    }

    function _verifySwap(address tokenOut, address to, uint256 balance, uint256 amountOutMin, uint256 amountOut)
        internal
        view
        returns (uint256)
    {
        if (amountOut < amountOutMin) revert Router__InsufficientOutputAmount(amountOut, amountOutMin);

        uint256 balanceAfter = _balanceOf(tokenOut, to);

        if (balanceAfter < balance + amountOutMin) {
            revert Router__InsufficientAmountReceived(balance, balanceAfter, amountOutMin);
        }

        unchecked {
            return balanceAfter - balance;
        }
    }

    function _swapExact(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        address from,
        address to,
        bytes calldata routes,
        bool exactIn
    ) internal returns (uint256 totalIn, uint256 totalOut) {
        uint256 balance = _balanceOf(tokenOut, to);

        address recipient;
        (recipient, tokenOut) = tokenOut == address(0) ? (address(this), WNATIVE) : (to, tokenOut);

        if (tokenIn == address(0)) {
            tokenIn = WNATIVE;
            from = address(this);
            _wrap(amountIn);
        }

        (totalIn, totalOut) = _swap(tokenIn, tokenOut, amountIn, amountOut, from, recipient, routes, exactIn);

        if (exactIn) {
            if (totalIn != amountIn) revert Router__InvalidTotalIn(totalIn, amountIn);
        } else {
            if (totalIn > amountIn) revert Router__MaxAmountInExceeded(totalIn, amountIn);
        }

        if (recipient == address(this)) {
            _unwrap(totalOut);
            _transferNative(to, totalOut);

            totalOut = _verifySwap(address(0), to, balance, amountOut, totalOut);
        } else {
            totalOut = _verifySwap(tokenOut, to, balance, amountOut, totalOut);
        }

        unchecked {
            uint256 refund;
            if (from == address(this)) {
                uint256 unwrap = amountIn - totalIn;
                if (unwrap > 0) _unwrap(unwrap);

                refund = msg.value + unwrap - amountIn;
            } else {
                refund = msg.value;
            }

            if (refund > 0) _transferNative(msg.sender, refund);
        }
    }

    function _swap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        address from,
        address to,
        bytes calldata routes,
        bool exactIn
    ) internal returns (uint256 totalIn, uint256 totalOut) {
        address logic = _logic;
        if (logic == address(0)) revert Router__LogicNotSet();

        bytes32 key = _getKey(tokenIn, logic, from);

        _allowances[key] = amountIn;

        uint256 length = 256 + routes.length; // 32 * 6 + 32 + 32 + routes.length
        bytes memory data = new bytes(length);

        assembly {
            switch exactIn
            case 1 { mstore(data, 0xb69ca0d9) }
            default { mstore(data, 0x728fea6b) }

            mstore(add(data, 32), tokenIn)
            mstore(add(data, 64), tokenOut)
            mstore(add(data, 96), from)
            mstore(add(data, 128), to)
            mstore(add(data, 160), amountIn)
            mstore(add(data, 192), amountOut)
            mstore(add(data, 224), 224) // 32 * 6 + 32
            mstore(add(data, 256), routes.length)
            calldatacopy(add(data, 288), routes.offset, routes.length)

            switch call(gas(), logic, 0, add(data, 28), add(length, 4), 0, 64)
            case 0 {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }
            default {
                totalIn := mload(0)
                totalOut := mload(32)
            }
        }

        _allowances[key] = 0;
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
