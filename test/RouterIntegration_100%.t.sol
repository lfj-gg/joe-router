// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import "./RouterIntegration.t.sol";

contract RouterIntegration100PercentTest is RouterIntegrationTest {
    function setUp() public override {
        FEE_BIPS = 1e4;
        super.setUp();
    }
}
