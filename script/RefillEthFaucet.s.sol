// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";

/// @notice Send native ETH to the deployed testnet ETH faucet.
contract RefillEthFaucet is Script {
    address internal constant FAUCET = 0x4FaEF9f379556d973e733B2345097A51071CF4b6;
    uint256 internal constant GAS_RESERVE = 0.001 ether;

    function run() external {
        uint256 deployerKey = _deployerPrivateKey();
        address deployer = vm.addr(deployerKey);
        uint256 balance = deployer.balance;
        uint256 sendAmount = balance > GAS_RESERVE ? balance - GAS_RESERVE : 0;

        console2.log("Deployer:", deployer);
        console2.log("Deployer balance (wei):", balance);
        console2.log("Send amount (wei):", sendAmount);
        console2.log("Faucet before (wei):", FAUCET.balance);

        require(sendAmount > 0, "nothing to send");

        vm.startBroadcast(deployerKey);
        (bool ok,) = FAUCET.call{value: sendAmount}("");
        require(ok, "transfer failed");
        vm.stopBroadcast();

        console2.log("Faucet after (wei):", FAUCET.balance);
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
