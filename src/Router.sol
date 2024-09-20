// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable2Step, Ownable} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {TokenLib} from "./libraries/TokenLib.sol";
import {RouterLib} from "./libraries/RouterLib.sol";
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

    fallback() external {
        RouterLib.validateAndTransfer(_allowances);
    }

    constructor(address wnative, address initialOwner) Ownable(initialOwner) {
        if (address(wnative).code.length == 0) revert Router__InvalidWnative();

        WNATIVE = wnative;
    }

    function getLogic() external view returns (address) {
        return _logic;
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
        if (amountIn == 0) amountIn = tokenIn == address(0) ? msg.value : TokenLib.balanceOf(tokenIn, msg.sender);

        _verifyParameters(tokenIn, tokenOut, amountIn, to, deadline);

        (totalIn, totalOut) = _swap(tokenIn, tokenOut, amountIn, amountOutMin, msg.sender, to, routes, true);

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

        (totalIn, totalOut) = _swap(tokenIn, tokenOut, amountInMax, amountOut, msg.sender, to, routes, false);

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
            _swap(tokenIn, tokenOut, amountIn, amountOut, msg.sender, msg.sender, routes, exactIn);

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

        uint256 balanceAfter = TokenLib.universalBalanceOf(tokenOut, to);

        if (balanceAfter < balance + amountOutMin) {
            revert Router__InsufficientAmountReceived(balance, balanceAfter, amountOutMin);
        }

        unchecked {
            return balanceAfter - balance;
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
        uint256 balance = TokenLib.universalBalanceOf(tokenOut, to);

        address recipient;
        (recipient, tokenOut) = tokenOut == address(0) ? (address(this), WNATIVE) : (to, tokenOut);

        if (tokenIn == address(0)) {
            tokenIn = WNATIVE;
            from = address(this);
            TokenLib.wrap(WNATIVE, amountIn);
        }

        (totalIn, totalOut) = RouterLib.swap(
            _allowances, tokenIn, tokenOut, amountIn, amountOut, from, recipient, routes, exactIn, _logic
        );

        if (exactIn) {
            if (totalIn != amountIn) revert Router__InvalidTotalIn(totalIn, amountIn);
        } else {
            if (totalIn > amountIn) revert Router__MaxAmountInExceeded(totalIn, amountIn);
        }

        if (recipient == address(this)) {
            TokenLib.unwrap(WNATIVE, totalOut);
            TokenLib.transferNative(to, totalOut);

            totalOut = _verifySwap(address(0), to, balance, amountOut, totalOut);
        } else {
            totalOut = _verifySwap(tokenOut, to, balance, amountOut, totalOut);
        }

        unchecked {
            uint256 refund;
            if (from == address(this)) {
                uint256 unwrap = amountIn - totalIn;
                if (unwrap > 0) TokenLib.unwrap(WNATIVE, unwrap);

                refund = msg.value + unwrap - amountIn;
            } else {
                refund = msg.value;
            }

            if (refund > 0) TokenLib.transferNative(msg.sender, refund);
        }
    }
}
