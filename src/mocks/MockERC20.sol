// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title MockERC20
/// @notice Mintable ERC20 for testnet collateral and USDG stand-ins.
contract MockERC20 is ERC20 {
    uint8 private immutable _decimals;

    /// @notice Per-wallet faucet cooldown (48 hours).
    uint256 public constant COOLDOWN_DURATION = 48 hours;

    mapping(address account => uint256 timestamp) public lastMintAt;

    error FaucetCooldown(uint256 availableAt);

    constructor(string memory name_, string memory symbol_, uint8 decimals_) ERC20(name_, symbol_) {
        _decimals = decimals_;
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    function mint(address to, uint256 amount) external {
        uint256 last = lastMintAt[msg.sender];
        if (last != 0) {
            uint256 availableAt = last + COOLDOWN_DURATION;
            if (block.timestamp < availableAt) {
                revert FaucetCooldown(availableAt);
            }
        }
        lastMintAt[msg.sender] = block.timestamp;
        _mint(to, amount);
    }

    function cooldownRemaining(address account) external view returns (uint256) {
        uint256 last = lastMintAt[account];
        if (last == 0) return 0;
        uint256 availableAt = last + COOLDOWN_DURATION;
        if (block.timestamp >= availableAt) return 0;
        return availableAt - block.timestamp;
    }

    function burn(address from, uint256 amount) external {
        _burn(from, amount);
    }
}
