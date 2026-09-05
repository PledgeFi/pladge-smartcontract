// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {PledgeChainlinkOracle} from "../src/oracle/PledgeChainlinkOracle.sol";
import {OracleProxyDeploy} from "./OracleProxyDeploy.sol";

/// @title DeployOracle
/// @notice Deploy UUPS-upgradeable PledgeChainlinkOracle. Use the proxy address.
contract DeployOracle is Script {
    function run() external {
        uint256 deployerKey = _deployerPrivateKey();
        address deployer = vm.addr(deployerKey);

        vm.startBroadcast(deployerKey);
        (PledgeChainlinkOracle oracle, address implementation) = OracleProxyDeploy.deploy(deployer);
        vm.stopBroadcast();

        console2.log("PledgeChainlinkOracle proxy (use this)", address(oracle));
        console2.log("Implementation", implementation);
        console2.log("Owner", deployer);
        console2.log("Name", oracle.name());
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
