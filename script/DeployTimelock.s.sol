// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import {PledgeSafe} from "./PledgeSafe.sol";

/// @title DeployTimelock
/// @notice Deploys a 48h Timelock whose sole proposer, canceller, and executor is the Pledge 2-of-3 Safe.
/// @dev Prefer `script/mainnet/16_DeploySafeAndTimelock.s.sol` for the first deploy: it creates the Safe
///      and the Timelock together. This script is for the case where `PLEDGE_SAFE` is already live.
///
///      `admin = address(0)`, so role changes afterwards can only be scheduled by the Safe and executed
///      by the timelock itself. The retired Safe `0x509d…` is rejected.
contract DeployTimelock is Script, PledgeSafe {
    function run() external returns (TimelockController timelock) {
        uint256 deployerKey = _deployerPrivateKey();
        address deployer = vm.addr(deployerKey);
        address safe = vm.envAddress("PLEDGE_SAFE");
        assertPledgeSafe(safe);

        console2.log("Deployer:", deployer);
        console2.log("Safe (proposer/canceller/executor):", safe);
        console2.log("Min delay (seconds):", TIMELOCK_MIN_DELAY);

        vm.startBroadcast(deployerKey);
        timelock = deployTimelock(safe);
        vm.stopBroadcast();

        assertPledgeTimelock(address(timelock), safe, deployer);

        console2.log("TimelockController deployed at:", address(timelock));
        console2.log("Next: simulate 11_TransferOwnershipToTimelock.s.sol without --broadcast.");
        console2.log("Ownership transfer is single-step. There is no acceptOwnership.");
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
