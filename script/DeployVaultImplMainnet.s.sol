// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {PledgeVaultManager} from "../src/core/PledgeVaultManager.sol";

/// @title DeployVaultImplMainnet
/// @notice Implementation only. Follow with DeployVaultProxyMainnet.
contract DeployVaultImplMainnet is Script {
    address internal constant USDG = 0x5fc5360D0400a0Fd4f2af552ADD042D716F1d168;
    address internal constant SURPLUS = 0xEa30446c46D61514f19c897224E65b13Fb0A826c;

    function run() external {
        uint256 deployerKey = _deployerPrivateKey();
        address deployer = vm.addr(deployerKey);

        console2.log("Deployer", deployer);
        console2.log("ETH", deployer.balance);
        require(deployer.balance >= 0.0019 ether, "need ~0.002 ETH for vault implementation");

        vm.startBroadcast(deployerKey);
        PledgeVaultManager implementation = new PledgeVaultManager(USDG, SURPLUS, address(0));
        vm.stopBroadcast();

        console2.log("Implementation (not the live vault)", address(implementation));
        console2.log("Next: MAINNET_VAULT_IMPL then DeployVaultProxyMainnet");
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
