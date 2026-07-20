// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {PledgeProtocol} from "../src/PledgeProtocol.sol";
import {PledgeVaultManager} from "../src/core/PledgeVaultManager.sol";
import {PledgeSurplusBuffer} from "../src/core/PledgeSurplusBuffer.sol";
import {PledgeStabilityPool} from "../src/core/PledgeStabilityPool.sol";
import {PledgeChainlinkOracle} from "../src/oracle/PledgeChainlinkOracle.sol";

/// @title DeployPledgeMainnet
/// @notice Deploy Pledge Finance core to Robinhood Mainnet (chain 4663).
/// @dev Uses official Paxos USDG — no mock stablecoin minting.
contract DeployPledgeMainnet is Script {
    address internal constant USDG =
        0x5fc5360D0400a0Fd4f2af552ADD042D716F1d168;

    function run() external {
        uint256 deployerKey = _deployerPrivateKey();
        address deployer = vm.addr(deployerKey);

        console2.log("Protocol:", PledgeProtocol.NAME);
        console2.log("Version:", PledgeProtocol.VERSION);
        console2.log("Network: Robinhood Mainnet (4663)");
        console2.log("Deployer:", deployer);
        console2.log("USDG:", USDG);

        vm.startBroadcast(deployerKey);

        PledgeChainlinkOracle oracle = new PledgeChainlinkOracle(deployer);
        PledgeSurplusBuffer surplus = new PledgeSurplusBuffer(USDG, deployer);
        PledgeVaultManager vault = new PledgeVaultManager(USDG, address(surplus), deployer);
        PledgeStabilityPool stabilityPool = new PledgeStabilityPool(USDG, deployer);

        stabilityPool.setVaultManager(address(vault));

        vm.stopBroadcast();

        console2.log("PledgeChainlinkOracle", address(oracle));
        console2.log("PledgeSurplusBuffer", address(surplus));
        console2.log("PledgeVaultManager", address(vault));
        console2.log("PledgeStabilityPool", address(stabilityPool));
        console2.log("Next: forge script script/RegisterMainnetMarkets.s.sol --rpc-url robinhood_mainnet --broadcast");
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
