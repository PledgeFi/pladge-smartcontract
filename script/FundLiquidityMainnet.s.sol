// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {PledgeVaultManager} from "../src/core/PledgeVaultManager.sol";

/// @title FundLiquidityMainnet
/// @notice Approve + fundLiquidity on the live vault. Amount is native USDG units (6 decimals).
/// @dev MAINNET_FUND_AMOUNT=10000000000 is 10,000 USDG.
contract FundLiquidityMainnet is Script {
    address internal constant USDG = 0x5fc5360D0400a0Fd4f2af552ADD042D716F1d168;

    function run() external {
        uint256 deployerKey = _deployerPrivateKey();
        address deployer = vm.addr(deployerKey);
        address vault = vm.envAddress("MAINNET_VAULT_MANAGER");
        uint256 amount = vm.envUint("MAINNET_FUND_AMOUNT");

        uint256 wallet = IERC20(USDG).balanceOf(deployer);
        console2.log("Deployer", deployer);
        console2.log("Vault", vault);
        console2.log("Wallet USDG", wallet);
        console2.log("Fund amount", amount);

        require(amount > 0, "MAINNET_FUND_AMOUNT=0");
        require(wallet >= amount, "insufficient USDG");

        vm.startBroadcast(deployerKey);
        IERC20(USDG).approve(vault, amount);
        PledgeVaultManager(vault).fundLiquidity(amount);
        vm.stopBroadcast();

        console2.log("Vault USDG", IERC20(USDG).balanceOf(vault));
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
