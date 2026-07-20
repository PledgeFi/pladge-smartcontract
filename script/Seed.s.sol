// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {PledgeProtocol} from "../src/PledgeProtocol.sol";
import {PledgeVaultManager} from "../src/core/PledgeVaultManager.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";

/// @title SeedPledgeTestnet
/// @author Pledge Finance
contract SeedPledgeTestnet is Script {
    function run() external {
        uint256 deployerKey = _deployerPrivateKey();
        address deployer = vm.addr(deployerKey);

        address vault = vm.envAddress("VAULT_MANAGER");
        address usdg = vm.envAddress("USDG_TOKEN");
        address mNvda = vm.envAddress("MNVDA_TOKEN");

        console2.log("Protocol:", PledgeProtocol.NAME);

        vm.startBroadcast(deployerKey);

        MockERC20(usdg).mint(deployer, 1_000_000e18);
        MockERC20(mNvda).mint(deployer, 10_000e18);

        MockERC20(usdg).approve(vault, type(uint256).max);
        PledgeVaultManager(vault).fundLiquidity(500_000e18);

        vm.stopBroadcast();

        console2.log("Seeded Pledge VaultManager", vault);
        console2.log("Deployer USDG", MockERC20(usdg).balanceOf(deployer));
        console2.log("Deployer mNVDA", MockERC20(mNvda).balanceOf(deployer));
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
