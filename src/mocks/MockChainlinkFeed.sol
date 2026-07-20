// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @title MockChainlinkFeed
/// @notice Chainlink AggregatorV3-compatible feed for Robinhood testnet (8 decimals).
contract MockChainlinkFeed is Ownable {
    uint8 public constant DECIMALS = 8;

    string public description;
    int256 public answer;
    uint80 public roundId;
    uint256 public updatedAt;

    constructor(string memory description_, int256 initialAnswer, address owner_) Ownable(owner_) {
        description = description_;
        _setAnswer(initialAnswer);
    }

    function decimals() external pure returns (uint8) {
        return DECIMALS;
    }

    function latestRoundData()
        external
        view
        returns (
            uint80 roundId_,
            int256 answer_,
            uint256 startedAt,
            uint256 updatedAt_,
            uint80 answeredInRound
        )
    {
        return (roundId, answer, updatedAt, updatedAt, roundId);
    }

    function setAnswer(int256 newAnswer) external onlyOwner {
        _setAnswer(newAnswer);
    }

    function _setAnswer(int256 newAnswer) internal {
        require(newAnswer > 0, "bad price");
        roundId += 1;
        answer = newAnswer;
        updatedAt = block.timestamp;
    }
}
