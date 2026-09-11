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
        assertEq(lockedUntil, originalUnlock, "unlock date must not move");
        // The shorter request does not take effect, so the recorded duration is what is still
        // outstanding. Recording 1 day here would demote the boost on a position that stays
        // locked for another 7.
        assertEq(lockDuration, 7 days, "keeps the commitment still outstanding");
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

contract PledgeStakingBoostTest is Test {
    MockERC20 internal plg;
    PledgeStaking internal staking;

    address internal shortStaker = makeAddr("shortStaker");
    address internal longStaker = makeAddr("longStaker");
    address internal admin = makeAddr("admin");
    address internal keeper = makeAddr("keeper");

    uint256 internal pool;
    uint256 internal constant BPS = 10_000;
    uint256 internal constant RATE = 1e16;

    function setUp() public {
        plg = new MockERC20("Pledge Finance", "PLG", 18);
        staking = new PledgeStaking(admin);

        vm.startPrank(admin);
        pool = staking.addPool(address(plg), address(plg), RATE, 1 days, 90 days, true);
        staking.setMaxBoostBps(pool, 3 * BPS); // 3.00x at the longest lock
        plg.mint(admin, 10_000_000e18);
        plg.approve(address(staking), type(uint256).max);
        staking.fundRewards(pool, 1_000_000e18);
        vm.stopPrank();

        // MockERC20's faucet has a per-caller cooldown, so each staker mints for itself.
        vm.startPrank(shortStaker);
        plg.mint(shortStaker, 1_000_000e18);
        plg.approve(address(staking), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(longStaker);
        plg.mint(longStaker, 1_000_000e18);
        plg.approve(address(staking), type(uint256).max);
        vm.stopPrank();
    }

    function test_multiplierIsLinearBetweenMinAndMaxLock() public view {
        assertEq(staking.multiplierBps(pool, 1 days), BPS, "shortest lock is 1.00x");
        assertEq(staking.multiplierBps(pool, 90 days), 3 * BPS, "longest lock is 3.00x");

        // Halfway through the range should land halfway to the cap.
        uint256 mid = staking.multiplierBps(pool, 1 days + (89 days / 2));
        assertApproxEqAbs(mid, 2 * BPS, 10, "midpoint is about 2.00x");

        // Below the minimum and above the maximum both clamp.
        assertEq(staking.multiplierBps(pool, 0), BPS);
        assertEq(staking.multiplierBps(pool, 999 days), 3 * BPS);
    }

    function test_longLockEarnsThreeTimesTheShortLock() public {
        vm.prank(shortStaker);
        staking.stake(pool, 1_000e18, 1 days);
        vm.prank(longStaker);
        staking.stake(pool, 1_000e18, 90 days);

        // Equal principal, so weight is entirely down to the lock.
        assertEq(staking.userWeight(pool, shortStaker), 1_000e18);
        assertEq(staking.userWeight(pool, longStaker), 3_000e18);
        assertEq(staking.totalWeight(pool), 4_000e18);

        vm.warp(block.timestamp + 12 hours);

        uint256 shortPending = staking.pendingReward(pool, shortStaker);
        uint256 longPending = staking.pendingReward(pool, longStaker);

        assertApproxEqRel(longPending, shortPending * 3, 1e12, "3x lock earns 3x rewards");
        assertApproxEqRel(shortPending + longPending, RATE * 12 hours, 1e12, "no reward conjured or lost");
    }

    function test_boostDisappearsWhenTheLockExpires() public {
        vm.prank(longStaker);
        staking.stake(pool, 1_000e18, 2 days);
        assertGt(staking.userWeight(pool, longStaker), 1_000e18, "starts boosted");

        vm.warp(block.timestamp + 2 days + 1);

        // The view reports the truth immediately; storage has not caught up yet.
        assertEq(staking.weightOf(pool, longStaker), 1_000e18, "expired position is worth 1.00x");
        assertGt(staking.userWeight(pool, longStaker), 1_000e18, "stored weight is still stale");

        // Anyone can correct it, not just the staker.
        vm.prank(keeper);
        staking.syncWeight(pool, longStaker);

        assertEq(staking.userWeight(pool, longStaker), 1_000e18, "demoted to 1.00x");
        assertEq(staking.totalWeight(pool), 1_000e18);
    }

    function test_syncingAnExpiredPositionDoesNotStealItsEarnedRewards() public {
        vm.prank(longStaker);
        staking.stake(pool, 1_000e18, 2 days);

        vm.warp(block.timestamp + 2 days);
        uint256 earned = staking.pendingReward(pool, longStaker);
        assertGt(earned, 0);

        uint256 balanceBefore = plg.balanceOf(longStaker);
        vm.prank(keeper);
        staking.syncWeight(pool, longStaker);

        // syncWeight settles rather than discards: the rewards are paid out, not zeroed.
        assertEq(plg.balanceOf(longStaker) - balanceBefore, earned, "earned rewards are paid, not lost");
        assertEq(staking.pendingReward(pool, longStaker), 0);
    }

    function test_toppingUpDoesNotDemoteALongerRunningLock() public {
        vm.startPrank(longStaker);
        staking.stake(pool, 1_000e18, 90 days);
        uint256 boostedWeight = staking.userWeight(pool, longStaker);

        // Adding to the position with the shortest lock must not cost the 3.00x already committed.
        staking.stake(pool, 1_000e18, 1 days);
        vm.stopPrank();

        assertApproxEqRel(staking.userWeight(pool, longStaker), boostedWeight * 2, 1e15, "still near 3.00x");
        assertGt(staking.userWeight(pool, longStaker), 2_000e18, "did not silently fall back to 1.00x");
    }

    function test_unstakingReleasesWeight() public {
        vm.prank(longStaker);
        staking.stake(pool, 1_000e18, 90 days);
        assertEq(staking.totalWeight(pool), 3_000e18);

        vm.warp(block.timestamp + 90 days);
        vm.prank(longStaker);
        staking.unstake(pool, 1_000e18);

        assertEq(staking.userWeight(pool, longStaker), 0);
        assertEq(staking.totalWeight(pool), 0, "weight must not outlive the stake");
    }

    function test_emergencyWithdrawReleasesWeight() public {
        vm.prank(longStaker);
        staking.stake(pool, 1_000e18, 1 days);
        vm.warp(block.timestamp + 1 days);

        vm.prank(longStaker);
        staking.emergencyWithdraw(pool);

        assertEq(staking.userWeight(pool, longStaker), 0);
        assertEq(staking.totalWeight(pool), 0);
    }

    function test_boostOffBehavesExactlyLikeBefore() public {
        vm.prank(admin);
        staking.setMaxBoostBps(pool, 0);

        vm.prank(shortStaker);
        staking.stake(pool, 1_000e18, 1 days);
        vm.prank(longStaker);
        staking.stake(pool, 1_000e18, 90 days);

        assertEq(staking.userWeight(pool, shortStaker), 1_000e18);
        assertEq(staking.userWeight(pool, longStaker), 1_000e18, "no boost means weight is just principal");

        vm.warp(block.timestamp + 1 days);
        assertEq(
            staking.pendingReward(pool, shortStaker),
            staking.pendingReward(pool, longStaker),
            "equal stakes earn equally"
        );
    }

    function test_revertsOnAbsurdBoost() public {
        vm.startPrank(admin);
        vm.expectRevert(PledgeStaking.InvalidBoost.selector);
        staking.setMaxBoostBps(pool, BPS - 1); // below 1.00x would cut principal
        vm.expectRevert(PledgeStaking.InvalidBoost.selector);
        staking.setMaxBoostBps(pool, 11 * BPS); // beyond the 10x cap
        vm.stopPrank();
    }

    function test_projectedAprFallsAsThePoolFillsUp() public {
        uint256 aprAlone = staking.projectedAprBps(pool, 1_000e18, 90 days);
        assertGt(aprAlone, 0);

        vm.prank(shortStaker);
        staking.stake(pool, 100_000e18, 1 days);

        uint256 aprCrowded = staking.projectedAprBps(pool, 1_000e18, 90 days);
        assertLt(aprCrowded, aprAlone, "more stakers means a smaller slice each");

        // The long lock must still beat the short one at any level of crowding.
        assertGt(
            staking.projectedAprBps(pool, 1_000e18, 90 days),
            staking.projectedAprBps(pool, 1_000e18, 1 days),
            "locking longer always pays better"
        );
    }

    function test_projectedAprIsZeroWithoutAReserve() public {
        vm.startPrank(admin);
        (,,,,,,,,, uint256 reserve) = staking.pools(pool);
        staking.withdrawRewards(pool, admin, reserve);
        vm.stopPrank();

        assertEq(staking.projectedAprBps(pool, 1_000e18, 90 days), 0, "an empty pool must not advertise an APR");
    }

    function test_noEmissionIsBurnedWhileThePoolIsEmpty() public {
        (,,,,,,,,, uint256 reserveBefore) = staking.pools(pool);
        vm.warp(block.timestamp + 30 days);

        vm.prank(shortStaker);
        staking.stake(pool, 1_000e18, 1 days);

        (,,,,,,,,, uint256 reserveAfter) = staking.pools(pool);
        assertEq(reserveAfter, reserveBefore, "30 idle days must not drain the reserve");
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
