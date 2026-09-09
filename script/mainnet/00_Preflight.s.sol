// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {console2} from "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MainnetBase} from "./MainnetBase.sol";

interface IAggregatorV3 {
    function decimals() external view returns (uint8);
    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);
}

/// @title PreflightMainnet
/// @notice Read-only. Confirms the deployer can actually complete the redeploy before any gas is spent.
contract PreflightMainnet is MainnetBase {
    function run() external view onlyMainnet {
        address deployer = vm.addr(deployerKey());

        console2.log("=== Preflight: Robinhood Mainnet 4663 ===");
        console2.log("deployer      ", deployer);
        console2.log("block         ", block.number);
        console2.log("ETH (wei)     ", deployer.balance);
        console2.log("USDG (6dp)    ", IERC20(USDG).balanceOf(deployer));
        console2.log("PLG  (18dp)   ", IERC20(PLG).balanceOf(deployer));
        console2.log("NVDA (18dp)   ", IERC20(NVDA).balanceOf(deployer));
        console2.log("SPY  (18dp)   ", IERC20(SPY).balanceOf(deployer));

        _checkFeed("NVDA", NVDA_FEED);
        _checkFeed("SPY", SPY_FEED);

        // Deploying the five implementations plus proxies measured ~11.3M gas. At 0.25 gwei that
        // is ~0.003 ETH; the floor below leaves room for a failed transaction and a retry.
        require(deployer.balance >= 0.005 ether, "preflight: need at least 0.005 ETH");
        console2.log("ETH sufficient for the deploy steps");
    }

    function _checkFeed(string memory symbol, address feed) internal view {
        (uint80 roundId, int256 answer,, uint256 updatedAt, uint80 answeredInRound) =
            IAggregatorV3(feed).latestRoundData();
        uint8 dec = IAggregatorV3(feed).decimals();

        console2.log(string.concat("-- feed ", symbol), feed);
        console2.log("   price (feed dp)", uint256(answer));
        console2.log("   decimals       ", dec);
        console2.log("   age (seconds)  ", block.timestamp - updatedAt);

        require(answer > 0, "feed: non-positive answer");
        require(answeredInRound >= roundId, "feed: stale round");
        require(block.timestamp - updatedAt <= ORACLE_MAX_STALENESS, "feed: older than maxStaleness");
    }
}
