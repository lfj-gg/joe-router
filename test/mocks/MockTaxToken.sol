// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {MockERC20} from "./MockERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

contract MockTaxToken is MockERC20 {
    uint256 public tax;

    constructor(string memory name, string memory symbol, uint8 decimals_) MockERC20(name, symbol, decimals_) {}

    function setTax(uint256 tax_) external {
        tax = tax_;
    }

    function _update(address from, address to, uint256 value) internal override {
        uint256 taxAmount = Math.mulDiv(value, tax, 1e18, Math.Rounding.Ceil);

        if (taxAmount > 0) {
            value -= taxAmount;
            super._update(from, address(0), taxAmount);
        }

        super._update(from, to, value);
    }
}
