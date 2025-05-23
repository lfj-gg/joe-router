// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {FeeLogic} from "./FeeLogic.sol";
import {IForwarderLogic} from "./interfaces/IForwarderLogic.sol";
import {RouterLib} from "./libraries/RouterLib.sol";
import {TokenLib} from "./libraries/TokenLib.sol";

/**
 * @title ForwarderLogic
 * @notice Forwarder logic contract to call another router.
 * Note: this contract will not work with transfer tax tokens.
 */
contract ForwarderLogic is FeeLogic, IForwarderLogic {
    using EnumerableSet for EnumerableSet.AddressSet;
    using SafeERC20 for IERC20;

    address private immutable _router;

    EnumerableSet.AddressSet private _trustedRouter;
    mapping(address => bool) private _blacklist;

    constructor(address router, address protocolFeeReceiver, uint96 protocolFeeShare)
        FeeLogic(protocolFeeReceiver, protocolFeeShare)
    {
        if (router == address(0)) revert ForwarderLogic__InvalidRouter();
        _router = router;
    }

    /**
     * @dev Returns the length of the trusted routers.
     */
    function getTrustedRouterLength() external view override returns (uint256) {
        return _trustedRouter.length();
    }

    /**
     * @dev Returns the trusted router at the specified index.
     */
    function getTrustedRouterAt(uint256 index) external view override returns (address) {
        return _trustedRouter.at(index);
    }

    /**
     * @dev Returns the blacklist status of the account.
     */
    function isBlacklisted(address account) external view override returns (bool) {
        return _blacklist[account];
    }

    /**
     * @dev Swaps an exact amount of tokenIn for as much tokenOut as possible using an external router.
     * The function will simply forward the call to the router and return the amount of tokenIn and tokenOut swapped.
     *
     * Requirements:
     * - The caller must be the router.
     * - The third party router must be trusted.
     * - The data must be formatted using abi.encodePacked(approval, router, uint16(feePercent), routerData).
     * - The fee amount must be less than or equal to the amountIn.
     * - The router data must use at most `amountIn - feeAmount` of tokenIn.
     */
    function swapExactIn(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256,
        address from,
        address to,
        bytes calldata data
    ) external override returns (uint256, uint256) {
        if (msg.sender != _router) revert ForwarderLogic__OnlyRouter();
        if (_blacklist[from] || (from != to && _blacklist[to])) revert ForwarderLogic__Blacklisted();

        address approval = address(uint160(bytes20(data[0:20])));
        address router = address(uint160(bytes20(data[20:40])));
        uint256 feePercent = uint256(uint16(bytes2(data[40:42])));
        (address feeReceiver, bytes memory routerData) =
            feePercent == 0 ? (address(0), data[42:]) : (address(uint160(bytes20(data[42:62]))), data[62:]);

        RouterLib.transfer(_router, tokenIn, from, address(this), amountIn);

        uint256 feeAmount = (amountIn * feePercent) / BPS;
        _sendFee(tokenIn, address(this), feeReceiver, feeAmount);

        SafeERC20.forceApprove(IERC20(tokenIn), approval, amountIn - feeAmount);

        _call(router, routerData);

        SafeERC20.forceApprove(IERC20(tokenIn), approval, 0);

        uint256 balance = TokenLib.balanceOf(tokenOut, address(this));
        TokenLib.transfer(tokenOut, to, balance);

        return (amountIn, balance);
    }

    /**
     * @dev Reverts as there is no real way to only take the required amount of token in.
     */
    function swapExactOut(address, address, uint256, uint256, address, address, bytes calldata)
        external
        pure
        returns (uint256, uint256)
    {
        revert ForwarderLogic__NotImplemented();
    }

    /**
     * @dev Sweeps tokens from the contract to the recipient.
     *
     * Requirements:
     * - The caller must be the router owner.
     */
    function sweep(address token, address to, uint256 amount) external override {
        _checkSender();

        token == address(0) ? TokenLib.transferNative(to, amount) : TokenLib.transfer(token, to, amount);
    }

    /**
     * @dev Updates the trusted routers.
     *
     * Requirements:
     * - The caller must be the router owner.
     */
    function updateTrustedRouter(address router, bool add) external override {
        _checkSender();

        if (!(add ? _trustedRouter.add(router) : _trustedRouter.remove(router))) {
            revert ForwarderLogic__RouterUpdateFailed();
        }

        emit TrustedRouterUpdated(router, add);
    }

    /**
     * @dev Updates the blacklist.
     *
     * Requirements:
     * - The caller must be the router owner.
     */
    function updateBlacklist(address account, bool blacklisted) external override {
        _checkSender();

        _blacklist[account] = blacklisted;

        emit BlacklistUpdated(account, blacklisted);
    }

    /**
     * @dev Checks if the sender is the router's owner.
     *
     * Requirements:
     * - The sender must be the router's owner.
     */
    function _checkSender() internal view override {
        if (msg.sender != Ownable(_router).owner()) revert ForwarderLogic__OnlyRouterOwner();
    }

    /**
     * @dev Calls the target contract with the provided data.
     *
     * Requirements:
     * - The call must be successful.
     * - The target contract must have code.
     */
    function _call(address router, bytes memory data) private {
        if (!_trustedRouter.contains(router)) revert ForwarderLogic__UntrustedRouter();

        uint256 successState;
        assembly {
            successState := call(gas(), router, 0, add(data, 32), mload(data), 0, 0)

            if iszero(successState) {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }

            if iszero(returndatasize()) {
                if iszero(extcodesize(router)) {
                    mstore(0, 0x595e4957) // ForwarderLogic__NoCode()
                    revert(0x1c, 4)
                }
            }
        }
    }
}
