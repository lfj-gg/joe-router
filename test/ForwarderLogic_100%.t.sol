// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ForwarderLogicTest} from "./ForwarderLogic.t.sol";

contract ForwarderLogic100PercentTest is ForwarderLogicTest {
    function setUp() public override {
        FEE_BIPS = 1e4;
        super.setUp();
    }
}
