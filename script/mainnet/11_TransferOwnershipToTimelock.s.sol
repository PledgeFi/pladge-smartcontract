// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {console2} from "forge-std/Script.sol";
import {PledgeSafe} from "../PledgeSafe.sol";
import {MainnetBase} from "./MainnetBase.sol";

interface IOwned {
    function owner() external view returns (address);
    function transferOwnership(address newOwner) external;
}

/// @title TransferOwnershipToTimelockMainnet
/// @notice Final and irreversible. Hands the five proxies and PledgeReferralClaim to the new Timelock.
/// @dev `transferOwnership` is SINGLE STEP: there is no pendingOwner and no acceptOwnership, so
///      ownership moves the instant this broadcasts. A wrong TIMELOCK address permanently bricks
///      every admin action, including upgrades. Run without --broadcast first and read the logs.
///
///      `PLEDGE_SAFE` must be the 2-of-3 Safe from 16_DeploySafeAndTimelock.s.sol, and `PLEDGE_TIMELOCK`
///      the 48h timelock that Safe alone can propose, cancel, and execute. The retired timelock
///      `0x1195…` is rejected.
///
///      After this, changing anything requires two of the three Safe signers to schedule() on the
///      Timelock, wait out 48 hours, then the Safe calls execute(). The referral claim signer is
///      not changed; only `owner` moves.
contract TransferOwnershipToTimelockMainnet is MainnetBase, PledgeSafe {
    function run() external onlyMainnet {
        uint256 key = deployerKey();
        address deployer = vm.addr(key);
        address safe = vm.envAddress("PLEDGE_SAFE");
        address timelock = vm.envAddress("PLEDGE_TIMELOCK");
        assertPledgeSafe(safe);
        assertPledgeTimelock(timelock, safe, deployer);

        address oracle = requireDeployed("PLEDGE_ORACLE_PROXY");
        address surplus = requireDeployed("PLEDGE_SURPLUS_PROXY");
        address vault = requireDeployed("PLEDGE_VAULT_PROXY");
        address pool = requireDeployed("PLEDGE_POOL_PROXY");
        address staking = requireDeployed("PLEDGE_STAKING_PROXY");
        address referral = requireDeployed("REFERRAL_CLAIM_ADDRESS");

        console2.log("deployer", deployer);
        console2.log("safe", safe);
        console2.log("new owner (timelock)", timelock);

        _requireOwner(oracle, "oracle", deployer);
        _requireOwner(surplus, "surplus", deployer);
        _requireOwner(vault, "vault", deployer);
        _requireOwner(pool, "pool", deployer);
        _requireOwner(staking, "staking", deployer);
        _requireOwner(referral, "referral", deployer);

        vm.startBroadcast(key);
        IOwned(oracle).transferOwnership(timelock);
        IOwned(surplus).transferOwnership(timelock);
        IOwned(vault).transferOwnership(timelock);
        IOwned(pool).transferOwnership(timelock);
        IOwned(staking).transferOwnership(timelock);
        IOwned(referral).transferOwnership(timelock);
        vm.stopBroadcast();

        _requireOwner(oracle, "oracle", timelock);
        _requireOwner(surplus, "surplus", timelock);
        _requireOwner(vault, "vault", timelock);
        _requireOwner(pool, "pool", timelock);
        _requireOwner(staking, "staking", timelock);
        _requireOwner(referral, "referral", timelock);

        console2.log("transferred oracle", oracle);
        console2.log("transferred surplus", surplus);
        console2.log("transferred vault", vault);
        console2.log("transferred pool", pool);
        console2.log("transferred staking", staking);
        console2.log("transferred referral", referral);
        console2.log("Done. The deployer EOA no longer controls these contracts.");
    }

    function _requireOwner(address target, string memory label, address expected) internal view {
        require(IOwned(target).owner() == expected, string.concat(label, ": unexpected owner"));
    }
}
