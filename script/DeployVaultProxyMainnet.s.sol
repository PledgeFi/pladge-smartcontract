// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {PledgeVaultManager} from "../src/core/PledgeVaultManager.sol";

/// @title DeployVaultProxyMainnet
/// @notice ERC1967 proxy + initialize. Requires MAINNET_VAULT_IMPL.
contract DeployVaultProxyMainnet is Script {
    function run() external {
        uint256 deployerKey = _deployerPrivateKey();
        address deployer = vm.addr(deployerKey);
        address implementation = vm.envAddress("MAINNET_VAULT_IMPL");

        console2.log("Deployer", deployer);
        console2.log("Implementation", implementation);
        require(implementation.code.length > 0, "impl not deployed");

        vm.startBroadcast(deployerKey);
        ERC1967Proxy proxy = new ERC1967Proxy(
            implementation, abi.encodeCall(PledgeVaultManager.initialize, (deployer))
        );
        vm.stopBroadcast();

        console2.log("PledgeVaultManager proxy (use this)", address(proxy));
        console2.log("Owner", PledgeVaultManager(address(proxy)).owner());
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
