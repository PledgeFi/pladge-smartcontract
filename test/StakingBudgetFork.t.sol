// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {PledgeStaking} from "../src/core/PledgeStaking.sol";

/**
 * Rehearses whole staking campaigns against the live mainnet contract, on a fork.
 *
 * The point is the reward rate. Setting a rate by hand and funding separately is how a pool goes
 * dry mid-campaign: the two numbers are independent, so nothing stops you from promising 6,111
 * PLG a day out of a 967 PLG budget. Here the rate is *derived* — budget divided by the campaign
 * length — so the reserve covers the campaign exactly, by construction. Integer division always
 * rounds down, so the error can only ever leave dust behind, never come up short.
 *
 * Two time bases, same code path. `UNIT=minute` compresses a campaign into minutes for a quick
 * rehearsal; `UNIT=day` runs the real thing. On a fork the clock is free either way, which is the
 * whole reason to test here rather than on mainnet — a 90-day lock cannot be exercised on mainnet
 * without waiting 90 days.
 *
 * Skipped unless FORK_RPC is set, so `forge test` stays green offline.
 *
 *   FORK_RPC=https://rpc.mainnet.chain.robinhood.com \
 *   forge test --match-contract StakingBudgetFork -vv
 *
 * Knobs for the single-campaign test: UNIT (minute|day), PERIODS, BUDGET, MIN_LOCK, MAX_LOCK,
 * STAKE_LONG, STAKE_SHORT. The scenario table ignores them and runs its own fixed set.
 */
contract StakingBudgetForkTest is Test {
    PledgeStaking constant STAKING = PledgeStaking(0xEe8c2E6ED39B79Cd6806926d96CD570F5b94bF07);
    IERC20 constant PLG = IERC20(0x1BE3010124C86e8a03c6Fb6e91c534D4A2b1fFCf);
    address constant OWNER = 0x82FBf39835a885C1CdA3D756FB6AA79802f29e92;
    uint256 constant POOL = 2;

    uint256 constant BPS = 10_000;
    uint256 constant ONE = 1e18;

    address budi = makeAddr("budi"); // locks long, should earn the full boost
    address ani = makeAddr("ani"); // locks short, the 1.00x baseline

    /// One campaign to rehearse. Amounts in whole PLG; durations in `unitSeconds`.
    struct Campaign {
        string label;
        uint256 budget;
        uint256 periods;
        uint256 minLockUnits;
        uint256 maxLockUnits;
        uint256 stakeLong;
        uint256 stakeShort;
    }

    struct Outcome {
        uint256 perUnit; // emission per time unit, wei
        uint256 ratePerSecond;
        uint256 longEarned;
        uint256 shortEarned;
        uint256 paid;
        uint256 reserveLeft;
        uint256 longAprBps;
        uint256 shortAprBps;
    }

    string unitName;
    uint256 unitSeconds;
    bool forked;

    function setUp() public {
        string memory rpc = vm.envOr("FORK_RPC", string(""));
        if (bytes(rpc).length == 0) return;
        vm.createSelectFork(rpc);
        forked = true;

        bool perMinute = keccak256(bytes(vm.envOr("UNIT", string("day")))) == keccak256("minute");
        unitName = perMinute ? "menit" : "hari";
        unitSeconds = perMinute ? 60 : 1 days;
    }

    /// A single campaign, fully configurable from the environment.
    function test_budgetCoversCampaignExactly() public {
        if (!forked) {
            vm.skip(true);
            return;
        }

        uint256 periods = vm.envOr("PERIODS", uint256(30));
        Campaign memory c = Campaign({
            label: "kampanye tunggal",
            budget: vm.envOr("BUDGET", uint256(967)),
            periods: periods,
            minLockUnits: vm.envOr("MIN_LOCK", uint256(1)),
            // Defaulting the longest lock to the campaign length makes every position expire
            // exactly when the money runs out, so the boost applies evenly across the whole run.
            maxLockUnits: vm.envOr("MAX_LOCK", periods),
            stakeLong: vm.envOr("STAKE_LONG", uint256(10_000)),
            stakeShort: vm.envOr("STAKE_SHORT", uint256(10_000))
        });

        Outcome memory o = _runCampaign(c);
        _emit(c, o);
        _assertBudgetHeld(c, o);
    }

    /**
     * Side-by-side comparison of the budgets actually on the table, at a fixed 20,000 PLG of
     * deposits. Each case runs the same live contract from the same fork block and is reverted
     * afterwards, so no case can contaminate the next.
     *
     * Read the APR column, not the PLG column. It is the number that decides whether anyone
     * shows up, and it is the one that falls apart when the budget is too thin.
     */
    function test_scenarioTable() public {
        if (!forked) {
            vm.skip(true);
            return;
        }
        // The table is denominated in days regardless of UNIT; a minute-scale APR is meaningless.
        unitSeconds = 1 days;
        unitName = "hari";

        Campaign[7] memory cases = [
            _c("A. 967 PLG yang ada -> 7 hari", 967, 7, 10_000, 10_000),
            _c("B. 967 PLG yang ada -> 30 hari", 967, 30, 10_000, 10_000),
            _c("C. 967 PLG yang ada -> 90 hari", 967, 90, 10_000, 10_000),
            _c("D. tambah jadi 42.778 -> 7 hari", 42_778, 7, 10_000, 10_000),
            _c("E. tambah jadi 183.333 -> 30 hari", 183_333, 30, 10_000, 10_000),
            _c("F. tambah jadi 550.000 -> 90 hari", 550_000, 90, 10_000, 10_000),
            _c("G. 550.000 -> 90 hari, tapi TVL 10x", 550_000, 90, 100_000, 100_000)
        ];

        for (uint256 i = 0; i < cases.length; i++) {
            uint256 snap = vm.snapshotState();
            Outcome memory o = _runCampaign(cases[i]);
            _emit(cases[i], o);
            _assertBudgetHeld(cases[i], o);
            vm.revertToState(snap);
        }
    }

    /**
     * The lock has to hold, or every duration promised on the staking page is decoration. Both
     * exit paths are checked: `unstake`, and `emergencyWithdraw`, whose name invites the
     * assumption that it is a way out of the lock. It is not — it is an escape from a broken
     * reward token, and it enforces the same lock.
     */
    function test_lockCannotBeEscaped() public {
        if (!forked) {
            vm.skip(true);
            return;
        }
        _openPool(967, 90 days, 1 days, 90 days);
        _stakeAs(budi, 10_000 * ONE, 90 days);

        vm.warp(block.timestamp + 89 days);

        vm.prank(budi);
        vm.expectRevert(PledgeStaking.LockActive.selector);
        STAKING.unstake(POOL, 10_000 * ONE);

        vm.prank(budi);
        vm.expectRevert(PledgeStaking.LockActive.selector);
        STAKING.emergencyWithdraw(POOL);

        // Rewards are not locked, only principal. Claiming mid-lock has to keep working, or
        // there is no reason for anyone to pick the long lock in the first place.
        uint256 owed = STAKING.pendingReward(POOL, budi);
        assertGt(owed, 0, "tidak ada bunga yang terkumpul selama terkunci");
        vm.prank(budi);
        STAKING.claim(POOL);
        assertEq(PLG.balanceOf(budi), owed, "klaim selama terkunci tidak terbayar");

        vm.warp(block.timestamp + 1 days + 1);
        vm.prank(budi);
        STAKING.unstake(POOL, 10_000 * ONE);
        assertGe(PLG.balanceOf(budi), 10_000 * ONE, "titipan pokok tidak kembali utuh");
    }

    /// Pausing must stop the meter without trapping anyone who is already unlocked.
    function test_pauseStopsAccrualButNotTheExit() public {
        if (!forked) {
            vm.skip(true);
            return;
        }
        _openPool(967, 30 days, 1 days, 30 days);
        _stakeAs(ani, 10_000 * ONE, 1 days);

        vm.warp(block.timestamp + 2 days);
        uint256 owedAtPause = STAKING.pendingReward(POOL, ani);
        assertGt(owedAtPause, 0, "tidak ada bunga sebelum dijeda");

        vm.prank(OWNER);
        STAKING.setPoolActive(POOL, false);

        vm.warp(block.timestamp + 10 days);
        assertEq(STAKING.pendingReward(POOL, ani), owedAtPause, "bunga masih jalan padahal pool dijeda");

        // The lock has expired, so a pause must not stand between a staker and their money.
        vm.prank(ani);
        STAKING.unstake(POOL, 10_000 * ONE);
        assertEq(PLG.balanceOf(ani), 10_000 * ONE + owedAtPause, "tidak bisa keluar saat pool dijeda");
    }

    /**
     * Demonstrates audit finding H-2, which is still open. Not a bug in the sense of broken code
     * -- the bound holds and already-earned rewards survive -- but a trust assumption a staker
     * cannot see or opt out of, and it belongs in a test so nobody rediscovers it in production.
     */
    function test_ownerCanStopRewardsWhileStakersStayLocked() public {
        if (!forked) {
            vm.skip(true);
            return;
        }
        _openPool(967, 90 days, 1 days, 90 days);
        _stakeAs(budi, 10_000 * ONE, 90 days);

        vm.warp(block.timestamp + 10 days);
        uint256 earnedSoFar = STAKING.pendingReward(POOL, budi);
        assertGt(earnedSoFar, 0, "sepuluh hari tanpa bunga");

        // The half that is protected: what has already accrued has left the reserve, so claiming
        // it is unaffected by anything the owner does next.
        vm.prank(budi);
        STAKING.claim(POOL);
        assertEq(PLG.balanceOf(budi), earnedSoFar, "bunga yang sudah didapat tidak terbayar penuh");

        (,,,,,,,,, uint256 reserve) = STAKING.pools(POOL);
        vm.prank(OWNER);
        STAKING.withdrawRewards(POOL, OWNER, reserve);

        // The half that is not: every future reward is gone in one owner transaction.
        vm.warp(block.timestamp + 50 days);
        assertEq(STAKING.pendingReward(POOL, budi), 0, "masih ada emisi padahal kantong sudah dikosongkan");

        // And the staker cannot respond. Thirty days still to run on a pool that now pays nothing.
        vm.prank(budi);
        vm.expectRevert(PledgeStaking.LockActive.selector);
        STAKING.unstake(POOL, 10_000 * ONE);

        emit log("H-2 terbukti: pemilik bisa menghentikan seluruh bunga, penitip tidak bisa keluar");
        emit log_named_decimal_uint("  bunga yang selamat (PLG)", earnedSoFar, 18);
        emit log_named_decimal_uint("  anggaran yang ditarik pemilik (PLG)", reserve, 18);
    }

    /// Shared owner-side opening used by the behavioural tests, which do not vary the budget.
    function _openPool(uint256 budgetWhole, uint256 campaign, uint256 minLock, uint256 maxLock) internal {
        uint256 budget = budgetWhole * ONE;
        deal(address(PLG), OWNER, budget);
        vm.startPrank(OWNER);
        STAKING.setLockDuration(POOL, minLock, maxLock);
        STAKING.setRewardRate(POOL, budget / campaign);
        PLG.approve(address(STAKING), budget);
        STAKING.fundRewards(POOL, budget);
        STAKING.setPoolActive(POOL, true);
        vm.stopPrank();
    }

    function _c(string memory label, uint256 budget, uint256 periods, uint256 stakeLong, uint256 stakeShort)
        internal
        pure
        returns (Campaign memory)
    {
        return Campaign({
            label: label,
            budget: budget,
            periods: periods,
            minLockUnits: 1,
            maxLockUnits: periods,
            stakeLong: stakeLong,
            stakeShort: stakeShort
        });
    }

    /// Configure, fund, open, stake, run the clock out, settle. Returns what everyone walked away with.
    function _runCampaign(Campaign memory c) internal returns (Outcome memory o) {
        uint256 budget = c.budget * ONE;
        uint256 campaign = c.periods * unitSeconds;
        uint256 minLock = c.minLockUnits * unitSeconds;
        uint256 maxLock = c.maxLockUnits * unitSeconds;
        uint256 stakeLong = c.stakeLong * ONE;
        uint256 stakeShort = c.stakeShort * ONE;

        // The one number that matters: spend the whole budget over the campaign, no more.
        o.ratePerSecond = budget / campaign;
        o.perUnit = o.ratePerSecond * unitSeconds;

        deal(address(PLG), OWNER, budget);
        vm.startPrank(OWNER);
        STAKING.setLockDuration(POOL, minLock, maxLock);
        STAKING.setRewardRate(POOL, o.ratePerSecond);
        PLG.approve(address(STAKING), budget);
        STAKING.fundRewards(POOL, budget);
        STAKING.setPoolActive(POOL, true);
        vm.stopPrank();

        _stakeAs(budi, stakeLong, maxLock);
        _stakeAs(ani, stakeShort, minLock);

        uint256 start = block.timestamp;

        // Mid-campaign claim, to prove rewards are reachable before the lock expires.
        vm.warp(start + campaign / 2);
        uint256 mid = STAKING.pendingReward(POOL, budi);
        vm.prank(budi);
        STAKING.claim(POOL);
        assertEq(PLG.balanceOf(budi), mid, "klaim tengah jalan tidak sesuai pendingReward");

        vm.warp(start + campaign);

        // Locks have expired, so the stored weights are stale until someone syncs them. Doing it
        // here keeps the final unstake from settling at a boost nobody is entitled to any more.
        STAKING.syncWeight(POOL, budi);
        STAKING.syncWeight(POOL, ani);

        vm.prank(budi);
        STAKING.unstake(POOL, stakeLong);
        vm.prank(ani);
        STAKING.unstake(POOL, stakeShort);

        o.longEarned = PLG.balanceOf(budi) - stakeLong;
        o.shortEarned = PLG.balanceOf(ani) - stakeShort;
        o.paid = o.longEarned + o.shortEarned;
        (,,,,,,,,, o.reserveLeft) = STAKING.pools(POOL);

        // Annualised return on principal. This is what a staker compares against every other
        // place they could park the same tokens, and the only figure that answers "worth it?".
        o.longAprBps = (o.longEarned * 365 days * BPS) / (stakeLong * campaign);
        o.shortAprBps = (o.shortEarned * 365 days * BPS) / (stakeShort * campaign);
    }

    function _assertBudgetHeld(Campaign memory c, Outcome memory o) internal pure {
        uint256 budget = c.budget * ONE;
        uint256 campaign = c.periods * 1 days;

        // The whole claim of this harness: the pool pays out its budget and stops, never more.
        assertLe(o.paid, budget, "membayar lebih dari anggaran");

        // Two separate roundings, worth keeping apart. The reserve keeps whatever `budget /
        // campaign` truncated -- at most one wei per second, and provably so. Anything bigger
        // means the emission stalled and stakers were quietly short-changed.
        assertLe(o.reserveLeft, campaign, "kantong tidak habis terpakai - emisi tersendat");

        // The rest is per-share rounding in accRewardPerShare, which strands a few wei in the
        // contract forever. It scales with staker count, not with time or budget, so the only
        // sane bound is a relative one. 0.0001% is still thousands of times looser than observed.
        assertApproxEqRel(o.paid, budget, 0.000001e18, "terlalu banyak yang tersangkut di pembulatan");

        // Equal principal, so the split is the boost and nothing else.
        if (c.stakeLong == c.stakeShort) {
            assertApproxEqRel(o.longEarned * BPS, o.shortEarned * 3 * BPS, 0.001e18, "pembagian boost meleset");
        }
    }

    function _stakeAs(address who, uint256 amount, uint256 lock) internal {
        deal(address(PLG), who, amount);
        vm.startPrank(who);
        PLG.approve(address(STAKING), amount);
        STAKING.stake(POOL, amount, lock);
        vm.stopPrank();
    }

    function _emit(Campaign memory c, Outcome memory o) internal {
        emit log("");
        emit log(c.label);
        emit log_named_uint("  lama kampanye     (hari)", c.periods);
        emit log_named_decimal_uint("  dibayar per hari   (PLG)", o.perUnit, 18);
        emit log_named_uint("  rewardRatePerSecond (wei)", o.ratePerSecond);
        emit log_named_decimal_uint("  titipan tiap orang (PLG)", c.stakeLong * ONE, 18);
        emit log_named_decimal_uint("  Budi kunci panjang (PLG)", o.longEarned, 18);
        emit log_named_decimal_uint("  Ani  kunci pendek  (PLG)", o.shortEarned, 18);
        emit log_named_decimal_uint("  APR Budi              (%)", o.longAprBps, 2);
        emit log_named_decimal_uint("  APR Ani               (%)", o.shortAprBps, 2);
        emit log_named_decimal_uint("  sisa di kantong    (PLG)", o.reserveLeft, 18);
    }
}
