// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IOracle} from "../interfaces/IOracle.sol";

/// @title PledgeOracle
/// @author Pledge Finance
/// @notice Pledge Finance testnet price oracle (USD, 18 decimals). Replace with Chainlink on mainnet.
contract PledgeOracle is IOracle, Ownable {
    mapping(address => uint256) public prices;
    mapping(address => uint256) public updatedAt;
    uint256 public maxStaleness = 24 hours;

    event PriceUpdated(address indexed asset, uint256 priceUsd);

    constructor(address owner_) Ownable(owner_) {}

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
