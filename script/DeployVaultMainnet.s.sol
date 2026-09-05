// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {PledgeVaultManager} from "../src/core/PledgeVaultManager.sol";
import {VaultProxyDeploy} from "./VaultProxyDeploy.sol";

/// @title DeployVaultMainnet
/// @notice Deploy vault only, using the already-broadcast surplus buffer.
contract DeployVaultMainnet is Script {
    address internal constant USDG = 0x5fc5360D0400a0Fd4f2af552ADD042D716F1d168;
    address internal constant SURPLUS = 0xEa30446c46D61514f19c897224E65b13Fb0A826c;

    function run() external {
        uint256 deployerKey = _deployerPrivateKey();
        address deployer = vm.addr(deployerKey);

        console2.log("Deployer:", deployer);
        console2.log("Surplus:", SURPLUS);

        vm.startBroadcast(deployerKey);
        (PledgeVaultManager vault, address implementation) = VaultProxyDeploy.deploy(USDG, SURPLUS, deployer);
        vm.stopBroadcast();

        console2.log("Implementation", implementation);
        console2.log("PledgeVaultManager proxy", address(vault));
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
