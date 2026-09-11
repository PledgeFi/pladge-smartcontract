// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {console2} from "forge-std/Script.sol";
import {PledgeStaking} from "../../src/core/PledgeStaking.sol";
import {MainnetBase} from "./MainnetBase.sol";

/// @title RenameStakingPoolsMainnet
/// @notice Step 13. Clears the leftover "PONS Staking" name so the live pool reads "PLG Staking".
/// @dev Pool names live in contract storage and the frontend renders them verbatim, so this is the
///      only way to change what a user sees. Pools can never be deleted, which is why the retired
///      pool 0 has to be renamed rather than removed.
///
///      ORDER MATTERS: pool 0 currently holds the name "PLG Staking" while staking the abandoned
///      launchpad token. Renaming pool 2 first would leave two pools called "PLG Staking" and no
///      way for a user to tell them apart, so pool 0 is renamed out of the way first.
contract RenameStakingPoolsMainnet is MainnetBase {
    address internal constant STAKING_PROXY = 0xEe8c2E6ED39B79Cd6806926d96CD570F5b94bF07;
    address internal constant LEGACY_PLG = 0xDfC0a301CA6F62c32800C4827974ECac64BC7e38;

    string internal constant RETIRED_NAME = "PLG Staking (retired)";
    string internal constant LIVE_NAME = "PLG Staking";

    function run() external onlyMainnet {
        uint256 key = deployerKey();
        address deployer = vm.addr(key);

        PledgeStaking staking = PledgeStaking(STAKING_PROXY);
        require(staking.owner() == deployer, "rename: deployer is not the current owner");
        require(staking.poolCount() == 3, "rename: unexpected pool count, re-check before broadcasting");

        // Both tokens report the symbol PLG, so identify the pools by address, never by symbol.
        (address stake0,,,,,,,,,) = staking.pools(0);
        (address stake2,,,,,,,,,) = staking.pools(2);
        require(stake0 == LEGACY_PLG, "rename: pool 0 is not the legacy PLG pool, aborting");
        require(stake2 == PLG, "rename: pool 2 is not the live PLG pool, aborting");

        console2.log("pool 0 name (before)", staking.poolNames(0));
        console2.log("pool 2 name (before)", staking.poolNames(2));

        vm.startBroadcast(key);
        staking.setPoolName(0, RETIRED_NAME);
        staking.setPoolName(2, LIVE_NAME);
        vm.stopBroadcast();

        require(
            keccak256(bytes(staking.poolNames(0))) == keccak256(bytes(RETIRED_NAME)), "rename: pool 0 name not applied"
        );
        require(
            keccak256(bytes(staking.poolNames(2))) == keccak256(bytes(LIVE_NAME)), "rename: pool 2 name not applied"
        );

        console2.log("pool 0 name (after)", staking.poolNames(0));
        console2.log("pool 2 name (after)", staking.poolNames(2));
        console2.log("Done. No pool is named PONS any more.");
    }
}
