// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {console2} from "forge-std/Script.sol";
import {PledgeStaking} from "../../src/core/PledgeStaking.sol";
import {MainnetBase} from "./MainnetBase.sol";

/// @title RotateStakingToPons
/// @notice Step 12. Retire the legacy PLG/USDG staking pools and replace them with a single
///         PONS-only pool (stake PONS, earn PONS). Both legacy pools have `totalStaked == 0`
///         at time of writing, so no staker principal is at risk.
/// @dev Actions, all on the live `PledgeFinanceStaking` proxy:
///      1. Deactivate pool 0 (PLG/PLG) and pool 1 (USDG/PLG) so nobody can stake into them again.
///      2. Withdraw the full 550,000 PLG reward reserve out of pool 0 back to the deployer.
///      3. Create a brand new pool: stake PONS, reward PONS, 1-90 day lock range, same
///         90-day/550k-token program shape as the original design. Left UNFUNDED (rewardReserve
///         stays 0) because the deployer currently holds 0 PONS; fund it later by calling
///         `fundRewards(newPoolId, amount)` from any address that holds PONS.
contract RotateStakingToPons is MainnetBase {
    address internal constant STAKING_PROXY = 0xEe8c2E6ED39B79Cd6806926d96CD570F5b94bF07;
    address internal constant LEGACY_PLG = 0xDfC0a301CA6F62c32800C4827974ECac64BC7e38;

    uint256 internal constant LEGACY_PLG_RESERVE = 550_000e18;
    uint256 internal constant PROGRAM_DURATION = 90 days;
    uint256 internal constant PONS_REWARDS_TARGET = 550_000e18;

    function run() external onlyMainnet {
        uint256 key = deployerKey();
        address deployer = vm.addr(key);

        PledgeStaking staking = PledgeStaking(STAKING_PROXY);
        require(staking.owner() == deployer, "rotate: deployer is not the current owner");
        require(staking.poolCount() == 2, "rotate: unexpected pool count, re-check before broadcasting");

        // Sanity: confirm the legacy pools are still empty of stakers before touching them.
        (address stake0,,,uint256 totalStaked0,,,,, bool active0, uint256 reserve0) = staking.pools(0);
        (address stake1,,,uint256 totalStaked1,,,,,, uint256 reserve1) = staking.pools(1);
        require(stake0 == LEGACY_PLG, "rotate: pool 0 is not the legacy PLG pool, aborting");
        require(totalStaked0 == 0, "rotate: pool 0 has stakers, aborting");
        require(totalStaked1 == 0, "rotate: pool 1 has stakers, aborting");
        require(reserve0 == LEGACY_PLG_RESERVE, "rotate: pool 0 reserve is not the expected 550k, aborting");

        uint256 ponsRewardRate = PONS_REWARDS_TARGET / PROGRAM_DURATION;

        console2.log("staking proxy", STAKING_PROXY);
        console2.log("pool0 stakeToken", stake0);
        console2.log("pool0 active (before)", active0);
        console2.log("pool0 reserve (before)", reserve0);
        console2.log("pool1 stakeToken", stake1);
        console2.log("pons reward rate per second", ponsRewardRate);

        vm.startBroadcast(key);

        // 1. Retire the legacy pools: block new stakes, keep them visible/inert for history.
        staking.setPoolActive(0, false);
        staking.setPoolActive(1, false);

        // 2. Reclaim the dead-token reward reserve.
        staking.withdrawRewards(0, deployer, LEGACY_PLG_RESERVE);

        // 3. Create the PONS-only pool. Left unfunded; fund later once PONS is available.
        uint256 ponsPoolId = staking.addPool(PONS, PONS, ponsRewardRate, 1 days, 90 days, true);
        staking.setPoolName(ponsPoolId, "PONS Staking");

        vm.stopBroadcast();

        (,,,,,,,, bool pool0ActiveAfter,) = staking.pools(0);
        (,,,,,,,, bool pool1ActiveAfter,) = staking.pools(1);
        require(!pool0ActiveAfter, "rotate: pool 0 still active after tx");
        require(!pool1ActiveAfter, "rotate: pool 1 still active after tx");
        require(staking.poolCount() == 3, "rotate: new pool was not created");

        console2.log("done. new PONS pool id", ponsPoolId);
        console2.log("next: fundRewards(ponsPoolId, amount) once PONS is available");
    }
}
