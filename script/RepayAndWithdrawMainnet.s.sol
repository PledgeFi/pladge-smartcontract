// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {PledgeVaultManager} from "../src/core/PledgeVaultManager.sol";

/// @notice Fully repay the live NVDA loan and withdraw collateral.
contract RepayAndWithdrawMainnet is Script {
    address internal constant NVDA = 0xd0601CE157Db5bdC3162BbaC2a2C8aF5320D9EEC;
    address internal constant USDG = 0x5fc5360D0400a0Fd4f2af552ADD042D716F1d168;

    function run() external {
        uint256 deployerKey = _deployerPrivateKey();
        address deployer = vm.addr(deployerKey);
        PledgeVaultManager vault = PledgeVaultManager(vm.envAddress("MAINNET_VAULT_MANAGER"));

        (uint256 principal, uint256 interest, uint256 total, uint256 openedAt, uint16 aprBps) =
            vault.getRepayBreakdown(deployer, NVDA);
        console2.log("Principal", principal);
        console2.log("Interest", interest);
        console2.log("Total due", total);
        console2.log("Opened at", openedAt);
        console2.log("APR bps", aprBps);
        require(total > 0, "no debt");
        uint256 walletUsdg = IERC20(USDG).balanceOf(deployer);
        require(walletUsdg >= total, "not enough USDG");

        vm.startBroadcast(deployerKey);
        IERC20(USDG).approve(address(vault), walletUsdg);
        vault.repay(NVDA, walletUsdg);
        (uint256 col, uint256 debt,) = vault.positions(NVDA, deployer);
        require(debt == 0, "debt leftover");
        vault.withdraw(NVDA, col);
        vm.stopBroadcast();

        console2.log("Wallet NVDA", IERC20(NVDA).balanceOf(deployer));
        console2.log("Wallet USDG", IERC20(USDG).balanceOf(deployer));
        console2.log("Vault USDG", IERC20(USDG).balanceOf(address(vault)));
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
