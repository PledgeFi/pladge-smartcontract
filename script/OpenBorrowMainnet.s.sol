// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {PledgeVaultManager} from "../src/core/PledgeVaultManager.sol";

/// @notice Leave an open live position: lock NVDA, borrow 2 USDG, do not repay.
contract OpenBorrowMainnet is Script {
    address internal constant NVDA = 0xd0601CE157Db5bdC3162BbaC2a2C8aF5320D9EEC;
    address internal constant USDG = 0x5fc5360D0400a0Fd4f2af552ADD042D716F1d168;
    uint256 internal constant BORROW_USDG = 2_000_000;

    function run() external {
        uint256 deployerKey = _deployerPrivateKey();
        address deployer = vm.addr(deployerKey);
        PledgeVaultManager vault = PledgeVaultManager(vm.envAddress("MAINNET_VAULT_MANAGER"));
        uint256 nvdaBal = IERC20(NVDA).balanceOf(deployer);
        require(nvdaBal > 0, "no NVDA");

        console2.log("Deployer", deployer);
        console2.log("NVDA to lock", nvdaBal);

        vm.startBroadcast(deployerKey);
        IERC20(NVDA).approve(address(vault), nvdaBal);
        vault.deposit(NVDA, nvdaBal);
        require(vault.getBorrowable(deployer, NVDA) >= BORROW_USDG, "below LTV");
        vault.borrow(NVDA, BORROW_USDG);
        vm.stopBroadcast();

        (uint256 col, uint256 debt,) = vault.positions(NVDA, deployer);
        console2.log("Locked NVDA", col);
        console2.log("Debt USDG", debt);
        console2.log("Wallet NVDA", IERC20(NVDA).balanceOf(deployer));
        console2.log("Wallet USDG", IERC20(USDG).balanceOf(deployer));
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
