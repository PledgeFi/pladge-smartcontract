// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {PledgeProtocol} from "../src/PledgeProtocol.sol";
import {PledgeVaultManager} from "../src/core/PledgeVaultManager.sol";
import {PledgeSurplusBuffer} from "../src/core/PledgeSurplusBuffer.sol";
import {PledgeStabilityPool} from "../src/core/PledgeStabilityPool.sol";
import {ProxyDeploy} from "./ProxyDeploy.sol";

/// @title DeployCoreMainnet
/// @notice Deploy surplus, vault, and stability pool. Does not deploy a new oracle.
contract DeployCoreMainnet is Script {
    address internal constant USDG = 0x5fc5360D0400a0Fd4f2af552ADD042D716F1d168;
    address internal constant ORACLE = 0x195287cbcd53eF058a3DeC4c6DC8f17Bf79A28d9;

    function run() external {
        uint256 deployerKey = _deployerPrivateKey();
        address deployer = vm.addr(deployerKey);

        console2.log("Protocol:", PledgeProtocol.NAME);
        console2.log("Deployer:", deployer);
        console2.log("USDG:", USDG);
        console2.log("Existing oracle", ORACLE);

        vm.startBroadcast(deployerKey);
        (PledgeSurplusBuffer surplus,) = ProxyDeploy.surplus(USDG, deployer);
        (PledgeVaultManager vault,) = ProxyDeploy.vault(USDG, address(surplus), deployer);
        (PledgeStabilityPool stabilityPool,) = ProxyDeploy.pool(USDG, deployer);
        stabilityPool.setVaultManager(address(vault));
        vm.stopBroadcast();

        console2.log("PledgeSurplusBuffer proxy", address(surplus));
        console2.log("PledgeVaultManager proxy", address(vault));
        console2.log("PledgeStabilityPool proxy", address(stabilityPool));
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
