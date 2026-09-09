// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {console2} from "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {PledgeVaultManager} from "../../src/core/PledgeVaultManager.sol";
import {MainnetBase} from "./MainnetBase.sol";

/// @title SmokeVaultMainnet
/// @notice Step 09. One real loan end to end: deposit NVDA, borrow, read the repay receipt, repay,
///         withdraw. Asserts at every stage so a partial failure is obvious.
/// @dev Amounts come from the environment so the operator picks the size:
///      PLEDGE_SMOKE_COLLATERAL (18dp NVDA) and PLEDGE_SMOKE_BORROW (6dp USDG).
contract SmokeVaultMainnet is MainnetBase {
    function run() external onlyMainnet {
        uint256 key = deployerKey();
        address deployer = vm.addr(key);
        PledgeVaultManager vault = PledgeVaultManager(requireDeployed("PLEDGE_VAULT_PROXY"));
        uint256 collateralAmount = vm.envUint("PLEDGE_SMOKE_COLLATERAL");
        uint256 borrowAmount = vm.envUint("PLEDGE_SMOKE_BORROW");

        require(IERC20(NVDA).balanceOf(deployer) >= collateralAmount, "smoke: not enough NVDA");
        require(IERC20(USDG).balanceOf(address(vault)) >= borrowAmount, "smoke: vault inventory too low");

        uint256 nvdaBefore = IERC20(NVDA).balanceOf(deployer);
        uint256 usdgBefore = IERC20(USDG).balanceOf(deployer);

        vm.startBroadcast(key);
        IERC20(NVDA).approve(address(vault), collateralAmount);
        vault.deposit(NVDA, collateralAmount);

        uint256 borrowable = vault.getBorrowable(deployer, NVDA);
        console2.log("borrowable after deposit", borrowable);
        require(borrowable >= borrowAmount, "smoke: borrow exceeds LTV headroom");

        vault.borrow(NVDA, borrowAmount);
        console2.log("health factor after borrow", vault.getHealthFactor(deployer, NVDA));

        _repayAndWithdraw(vault, deployer);
        vm.stopBroadcast();

        console2.log("NVDA before/after", nvdaBefore, IERC20(NVDA).balanceOf(deployer));
        console2.log("USDG before/after", usdgBefore, IERC20(USDG).balanceOf(deployer));
        require(IERC20(NVDA).balanceOf(deployer) == nvdaBefore, "smoke: collateral not fully returned");
    }

    function _repayAndWithdraw(PledgeVaultManager vault, address deployer) internal {
        (uint256 principal, uint256 interest, uint256 total, uint256 openedAt, uint16 aprBps) =
            vault.getRepayBreakdown(deployer, NVDA);

        console2.log("-- repay receipt");
        console2.log("   principal", principal);
        console2.log("   interest ", interest);
        console2.log("   total due", total);
        console2.log("   openedAt ", openedAt);
        console2.log("   apr bps  ", aprBps);
        require(principal + interest == total, "smoke: receipt does not add up");
        require(IERC20(USDG).balanceOf(deployer) >= total, "smoke: not enough USDG to repay");

        IERC20(USDG).approve(address(vault), total);
        vault.repay(NVDA, total);

        (uint256 collateral, uint256 debt,) = vault.positions(NVDA, deployer);
        require(debt == 0, "smoke: debt left over");
        vault.withdraw(NVDA, collateral);
    }
}
