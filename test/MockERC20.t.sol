// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";

contract MockERC20Test is Test {
    MockERC20 internal token;
    address internal alice = makeAddr("alice");

    function setUp() public {
        token = new MockERC20("Mock", "MOCK", 18);
    }

    function test_mint_withoutCooldown() public {
        vm.prank(alice);
        token.mint(alice, 100e18);
        assertEq(token.balanceOf(alice), 100e18);
    }

    function test_revertsDuringCooldown() public {
        vm.startPrank(alice);
        token.mint(alice, 100e18);
        vm.expectRevert(abi.encodeWithSelector(MockERC20.FaucetCooldown.selector, block.timestamp + 48 hours));
        token.mint(alice, 1e18);
        vm.stopPrank();
    }

    function test_mintAfterCooldown() public {
        vm.startPrank(alice);
        token.mint(alice, 100e18);
        vm.warp(block.timestamp + 48 hours);
        token.mint(alice, 50e18);
        assertEq(token.balanceOf(alice), 150e18);
        vm.stopPrank();
    }

    function test_cooldownRemaining() public {
        vm.prank(alice);
        token.mint(alice, 1e18);
        assertEq(token.cooldownRemaining(alice), 48 hours);

        vm.warp(block.timestamp + 12 hours);
        assertEq(token.cooldownRemaining(alice), 36 hours);

        vm.warp(block.timestamp + 36 hours);
        assertEq(token.cooldownRemaining(alice), 0);
    }
}
