// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {console2} from "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {PledgeVaultManager} from "../../src/core/PledgeVaultManager.sol";
import {MainnetBase} from "./MainnetBase.sol";

/// @title FundLiquidityMainnet
/// @notice Step 08. Seeds the vault's USDG inventory — the only source of borrowable USDG.
/// @dev PLEDGE_FUND_AMOUNT is in native 6-decimal units: 10000000 is 10 USDG.
contract FundLiquidityMainnet is MainnetBase {
    function run() external onlyMainnet {
        uint256 key = deployerKey();
        address deployer = vm.addr(key);
        address vault = requireDeployed("PLEDGE_VAULT_PROXY");
        uint256 amount = vm.envUint("PLEDGE_FUND_AMOUNT");

        uint256 wallet = IERC20(USDG).balanceOf(deployer);
        console2.log("vault", vault);
        console2.log("wallet USDG", wallet);
        console2.log("fund amount", amount);

        require(amount > 0, "fund: PLEDGE_FUND_AMOUNT is zero");
        require(wallet >= amount, "fund: insufficient USDG");

        vm.startBroadcast(key);
        IERC20(USDG).approve(vault, amount);
        PledgeVaultManager(vault).fundLiquidity(amount);
        vm.stopBroadcast();

        console2.log("vault USDG inventory", IERC20(USDG).balanceOf(vault));
    }
}
