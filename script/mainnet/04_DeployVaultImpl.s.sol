// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {console2} from "forge-std/Script.sol";
import {PledgeVaultManager} from "../../src/core/PledgeVaultManager.sol";
import {MainnetBase} from "./MainnetBase.sol";

/// @title DeployVaultImplMainnet
/// @notice Step 04. Implementation only — the largest deploy in the sequence (~3.1M gas), which is
///         why it is not bundled with the proxy.
/// @dev `usdg`, `usdgDecimals`, and `surplusBuffer` are immutable, so they live in this bytecode
///      rather than in proxy storage. Any future vault upgrade MUST reuse these exact constructor
///      arguments or the proxy will silently start pointing at a different USDG or surplus buffer.
contract DeployVaultImplMainnet is MainnetBase {
    function run() external onlyMainnet {
        uint256 key = deployerKey();
        address surplus = requireDeployed("PLEDGE_SURPLUS_PROXY");

        console2.log("USDG", USDG);
        console2.log("surplus buffer", surplus);

        vm.startBroadcast(key);
        PledgeVaultManager implementation = new PledgeVaultManager(USDG, surplus, address(0));
        vm.stopBroadcast();

        require(implementation.usdgDecimals() == 6, "vault: USDG is not 6 decimals");
        require(address(implementation.surplusBuffer()) == surplus, "vault: surplus mismatch");

        console2.log("implementation (NOT the vault address)", address(implementation));
        console2.log("usdgDecimals", implementation.usdgDecimals());
        console2.log("Next:");
        logExport("PLEDGE_VAULT_IMPL", address(implementation));
    }
}
