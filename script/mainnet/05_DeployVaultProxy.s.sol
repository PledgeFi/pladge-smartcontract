// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {console2} from "forge-std/Script.sol";
import {PledgeFinanceVault} from "../../src/upgrade/PledgeFinanceProxies.sol";
import {PledgeVaultManager} from "../../src/core/PledgeVaultManager.sol";
import {MainnetBase} from "./MainnetBase.sol";

/// @title DeployVaultProxyMainnet
/// @notice Step 05. Branded ERC1967 proxy over the step 04 implementation. This proxy is the canonical vault.
contract DeployVaultProxyMainnet is MainnetBase {
    function run() external onlyMainnet {
        uint256 key = deployerKey();
        address deployer = vm.addr(key);
        address implementation = requireDeployed("PLEDGE_VAULT_IMPL");
        address surplus = requireDeployed("PLEDGE_SURPLUS_PROXY");

        vm.startBroadcast(key);
        PledgeFinanceVault proxy =
            new PledgeFinanceVault(implementation, abi.encodeCall(PledgeVaultManager.initialize, (deployer)));
        vm.stopBroadcast();

        PledgeVaultManager vault = PledgeVaultManager(address(proxy));
        require(vault.owner() == deployer, "vault: owner mismatch");
        require(address(vault.usdg()) == USDG, "vault: wrong USDG");
        require(vault.usdgDecimals() == 6, "vault: wrong USDG decimals");
        require(address(vault.surplusBuffer()) == surplus, "vault: wrong surplus buffer");
        require(vault.getMarketCount() == 0, "vault: unexpected markets");

        console2.log("proxy (THE vault, use this)", address(proxy));
        console2.log("implementation", implementation);
        console2.log("owner", vault.owner());
        console2.log("Next:");
        logExport("PLEDGE_VAULT_PROXY", address(proxy));
    }
}
