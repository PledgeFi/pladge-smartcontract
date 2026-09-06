// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IOracle} from "../interfaces/IOracle.sol";
import {PledgeUupsOwnable} from "../upgrade/PledgeUupsOwnable.sol";

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
/// @notice Upgradeable Chainlink price feeds for Robinhood stock tokens (USD, 18 decimals).
/// @dev Use the ERC1967 proxy address. Upgrade with upgradeToAndCall from owner.
/// @dev STORAGE LAYOUT IS LOAD-BEARING (this contract has live mainnet state). This contract is
///      a storage "leaf" (nothing inherits it), so it is safe to APPEND new state variables at
///      the end, but NEVER reorder or insert existing ones — see PledgeUupsOwnable for the
///      incident this note exists because of. `feeds` and `maxStaleness` must keep their exact
///      slot order (right after `owner` from PledgeUupsOwnable).
contract PledgeChainlinkOracle is IOracle, PledgeUupsOwnable {
    string public constant name = "Pledge Finance Oracle";

    mapping(address => address) public feeds;
    uint256 public maxStaleness;

    // --- Appended after initial mainnet deployment. Do not reorder. ---
    /// @notice Optional secondary feed used only if the primary feed reverts or is unusable.
    mapping(address => address) public fallbackFeeds;
    /// @notice Optional sanity bounds (18-decimal USD) rejecting implausible prices from either
    ///         feed. A market with `maxPriceUsd == 0` has no bound configured (bounds are opt-in
    ///         so this upgrade can never brick an already-configured market).
    mapping(address => uint256) public minPriceUsd;
    mapping(address => uint256) public maxPriceUsd;

    event FeedSet(address indexed asset, address indexed feed);
    event FallbackFeedSet(address indexed asset, address indexed feed);
    event PriceBoundsSet(address indexed asset, uint256 minPriceUsd, uint256 maxPriceUsd);
    event MaxStalenessUpdated(uint256 maxStaleness);

    error ZeroAddressFeed();
    error FeedNotAContract();
    error InvalidPriceBounds();

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address owner_) external initializer {
        _initOwner(owner_);
        maxStaleness = 24 hours;
    }

    /// @dev Rejects EOAs/undeployed addresses so a typo can't silently brick a market
    ///      (calls would revert only later, at `getPrice`, with a confusing low-level error).
    function setFeed(address asset, address feed) external onlyOwner {
        if (asset == address(0)) revert ZeroAddress();
        if (feed == address(0)) revert ZeroAddressFeed();
        if (feed.code.length == 0) revert FeedNotAContract();
        feeds[asset] = feed;
        emit FeedSet(asset, feed);
    }

    /// @notice Sets (or clears with `address(0)`) a secondary feed tried only if the primary
    ///         feed for `asset` reverts, is stale, or otherwise fails validation.
    function setFallbackFeed(address asset, address feed) external onlyOwner {
        if (asset == address(0)) revert ZeroAddress();
        if (feed != address(0) && feed.code.length == 0) revert FeedNotAContract();
        fallbackFeeds[asset] = feed;
        emit FallbackFeedSet(asset, feed);
    }

    /// @notice Sets coarse sanity bounds (18-decimal USD) for `asset`. `getPrice` reverts if
    ///         the feed-reported price falls outside `[minPriceUsd_, maxPriceUsd_]`. This guards
    ///         against a compromised/misbehaving feed reporting a wildly wrong price (including
    ///         a Chainlink aggregator's own `minAnswer`/`maxAnswer` clamp silently kicking in
    ///         during an extreme move instead of reverting).
    /// @dev Pass `maxPriceUsd_ == 0` to clear/disable bounds for `asset`.
    function setPriceBounds(address asset, uint256 minPriceUsd_, uint256 maxPriceUsd_) external onlyOwner {
        if (asset == address(0)) revert ZeroAddress();
        if (maxPriceUsd_ != 0 && minPriceUsd_ >= maxPriceUsd_) revert InvalidPriceBounds();
        minPriceUsd[asset] = minPriceUsd_;
        maxPriceUsd[asset] = maxPriceUsd_;
        emit PriceBoundsSet(asset, minPriceUsd_, maxPriceUsd_);
    }

    function setMaxStaleness(uint256 maxStaleness_) external onlyOwner {
        maxStaleness = maxStaleness_;
        emit MaxStalenessUpdated(maxStaleness_);
    }

    function getPrice(address asset) external view returns (uint256 priceUsd) {
        address feed = feeds[asset];
        require(feed != address(0), "ORACLE: no feed");

        address fb = fallbackFeeds[asset];
        if (fb == address(0)) {
            // No fallback configured: identical behavior/revert reasons as before this upgrade.
            priceUsd = _readFeedStrict(feed);
        } else {
            (bool ok, uint256 price) = _tryReadFeed(feed);
            if (!ok) {
                (bool okFb, uint256 priceFb) = _tryReadFeed(fb);
                require(okFb, "ORACLE: primary and fallback both failed");
                price = priceFb;
            }
            priceUsd = price;
        }

        uint256 hi = maxPriceUsd[asset];
        if (hi != 0) {
            require(priceUsd >= minPriceUsd[asset] && priceUsd <= hi, "ORACLE: price out of bounds");
        }
    }

    function isStale(address asset) external view returns (bool) {
        address feed = feeds[asset];
        if (feed == address(0)) return true;
        (bool ok,) = _tryReadFeed(feed);
        if (ok) return false;
        address fb = fallbackFeeds[asset];
        if (fb == address(0)) return true;
        (bool okFb,) = _tryReadFeed(fb);
        return !okFb;
    }

    /// @dev Original strict path (used whenever no fallback is configured for the asset):
    ///      reverts with a specific reason per failure mode, exactly as before this upgrade.
    function _readFeedStrict(address feed) internal view returns (uint256 priceUsd) {
        (uint80 roundId, int256 answer, uint256 startedAt, uint256 feedUpdatedAt, uint80 answeredInRound) =
            AggregatorV3Interface(feed).latestRoundData();
        require(answer > 0, "ORACLE: bad price");
        require(startedAt != 0 && feedUpdatedAt != 0, "ORACLE: round incomplete");
        require(answeredInRound >= roundId, "ORACLE: stale round");
        require(block.timestamp - feedUpdatedAt <= maxStaleness, "ORACLE: stale");

        uint8 feedDecimals = AggregatorV3Interface(feed).decimals();
        if (feedDecimals <= 18) {
            priceUsd = uint256(answer) * (10 ** uint256(18 - feedDecimals));
        } else {
            priceUsd = uint256(answer) / (10 ** uint256(feedDecimals - 18));
        }
    }

    /// @dev Non-reverting variant of `_readFeedStrict`, used only when a fallback feed exists so
    ///      a primary-feed failure can fall through to the fallback instead of reverting outright.
    function _tryReadFeed(address feed) internal view returns (bool ok, uint256 priceUsd) {
        try AggregatorV3Interface(feed).latestRoundData() returns (
            uint80 roundId, int256 answer, uint256 startedAt, uint256 feedUpdatedAt, uint80 answeredInRound
        ) {
            if (answer <= 0) return (false, 0);
            if (startedAt == 0 || feedUpdatedAt == 0) return (false, 0);
            if (answeredInRound < roundId) return (false, 0);
            if (block.timestamp - feedUpdatedAt > maxStaleness) return (false, 0);

            try AggregatorV3Interface(feed).decimals() returns (uint8 feedDecimals) {
                if (feedDecimals <= 18) {
                    priceUsd = uint256(answer) * (10 ** uint256(18 - feedDecimals));
                } else {
                    priceUsd = uint256(answer) / (10 ** uint256(feedDecimals - 18));
                }
                return (true, priceUsd);
            } catch {
                return (false, 0);
            }
        } catch {
            return (false, 0);
        }
    }
}
