// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {PledgeStaking} from "../src/core/PledgeStaking.sol";
import {PledgeUupsOwnable} from "../src/upgrade/PledgeUupsOwnable.sol";
import {ProxyDeploy} from "../script/ProxyDeploy.sol";

contract PledgeStakingTest is Test {
    MockERC20 internal plg;
    MockERC20 internal usdg;
    PledgeStaking internal staking;

    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
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
        vm.prank(bob);
        plg.mint(bob, 10_000e18);
    }

    function test_stake_and_claim_rewards() public {
        vm.startPrank(alice);
        plg.approve(address(staking), type(uint256).max);
        staking.stake(plgPool, 1_000e18);

        vm.warp(block.timestamp + 1 days);
        uint256 pending = staking.pendingReward(plgPool, alice);
        assertEq(pending, 1e16 * 1 days);

        uint256 beforeBal = plg.balanceOf(alice);
        staking.claim(plgPool);
        assertEq(plg.balanceOf(alice) - beforeBal, pending);
        assertEq(staking.pendingReward(plgPool, alice), 0);
        vm.stopPrank();
    }

    function test_unstake_after_lock() public {
        vm.startPrank(alice);
        plg.approve(address(staking), type(uint256).max);
        staking.stake(plgPool, 500e18);

        vm.warp(block.timestamp + 7 days);
        uint256 rewards = 1e16 * 7 days;
        staking.unstake(plgPool, 200e18);
        assertEq(plg.balanceOf(alice), 9_700e18 + rewards);
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

    function test_usdgPoolHasNoLock() public {
        vm.startPrank(alice);
        usdg.approve(address(staking), type(uint256).max);
        staking.stake(usdgPool, 1_000e18);
        staking.unstake(usdgPool, 1_000e18);
        assertEq(usdg.balanceOf(alice), 10_000e18);
        vm.stopPrank();
    }

    function test_rewardsSplitProportionalToStake() public {
        vm.startPrank(alice);
        plg.approve(address(staking), type(uint256).max);
        staking.stake(plgPool, 1_000e18);
        vm.stopPrank();

        vm.startPrank(bob);
        plg.approve(address(staking), type(uint256).max);
        staking.stake(plgPool, 1_000e18);
        vm.stopPrank();

        vm.warp(block.timestamp + 100);

        uint256 alicePending = staking.pendingReward(plgPool, alice);
        uint256 bobPending = staking.pendingReward(plgPool, bob);
        assertEq(alicePending, bobPending);
        assertEq(alicePending + bobPending, 1e16 * 100);
    }

    function test_emissionsStopWhenReserveRunsOut() public {
        PledgeStaking fresh = new PledgeStaking(admin);
        vm.startPrank(admin);
        uint256 poolId = fresh.addPool(address(plg), address(plg), 1e18, 0, true);
        plg.approve(address(fresh), type(uint256).max);
        fresh.fundRewards(poolId, 10e18);
        vm.stopPrank();

        vm.startPrank(alice);
        plg.approve(address(fresh), type(uint256).max);
        fresh.stake(poolId, 100e18);
        vm.stopPrank();

        vm.warp(block.timestamp + 100 days);
        assertEq(fresh.pendingReward(poolId, alice), 10e18);

        vm.prank(alice);
        fresh.claim(poolId);
        assertEq(plg.balanceOf(alice), 10_000e18 - 100e18 + 10e18);
        assertEq(fresh.pendingReward(poolId, alice), 0);

        vm.warp(block.timestamp + 1 days);
        assertEq(fresh.pendingReward(poolId, alice), 0);
    }

    function test_inactivePoolBlocksStakeButAllowsUnstakeAndClaim() public {
        vm.startPrank(alice);
        plg.approve(address(staking), type(uint256).max);
        staking.stake(plgPool, 500e18);
        vm.stopPrank();

        vm.prank(admin);
        staking.setPoolActive(plgPool, false);

        vm.startPrank(alice);
        vm.expectRevert(PledgeStaking.PoolInactive.selector);
        staking.stake(plgPool, 1e18);

        vm.warp(block.timestamp + 7 days);
        staking.claim(plgPool);
        staking.unstake(plgPool, 500e18);
        vm.stopPrank();
    }

    function test_ownerCanWithdrawUnusedRewards() public {
        uint256 adminBefore = plg.balanceOf(admin);
        vm.prank(admin);
        staking.withdrawRewards(usdgPool, admin, 1_000e18);
        assertEq(plg.balanceOf(admin), adminBefore + 1_000e18);

        (,,,,,,,,, uint256 reserve) = staking.pools(usdgPool);
        assertEq(reserve, 99_000e18);
    }

    function test_withdrawRewardsCannotTakeStakedPrincipal() public {
        vm.startPrank(alice);
        plg.approve(address(staking), type(uint256).max);
        staking.stake(plgPool, 1_000e18);
        vm.stopPrank();

        (,,,,,,,,, uint256 reserve) = staking.pools(plgPool);
        vm.prank(admin);
        vm.expectRevert(PledgeStaking.InsufficientRewardReserve.selector);
        staking.withdrawRewards(plgPool, admin, reserve + 1);
    }

    function test_addPoolRejectsZeroToken() public {
        vm.startPrank(admin);
        vm.expectRevert(PledgeUupsOwnable.ZeroAddress.selector);
        staking.addPool(address(0), address(plg), 1, 0, true);
        vm.expectRevert(PledgeUupsOwnable.ZeroAddress.selector);
        staking.addPool(address(plg), address(0), 1, 0, true);
        vm.stopPrank();
    }

    function test_proxyInitialize() public {
        (PledgeStaking proxied,) = ProxyDeploy.staking(admin);
        assertEq(proxied.owner(), admin);
        vm.prank(admin);
        uint256 poolId = proxied.addPool(address(plg), address(plg), 1e16, 0, true);
        assertEq(poolId, 0);
        assertEq(proxied.poolCount(), 1);
        assertEq(proxied.name(), "Pledge Finance Staking");
    }

    function test_metadataAndPoolName() public {
        assertEq(staking.name(), "Pledge Finance Staking");
        assertEq(staking.version(), "1.0.0");

        vm.prank(admin);
        staking.setPoolName(plgPool, "PLG Staking");
        assertEq(staking.poolNames(plgPool), "PLG Staking");
    }

    function test_stakeWithCustomLockDuration() public {
        vm.startPrank(alice);
        plg.approve(address(staking), type(uint256).max);
        staking.stake(plgPool, 500e18, 1 days);
        vm.stopPrank();

        (uint256 amount, uint256 pending, uint256 lockedUntil, uint256 lockDuration, uint256 lockRemaining) =
            staking.getPosition(plgPool, alice);
        assertEq(amount, 500e18);
        assertEq(pending, 0);
        assertEq(lockDuration, 1 days);
        assertEq(lockRemaining, 1 days);
        assertEq(lockedUntil, block.timestamp + 1 days);

        vm.prank(alice);
        vm.expectRevert(PledgeStaking.LockActive.selector);
        staking.unstake(plgPool, 500e18);

        vm.warp(block.timestamp + 1 days);
        vm.prank(alice);
        staking.unstake(plgPool, 500e18);

        (amount,,,, lockRemaining) = staking.getPosition(plgPool, alice);
        assertEq(amount, 0);
        assertEq(lockRemaining, 0);
    }

    function test_customLockMustBeWithinPoolRange() public {
        vm.startPrank(alice);
        plg.approve(address(staking), type(uint256).max);
        vm.expectRevert(PledgeStaking.InvalidLockDuration.selector);
        staking.stake(plgPool, 100e18, 8 days);
        vm.stopPrank();

        vm.prank(admin);
        staking.setLockDuration(plgPool, 1 days, 30 days);

        vm.startPrank(alice);
        vm.expectRevert(PledgeStaking.InvalidLockDuration.selector);
        staking.stake(plgPool, 100e18, 12 hours);
        staking.stake(plgPool, 100e18, 30 days);
        vm.stopPrank();

        (,,, uint256 lockDuration,) = staking.getPosition(plgPool, alice);
        assertEq(lockDuration, 30 days);
    }

    function test_defaultStakeUsesMaxLock() public {
        vm.startPrank(alice);
        plg.approve(address(staking), type(uint256).max);
        staking.stake(plgPool, 100e18);
        vm.stopPrank();

        (,,, uint256 lockDuration, uint256 lockRemaining) = staking.getPosition(plgPool, alice);
        assertEq(lockDuration, 7 days);
        assertEq(lockRemaining, 7 days);
    }

    function test_restakeCannotShortenActiveLock() public {
        vm.startPrank(alice);
        plg.approve(address(staking), type(uint256).max);
        staking.stake(plgPool, 100e18, 7 days);
        uint256 originalUnlock;
        (,, originalUnlock,,) = staking.getPosition(plgPool, alice);

        staking.stake(plgPool, 50e18, 1 days);
        vm.stopPrank();

        (,, uint256 lockedUntil, uint256 lockDuration,) = staking.getPosition(plgPool, alice);
        assertEq(lockedUntil, originalUnlock);
        assertEq(lockDuration, 1 days);
    }

    function test_addPoolWithMinAndMaxLock() public {
        vm.prank(admin);
        uint256 poolId = staking.addPool(address(plg), address(plg), 1e16, 3 days, 14 days, true);
        (,,,,,, uint256 minLock, uint256 maxLock,,) = staking.pools(poolId);
        assertEq(minLock, 3 days);
        assertEq(maxLock, 14 days);
    }

    function test_emergencyWithdrawReturnsPrincipalAndForfeitsRewards() public {
        vm.startPrank(alice);
        plg.approve(address(staking), type(uint256).max);
        staking.stake(plgPool, 1_000e18);

        vm.warp(block.timestamp + 7 days);
        assertGt(staking.pendingReward(plgPool, alice), 0, "should have accrued");

        uint256 balanceBefore = plg.balanceOf(alice);
        uint256 recovered = staking.emergencyWithdraw(plgPool);
        vm.stopPrank();

        assertEq(recovered, 1_000e18);
        assertEq(plg.balanceOf(alice) - balanceBefore, 1_000e18, "principal only, no rewards");

        (uint256 amount,, uint256 lockedUntil,,) = staking.getPosition(plgPool, alice);
        assertEq(amount, 0);
        assertEq(lockedUntil, 0);
        assertEq(staking.pendingReward(plgPool, alice), 0, "reward claim is forfeited");

        (,,, uint256 totalStaked,,,,,,) = staking.pools(plgPool);
        assertEq(totalStaked, 0);
    }

    /// @dev The reason this function exists: `unstake` harvests first, so a reward token that
    ///      reverts on transfer would otherwise strand principal permanently.
    function test_emergencyWithdrawRescuesPrincipalWhenRewardTransferReverts() public {
        RevertingERC20 brokenReward = new RevertingERC20();

        vm.startPrank(admin);
        uint256 poolId = staking.addPool(address(plg), address(brokenReward), 1e16, 0, 0, true);
        brokenReward.mint(admin, 100_000e18);
        brokenReward.approve(address(staking), type(uint256).max);
        staking.fundRewards(poolId, 100_000e18);
        vm.stopPrank();

        vm.startPrank(alice);
        plg.approve(address(staking), type(uint256).max);
        staking.stake(poolId, 1_000e18);
        vm.warp(block.timestamp + 1 days);

        brokenReward.setRevertOnTransfer(true);

        vm.expectRevert(RevertingERC20.TransferDisabled.selector);
        staking.unstake(poolId, 1_000e18);

        vm.expectRevert(RevertingERC20.TransferDisabled.selector);
        staking.claim(poolId);

        uint256 balanceBefore = plg.balanceOf(alice);
        staking.emergencyWithdraw(poolId);
        vm.stopPrank();

        assertEq(plg.balanceOf(alice) - balanceBefore, 1_000e18, "principal recovered");
    }

    function test_revertsEmergencyWithdrawDuringLock() public {
        vm.startPrank(alice);
        plg.approve(address(staking), type(uint256).max);
        staking.stake(plgPool, 500e18);
        vm.expectRevert(PledgeStaking.LockActive.selector);
        staking.emergencyWithdraw(plgPool);
        vm.stopPrank();
    }

    function test_revertsEmergencyWithdrawWithoutStake() public {
        vm.prank(bob);
        vm.expectRevert(PledgeStaking.InsufficientStake.selector);
        staking.emergencyWithdraw(plgPool);
    }

    function test_emergencyWithdrawLeavesOtherStakersWhole() public {
        vm.startPrank(alice);
        plg.approve(address(staking), type(uint256).max);
        staking.stake(plgPool, 1_000e18);
        vm.stopPrank();

        vm.startPrank(bob);
        plg.approve(address(staking), type(uint256).max);
        staking.stake(plgPool, 1_000e18);
        vm.stopPrank();

        vm.warp(block.timestamp + 7 days);
        uint256 bobPendingBefore = staking.pendingReward(plgPool, bob);

        vm.prank(alice);
        staking.emergencyWithdraw(plgPool);

        // Bob keeps exactly his own share. Alice's forfeited share is not redistributed to him,
        // which would otherwise be a retroactive payout for a period she was still staked.
        assertEq(staking.pendingReward(plgPool, bob), bobPendingBefore, "bob unaffected");

        uint256 bobBalanceBefore = plg.balanceOf(bob);
        vm.prank(bob);
        staking.unstake(plgPool, 1_000e18);
        assertEq(plg.balanceOf(bob) - bobBalanceBefore, 1_000e18 + bobPendingBefore);
    }
}

/// @dev Reward token whose `transfer` can be switched off while `transferFrom` keeps working,
///      so a pool can be funded and then have its payout leg break.
contract RevertingERC20 {
    error TransferDisabled();

    string public name = "Broken";
    string public symbol = "BRK";
    uint8 public decimals = 18;
    bool public revertOnTransfer;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    function setRevertOnTransfer(bool value) external {
        revertOnTransfer = value;
    }

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        if (revertOnTransfer) revert TransferDisabled();
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}
