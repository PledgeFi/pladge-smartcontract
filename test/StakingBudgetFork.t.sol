// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {PledgeStaking} from "../src/core/PledgeStaking.sol";

/**
 * Rehearses a full staking campaign against the live mainnet contract, on a fork.
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
 * Knobs: UNIT (minute|day), PERIODS, BUDGET, MIN_LOCK, MAX_LOCK, STAKE_LONG, STAKE_SHORT.
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

    string unitName;
    uint256 unitSeconds;
    uint256 periods;
    uint256 budget;
    uint256 minLock;
    uint256 maxLock;
    uint256 campaign;
    uint256 rate;

    function setUp() public {
        string memory rpc = vm.envOr("FORK_RPC", string(""));
        if (bytes(rpc).length == 0) return;
        vm.createSelectFork(rpc);

        bool perMinute = keccak256(bytes(vm.envOr("UNIT", string("day")))) == keccak256("minute");
        unitName = perMinute ? "menit" : "hari";
        unitSeconds = perMinute ? 60 : 1 days;

        periods = vm.envOr("PERIODS", uint256(30));
        budget = vm.envOr("BUDGET", uint256(967)) * ONE;
        minLock = vm.envOr("MIN_LOCK", uint256(1)) * unitSeconds;
        // Defaulting the longest lock to the campaign length makes every position expire exactly
        // when the money runs out, so the boost applies evenly across the whole run.
        maxLock = vm.envOr("MAX_LOCK", periods) * unitSeconds;
        campaign = periods * unitSeconds;

        // The one number that matters: spend the whole budget over the campaign, no more.
        rate = budget / campaign;
    }

    function test_budgetCoversCampaignExactly() public {
        if (unitSeconds == 0) {
            vm.skip(true);
            return;
        }

        uint256 stakeLong = vm.envOr("STAKE_LONG", uint256(10_000)) * ONE;
        uint256 stakeShort = vm.envOr("STAKE_SHORT", uint256(10_000)) * ONE;

        _configurePool();
        _report("--- setelan kampanye ---");
        emit log_named_uint("panjang kampanye (detik)", campaign);
        emit log_named_decimal_uint("anggaran (PLG)", budget, 18);
        emit log_named_string("satuan waktu", unitName);
        emit log_named_decimal_uint("dibayar per satuan (PLG)", rate * unitSeconds, 18);
        emit log_named_uint("rewardRatePerSecond (wei)", rate);
        emit log_named_uint("kunci terpendek (detik)", minLock);
        emit log_named_uint("kunci terpanjang (detik)", maxLock);
        emit log_named_uint("pengali kunci terpanjang (bps)", STAKING.multiplierBps(POOL, maxLock));

        _stakeAs(budi, stakeLong, maxLock);
        _stakeAs(ani, stakeShort, minLock);

        uint256 start = block.timestamp;

        // Mid-campaign claim, to prove rewards are reachable before the lock expires.
        vm.warp(start + campaign / 2);
        uint256 budiMid = STAKING.pendingReward(POOL, budi);
        vm.prank(budi);
        STAKING.claim(POOL);
        assertEq(PLG.balanceOf(budi), budiMid, "klaim tengah jalan tidak sesuai pendingReward");

        vm.warp(start + campaign);

        // Locks have expired, so the stored weights are stale until someone syncs them. Doing it
        // here keeps the final unstake from settling at a boost nobody is entitled to any more.
        STAKING.syncWeight(POOL, budi);
        STAKING.syncWeight(POOL, ani);

        vm.prank(budi);
        STAKING.unstake(POOL, stakeLong);
        vm.prank(ani);
        STAKING.unstake(POOL, stakeShort);

        uint256 budiEarned = PLG.balanceOf(budi) - stakeLong;
        uint256 aniEarned = PLG.balanceOf(ani) - stakeShort;
        uint256 paid = budiEarned + aniEarned;
        (,,,,,,,,, uint256 reserveLeft) = STAKING.pools(POOL);

        _report("--- hasil ---");
        emit log_named_decimal_uint("Budi, kunci terpanjang (PLG)", budiEarned, 18);
        emit log_named_decimal_uint("Ani, kunci terpendek  (PLG)", aniEarned, 18);
        emit log_named_decimal_uint("total dibayarkan      (PLG)", paid, 18);
        emit log_named_decimal_uint("sisa di kantong       (PLG)", reserveLeft, 18);

        // The whole claim of this harness: the pool pays out its budget and stops, never more.
        assertLe(paid, budget, "membayar lebih dari anggaran");

        // Two separate roundings, worth keeping apart. The reserve keeps whatever `budget /
        // campaign` truncated -- at most one wei per second, and provably so. Anything bigger
        // means the emission stalled and stakers were quietly short-changed.
        assertLe(reserveLeft, campaign, "kantong tidak habis terpakai - emisi tersendat");

        // The rest is per-share rounding in accRewardPerShare, which strands a few wei in the
        // contract forever. It scales with staker count, not with time or budget, so the only
        // sane bound is a relative one. 0.0001% is still thousands of times looser than observed.
        assertApproxEqRel(paid, budget, 0.000001e18, "terlalu banyak yang tersangkut di pembulatan");

        // Equal principal, so the split is the boost and nothing else.
        if (stakeLong == stakeShort) {
            uint256 boost = STAKING.multiplierBps(POOL, maxLock);
            assertApproxEqRel(budiEarned * BPS, aniEarned * boost, 0.001e18, "pembagian boost meleset");
        }
    }

    /// Owner-side setup: lock window, derived rate, funding, and opening the pool.
    function _configurePool() internal {
        deal(address(PLG), OWNER, budget);

        vm.startPrank(OWNER);
        STAKING.setLockDuration(POOL, minLock, maxLock);
        STAKING.setRewardRate(POOL, rate);
        PLG.approve(address(STAKING), budget);
        STAKING.fundRewards(POOL, budget);
        STAKING.setPoolActive(POOL, true);
        vm.stopPrank();
    }

    function _stakeAs(address who, uint256 amount, uint256 lock) internal {
        deal(address(PLG), who, amount);
        vm.startPrank(who);
        PLG.approve(address(STAKING), amount);
        STAKING.stake(POOL, amount, lock);
        vm.stopPrank();
    }

    function _report(string memory heading) internal {
        emit log(heading);
    }
}
