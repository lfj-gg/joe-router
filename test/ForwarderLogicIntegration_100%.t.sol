// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import "./ForwarderLogicIntegration.t.sol";

contract ForwarderLogicIntegration100PercentTest is ForwarderLogicIntegrationTest {
    function setUp() public override {
        FEE_BIPS = 1e4;
        super.setUp();
    }
}
