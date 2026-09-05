// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title TestnetEthFaucet
/// @notice Dispenses native ETH for Robinhood Chain testnet gas.
contract TestnetEthFaucet {
    uint256 public constant COOLDOWN_DURATION = 24 hours;

    uint256 public claimAmount;
    mapping(address account => uint256 timestamp) public lastClaimAt;

    error FaucetCooldown(uint256 availableAt);
    error FaucetEmpty();
    error TransferFailed();

    event Claimed(address indexed account, uint256 amount);

    constructor(uint256 claimAmountWei) {
        claimAmount = claimAmountWei;
    }

    receive() external payable {}

    function claim() external {
        uint256 last = lastClaimAt[msg.sender];
        if (last != 0) {
            uint256 availableAt = last + COOLDOWN_DURATION;
            if (block.timestamp < availableAt) {
                revert FaucetCooldown(availableAt);
            }
        }

        uint256 amount = claimAmount;
        if (address(this).balance < amount) revert FaucetEmpty();

        lastClaimAt[msg.sender] = block.timestamp;
        (bool ok,) = msg.sender.call{value: amount}("");
        if (!ok) revert TransferFailed();

        emit Claimed(msg.sender, amount);
    }

    function cooldownRemaining(address account) external view returns (uint256) {
        uint256 last = lastClaimAt[account];
        if (last == 0) return 0;
        uint256 availableAt = last + COOLDOWN_DURATION;
        if (block.timestamp >= availableAt) return 0;
        return availableAt - block.timestamp;
    }
}
