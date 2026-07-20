// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IOracle} from "../interfaces/IOracle.sol";

interface AggregatorV3Interface {
    function decimals() external view returns (uint8);
    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        );
}

/// @title PledgeChainlinkOracle
/// @author Pledge Finance
/// @notice Chainlink price feeds for Robinhood stock tokens (USD, 18 decimals).
contract PledgeChainlinkOracle is IOracle, Ownable {
    mapping(address => address) public feeds;
    uint256 public maxStaleness = 24 hours;

    event FeedSet(address indexed asset, address indexed feed);
    event MaxStalenessUpdated(uint256 maxStaleness);

    constructor(address owner_) Ownable(owner_) {}

    function setFeed(address asset, address feed) external onlyOwner {
        feeds[asset] = feed;
        emit FeedSet(asset, feed);
    }

    function setMaxStaleness(uint256 maxStaleness_) external onlyOwner {
        maxStaleness = maxStaleness_;
        emit MaxStalenessUpdated(maxStaleness_);
    }

    function getPrice(address asset) external view returns (uint256 priceUsd) {
        address feed = feeds[asset];
        require(feed != address(0), "ORACLE: no feed");

        (, int256 answer,, uint256 feedUpdatedAt,) = AggregatorV3Interface(feed).latestRoundData();
        require(answer > 0, "ORACLE: bad price");
        require(block.timestamp - feedUpdatedAt <= maxStaleness, "ORACLE: stale");

        uint8 feedDecimals = AggregatorV3Interface(feed).decimals();
        if (feedDecimals <= 18) {
            priceUsd = uint256(answer) * (10 ** uint256(18 - feedDecimals));
        } else {
            priceUsd = uint256(answer) / (10 ** uint256(feedDecimals - 18));
        }
    }

    function isStale(address asset) external view returns (bool) {
        address feed = feeds[asset];
        if (feed == address(0)) return true;
        (, int256 answer,, uint256 feedUpdatedAt,) = AggregatorV3Interface(feed).latestRoundData();
        if (answer <= 0) return true;
        return block.timestamp - feedUpdatedAt > maxStaleness;
    }
}
