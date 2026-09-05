// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IOracle} from "../interfaces/IOracle.sol";
import {PledgeUupsOwnable} from "../upgrade/PledgeUupsOwnable.sol";

/// @title PledgeOracle
/// @author Pledge Finance
/// @notice Pledge Finance testnet price oracle (USD, 18 decimals). Replace with Chainlink on mainnet.
/// @dev Production: deploy behind ERC1967Proxy. Tests may pass owner in the constructor.
contract PledgeOracle is IOracle, PledgeUupsOwnable {
    mapping(address => uint256) public prices;
    mapping(address => uint256) public updatedAt;
    uint256 public maxStaleness;

    event PriceUpdated(address indexed asset, uint256 priceUsd);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address owner_) {
        maxStaleness = 24 hours;
        _disableAndMaybeSetOwner(owner_);
    }

    function initialize(address owner_) external initializer {
        _initOwner(owner_);
        maxStaleness = 24 hours;
    }

    function setPrice(address asset, uint256 priceUsd) external onlyOwner {
        prices[asset] = priceUsd;
        updatedAt[asset] = block.timestamp;
        emit PriceUpdated(asset, priceUsd);
    }

    function setMaxStaleness(uint256 maxStaleness_) external onlyOwner {
        maxStaleness = maxStaleness_;
    }

    function getPrice(address asset) external view returns (uint256) {
        uint256 price = prices[asset];
        require(price > 0, "ORACLE: no price");
        require(!isStale(asset), "ORACLE: stale");
        return price;
    }

    function isStale(address asset) public view returns (bool) {
        if (updatedAt[asset] == 0) return true;
        return block.timestamp - updatedAt[asset] > maxStaleness;
    }
}
