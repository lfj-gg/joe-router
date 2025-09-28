// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {TokenLib} from "../../src/libraries/TokenLib.sol";
import {IUV4Manager} from "../interfaces/IUV4Manager.sol";

interface IUnlockCallback {
    function unlockCallback(bytes calldata data) external returns (bytes memory d);
}

contract MockV4Manager {
    int128 _delta0;
    int128 _delta1;

    address _token0;
    address _token1;

    bool unlocked;
    address _token;
    uint256 _balance;

    mapping(address => int256) _balances;

    bytes public msgData;

    function test() public pure {} // To avoid this contract to be included in coverage

    function set(int128 delta0, int128 delta1) external {
        _delta0 = delta0;
        _delta1 = delta1;
    }

    function unlock(bytes calldata data) external returns (bytes memory d) {
        require(!unlocked, "Already unlocked");
        unlocked = true;

        d = IUnlockCallback(msg.sender).unlockCallback(data);

        require(_balances[_token0] == 0 && _balances[_token1] == 0, "Non zero balance");
        _token0 = address(0);
        _token1 = address(0);
        unlocked = false;
    }

    function swap(IUV4Manager.PoolKey memory key, IUV4Manager.SwapParams memory, bytes calldata)
        external
        returns (int256 delta)
    {
        require(unlocked, "Not unlocked");

        msgData = msg.data;

        _token0 = key.currency0;
        _token1 = key.currency1;
        _balances[key.currency0] += _delta0;
        _balances[key.currency1] += _delta1;

        int256 amount0 = _delta0;
        int256 amount1 = _delta1;
        assembly ("memory-safe") {
            delta := or(shl(128, amount0), and(sub(shl(128, 1), 1), amount1))
        }
    }

    function sync(address token) external {
        require(unlocked, "Not unlocked");
        _token = token;
        _balance = TokenLib.universalBalanceOf(token, address(this));
    }

    function settle() external payable returns (uint256 amount) {
        require(unlocked, "Not unlocked");
        amount = TokenLib.universalBalanceOf(_token, address(this)) - _balance;
        _balances[_token] += int256(amount);

        _token = address(0);
        _balance = 0;
    }

    function take(address token, address to, uint256 amount) external {
        require(unlocked, "Not unlocked");
        _balances[token] -= int256(amount);
        if (token == address(0)) TokenLib.transferNative(to, amount);
        else TokenLib.transfer(token, to, amount);
    }
}
