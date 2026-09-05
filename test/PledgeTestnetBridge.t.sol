// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {PledgeTestnetBridge} from "../src/core/PledgeTestnetBridge.sol";

contract PledgeTestnetBridgeTest is Test {
    MockERC20 internal usdg;
    PledgeTestnetBridge internal bridge;

    address internal admin = makeAddr("admin");
    uint256 internal aliceKey = 0xA11CE;
    address internal alice;

    uint256 internal constant ETH_MAINNET = 1;
    uint256 internal constant BRIDGE_AMOUNT = 500e18;
    uint256 internal constant PAY_ETH = 1 ether;
    uint256 internal constant PAY_USDG = 600e18;

    function setUp() public {
        alice = vm.addr(aliceKey);
        usdg = new MockERC20("USDG", "USDG", 18);
        bridge = new PledgeTestnetBridge(admin);

        vm.startPrank(admin);
        bridge.setUsdgPayToken(address(usdg));
        bridge.setRoute(ETH_MAINNET, "USDG", address(usdg), 10e18, 10_000e18, true);
        usdg.mint(admin, 10_000e18);
        usdg.approve(address(bridge), type(uint256).max);
        bridge.fund(address(usdg), 5_000e18);
        vm.stopPrank();

        vm.deal(alice, 10 ether);
    }

    function _sign(
        uint256 sourceChainId,
        string memory tokenSymbol,
        uint256 amount,
        bytes32 payAssetKey,
        uint256 payAmount,
        uint256 deadline
    ) internal view returns (bytes memory sig, uint256 nonce) {
        nonce = bridge.nonces(alice);
        bytes32 digest =
            bridge.computeDigest(alice, sourceChainId, tokenSymbol, amount, payAssetKey, payAmount, nonce, deadline);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(aliceKey, digest);
        sig = abi.encodePacked(r, s, v);
    }

    function test_complete_bridge_with_eth_payment() public {
        uint256 deadline = block.timestamp + 1 hours;
        bytes32 payKey = bridge.PAY_ETH();
        (bytes memory sig, uint256 nonce) =
            _sign(ETH_MAINNET, "USDG", BRIDGE_AMOUNT, payKey, PAY_ETH, deadline);

        uint256 ethBefore = alice.balance;

        vm.prank(alice);
        bridge.completeBridge{value: PAY_ETH}(
            ETH_MAINNET, "USDG", BRIDGE_AMOUNT, payKey, PAY_ETH, nonce, deadline, sig
        );

        assertEq(usdg.balanceOf(alice), BRIDGE_AMOUNT);
        assertEq(alice.balance, ethBefore - PAY_ETH);
        assertEq(bridge.nonces(alice), 1);
        assertEq(address(bridge).balance, PAY_ETH);
    }

    function test_complete_bridge_with_usdg_payment() public {
        usdg.mint(alice, PAY_USDG);

        vm.startPrank(alice);
        usdg.approve(address(bridge), PAY_USDG);

        uint256 deadline = block.timestamp + 1 hours;
        bytes32 payKey = bridge.PAY_USDG();
        (bytes memory sig, uint256 nonce) =
            _sign(ETH_MAINNET, "USDG", BRIDGE_AMOUNT, payKey, PAY_USDG, deadline);

        bridge.completeBridge(ETH_MAINNET, "USDG", BRIDGE_AMOUNT, payKey, PAY_USDG, nonce, deadline, sig);
        vm.stopPrank();

        assertEq(usdg.balanceOf(alice), BRIDGE_AMOUNT);
        assertEq(usdg.balanceOf(address(bridge)), 5_000e18 + PAY_USDG - BRIDGE_AMOUNT);
    }

    function test_reverts_wrong_eth_payment() public {
        uint256 deadline = block.timestamp + 1 hours;
        bytes32 payKey = bridge.PAY_ETH();
        (bytes memory sig, uint256 nonce) =
            _sign(ETH_MAINNET, "USDG", BRIDGE_AMOUNT, payKey, PAY_ETH, deadline);

        vm.prank(alice);
        vm.expectRevert(PledgeTestnetBridge.InvalidPayment.selector);
        bridge.completeBridge{value: PAY_ETH / 2}(
            ETH_MAINNET, "USDG", BRIDGE_AMOUNT, payKey, PAY_ETH, nonce, deadline, sig
        );
    }

    function test_reverts_amount_out_of_range() public {
        uint256 deadline = block.timestamp + 1 hours;
        bytes32 payKey = bridge.PAY_ETH();
        (bytes memory sig, uint256 nonce) = _sign(ETH_MAINNET, "USDG", 5e18, payKey, PAY_ETH, deadline);

        vm.prank(alice);
        vm.expectRevert();
        bridge.completeBridge{value: PAY_ETH}(
            ETH_MAINNET, "USDG", 5e18, payKey, PAY_ETH, nonce, deadline, sig
        );
    }

    function test_reverts_during_cooldown() public {
        vm.prank(admin);
        bridge.setCooldownDuration(24 hours);

        uint256 deadline = block.timestamp + 1 hours;
        bytes32 payKey = bridge.PAY_ETH();

        vm.startPrank(alice);
        (bytes memory sig, uint256 nonce) =
            _sign(ETH_MAINNET, "USDG", BRIDGE_AMOUNT, payKey, PAY_ETH, deadline);
        bridge.completeBridge{value: PAY_ETH}(
            ETH_MAINNET, "USDG", BRIDGE_AMOUNT, payKey, PAY_ETH, nonce, deadline, sig
        );

        (sig, nonce) = _sign(ETH_MAINNET, "USDG", BRIDGE_AMOUNT, payKey, PAY_ETH, deadline);
        vm.expectRevert();
        bridge.completeBridge{value: PAY_ETH}(
            ETH_MAINNET, "USDG", BRIDGE_AMOUNT, payKey, PAY_ETH, nonce, deadline, sig
        );
        vm.stopPrank();
    }

    function test_no_cooldown_by_default() public {
        uint256 deadline = block.timestamp + 1 hours;
        bytes32 payKey = bridge.PAY_ETH();

        vm.startPrank(alice);
        (bytes memory sig, uint256 nonce) =
            _sign(ETH_MAINNET, "USDG", BRIDGE_AMOUNT, payKey, PAY_ETH, deadline);
        bridge.completeBridge{value: PAY_ETH}(
            ETH_MAINNET, "USDG", BRIDGE_AMOUNT, payKey, PAY_ETH, nonce, deadline, sig
        );

        deadline = block.timestamp + 1 hours;
        (sig, nonce) = _sign(ETH_MAINNET, "USDG", BRIDGE_AMOUNT, payKey, PAY_ETH, deadline);
        bridge.completeBridge{value: PAY_ETH}(
            ETH_MAINNET, "USDG", BRIDGE_AMOUNT, payKey, PAY_ETH, nonce, deadline, sig
        );

        assertEq(usdg.balanceOf(alice), BRIDGE_AMOUNT * 2);
        vm.stopPrank();
    }

    function test_cooldown_expires() public {
        vm.prank(admin);
        bridge.setCooldownDuration(24 hours);

        uint256 deadline = block.timestamp + 1 hours;
        bytes32 payKey = bridge.PAY_ETH();

        vm.startPrank(alice);
        (bytes memory sig, uint256 nonce) =
            _sign(ETH_MAINNET, "USDG", BRIDGE_AMOUNT, payKey, PAY_ETH, deadline);
        bridge.completeBridge{value: PAY_ETH}(
            ETH_MAINNET, "USDG", BRIDGE_AMOUNT, payKey, PAY_ETH, nonce, deadline, sig
        );

        vm.warp(block.timestamp + 24 hours);
        deadline = block.timestamp + 1 hours;
        (sig, nonce) = _sign(ETH_MAINNET, "USDG", BRIDGE_AMOUNT, payKey, PAY_ETH, deadline);
        bridge.completeBridge{value: PAY_ETH}(
            ETH_MAINNET, "USDG", BRIDGE_AMOUNT, payKey, PAY_ETH, nonce, deadline, sig
        );

        assertEq(usdg.balanceOf(alice), BRIDGE_AMOUNT * 2);
        vm.stopPrank();
    }
}
