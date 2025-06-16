// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import "../src/ForwarderLogic.sol";
import "../src/Router.sol";
import "./mocks/MockERC20.sol";

contract ForwarderLogicIntegrationTest is Test {
    Router public router;
    ForwarderLogic public forwarder;

    address constant USDC = 0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E;
    address constant WAVAX = 0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7;
    address constant AVAX = address(0);

    uint256 constant BPS = 1e4;
    uint256 constant DEFAULT_FEE = 0.1e4;

    uint256 constant USDC_AMOUNT = 3500e6;
    uint256 constant AVAX_AMOUNT = 100e18;

    address constant ODOS = 0x88de50B233052e4Fb783d4F6db78Cc34fEa3e9FC;
    bytes ODOS_USDC_AVAX = vm.parseBytes(
        "0x83bd37f90001b97ef9ef8734c71904d8002f8b6bc66dd9c48a6e0001b31f66aa3c1e785363f0875a1b74e27b85fd66c704d09dc30009053bf3a08d425580000147ae0001F82aB7d84F27D8d2e7A6B2859b3f7835550e14F0000000012e234DAe75C793f67A35089C9d99245E1C58470b3f40db9c110505140102a0ca90030101010102001e010520248c030101010302001e0152626a710b010104020001042b06d50b010105020001173a74720b020006020001587951a50b020007020000110300020807135fb3260b000a0a08010615040c010c0800041103000d0e07433555a4030101010f0e011e0793aedfda03010101100e011e060b0101110e0100030101000912011e08150101000b1301ff00000000000e0100ab771e9288e0aa97e11557e6654c3a9665b97ef9ef8734c71904d8002f8b6bc66dd9c48a6ef4003f4efbe8691b60249e6afbd307abe7758adbfae3f424a0a47706811521e3ee268f00cfb5c45ea20c959b19f114e9c2d81547734cdc1110bd773d804226ca4edb38e7ef56d16d16e92dc3223347a0184b487c7e811f1d9734d49e78293e00b3768079152b9d0fdc40c096757f570a51e494bd4b943e50d5a37dc5c9a396a03dd1136fc76a1a02b1c88ffa4d8fbe532f765f9e6c10051e917caf85dd2acaacf9ab5dd8f239e2916f54e8b1de171aa9c04aa13655c211bbe9f63059a4a5a5e0c558c7e410412d989702230a8ea53601f5cd2dc00fdbc13d4df4a8c749d5c2bdffac6ce2bfdb6640f4f80f226bc10bab7c05d54fc5cb6e4ad87c6f5db3b807c94bb89c52fe15c2695f1f920da45c30aae47d11de51007af9d4fcc0eb12eef6aa248225a3e6ac1b021a0ac52b50b7545627a5162f82a992c33b87adc75187b218bc78d84ba0c46dfe32cf2895a19939c86b81a77700000000"
    );
    bytes ODOS_AVAX_USDC = vm.parseBytes(
        "0x83bd37f90001b31f66aa3c1e785363f0875a1b74e27b85fd66c70001b97ef9ef8734c71904d8002f8b6bc66dd9c48a6e09056bc75e2d6310000004d7de403b0147ae0001F82aB7d84F27D8d2e7A6B2859b3f7835550e14F0000000012e234DAe75C793f67A35089C9d99245E1C58470b3f40db9c030102040127337c780b01010102010015010101030201ff000000000000000000fae3f424a0a47706811521e3ee268f00cfb5c45eb31f66aa3c1e785363f0875a1b74e27b85fd66c7864d4e5ee7318e97483db7eb0912e09f161516ea00000000"
    );

    address constant OKX = 0x1daC23e41Fc8ce857E86fD8C1AE5b6121C67D96d;
    address constant OKX_APPROVAL = 0x40aA958dd87FC8305b97f2BA922CDdCa374bcD7f;
    bytes OKX_USDC_AVAX = vm.parseBytes(
        "0xb80c2f090000000000000000000000000000000000000000000000000000000000019ff4000000000000000000000000b97ef9ef8734c71904d8002f8b6bc66dd9c48a6e000000000000000000000000b31f66aa3c1e785363f0875a1b74e27b85fd66c700000000000000000000000000000000000000000000000000000000d09dc3000000000000000000000000000000000000000000000000029de94a9f297518c00000000000000000000000000000000000000000000000000000000067868b3b000000000000000000000000000000000000000000000000000000000000012000000000000000000000000000000000000000000000000000000000000001800000000000000000000000000000000000000000000000000000000000000b000000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000009c76524000000000000000000000000000000000000000000000000000000000342770c00000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000003c00000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000a00000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000016000000000000000000000000000000000000000000000000000000000000001c0000000000000000000000000b97ef9ef8734c71904d8002f8b6bc66dd9c48a6e00000000000000000000000000000000000000000000000000000000000000020000000000000000000000006667c8dc9fbfec411e7c1ee2b24de960149f930f000000000000000000000000be882fb094143b59dc5335d32cecb711570ebdd40000000000000000000000000000000000000000000000000000000000000002000000000000000000000000864d4e5ee7318e97483db7eb0912e09f161516ea000000000000000000000000be882fb094143b59dc5335d32cecb711570ebdd40000000000000000000000000000000000000000000000000000000000000002000000000000000000001c20864d4e5ee7318e97483db7eb0912e09f161516ea800000000000000000000af0fae3f424a0a47706811521e3ee268f00cfb5c45e0000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000c0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000060000000000000000000000000b97ef9ef8734c71904d8002f8b6bc66dd9c48a6e000000000000000000000000b31f66aa3c1e785363f0875a1b74e27b85fd66c700000000000000000000000000000000000000000000000000000000000001f400000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000024000000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000e000000000000000000000000000000000000000000000000000000000000001200000000000000000000000000000000000000000000000000000000000000160000000000000000000000000b97ef9ef8734c71904d8002f8b6bc66dd9c48a6e00000000000000000000000000000000000000000000000000000000000000010000000000000000000000008009858707810928cce2c3526b78a4eb8043888c00000000000000000000000000000000000000000000000000000000000000010000000000000000000000008009858707810928cce2c3526b78a4eb8043888c0000000000000000000000000000000000000000000000000000000000000001000000000000000000002710ed9e3f98bbed560e66b89aac922e29d4596a9642000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000040000000000000000000000000b97ef9ef8734c71904d8002f8b6bc66dd9c48a6e00000000000000000000000049d5c2bdffac6ce2bfdb6640f4f80f226bc10bab00000000000000000000000000000000000000000000000000000000000000a00000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000016000000000000000000000000000000000000000000000000000000000000001c000000000000000000000000049d5c2bdffac6ce2bfdb6640f4f80f226bc10bab0000000000000000000000000000000000000000000000000000000000000002000000000000000000000000be882fb094143b59dc5335d32cecb711570ebdd400000000000000000000000047b5bc2c49ad25dfa6d7363c5e9b28ef804e11850000000000000000000000000000000000000000000000000000000000000002000000000000000000000000be882fb094143b59dc5335d32cecb711570ebdd4000000000000000000000000fe15c2695f1f920da45c30aae47d11de51007af900000000000000000000000000000000000000000000000000000000000000020000000000000000000017707b602f98d71715916e7c963f51bfebc754ade2d0000000000000000000000fa0fe15c2695f1f920da45c30aae47d11de51007af900000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000012000000000000000000000000000000000000000000000000000000000000000c000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000006000000000000000000000000049d5c2bdffac6ce2bfdb6640f4f80f226bc10bab000000000000000000000000b31f66aa3c1e785363f0875a1b74e27b85fd66c700000000000000000000000000000000000000000000000000000000000001f40000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000001e0000000000000000000000000000000000000000000000000000000000000000"
    );
    bytes OKX_AVAX_USDC = vm.parseBytes(
        "0xb80c2f090000000000000000000000000000000000000000000000000000000000019ff4000000000000000000000000b31f66aa3c1e785363f0875a1b74e27b85fd66c7000000000000000000000000b97ef9ef8734c71904d8002f8b6bc66dd9c48a6e0000000000000000000000000000000000000000000000056bc75e2d63100000000000000000000000000000000000000000000000000000000000006be6f5e80000000000000000000000000000000000000000000000000000000067868b3c00000000000000000000000000000000000000000000000000000000000001200000000000000000000000000000000000000000000000000000000000000160000000000000000000000000000000000000000000000000000000000000046000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000056bc75e2d63100000000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000e000000000000000000000000000000000000000000000000000000000000001200000000000000000000000000000000000000000000000000000000000000160000000000000000000000000b31f66aa3c1e785363f0875a1b74e27b85fd66c70000000000000000000000000000000000000000000000000000000000000001000000000000000000000000be882fb094143b59dc5335d32cecb711570ebdd40000000000000000000000000000000000000000000000000000000000000001000000000000000000000000be882fb094143b59dc5335d32cecb711570ebdd40000000000000000000000000000000000000000000000000000000000000001000000000000000000002710fae3f424a0a47706811521e3ee268f00cfb5c45e0000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000c0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000060000000000000000000000000b31f66aa3c1e785363f0875a1b74e27b85fd66c7000000000000000000000000b97ef9ef8734c71904d8002f8b6bc66dd9c48a6e00000000000000000000000000000000000000000000000000000000000001f40000000000000000000000000000000000000000000000000000000000000000"
    );

    address constant JAR = 0x45A62B090DF48243F12A21897e7ed91863E2c86b;
    address constant JAR_LOGIC = 0xB35033d71cF5E13cAB5eB8618260F94363Dff9Cf;
    address constant LB22_AVAX_USDC_PAIR = 0xD446eb1660F766d533BeCeEf890Df7A69d26f7d1;
    bytes JAR_USDC_AVAX = abi.encodeWithSelector(
        0xf1910f70,
        JAR_LOGIC,
        USDC,
        WAVAX,
        USDC_AMOUNT,
        AVAX_AMOUNT * 90 / 100,
        0x2e234DAe75C793f67A35089C9d99245E1C58470b,
        type(uint256).max,
        abi.encodePacked(
            uint8(2), uint8(0), USDC, WAVAX, LB22_AVAX_USDC_PAIR, uint16(1e4), uint8(3), uint8(0), uint8(0), uint8(1)
        )
    );
    bytes JAR_AVAX_USDC = abi.encodeWithSelector(
        0xf1910f70,
        JAR_LOGIC,
        WAVAX,
        USDC,
        AVAX_AMOUNT,
        USDC_AMOUNT * 90 / 100,
        0x2e234DAe75C793f67A35089C9d99245E1C58470b,
        type(uint256).max,
        abi.encodePacked(
            uint8(2), uint8(0), WAVAX, USDC, LB22_AVAX_USDC_PAIR, uint16(1e4), uint8(3), uint8(1), uint8(0), uint8(1)
        )
    );

    address alice = makeAddr("alice");
    address feeReceiver = makeAddr("feeReceiver");
    address thirdPartyFeeReceiver = makeAddr("thirdPartyFeeReceiver");

    uint16 FEE_BIPS = 0.15e4; // 15%

    receive() external payable {}

    function setUp() public virtual {
        vm.createSelectFork(StdChains.getChain("avalanche").rpcUrl, 55797609);

        router = new Router(WAVAX, address(this));
        forwarder = new ForwarderLogic(address(router), feeReceiver, FEE_BIPS);

        router.updateRouterLogic(address(forwarder), true);
        router.updateRouterLogic(address(JAR_LOGIC), true);

        forwarder.updateTrustedRouter(ODOS, true);
        forwarder.updateTrustedRouter(OKX, true);
        forwarder.updateTrustedRouter(JAR, true);
    }

    function test_ODOS() public {
        deal(USDC, address(this), USDC_AMOUNT);
        deal(WAVAX, address(this), AVAX_AMOUNT);

        IERC20(USDC).approve(address(router), USDC_AMOUNT);
        IERC20(WAVAX).approve(address(router), AVAX_AMOUNT);

        IRouter(router).swapExactIn(
            address(forwarder),
            USDC,
            WAVAX,
            USDC_AMOUNT,
            AVAX_AMOUNT / 2,
            alice,
            block.timestamp,
            abi.encodePacked(ODOS, ODOS, uint16(0), ODOS_USDC_AVAX)
        );

        assertEq(IERC20(USDC).balanceOf(address(this)), 0, "test_ODOS::1");
        assertGe(IERC20(WAVAX).balanceOf(alice), AVAX_AMOUNT / 2, "test_ODOS::2");

        IRouter(router).swapExactIn(
            address(forwarder),
            WAVAX,
            USDC,
            AVAX_AMOUNT,
            USDC_AMOUNT / 2,
            alice,
            block.timestamp,
            abi.encodePacked(ODOS, ODOS, uint16(0), ODOS_AVAX_USDC)
        );

        assertEq(IERC20(WAVAX).balanceOf(address(this)), 0, "test_ODOS::3");
        assertGe(IERC20(USDC).balanceOf(alice), USDC_AMOUNT / 2, "test_ODOS::4");
    }

    function test_ODOS_Native() public {
        deal(USDC, address(this), USDC_AMOUNT);
        deal(address(this), AVAX_AMOUNT);

        IERC20(USDC).approve(address(router), USDC_AMOUNT);

        IRouter(router).swapExactIn(
            address(forwarder),
            USDC,
            AVAX,
            USDC_AMOUNT,
            AVAX_AMOUNT / 2,
            alice,
            block.timestamp,
            abi.encodePacked(ODOS, ODOS, uint16(0), ODOS_USDC_AVAX)
        );

        assertEq(IERC20(USDC).balanceOf(address(this)), 0, "test_ODOS_Native::1");
        assertGe(alice.balance, AVAX_AMOUNT / 2, "test_ODOS_Native::2");

        IRouter(router).swapExactIn{value: AVAX_AMOUNT}(
            address(forwarder),
            AVAX,
            USDC,
            AVAX_AMOUNT,
            USDC_AMOUNT / 2,
            alice,
            block.timestamp,
            abi.encodePacked(ODOS, ODOS, uint16(0), ODOS_AVAX_USDC)
        );

        assertEq(address(this).balance, 0, "test_ODOS_Native::3");
        assertGe(IERC20(USDC).balanceOf(alice), USDC_AMOUNT / 2, "test_ODOS_Native::4");
    }

    function test_ODOS_WithFeeIn() public {
        uint256 usdcAmountWithFee = _getAmountWithFee(USDC_AMOUNT, DEFAULT_FEE);
        uint256 avaxAmountWithFee = _getAmountWithFee(AVAX_AMOUNT, DEFAULT_FEE);

        deal(USDC, address(this), usdcAmountWithFee);
        deal(WAVAX, address(this), avaxAmountWithFee);

        IERC20(USDC).approve(address(router), usdcAmountWithFee);
        IERC20(WAVAX).approve(address(router), avaxAmountWithFee);

        IRouter(router).swapExactIn(
            address(forwarder),
            USDC,
            WAVAX,
            usdcAmountWithFee,
            AVAX_AMOUNT / 2,
            alice,
            block.timestamp,
            abi.encodePacked(ODOS, ODOS, uint16(DEFAULT_FEE), uint8(1), thirdPartyFeeReceiver, ODOS_USDC_AVAX)
        );

        uint256 feeAmount = (usdcAmountWithFee * DEFAULT_FEE) / BPS;
        uint256 protocolFeeAmount = (feeAmount * FEE_BIPS) / BPS;

        assertEq(IERC20(USDC).balanceOf(address(this)), 0, "test_ODOS_WithFeeIn::1");
        assertEq(IERC20(USDC).balanceOf(feeReceiver), protocolFeeAmount, "test_ODOS_WithFeeIn::2");
        assertEq(IERC20(USDC).balanceOf(thirdPartyFeeReceiver), feeAmount - protocolFeeAmount, "test_ODOS_WithFeeIn::3");
        assertGe(IERC20(WAVAX).balanceOf(alice), AVAX_AMOUNT / 2, "test_ODOS_WithFeeIn::4");

        IRouter(router).swapExactIn(
            address(forwarder),
            WAVAX,
            USDC,
            avaxAmountWithFee,
            USDC_AMOUNT / 2,
            alice,
            block.timestamp,
            abi.encodePacked(ODOS, ODOS, uint16(DEFAULT_FEE), uint8(1), thirdPartyFeeReceiver, ODOS_AVAX_USDC)
        );

        feeAmount = (avaxAmountWithFee * DEFAULT_FEE) / BPS;
        protocolFeeAmount = (feeAmount * FEE_BIPS) / BPS;

        assertEq(IERC20(WAVAX).balanceOf(address(this)), 0, "test_ODOS_WithFeeIn::5");
        assertEq(IERC20(WAVAX).balanceOf(feeReceiver), protocolFeeAmount, "test_ODOS_WithFeeIn::6");
        assertEq(
            IERC20(WAVAX).balanceOf(thirdPartyFeeReceiver), feeAmount - protocolFeeAmount, "test_ODOS_WithFeeIn::7"
        );
        assertGe(IERC20(USDC).balanceOf(alice), USDC_AMOUNT / 2, "test_ODOS_WithFeeIn::8");
    }

    function test_ODOS_NativeWithFeeIn() public {
        uint256 usdcAmountWithFee = _getAmountWithFee(USDC_AMOUNT, DEFAULT_FEE);
        uint256 avaxAmountWithFee = _getAmountWithFee(AVAX_AMOUNT, DEFAULT_FEE);

        deal(USDC, address(this), usdcAmountWithFee);
        deal(address(this), avaxAmountWithFee);

        IERC20(USDC).approve(address(router), usdcAmountWithFee);

        IRouter(router).swapExactIn(
            address(forwarder),
            USDC,
            AVAX,
            usdcAmountWithFee,
            AVAX_AMOUNT / 2,
            alice,
            block.timestamp,
            abi.encodePacked(ODOS, ODOS, uint16(DEFAULT_FEE), uint8(1), thirdPartyFeeReceiver, ODOS_USDC_AVAX)
        );

        uint256 feeAmount = (usdcAmountWithFee * DEFAULT_FEE) / BPS;
        uint256 protocolFeeAmount = (feeAmount * FEE_BIPS) / BPS;

        assertEq(IERC20(USDC).balanceOf(address(this)), 0, "test_ODOS_NativeWithFeeIn::1");
        assertEq(IERC20(USDC).balanceOf(feeReceiver), protocolFeeAmount, "test_ODOS_NativeWithFeeIn::2");
        assertEq(
            IERC20(USDC).balanceOf(thirdPartyFeeReceiver), feeAmount - protocolFeeAmount, "test_ODOS_NativeWithFeeIn::3"
        );
        assertGe(alice.balance, AVAX_AMOUNT / 2, "test_ODOS_NativeWithFeeIn::4");

        IRouter(router).swapExactIn{value: avaxAmountWithFee}(
            address(forwarder),
            AVAX,
            USDC,
            avaxAmountWithFee,
            USDC_AMOUNT / 2,
            alice,
            block.timestamp,
            abi.encodePacked(ODOS, ODOS, uint16(DEFAULT_FEE), uint8(1), thirdPartyFeeReceiver, ODOS_AVAX_USDC)
        );

        feeAmount = (avaxAmountWithFee * DEFAULT_FEE) / BPS;
        protocolFeeAmount = (feeAmount * FEE_BIPS) / BPS;

        assertEq(address(this).balance, 0, "test_ODOS_NativeWithFeeIn::5");
        assertEq(IERC20(WAVAX).balanceOf(feeReceiver), protocolFeeAmount, "test_ODOS_NativeWithFeeIn::6");
        assertEq(
            IERC20(WAVAX).balanceOf(thirdPartyFeeReceiver),
            feeAmount - protocolFeeAmount,
            "test_ODOS_NativeWithFeeIn::7"
        );
        assertGe(IERC20(USDC).balanceOf(alice), USDC_AMOUNT / 2, "test_ODOS_NativeWithFeeIn::8");
    }

    function test_ODOS_WithFeeOut() public {
        deal(USDC, address(this), USDC_AMOUNT);
        deal(WAVAX, address(this), AVAX_AMOUNT);

        IERC20(USDC).approve(address(router), USDC_AMOUNT);
        IERC20(WAVAX).approve(address(router), AVAX_AMOUNT);

        (, uint256 avaxAmountOut) = IRouter(router).swapExactIn(
            address(forwarder),
            USDC,
            WAVAX,
            USDC_AMOUNT,
            AVAX_AMOUNT / 2,
            alice,
            block.timestamp,
            abi.encodePacked(ODOS, ODOS, uint16(DEFAULT_FEE), uint8(0), thirdPartyFeeReceiver, ODOS_USDC_AVAX)
        );

        uint256 feeAmount = (avaxAmountOut * DEFAULT_FEE) / (BPS - DEFAULT_FEE);
        uint256 protocolFeeAmount = (feeAmount * FEE_BIPS) / BPS;

        assertEq(IERC20(USDC).balanceOf(address(this)), 0, "test_ODOS_WithFeeOut::1");
        assertEq(IERC20(WAVAX).balanceOf(alice), avaxAmountOut, "test_ODOS_WithFeeOut::2");
        assertGe(avaxAmountOut, AVAX_AMOUNT / 2, "test_ODOS_WithFeeOut::3");
        assertEq(IERC20(WAVAX).balanceOf(feeReceiver), protocolFeeAmount, "test_ODOS_WithFeeOut::4");
        assertEq(
            IERC20(WAVAX).balanceOf(thirdPartyFeeReceiver), feeAmount - protocolFeeAmount, "test_ODOS_WithFeeOut::5"
        );

        (, uint256 usdcAmountOut) = IRouter(router).swapExactIn(
            address(forwarder),
            WAVAX,
            USDC,
            AVAX_AMOUNT,
            USDC_AMOUNT / 2,
            alice,
            block.timestamp,
            abi.encodePacked(ODOS, ODOS, uint16(DEFAULT_FEE), uint8(0), thirdPartyFeeReceiver, ODOS_AVAX_USDC)
        );

        feeAmount = (usdcAmountOut * DEFAULT_FEE) / (BPS - DEFAULT_FEE);
        protocolFeeAmount = (feeAmount * FEE_BIPS) / BPS;

        assertEq(IERC20(WAVAX).balanceOf(address(this)), 0, "test_ODOS_WithFeeOut::6");
        assertEq(IERC20(USDC).balanceOf(alice), usdcAmountOut, "test_ODOS_WithFeeOut::7");
        assertGe(usdcAmountOut, USDC_AMOUNT / 2, "test_ODOS_WithFeeOut::8");
        assertEq(IERC20(USDC).balanceOf(feeReceiver), protocolFeeAmount, "test_ODOS_WithFeeOut::9");
        assertEq(
            IERC20(USDC).balanceOf(thirdPartyFeeReceiver), feeAmount - protocolFeeAmount, "test_ODOS_WithFeeOut::10"
        );
    }

    function test_ODOS_NativeWithFeeOut() public {
        deal(USDC, address(this), USDC_AMOUNT);
        deal(address(this), AVAX_AMOUNT);

        IERC20(USDC).approve(address(router), USDC_AMOUNT);

        (, uint256 avaxAmountOut) = IRouter(router).swapExactIn(
            address(forwarder),
            USDC,
            AVAX,
            USDC_AMOUNT,
            AVAX_AMOUNT / 2,
            alice,
            block.timestamp,
            abi.encodePacked(ODOS, ODOS, uint16(DEFAULT_FEE), uint8(0), thirdPartyFeeReceiver, ODOS_USDC_AVAX)
        );

        uint256 feeAmount = (avaxAmountOut * DEFAULT_FEE) / (BPS - DEFAULT_FEE);
        uint256 protocolFeeAmount = (feeAmount * FEE_BIPS) / BPS;

        assertEq(IERC20(USDC).balanceOf(address(this)), 0, "test_ODOS_NativeWithFeeOut::1");
        assertEq(alice.balance, avaxAmountOut, "test_ODOS_NativeWithFeeOut::2");
        assertGe(avaxAmountOut, AVAX_AMOUNT / 2, "test_ODOS_NativeWithFeeOut::3");
        assertEq(IERC20(WAVAX).balanceOf(feeReceiver), protocolFeeAmount, "test_ODOS_NativeWithFeeOut::4");
        assertEq(
            IERC20(WAVAX).balanceOf(thirdPartyFeeReceiver),
            feeAmount - protocolFeeAmount,
            "test_ODOS_NativeWithFeeOut::5"
        );

        (, uint256 usdcAmountOut) = IRouter(router).swapExactIn{value: AVAX_AMOUNT}(
            address(forwarder),
            AVAX,
            USDC,
            AVAX_AMOUNT,
            USDC_AMOUNT / 2,
            alice,
            block.timestamp,
            abi.encodePacked(ODOS, ODOS, uint16(DEFAULT_FEE), uint8(0), thirdPartyFeeReceiver, ODOS_AVAX_USDC)
        );

        feeAmount = (usdcAmountOut * DEFAULT_FEE) / (BPS - DEFAULT_FEE);
        protocolFeeAmount = (feeAmount * FEE_BIPS) / BPS;

        assertEq(address(this).balance, 0, "test_ODOS_NativeWithFeeOut::6");
        assertEq(IERC20(USDC).balanceOf(alice), usdcAmountOut, "test_ODOS_NativeWithFeeOut::7");
        assertGe(usdcAmountOut, USDC_AMOUNT / 2, "test_ODOS_NativeWithFeeOut::8");
        assertEq(IERC20(USDC).balanceOf(feeReceiver), protocolFeeAmount, "test_ODOS_NativeWithFeeOut::9");
        assertEq(
            IERC20(USDC).balanceOf(thirdPartyFeeReceiver),
            feeAmount - protocolFeeAmount,
            "test_ODOS_NativeWithFeeOut::10"
        );
    }

    function test_OKX() public {
        deal(USDC, address(this), USDC_AMOUNT);
        deal(WAVAX, address(this), AVAX_AMOUNT);

        IERC20(USDC).approve(address(router), USDC_AMOUNT);
        IERC20(WAVAX).approve(address(router), AVAX_AMOUNT);

        IRouter(router).swapExactIn(
            address(forwarder),
            USDC,
            WAVAX,
            USDC_AMOUNT,
            AVAX_AMOUNT / 2,
            alice,
            block.timestamp,
            abi.encodePacked(OKX_APPROVAL, OKX, uint16(0), OKX_USDC_AVAX)
        );

        assertEq(IERC20(USDC).balanceOf(address(this)), 0, "test_OKX::1");
        assertGe(IERC20(WAVAX).balanceOf(alice), AVAX_AMOUNT / 2, "test_OKX::2");

        IRouter(router).swapExactIn(
            address(forwarder),
            WAVAX,
            USDC,
            AVAX_AMOUNT,
            USDC_AMOUNT / 2,
            alice,
            block.timestamp,
            abi.encodePacked(OKX_APPROVAL, OKX, uint16(0), OKX_AVAX_USDC)
        );

        assertEq(IERC20(WAVAX).balanceOf(address(this)), 0, "test_OKX::3");
        assertGe(IERC20(USDC).balanceOf(alice), USDC_AMOUNT / 2, "test_OKX::4");
    }

    function test_OKX_Native() public {
        deal(USDC, address(this), USDC_AMOUNT);
        deal(address(this), AVAX_AMOUNT);

        IERC20(USDC).approve(address(router), USDC_AMOUNT);

        IRouter(router).swapExactIn(
            address(forwarder),
            USDC,
            AVAX,
            USDC_AMOUNT,
            AVAX_AMOUNT / 2,
            alice,
            block.timestamp,
            abi.encodePacked(OKX_APPROVAL, OKX, uint16(0), OKX_USDC_AVAX)
        );

        assertEq(IERC20(USDC).balanceOf(address(this)), 0, "test_OKX_Native::1");
        assertGe(alice.balance, AVAX_AMOUNT / 2, "test_OKX_Native::2");

        IRouter(router).swapExactIn{value: AVAX_AMOUNT}(
            address(forwarder),
            AVAX,
            USDC,
            AVAX_AMOUNT,
            USDC_AMOUNT / 2,
            alice,
            block.timestamp,
            abi.encodePacked(OKX_APPROVAL, OKX, uint16(0), OKX_AVAX_USDC)
        );

        assertEq(address(this).balance, 0, "test_OKX_Native::3");
        assertGe(IERC20(USDC).balanceOf(alice), USDC_AMOUNT / 2, "test_OKX_Native::4");
    }

    function test_OKX_WithFeeIn() public {
        uint256 usdcAmountWithFee = _getAmountWithFee(USDC_AMOUNT, DEFAULT_FEE);
        uint256 avaxAmountWithFee = _getAmountWithFee(AVAX_AMOUNT, DEFAULT_FEE);

        deal(USDC, address(this), usdcAmountWithFee);
        deal(WAVAX, address(this), avaxAmountWithFee);

        IERC20(USDC).approve(address(router), usdcAmountWithFee);
        IERC20(WAVAX).approve(address(router), avaxAmountWithFee);

        IRouter(router).swapExactIn(
            address(forwarder),
            USDC,
            WAVAX,
            usdcAmountWithFee,
            AVAX_AMOUNT / 2,
            alice,
            block.timestamp,
            abi.encodePacked(OKX_APPROVAL, OKX, uint16(DEFAULT_FEE), uint8(1), thirdPartyFeeReceiver, OKX_USDC_AVAX)
        );

        uint256 feeAmount = (usdcAmountWithFee * DEFAULT_FEE) / BPS;
        uint256 protocolFeeAmount = (feeAmount * FEE_BIPS) / BPS;

        assertEq(IERC20(USDC).balanceOf(address(this)), 0, "test_OKX_WithFeeIn::1");
        assertEq(IERC20(USDC).balanceOf(feeReceiver), protocolFeeAmount, "test_OKX_WithFeeIn::2");
        assertEq(IERC20(USDC).balanceOf(thirdPartyFeeReceiver), feeAmount - protocolFeeAmount, "test_OKX_WithFeeIn::3");
        assertGe(IERC20(WAVAX).balanceOf(alice), AVAX_AMOUNT / 2, "test_OKX_WithFeeIn::4");

        IRouter(router).swapExactIn(
            address(forwarder),
            WAVAX,
            USDC,
            avaxAmountWithFee,
            USDC_AMOUNT / 2,
            alice,
            block.timestamp,
            abi.encodePacked(OKX_APPROVAL, OKX, uint16(DEFAULT_FEE), uint8(1), thirdPartyFeeReceiver, OKX_AVAX_USDC)
        );

        feeAmount = (avaxAmountWithFee * DEFAULT_FEE) / BPS;
        protocolFeeAmount = (feeAmount * FEE_BIPS) / BPS;

        assertEq(IERC20(WAVAX).balanceOf(address(this)), 0, "test_OKX_WithFeeIn::5");
        assertEq(IERC20(WAVAX).balanceOf(feeReceiver), protocolFeeAmount, "test_OKX_WithFeeIn::6");
        assertEq(IERC20(WAVAX).balanceOf(thirdPartyFeeReceiver), feeAmount - protocolFeeAmount, "test_OKX_WithFeeIn::7");
        assertGe(IERC20(USDC).balanceOf(alice), USDC_AMOUNT / 2, "test_OKX_WithFeeIn::8");
    }

    function test_OKX_NativeWithFeeIn() public {
        uint256 usdcAmountWithFee = _getAmountWithFee(USDC_AMOUNT, DEFAULT_FEE);
        uint256 avaxAmountWithFee = _getAmountWithFee(AVAX_AMOUNT, DEFAULT_FEE);

        deal(USDC, address(this), usdcAmountWithFee);
        deal(address(this), avaxAmountWithFee);

        IERC20(USDC).approve(address(router), usdcAmountWithFee);

        IRouter(router).swapExactIn(
            address(forwarder),
            USDC,
            AVAX,
            usdcAmountWithFee,
            AVAX_AMOUNT / 2,
            alice,
            block.timestamp,
            abi.encodePacked(OKX_APPROVAL, OKX, uint16(DEFAULT_FEE), uint8(1), thirdPartyFeeReceiver, OKX_USDC_AVAX)
        );

        uint256 feeAmount = (usdcAmountWithFee * DEFAULT_FEE) / BPS;
        uint256 protocolFeeAmount = (feeAmount * FEE_BIPS) / BPS;

        assertEq(IERC20(USDC).balanceOf(address(this)), 0, "test_OKX_NativeWithFeeIn::1");
        assertEq(IERC20(USDC).balanceOf(feeReceiver), protocolFeeAmount, "test_OKX_NativeWithFeeIn::2");
        assertEq(
            IERC20(USDC).balanceOf(thirdPartyFeeReceiver), feeAmount - protocolFeeAmount, "test_OKX_NativeWithFeeIn::3"
        );
        assertGe(alice.balance, AVAX_AMOUNT / 2, "test_OKX_NativeWithFeeIn::4");

        IRouter(router).swapExactIn{value: avaxAmountWithFee}(
            address(forwarder),
            AVAX,
            USDC,
            avaxAmountWithFee,
            USDC_AMOUNT / 2,
            alice,
            block.timestamp,
            abi.encodePacked(OKX_APPROVAL, OKX, uint16(DEFAULT_FEE), uint8(1), thirdPartyFeeReceiver, OKX_AVAX_USDC)
        );

        feeAmount = (avaxAmountWithFee * DEFAULT_FEE) / BPS;
        protocolFeeAmount = (feeAmount * FEE_BIPS) / BPS;

        assertEq(address(this).balance, 0, "test_OKX_NativeWithFeeIn::5");
        assertEq(IERC20(WAVAX).balanceOf(feeReceiver), protocolFeeAmount, "test_OKX_NativeWithFeeIn::6");
        assertEq(
            IERC20(WAVAX).balanceOf(thirdPartyFeeReceiver), feeAmount - protocolFeeAmount, "test_OKX_NativeWithFeeIn::7"
        );
        assertGe(IERC20(USDC).balanceOf(alice), USDC_AMOUNT / 2, "test_OKX_NativeWithFeeIn::8");
    }

    function test_OKX_WithFeeOut() public {
        deal(USDC, address(this), USDC_AMOUNT);
        deal(WAVAX, address(this), AVAX_AMOUNT);

        IERC20(USDC).approve(address(router), USDC_AMOUNT);
        IERC20(WAVAX).approve(address(router), AVAX_AMOUNT);

        (, uint256 avaxAmountOut) = IRouter(router).swapExactIn(
            address(forwarder),
            USDC,
            WAVAX,
            USDC_AMOUNT,
            AVAX_AMOUNT / 2,
            alice,
            block.timestamp,
            abi.encodePacked(OKX_APPROVAL, OKX, uint16(DEFAULT_FEE), uint8(0), thirdPartyFeeReceiver, OKX_USDC_AVAX)
        );

        uint256 feeAmount = (avaxAmountOut * DEFAULT_FEE) / (BPS - DEFAULT_FEE);
        uint256 protocolFeeAmount = (feeAmount * FEE_BIPS) / BPS;

        assertEq(IERC20(USDC).balanceOf(address(this)), 0, "test_OKX_WithFeeOut::1");
        assertEq(IERC20(WAVAX).balanceOf(alice), avaxAmountOut, "test_OKX_WithFeeOut::2");
        assertGe(avaxAmountOut, AVAX_AMOUNT / 2, "test_OKX_WithFeeOut::3");
        assertEq(IERC20(WAVAX).balanceOf(feeReceiver), protocolFeeAmount, "test_OKX_WithFeeOut::4");
        assertEq(
            IERC20(WAVAX).balanceOf(thirdPartyFeeReceiver), feeAmount - protocolFeeAmount, "test_OKX_WithFeeOut::5"
        );

        (, uint256 usdcAmountOut) = IRouter(router).swapExactIn(
            address(forwarder),
            WAVAX,
            USDC,
            AVAX_AMOUNT,
            USDC_AMOUNT / 2,
            alice,
            block.timestamp,
            abi.encodePacked(OKX_APPROVAL, OKX, uint16(DEFAULT_FEE), uint8(0), thirdPartyFeeReceiver, OKX_AVAX_USDC)
        );

        feeAmount = (usdcAmountOut * DEFAULT_FEE) / (BPS - DEFAULT_FEE);
        protocolFeeAmount = (feeAmount * FEE_BIPS) / BPS;

        assertEq(IERC20(WAVAX).balanceOf(address(this)), 0, "test_OKX_WithFeeOut::6");
        assertEq(IERC20(USDC).balanceOf(alice), usdcAmountOut, "test_OKX_WithFeeOut::7");
        assertGe(usdcAmountOut, USDC_AMOUNT / 2, "test_OKX_WithFeeOut::8");
        assertEq(IERC20(USDC).balanceOf(feeReceiver), protocolFeeAmount, "test_OKX_WithFeeOut::9");
        assertEq(
            IERC20(USDC).balanceOf(thirdPartyFeeReceiver), feeAmount - protocolFeeAmount, "test_OKX_WithFeeOut::10"
        );
    }

    function test_OKX_NativeWithFeeOut() public {
        deal(USDC, address(this), USDC_AMOUNT);
        deal(address(this), AVAX_AMOUNT);

        IERC20(USDC).approve(address(router), USDC_AMOUNT);

        (, uint256 avaxAmountOut) = IRouter(router).swapExactIn(
            address(forwarder),
            USDC,
            AVAX,
            USDC_AMOUNT,
            AVAX_AMOUNT / 2,
            alice,
            block.timestamp,
            abi.encodePacked(OKX_APPROVAL, OKX, uint16(DEFAULT_FEE), uint8(0), thirdPartyFeeReceiver, OKX_USDC_AVAX)
        );

        uint256 feeAmount = (avaxAmountOut * DEFAULT_FEE) / (BPS - DEFAULT_FEE);
        uint256 protocolFeeAmount = (feeAmount * FEE_BIPS) / BPS;

        assertEq(IERC20(USDC).balanceOf(address(this)), 0, "test_OKX_NativeWithFeeOut::1");
        assertEq(alice.balance, avaxAmountOut, "test_OKX_NativeWithFeeOut::2");
        assertGe(avaxAmountOut, AVAX_AMOUNT / 2, "test_OKX_NativeWithFeeOut::3");
        assertEq(IERC20(WAVAX).balanceOf(feeReceiver), protocolFeeAmount, "test_OKX_NativeWithFeeOut::4");
        assertEq(
            IERC20(WAVAX).balanceOf(thirdPartyFeeReceiver),
            feeAmount - protocolFeeAmount,
            "test_OKX_NativeWithFeeOut::5"
        );

        (, uint256 usdcAmountOut) = IRouter(router).swapExactIn{value: AVAX_AMOUNT}(
            address(forwarder),
            AVAX,
            USDC,
            AVAX_AMOUNT,
            USDC_AMOUNT / 2,
            alice,
            block.timestamp,
            abi.encodePacked(OKX_APPROVAL, OKX, uint16(DEFAULT_FEE), uint8(0), thirdPartyFeeReceiver, OKX_AVAX_USDC)
        );

        feeAmount = (usdcAmountOut * DEFAULT_FEE) / (BPS - DEFAULT_FEE);
        protocolFeeAmount = (feeAmount * FEE_BIPS) / BPS;

        assertEq(address(this).balance, 0, "test_OKX_NativeWithFeeOut::6");
        assertEq(IERC20(USDC).balanceOf(alice), usdcAmountOut, "test_OKX_NativeWithFeeOut::7");
        assertGe(usdcAmountOut, USDC_AMOUNT / 2, "test_OKX_NativeWithFeeOut::8");
        assertEq(IERC20(USDC).balanceOf(feeReceiver), protocolFeeAmount, "test_OKX_NativeWithFeeOut::9");
        assertEq(
            IERC20(USDC).balanceOf(thirdPartyFeeReceiver),
            feeAmount - protocolFeeAmount,
            "test_OKX_NativeWithFeeOut::10"
        );
    }

    function test_JAR() public {
        deal(USDC, address(this), USDC_AMOUNT);
        deal(WAVAX, address(this), AVAX_AMOUNT);

        IERC20(USDC).approve(address(router), USDC_AMOUNT);
        IERC20(WAVAX).approve(address(router), AVAX_AMOUNT);

        IRouter(router).swapExactIn(
            address(forwarder),
            USDC,
            WAVAX,
            USDC_AMOUNT,
            AVAX_AMOUNT / 2,
            alice,
            block.timestamp,
            abi.encodePacked(JAR, JAR, uint16(0), JAR_USDC_AVAX)
        );

        assertEq(IERC20(USDC).balanceOf(address(this)), 0, "test_JAR::1");
        assertGe(IERC20(WAVAX).balanceOf(alice), AVAX_AMOUNT / 2, "test_JAR::2");

        IRouter(router).swapExactIn(
            address(forwarder),
            WAVAX,
            USDC,
            AVAX_AMOUNT,
            USDC_AMOUNT / 2,
            alice,
            block.timestamp,
            abi.encodePacked(JAR, JAR, uint16(0), JAR_AVAX_USDC)
        );

        assertEq(IERC20(WAVAX).balanceOf(address(this)), 0, "test_JAR::3");
        assertGe(IERC20(USDC).balanceOf(alice), USDC_AMOUNT / 2, "test_JAR::4");
    }

    function test_JAR_Native() public {
        deal(USDC, address(this), USDC_AMOUNT);
        deal(address(this), AVAX_AMOUNT);

        IERC20(USDC).approve(address(router), USDC_AMOUNT);

        IRouter(router).swapExactIn(
            address(forwarder),
            USDC,
            AVAX,
            USDC_AMOUNT,
            AVAX_AMOUNT / 2,
            alice,
            block.timestamp,
            abi.encodePacked(JAR, JAR, uint16(0), JAR_USDC_AVAX)
        );

        assertEq(IERC20(USDC).balanceOf(address(this)), 0, "test_JAR_Native::1");
        assertGe(alice.balance, AVAX_AMOUNT / 2, "test_JAR_Native::2");

        IRouter(router).swapExactIn{value: AVAX_AMOUNT}(
            address(forwarder),
            AVAX,
            USDC,
            AVAX_AMOUNT,
            USDC_AMOUNT / 2,
            alice,
            block.timestamp,
            abi.encodePacked(JAR, JAR, uint16(0), JAR_AVAX_USDC)
        );

        assertEq(address(this).balance, 0, "test_JAR_Native::3");
        assertGe(IERC20(USDC).balanceOf(alice), USDC_AMOUNT / 2, "test_JAR_Native::4");
    }

    function test_JAR_WithFeeIn() public {
        uint256 usdcAmountWithFee = _getAmountWithFee(USDC_AMOUNT, DEFAULT_FEE);
        uint256 avaxAmountWithFee = _getAmountWithFee(AVAX_AMOUNT, DEFAULT_FEE);

        deal(USDC, address(this), usdcAmountWithFee);
        deal(WAVAX, address(this), avaxAmountWithFee);

        IERC20(USDC).approve(address(router), usdcAmountWithFee);
        IERC20(WAVAX).approve(address(router), avaxAmountWithFee);

        IRouter(router).swapExactIn(
            address(forwarder),
            USDC,
            WAVAX,
            usdcAmountWithFee,
            AVAX_AMOUNT / 2,
            alice,
            block.timestamp,
            abi.encodePacked(JAR, JAR, uint16(DEFAULT_FEE), uint8(1), thirdPartyFeeReceiver, JAR_USDC_AVAX)
        );

        uint256 feeAmount = (usdcAmountWithFee * DEFAULT_FEE) / BPS;
        uint256 protocolFeeAmount = (feeAmount * FEE_BIPS) / BPS;

        assertEq(IERC20(USDC).balanceOf(address(this)), 0, "test_JAR_WithFeeIn::1");
        assertEq(IERC20(USDC).balanceOf(feeReceiver), protocolFeeAmount, "test_JAR_WithFeeIn::2");
        assertEq(IERC20(USDC).balanceOf(thirdPartyFeeReceiver), feeAmount - protocolFeeAmount, "test_JAR_WithFeeIn::3");
        assertGe(IERC20(WAVAX).balanceOf(alice), AVAX_AMOUNT / 2, "test_JAR_WithFeeIn::4");

        IRouter(router).swapExactIn(
            address(forwarder),
            WAVAX,
            USDC,
            avaxAmountWithFee,
            USDC_AMOUNT / 2,
            alice,
            block.timestamp,
            abi.encodePacked(JAR, JAR, uint16(DEFAULT_FEE), uint8(1), thirdPartyFeeReceiver, JAR_AVAX_USDC)
        );

        feeAmount = (avaxAmountWithFee * DEFAULT_FEE) / BPS;
        protocolFeeAmount = (feeAmount * FEE_BIPS) / BPS;

        assertEq(IERC20(WAVAX).balanceOf(address(this)), 0, "test_JAR_WithFeeIn::5");
        assertEq(IERC20(WAVAX).balanceOf(feeReceiver), protocolFeeAmount, "test_JAR_WithFeeIn::6");
        assertEq(IERC20(WAVAX).balanceOf(thirdPartyFeeReceiver), feeAmount - protocolFeeAmount, "test_JAR_WithFeeIn::7");
        assertGe(IERC20(USDC).balanceOf(alice), USDC_AMOUNT / 2, "test_JAR_WithFeeIn::8");
    }

    function test_JAR_NativeWithFeeIn() public {
        uint256 usdcAmountWithFee = _getAmountWithFee(USDC_AMOUNT, DEFAULT_FEE);
        uint256 avaxAmountWithFee = _getAmountWithFee(AVAX_AMOUNT, DEFAULT_FEE);

        deal(USDC, address(this), usdcAmountWithFee);
        deal(address(this), avaxAmountWithFee);

        IERC20(USDC).approve(address(router), usdcAmountWithFee);

        IRouter(router).swapExactIn(
            address(forwarder),
            USDC,
            AVAX,
            usdcAmountWithFee,
            AVAX_AMOUNT / 2,
            alice,
            block.timestamp,
            abi.encodePacked(JAR, JAR, uint16(DEFAULT_FEE), uint8(1), thirdPartyFeeReceiver, JAR_USDC_AVAX)
        );

        uint256 feeAmount = (usdcAmountWithFee * DEFAULT_FEE) / BPS;
        uint256 protocolFeeAmount = (feeAmount * FEE_BIPS) / BPS;

        assertEq(IERC20(USDC).balanceOf(address(this)), 0, "test_JAR_NativeWithFeeIn::1");
        assertEq(
            IERC20(USDC).balanceOf(thirdPartyFeeReceiver), feeAmount - protocolFeeAmount, "test_JAR_NativeWithFeeIn::2"
        );
        assertEq(IERC20(USDC).balanceOf(feeReceiver), protocolFeeAmount, "test_JAR_NativeWithFeeIn::3");
        assertGe(alice.balance, AVAX_AMOUNT / 2, "test_JAR_NativeWithFeeIn::4");

        IRouter(router).swapExactIn{value: avaxAmountWithFee}(
            address(forwarder),
            AVAX,
            USDC,
            avaxAmountWithFee,
            USDC_AMOUNT / 2,
            alice,
            block.timestamp,
            abi.encodePacked(JAR, JAR, uint16(DEFAULT_FEE), uint8(1), thirdPartyFeeReceiver, JAR_AVAX_USDC)
        );

        feeAmount = (avaxAmountWithFee * DEFAULT_FEE) / BPS;
        protocolFeeAmount = (feeAmount * FEE_BIPS) / BPS;

        assertEq(address(this).balance, 0, "test_JAR_NativeWithFeeIn::5");
        assertEq(IERC20(WAVAX).balanceOf(feeReceiver), protocolFeeAmount, "test_JAR_NativeWithFeeIn::6");
        assertEq(
            IERC20(WAVAX).balanceOf(thirdPartyFeeReceiver), feeAmount - protocolFeeAmount, "test_JAR_NativeWithFeeIn::7"
        );
        assertGe(IERC20(USDC).balanceOf(alice), USDC_AMOUNT / 2, "test_JAR_NativeWithFeeIn::8");
    }

    function test_JAR_WithFeeOut() public {
        deal(USDC, address(this), USDC_AMOUNT);
        deal(WAVAX, address(this), AVAX_AMOUNT);

        IERC20(USDC).approve(address(router), USDC_AMOUNT);
        IERC20(WAVAX).approve(address(router), AVAX_AMOUNT);

        (, uint256 avaxAmountOut) = IRouter(router).swapExactIn(
            address(forwarder),
            USDC,
            WAVAX,
            USDC_AMOUNT,
            AVAX_AMOUNT / 2,
            alice,
            block.timestamp,
            abi.encodePacked(JAR, JAR, uint16(DEFAULT_FEE), uint8(0), thirdPartyFeeReceiver, JAR_USDC_AVAX)
        );

        uint256 feeAmount = (avaxAmountOut * DEFAULT_FEE) / (BPS - DEFAULT_FEE);
        uint256 protocolFeeAmount = (feeAmount * FEE_BIPS) / BPS;

        assertEq(IERC20(USDC).balanceOf(address(this)), 0, "test_JAR_WithFeeOut::1");
        assertEq(IERC20(WAVAX).balanceOf(alice), avaxAmountOut, "test_JAR_WithFeeOut::2");
        assertGe(avaxAmountOut, AVAX_AMOUNT / 2, "test_JAR_WithFeeOut::3");
        assertEq(IERC20(WAVAX).balanceOf(feeReceiver), protocolFeeAmount, "test_JAR_WithFeeOut::4");
        assertEq(
            IERC20(WAVAX).balanceOf(thirdPartyFeeReceiver), feeAmount - protocolFeeAmount, "test_JAR_WithFeeOut::5"
        );

        (, uint256 usdcAmountOut) = IRouter(router).swapExactIn(
            address(forwarder),
            WAVAX,
            USDC,
            AVAX_AMOUNT,
            USDC_AMOUNT / 2,
            alice,
            block.timestamp,
            abi.encodePacked(JAR, JAR, uint16(DEFAULT_FEE), uint8(0), thirdPartyFeeReceiver, JAR_AVAX_USDC)
        );

        feeAmount = (usdcAmountOut * DEFAULT_FEE) / (BPS - DEFAULT_FEE);
        protocolFeeAmount = (feeAmount * FEE_BIPS) / BPS;

        assertEq(IERC20(WAVAX).balanceOf(address(this)), 0, "test_JAR_WithFeeOut::6");
        assertEq(IERC20(USDC).balanceOf(alice), usdcAmountOut, "test_JAR_WithFeeOut::7");
        assertGe(usdcAmountOut, USDC_AMOUNT / 2, "test_JAR_WithFeeOut::8");
        assertEq(IERC20(USDC).balanceOf(feeReceiver), protocolFeeAmount, "test_JAR_WithFeeOut::9");
        assertEq(
            IERC20(USDC).balanceOf(thirdPartyFeeReceiver), feeAmount - protocolFeeAmount, "test_JAR_WithFeeOut::10"
        );
    }

    function test_JAR_NativeWithFeeOut() public {
        deal(USDC, address(this), USDC_AMOUNT);
        deal(address(this), AVAX_AMOUNT);

        IERC20(USDC).approve(address(router), USDC_AMOUNT);

        (, uint256 avaxAmountOut) = IRouter(router).swapExactIn(
            address(forwarder),
            USDC,
            AVAX,
            USDC_AMOUNT,
            AVAX_AMOUNT / 2,
            alice,
            block.timestamp,
            abi.encodePacked(JAR, JAR, uint16(DEFAULT_FEE), uint8(0), thirdPartyFeeReceiver, JAR_USDC_AVAX)
        );

        uint256 feeAmount = (avaxAmountOut * DEFAULT_FEE) / (BPS - DEFAULT_FEE);
        uint256 protocolFeeAmount = (feeAmount * FEE_BIPS) / BPS;

        assertEq(IERC20(USDC).balanceOf(address(this)), 0, "test_JAR_NativeWithFeeOut::1");
        assertEq(alice.balance, avaxAmountOut, "test_JAR_NativeWithFeeOut::2");
        assertGe(avaxAmountOut, AVAX_AMOUNT / 2, "test_JAR_NativeWithFeeOut::3");
        assertEq(IERC20(WAVAX).balanceOf(feeReceiver), protocolFeeAmount, "test_JAR_NativeWithFeeOut::4");
        assertEq(
            IERC20(WAVAX).balanceOf(thirdPartyFeeReceiver),
            feeAmount - protocolFeeAmount,
            "test_JAR_NativeWithFeeOut::5"
        );

        (, uint256 usdcAmountOut) = IRouter(router).swapExactIn{value: AVAX_AMOUNT}(
            address(forwarder),
            AVAX,
            USDC,
            AVAX_AMOUNT,
            USDC_AMOUNT / 2,
            alice,
            block.timestamp,
            abi.encodePacked(JAR, JAR, uint16(DEFAULT_FEE), uint8(0), thirdPartyFeeReceiver, JAR_AVAX_USDC)
        );

        feeAmount = (usdcAmountOut * DEFAULT_FEE) / (BPS - DEFAULT_FEE);
        protocolFeeAmount = (feeAmount * FEE_BIPS) / BPS;

        assertEq(address(this).balance, 0, "test_JAR_NativeWithFeeOut::6");
        assertEq(IERC20(USDC).balanceOf(alice), usdcAmountOut, "test_JAR_NativeWithFeeOut::7");
        assertGe(usdcAmountOut, USDC_AMOUNT / 2, "test_JAR_NativeWithFeeOut::8");
        assertEq(IERC20(USDC).balanceOf(feeReceiver), protocolFeeAmount, "test_JAR_NativeWithFeeOut::9");
        assertEq(
            IERC20(USDC).balanceOf(thirdPartyFeeReceiver),
            feeAmount - protocolFeeAmount,
            "test_JAR_NativeWithFeeOut::10"
        );
    }

    function _getAmountWithFee(uint256 amountIn, uint256 feePercent) internal pure returns (uint256) {
        return (amountIn * BPS) / (BPS - feePercent);
    }
}
