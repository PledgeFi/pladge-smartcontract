// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {console2} from "forge-std/Script.sol";
import {PledgeFinanceStabilityPool} from "../../src/upgrade/PledgeFinanceProxies.sol";
import {PledgeStabilityPool} from "../../src/core/PledgeStabilityPool.sol";
import {MainnetBase} from "./MainnetBase.sol";

/// @title DeployPoolMainnet
/// @notice Step 06. Stability pool behind a proxy, pointed at the new vault.
/// @dev The pool is USDG parking, not a liquidation backstop: `payDebt` reverts and `liquidate`
///      pulls USDG from the liquidator's own wallet. `setVaultManager` only gates that dead
///      function today, but is set correctly so the wiring is not left dangling.
contract DeployPoolMainnet is MainnetBase {
    function run() external onlyMainnet {
        uint256 key = deployerKey();
        address deployer = vm.addr(key);
        address vault = requireDeployed("PLEDGE_VAULT_PROXY");

        vm.startBroadcast(key);
        PledgeStabilityPool implementation = new PledgeStabilityPool(USDG, address(0));
        PledgeFinanceStabilityPool proxy = new PledgeFinanceStabilityPool(
            address(implementation), abi.encodeCall(PledgeStabilityPool.initialize, (deployer))
        );
        PledgeStabilityPool(address(proxy)).setVaultManager(vault);
        vm.stopBroadcast();

        PledgeStabilityPool pool = PledgeStabilityPool(address(proxy));
        require(pool.owner() == deployer, "pool: owner mismatch");
        require(address(pool.usdg()) == USDG, "pool: wrong USDG");
        require(pool.vaultManager() == vault, "pool: wrong vault manager");

        console2.log("implementation", address(implementation));
        console2.log("proxy (use this)", address(proxy));
        console2.log("vaultManager", pool.vaultManager());
        console2.log("Next:");
        logExport("PLEDGE_POOL_IMPL", address(implementation));
        logExport("PLEDGE_POOL_PROXY", address(proxy));
    }
}
