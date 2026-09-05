// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {PledgeSurplusBuffer} from "../src/core/PledgeSurplusBuffer.sol";

/// @notice Pull USDG fees from surplus to the deployer. Old vault inventory cannot be drained.
contract WithdrawSurplusMainnet is Script {
    address internal constant USDG = 0x5fc5360D0400a0Fd4f2af552ADD042D716F1d168;
    address internal constant SURPLUS = 0xEa30446c46D61514f19c897224E65b13Fb0A826c;

    function run() external {
        uint256 deployerKey = _deployerPrivateKey();
        address deployer = vm.addr(deployerKey);
        uint256 amount = IERC20(USDG).balanceOf(SURPLUS);
        console2.log("Deployer", deployer);
        console2.log("Surplus USDG", amount);
        require(amount > 0, "surplus empty");

        vm.startBroadcast(deployerKey);
        PledgeSurplusBuffer(SURPLUS).withdraw(deployer, amount);
        vm.stopBroadcast();

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
