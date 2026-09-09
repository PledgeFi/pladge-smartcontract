// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {console2} from "forge-std/Script.sol";
import {PledgeChainlinkOracle} from "../../src/oracle/PledgeChainlinkOracle.sol";
import {MainnetBase} from "./MainnetBase.sol";

/// @title SetOracleFeedsMainnet
/// @notice Step 02. Wires the NVDA and SPY Chainlink feeds and widens staleness to 4 days.
/// @dev Equity feeds stop updating over weekends and outside market hours. 24h would freeze the
///      whole vault — including repay and withdraw — every Monday morning.
contract SetOracleFeedsMainnet is MainnetBase {
    function run() external onlyMainnet {
        uint256 key = deployerKey();
        address deployer = vm.addr(key);
        PledgeChainlinkOracle oracle = PledgeChainlinkOracle(requireDeployed("PLEDGE_ORACLE_PROXY"));
        require(oracle.owner() == deployer, "oracle: deployer is not owner");

        vm.startBroadcast(key);
        oracle.setMaxStaleness(ORACLE_MAX_STALENESS);
        oracle.setFeed(NVDA, NVDA_FEED);
        oracle.setFeed(SPY, SPY_FEED);
        vm.stopBroadcast();

        console2.log("oracle", address(oracle));
        console2.log("maxStaleness", oracle.maxStaleness());

        // Proves the whole path the vault depends on: feed -> 18-decimal USD price.
        uint256 nvda = oracle.getPrice(NVDA);
        uint256 spy = oracle.getPrice(SPY);
        console2.log("NVDA 18dp", nvda);
        console2.log("NVDA USD ", nvda / 1e18);
        console2.log("SPY  18dp", spy);
        console2.log("SPY  USD ", spy / 1e18);

        require(nvda > 0 && spy > 0, "oracle: zero price");
    }
}
