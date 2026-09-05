// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {TestnetEthFaucet} from "../src/mocks/TestnetEthFaucet.sol";

/// @notice Deploy native ETH faucet for Robinhood testnet (46630).
contract DeployEthFaucet is Script {
    uint256 internal constant CLAIM_AMOUNT = 0.01 ether;
    uint256 internal constant DEFAULT_SEED = 0.1 ether;
    uint256 internal constant GAS_RESERVE = 0.005 ether;

    function run() external {
        uint256 deployerKey = _deployerPrivateKey();
        address deployer = vm.addr(deployerKey);
        uint256 balance = deployer.balance;
        uint256 seedAmount = balance > GAS_RESERVE ? balance - GAS_RESERVE : 0;
        if (seedAmount > DEFAULT_SEED) seedAmount = DEFAULT_SEED;

        console2.log("Deployer:", deployer);
        console2.log("Deployer balance (wei):", balance);
        console2.log("Claim amount (wei):", CLAIM_AMOUNT);
        console2.log("Seed amount (wei):", seedAmount);

        vm.startBroadcast(deployerKey);

        TestnetEthFaucet faucet = new TestnetEthFaucet(CLAIM_AMOUNT);
        if (seedAmount > 0) {
            (bool sent,) = address(faucet).call{value: seedAmount}("");
            require(sent, "seed transfer failed");
        }

        vm.stopBroadcast();

        console2.log("PledgeTestnetEthFaucet", address(faucet));
        console2.log("Faucet balance (wei):", address(faucet).balance);
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
