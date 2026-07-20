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

    function setUp() public {
        alice = vm.addr(aliceKey);
        usdg = new MockERC20("USDG", "USDG", 18);
        bridge = new PledgeTestnetBridge(admin);

        vm.startPrank(admin);
        bridge.setRoute(ETH_MAINNET, "USDG", address(usdg), 10e18, 10_000e18, true);
        usdg.mint(admin, 10_000e18);
        usdg.approve(address(bridge), type(uint256).max);
        bridge.fund(address(usdg), 5_000e18);
        vm.stopPrank();
    }

    function _sign(uint256 sourceChainId, string memory tokenSymbol, uint256 amount, uint256 deadline)
        internal
        view
        returns (bytes memory sig, uint256 nonce)
    {
        nonce = bridge.nonces(alice);
        bytes32 digest = bridge.computeDigest(alice, sourceChainId, tokenSymbol, amount, nonce, deadline);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(aliceKey, digest);
        sig = abi.encodePacked(r, s, v);
    }

    function test_complete_bridge_releases_tokens() public {
        uint256 deadline = block.timestamp + 1 hours;
        (bytes memory sig, uint256 nonce) = _sign(ETH_MAINNET, "USDG", BRIDGE_AMOUNT, deadline);

        vm.prank(alice);
        bridge.completeBridge(ETH_MAINNET, "USDG", BRIDGE_AMOUNT, nonce, deadline, sig);

        assertEq(usdg.balanceOf(alice), BRIDGE_AMOUNT);
        assertEq(bridge.nonces(alice), 1);
    }

    function test_reverts_amount_out_of_range() public {
        uint256 deadline = block.timestamp + 1 hours;
        (bytes memory sig, uint256 nonce) = _sign(ETH_MAINNET, "USDG", 5e18, deadline);

        vm.prank(alice);
        vm.expectRevert();
        bridge.completeBridge(ETH_MAINNET, "USDG", 5e18, nonce, deadline, sig);
    }

    function test_reverts_during_cooldown() public {
        uint256 deadline = block.timestamp + 1 hours;
        (bytes memory sig, uint256 nonce) = _sign(ETH_MAINNET, "USDG", BRIDGE_AMOUNT, deadline);

        vm.startPrank(alice);
        bridge.completeBridge(ETH_MAINNET, "USDG", BRIDGE_AMOUNT, nonce, deadline, sig);

        (sig, nonce) = _sign(ETH_MAINNET, "USDG", BRIDGE_AMOUNT, deadline);
        vm.expectRevert();
        bridge.completeBridge(ETH_MAINNET, "USDG", BRIDGE_AMOUNT, nonce, deadline, sig);
        vm.stopPrank();
    }

    function test_cooldown_expires() public {
        uint256 deadline = block.timestamp + 1 hours;

        vm.startPrank(alice);
        (bytes memory sig, uint256 nonce) = _sign(ETH_MAINNET, "USDG", BRIDGE_AMOUNT, deadline);
        bridge.completeBridge(ETH_MAINNET, "USDG", BRIDGE_AMOUNT, nonce, deadline, sig);

        vm.warp(block.timestamp + 24 hours);
        deadline = block.timestamp + 1 hours;
        (sig, nonce) = _sign(ETH_MAINNET, "USDG", BRIDGE_AMOUNT, deadline);
        bridge.completeBridge(ETH_MAINNET, "USDG", BRIDGE_AMOUNT, nonce, deadline, sig);

        assertEq(usdg.balanceOf(alice), BRIDGE_AMOUNT * 2);
        vm.stopPrank();
    }
}
