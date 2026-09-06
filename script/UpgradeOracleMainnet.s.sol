// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {PledgeChainlinkOracle} from "../src/oracle/PledgeChainlinkOracle.sol";

/// @title UpgradeOracleMainnet
/// @notice Deploys the hardened `PledgeChainlinkOracle` implementation (Chainlink round-completeness
///         checks + `setFeed` validation) and upgrades the live mainnet proxy via UUPS.
/// @dev Must be run by the CURRENT owner of the oracle proxy. Storage (feeds, maxStaleness, owner,
///      pendingOwner) is preserved across the upgrade — only the logic contract changes.
///      Run this BEFORE handing ownership to the Timelock (see TransferOwnershipToTimelock.s.sol),
///      since after that only the Timelock (via the Safe, after the delay) can authorize upgrades.
contract UpgradeOracleMainnet is Script {
    address internal constant DEFAULT_ORACLE = 0x195287cbcd53eF058a3DeC4c6DC8f17Bf79A28d9;

    function run() external {
        uint256 deployerKey = _deployerPrivateKey();
        address deployer = vm.addr(deployerKey);

        address oracleAddr = vm.envOr("MAINNET_ORACLE", DEFAULT_ORACLE);
        PledgeChainlinkOracle oracle = PledgeChainlinkOracle(oracleAddr);

        console2.log("Deployer:", deployer);
        console2.log("Oracle proxy:", oracleAddr);
        console2.log("Current owner:", oracle.owner());
        require(oracle.owner() == deployer, "UpgradeOracleMainnet: deployer is not the current owner");

        vm.startBroadcast(deployerKey);
        PledgeChainlinkOracle newImplementation = new PledgeChainlinkOracle();
        oracle.upgradeToAndCall(address(newImplementation), "");
        vm.stopBroadcast();

        console2.log("New implementation deployed at:", address(newImplementation));
        console2.log("Oracle proxy upgraded. maxStaleness (unchanged):", oracle.maxStaleness());
        console2.log("Verify getPrice() still works for all 8 markets before proceeding.");
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
