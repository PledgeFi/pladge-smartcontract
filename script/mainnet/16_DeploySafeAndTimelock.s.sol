// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {console2} from "forge-std/Script.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import {PledgeSafe} from "../PledgeSafe.sol";
import {MainnetBase} from "./MainnetBase.sol";

/// @title DeploySafeAndTimelockMainnet
/// @notice Deploys the Pledge 2-of-3 Safe and a fresh 48h Timelock that only that Safe can drive.
/// @dev Does not transfer protocol ownership. Run 11_TransferOwnershipToTimelock.s.sol only after
///      the logged addresses have been checked byte for byte.
///
///      Signers, threshold 2:
///        0x229CA6EFbC034bBd0a2c5D4a2a3369A07eD2D829
///        0xBB445d38EE937A88AC87b7c58f16F085dB721A93
///        0xDAe2D6D7d1b58899a8E9aB9834b9de38a21877Ca
///
///      The retired Safe 0x509d… and timelock 0x1195… are not used. That timelock's admin is
///      burned and its only proposer is the old Safe, so these three signers cannot take it over.
contract DeploySafeAndTimelockMainnet is MainnetBase, PledgeSafe {
    function run() external onlyMainnet returns (address safe, TimelockController timelock) {
        uint256 key = deployerKey();
        address deployer = vm.addr(key);

        console2.log("deployer", deployer);
        console2.log("threshold", SAFE_THRESHOLD);
        console2.log("signer 1", SIGNER_1);
        console2.log("signer 2", SIGNER_2);
        console2.log("signer 3", SIGNER_3);

        vm.startBroadcast(key);
        SafeInfra memory infra = resolveSafeInfra();
        safe = createSafe(pledgeSigners(), SAFE_THRESHOLD, infra, SAFE_SALT_NONCE);
        timelock = deployTimelock(safe);
        vm.stopBroadcast();

        assertPledgeSafe(safe);
        assertPledgeTimelock(address(timelock), safe, deployer);

        console2.log("safe singleton", infra.singleton);
        console2.log("safe factory", infra.factory);
        console2.log("fallback handler", infra.handler);
        console2.log("deployed fresh Safe contracts", infra.deployedFresh);
        console2.log("Pledge Safe", safe);
        console2.log("TimelockController", address(timelock));
        logExport("PLEDGE_SAFE", safe);
        logExport("PLEDGE_TIMELOCK", address(timelock));
        console2.log("Next: simulate 11_TransferOwnershipToTimelock.s.sol without --broadcast.");
    }
}
