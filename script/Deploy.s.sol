// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {PledgeProtocol} from "../src/PledgeProtocol.sol";
import {PledgeVaultManager} from "../src/core/PledgeVaultManager.sol";
import {PledgeSurplusBuffer} from "../src/core/PledgeSurplusBuffer.sol";
import {PledgeStabilityPool} from "../src/core/PledgeStabilityPool.sol";
import {PledgeChainlinkOracle} from "../src/oracle/PledgeChainlinkOracle.sol";
import {MockChainlinkFeed} from "../src/mocks/MockChainlinkFeed.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";

/// @title DeployPledge
/// @author Pledge Finance
/// @notice Deploy Pledge Finance core contracts to Robinhood Testnet.
contract DeployPledge is Script {
    function run() external {
        uint256 deployerKey = _deployerPrivateKey();
        address deployer = vm.addr(deployerKey);

        console2.log("Protocol:", PledgeProtocol.NAME);
        console2.log("Version:", PledgeProtocol.VERSION);
        console2.log("Deployer:", deployer);

        vm.startBroadcast(deployerKey);

        MockERC20 usdg = new MockERC20(PledgeProtocol.USDG_NAME, PledgeProtocol.USDG_SYMBOL, 18);
        MockERC20 mNvda = new MockERC20("Pledge Finance mNVDA", "mNVDA", 18);
        PledgeChainlinkOracle oracle = new PledgeChainlinkOracle(deployer);
        oracle.setMaxStaleness(4 days);
        MockChainlinkFeed nvdaFeed =
            new MockChainlinkFeed("mNVDA / USD", 509_00000000, deployer);
        oracle.setFeed(address(mNvda), address(nvdaFeed));
        PledgeSurplusBuffer surplus = new PledgeSurplusBuffer(address(usdg), deployer);
        PledgeVaultManager vault = new PledgeVaultManager(address(usdg), address(surplus), deployer);
        PledgeStabilityPool stabilityPool = new PledgeStabilityPool(address(usdg), deployer);

        stabilityPool.setVaultManager(address(vault));

        vault.registerMarket(
            address(mNvda),
            address(oracle),
            6000,
            16600,
            500,
            120,
            50
        );

        vm.stopBroadcast();

        console2.log("PledgeFinanceUSDG", address(usdg));
        console2.log("PledgeFinanceMNVDA", address(mNvda));
        console2.log("PledgeChainlinkOracle", address(oracle));
        console2.log("mNVDA ChainlinkFeed", address(nvdaFeed));
        console2.log("PledgeSurplusBuffer", address(surplus));
        console2.log("PledgeVaultManager", address(vault));
        console2.log("PledgeStabilityPool", address(stabilityPool));
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
