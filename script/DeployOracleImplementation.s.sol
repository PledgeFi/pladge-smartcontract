// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {PledgeChainlinkOracle} from "../src/oracle/PledgeChainlinkOracle.sol";

/// @title DeployOracleImplementation
/// @notice Deploys a new (unattached) `PledgeChainlinkOracle` implementation contract.
/// @dev No ownership required — anyone can deploy a raw implementation. It only becomes live
///      once the oracle PROXY's owner (now the Timelock, via the Safe) calls
///      `upgradeToAndCall(newImpl, "")` on it. This script does NOT touch the proxy.
contract DeployOracleImplementation is Script {
    function run() external returns (address impl) {
        uint256 deployerKey = _deployerPrivateKey();
        vm.startBroadcast(deployerKey);
        PledgeChainlinkOracle newImplementation = new PledgeChainlinkOracle();
        vm.stopBroadcast();

        impl = address(newImplementation);
        console2.log("New PledgeChainlinkOracle implementation deployed at:", impl);
        console2.log("This is NOT live yet. The oracle proxy owner (Timelock) must call:");
        console2.log("  upgradeToAndCall(", impl, ", 0x)");
        console2.log("via Safe schedule() -> wait delay -> Safe execute().");
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
