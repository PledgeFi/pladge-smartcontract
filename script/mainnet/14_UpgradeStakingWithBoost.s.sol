// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {console2} from "forge-std/Script.sol";
import {PledgeStaking} from "../../src/core/PledgeStaking.sol";
import {MainnetBase} from "./MainnetBase.sol";

/// @title UpgradeStakingWithBoostMainnet
/// @notice Step 14. Swaps in the implementation that adds `emergencyWithdraw` and the lock boost.
///         Proxy address, pool list, names and reserves all survive untouched.
///
/// @dev THE ONE THING THAT MAKES THIS SAFE: every pool must have `totalStaked == 0`.
///
///      The upgrade redenominates `accRewardPerShare` from "per unit staked" to "per unit of
///      weight", and every open position's `rewardDebt` is recorded in the old basis. There is no
///      way to rewrite them — iterating stakers is an unbounded loop and the contract keeps no
///      staker list. So an open position would carry a debt in one unit against an index in
///      another, and its rewards would be silently wrong in either direction.
///
///      With nothing staked there is no debt to misread, so the change is clean. The require below
///      enforces that rather than trusting it. If it ever fails, this script is the wrong tool and
///      the change needs a fresh proxy plus a migration.
///
///      Storage layout is unchanged for slots 0-4; the boost lives in mappings appended after
///      `poolNames`. Verify with `forge inspect PledgeStaking storage-layout` before broadcasting.
contract UpgradeStakingWithBoostMainnet is MainnetBase {
    address internal constant STAKING_PROXY = 0xEe8c2E6ED39B79Cd6806926d96CD570F5b94bF07;

    /// @dev 3.00x at the pool's longest lock, tapering linearly to 1.00x at the shortest.
    uint256 internal constant MAX_BOOST_BPS = 30_000;
    uint256 internal constant BOOST_POOL_ID = 2;

    function run() external onlyMainnet {
        uint256 key = deployerKey();
        address deployer = vm.addr(key);

        PledgeStaking staking = PledgeStaking(STAKING_PROXY);
        require(staking.owner() == deployer, "upgrade: deployer is not the current owner");

        uint256 count = staking.poolCount();
        for (uint256 i = 0; i < count; i++) {
            (,,, uint256 totalStaked,,,,,,) = staking.pools(i);
            require(totalStaked == 0, "upgrade: a pool has stakers, rewardDebt cannot be migrated");
        }
        console2.log("all pools empty, safe to redenominate accRewardPerShare. pools:", count);

        (address stakeToken,,,,,,,,,) = staking.pools(BOOST_POOL_ID);
        require(stakeToken == PLG, "upgrade: boost pool is not the live PLG pool, aborting");

        vm.startBroadcast(key);

        PledgeStaking implementation = new PledgeStaking(address(0));
        staking.upgradeToAndCall(address(implementation), "");
        staking.setMaxBoostBps(BOOST_POOL_ID, MAX_BOOST_BPS);

        vm.stopBroadcast();

        // Prove the new code is actually live rather than assuming the upgrade landed.
        require(staking.maxBoostBps(BOOST_POOL_ID) == MAX_BOOST_BPS, "upgrade: boost not applied");
        require(staking.multiplierBps(BOOST_POOL_ID, 90 days) == MAX_BOOST_BPS, "upgrade: multiplier wrong at max lock");
        require(staking.multiplierBps(BOOST_POOL_ID, 1 days) == staking.BPS(), "upgrade: multiplier wrong at min lock");
        require(staking.owner() == deployer, "upgrade: owner changed unexpectedly");
        require(staking.poolCount() == count, "upgrade: pool list changed");

        console2.log("new implementation", address(implementation));
        console2.log("multiplier at  1 day ", staking.multiplierBps(BOOST_POOL_ID, 1 days));
        console2.log("multiplier at 30 days", staking.multiplierBps(BOOST_POOL_ID, 30 days));
        console2.log("multiplier at 90 days", staking.multiplierBps(BOOST_POOL_ID, 90 days));
        console2.log("Done. Record the implementation address in deployments/4663.json.");
    }
}
