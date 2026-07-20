// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IOracle
/// @notice Price feed for collateral valued in USD (18 decimals).
interface IOracle {
    function getPrice(address asset) external view returns (uint256 priceUsd);

    function isStale(address asset) external view returns (bool);
}
