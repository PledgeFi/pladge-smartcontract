// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {PledgeUupsOwnable} from "../src/upgrade/PledgeUupsOwnable.sol";

/// @title TransferOwnershipToTimelock
/// @notice Migrates admin control of the 4 core protocol contracts to the Timelock+Safe.
/// @dev Must be run by the CURRENT owner (deployer) of each contract. `transferOwnership` on
///      `PledgeUupsOwnable` is a SINGLE-STEP transfer (no `pendingOwner`/`acceptOwnership`) —
///      ownership changes IMMEDIATELY and IRREVERSIBLY by the deployer once this broadcasts.
///      There is no "accept" step for the Safe to run afterwards.
///
///      IMPORTANT: double, triple check the `TIMELOCK` address before broadcasting. If it is
///      wrong (e.g. not a real TimelockController, or one the Safe doesn't control), admin
///      control of these contracts is permanently lost (bricked) — there is no recovery path.
///      Run with a dry run (no --broadcast) first and manually verify `timelock` in the logs.
contract TransferOwnershipToTimelock is Script {
    address internal constant DEFAULT_ORACLE = 0x195287cbcd53eF058a3DeC4c6DC8f17Bf79A28d9;
    address internal constant DEFAULT_VAULT_MANAGER = 0x0dfd39ff00aFa2283A8c37770dB972aeC08AaB62;
    address internal constant DEFAULT_SURPLUS_BUFFER = 0xEa30446c46D61514f19c897224E65b13Fb0A826c;
    address internal constant DEFAULT_STABILITY_POOL = 0x8570a571CC83f87B3Ca4249B71646Cc807350e14;

    function run() external {
        uint256 deployerKey = _deployerPrivateKey();
        address deployer = vm.addr(deployerKey);

        address timelock = vm.envAddress("TIMELOCK");
        require(timelock != address(0), "TransferOwnershipToTimelock: TIMELOCK env var not set");
        require(timelock.code.length > 0, "TransferOwnershipToTimelock: TIMELOCK is not a contract");

        address oracle = vm.envOr("MAINNET_ORACLE", DEFAULT_ORACLE);
        address vaultManager = vm.envOr("MAINNET_VAULT_MANAGER", DEFAULT_VAULT_MANAGER);
        address surplusBuffer = vm.envOr("SURPLUS_BUFFER", DEFAULT_SURPLUS_BUFFER);
        address stabilityPool = vm.envOr("STABILITY_POOL", DEFAULT_STABILITY_POOL);

        console2.log("Deployer:", deployer);
        console2.log("Timelock (new owner - IMMEDIATE, one-step):", timelock);

        vm.startBroadcast(deployerKey);
        _transfer(oracle, "PledgeChainlinkOracle", timelock);
        _transfer(vaultManager, "PledgeVaultManager", timelock);
        _transfer(surplusBuffer, "PledgeSurplusBuffer", timelock);
        _transfer(stabilityPool, "PledgeStabilityPool", timelock);
        vm.stopBroadcast();

        console2.log("");
        console2.log("=== DONE ===");
        console2.log("Ownership of all 4 contracts has been transferred to the Timelock above.");
        console2.log("The deployer EOA no longer has any admin control over them.");
        console2.log("From now on, any admin action (setFeed, upgrades, param changes) requires:");
        console2.log("  1. Safe proposes + collects signatures (3-of-4) for a Timelock schedule() call");
        console2.log("  2. Wait for the timelock delay (48h)");
        console2.log("  3. Safe calls execute() on the Timelock to actually run the action");
    }

    function _transfer(address target, string memory label, address newOwner) internal {
        address current = PledgeUupsOwnable(target).owner();
        console2.log(string.concat(label, " current owner:"), current);
        PledgeUupsOwnable(target).transferOwnership(newOwner);
        console2.log(string.concat(label, " new owner:"), newOwner);
    }

    function _deployerPrivateKey() private view returns (uint256) {
        string memory raw = vm.envString("DEPLOYER_PRIVATE_KEY");
        bytes memory chars = bytes(raw);
        if (chars.length >= 2 && chars[0] == "0" && chars[1] == "x") {
            return vm.parseUint(raw);
        }
        return vm.parseUint(string.concat("0x", raw));
    }
}
