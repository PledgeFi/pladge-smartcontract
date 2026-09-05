// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {PledgeTestnetBridge} from "../src/core/PledgeTestnetBridge.sol";

/// @notice Set bridge cooldown on a deployed PledgeTestnetBridge (requires owner key).
/// @dev New deployments default to 0. Existing v1 bridge (immutable 24h) must be redeployed via DeployBridge.s.sol.
contract SetBridgeCooldownDuration is Script {
    function run() external {
        uint256 deployerKey = _deployerPrivateKey();
        address bridgeAddr = vm.envAddress("PLEDGE_BRIDGE");
        uint256 duration = vm.envOr("COOLDOWN_SECONDS", uint256(0));

        console2.log("Bridge:", bridgeAddr);
        console2.log("Cooldown seconds:", duration);

        vm.startBroadcast(deployerKey);
        PledgeTestnetBridge(bridgeAddr).setCooldownDuration(duration);
        vm.stopBroadcast();
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
