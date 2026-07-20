// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {PledgeStaking} from "../src/core/PledgeStaking.sol";

contract PledgeStakingTest is Test {
    MockERC20 internal plg;
    MockERC20 internal usdg;
    PledgeStaking internal staking;

    address internal alice = makeAddr("alice");
    address internal admin = makeAddr("admin");

    uint256 internal plgPool;
    uint256 internal usdgPool;

    function setUp() public {
        plg = new MockERC20("Pledge PLG", "PLG", 18);
        usdg = new MockERC20("Pledge USDG", "USDG", 18);
        staking = new PledgeStaking(admin);

        vm.startPrank(admin);
        plgPool = staking.addPool(address(plg), address(plg), 1e16, 7 days, true);
        usdgPool = staking.addPool(address(usdg), address(plg), 5e15, 0, true);
        plg.mint(admin, 1_000_000e18);
        plg.approve(address(staking), type(uint256).max);
        staking.fundRewards(plgPool, 100_000e18);
        staking.fundRewards(usdgPool, 100_000e18);
        vm.stopPrank();

        plg.mint(alice, 10_000e18);
        usdg.mint(alice, 10_000e18);
    }

    function test_stake_and_claim_rewards() public {
        vm.startPrank(alice);
        plg.approve(address(staking), type(uint256).max);
        staking.stake(plgPool, 1_000e18);

        vm.warp(block.timestamp + 1 days);
        staking.claim(plgPool);
        assertGt(plg.balanceOf(alice), 9_000e18);
        vm.stopPrank();
    }

    function test_unstake_after_lock() public {
        vm.startPrank(alice);
        plg.approve(address(staking), type(uint256).max);
        staking.stake(plgPool, 500e18);

        vm.warp(block.timestamp + 7 days);
        staking.unstake(plgPool, 200e18);
        assertGt(plg.balanceOf(alice), 9_700e18);
        assertEq(staking.pendingReward(plgPool, alice), 0);
        vm.stopPrank();
    }

    function test_reverts_unstake_during_lock() public {
        vm.startPrank(alice);
        plg.approve(address(staking), type(uint256).max);
        staking.stake(plgPool, 500e18);
        vm.expectRevert(PledgeStaking.LockActive.selector);
        staking.unstake(plgPool, 100e18);
        vm.stopPrank();
    }
}
