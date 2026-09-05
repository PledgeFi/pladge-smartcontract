// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {PledgeStabilityPool} from "../src/core/PledgeStabilityPool.sol";
import {ProxyDeploy} from "./ProxyDeploy.sol";

/// @title DeployPoolMainnet
/// @notice Deploy stability pool and point it at the vault. Requires MAINNET_VAULT_MANAGER.
contract DeployPoolMainnet is Script {
    address internal constant USDG = 0x5fc5360D0400a0Fd4f2af552ADD042D716F1d168;

    function run() external {
        uint256 deployerKey = _deployerPrivateKey();
        address deployer = vm.addr(deployerKey);
        address vault = vm.envAddress("MAINNET_VAULT_MANAGER");

        console2.log("Deployer:", deployer);
        console2.log("Vault:", vault);

        vm.startBroadcast(deployerKey);
        (PledgeStabilityPool pool, address implementation) = ProxyDeploy.pool(USDG, deployer);
        pool.setVaultManager(vault);
        vm.stopBroadcast();

        console2.log("Implementation", implementation);
        console2.log("PledgeStabilityPool proxy", address(pool));
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
