// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {RouterIntegrationTest} from "./RouterIntegration.t.sol";

contract RouterIntegration100PercentTest is RouterIntegrationTest {
    function setUp() public override {
        FEE_BIPS = 1e4;
        super.setUp();
    }
}
