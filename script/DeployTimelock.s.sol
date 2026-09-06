// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

/// @title DeployTimelock
/// @notice Deploys an OpenZeppelin `TimelockController` governed by the Pledge Finance Safe.
/// @dev The Safe is the sole proposer/canceller/executor. `admin = address(0)` so the timelock
///      is fully self-administered afterwards (role changes must go through the timelock itself).
///
///      IMPORTANT: verify the Safe address and its signer threshold on Safe UI
///      (Settings -> Owners) BEFORE broadcasting. A wrong address here would hand
///      admin control of the oracle/vault to an unrecoverable address.
contract DeployTimelock is Script {
    /// @dev Pledge Finance Safe on Robinhood Mainnet (chain 4663).
    ///      Override with `PLEDGE_SAFE` env var if deploying for a different chain/environment.
    address internal constant DEFAULT_SAFE = 0x509dC4A81045F6FA42D388A68e2C65d20d493560;

    /// @dev Default 48h delay between `schedule()` and `execute()`.
    uint256 internal constant DEFAULT_MIN_DELAY = 48 hours;

    function run() external returns (TimelockController timelock) {
        uint256 deployerKey = _deployerPrivateKey();
        address deployer = vm.addr(deployerKey);

        address safe = vm.envOr("PLEDGE_SAFE", DEFAULT_SAFE);
        uint256 minDelay = vm.envOr("TIMELOCK_MIN_DELAY_SECONDS", DEFAULT_MIN_DELAY);

        address[] memory proposers = new address[](1);
        proposers[0] = safe;
        address[] memory executors = new address[](1);
        executors[0] = safe;

        console2.log("Deployer:", deployer);
        console2.log("Safe (proposer/canceller/executor):", safe);
        console2.log("Min delay (seconds):", minDelay);

        vm.startBroadcast(deployerKey);
        // admin = address(0): no one but the timelock itself (via schedule+execute) can
        // grant/revoke PROPOSER_ROLE/EXECUTOR_ROLE/CANCELLER_ROLE afterwards.
        timelock = new TimelockController(minDelay, proposers, executors, address(0));
        vm.stopBroadcast();

        console2.log("TimelockController deployed at:", address(timelock));
        console2.log("Next: run TransferOwnershipToTimelock.s.sol, then have the Safe");
        console2.log("schedule()+execute() an `acceptOwnership()` call on each target contract.");
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
