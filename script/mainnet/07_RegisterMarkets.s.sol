// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {console2} from "forge-std/Script.sol";
import {PledgeVaultManager} from "../../src/core/PledgeVaultManager.sol";
import {MainnetBase} from "./MainnetBase.sol";

/// @title RegisterMarketsMainnet
/// @notice Step 07. Registers NVDA and SPY only. The remaining six names wait until the smoke
///         test has passed against a real loan.
contract RegisterMarketsMainnet is MainnetBase {
    function run() external onlyMainnet {
        uint256 key = deployerKey();
        address deployer = vm.addr(key);
        PledgeVaultManager vault = PledgeVaultManager(requireDeployed("PLEDGE_VAULT_PROXY"));
        address oracle = requireDeployed("PLEDGE_ORACLE_PROXY");
        require(vault.owner() == deployer, "vault: deployer is not owner");

        vm.startBroadcast(key);
        _register(vault, oracle, NVDA, NVDA_MAX_LTV_BPS, NVDA_LIQ_RATIO_BPS);
        _register(vault, oracle, SPY, SPY_MAX_LTV_BPS, SPY_LIQ_RATIO_BPS);
        vm.stopBroadcast();

        console2.log("vault", address(vault));
        console2.log("markets", vault.getMarketCount());
        _report(vault, "NVDA", NVDA);
        _report(vault, "SPY", SPY);
    }

    function _register(PledgeVaultManager vault, address oracle, address token, uint16 maxLtv, uint16 liqRatio)
        internal
    {
        (address existing,,,,,,,) = vault.markets(token);
        if (existing != address(0)) {
            console2.log("already registered, skipping", token);
            return;
        }
        vault.registerMarket(token, oracle, maxLtv, liqRatio, LIQ_BONUS_BPS, STABILITY_FEE_APR_BPS, ORIGINATION_FEE_BPS);
    }

    function _report(PledgeVaultManager vault, string memory symbol, address token) internal view {
        (
            address collateral,
            address oracle,
            uint16 maxLtvBps,
            uint16 liqRatioBps,
            uint16 liqBonusBps,
            uint16 aprBps,
            uint16 originationFeeBps,
            bool active
        ) = vault.markets(token);

        require(collateral == token, "market: not registered");
        require(active, "market: inactive");

        console2.log(string.concat("-- ", symbol), collateral);
        console2.log("   oracle        ", oracle);
        console2.log("   maxLtvBps     ", maxLtvBps);
        console2.log("   liqRatioBps   ", liqRatioBps);
        console2.log("   liqBonusBps   ", liqBonusBps);
        console2.log("   aprBps        ", aprBps);
        console2.log("   originationBps", originationFeeBps);
    }
}
