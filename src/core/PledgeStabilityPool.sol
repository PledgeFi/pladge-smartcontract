// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {PledgeUupsOwnable} from "../upgrade/PledgeUupsOwnable.sol";

/// @title PledgeStabilityPool
/// @author Pledge Finance
/// @notice Pledge Finance USDG pool for liquidation backstop.
/// @dev Production: deploy behind ERC1967Proxy. Tests may pass owner in the constructor.
contract PledgeStabilityPool is PledgeUupsOwnable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public immutable usdg;
    address public vaultManager;

    uint256 public totalDeposits;
    mapping(address => uint256) public balanceOf;

    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event VaultManagerUpdated(address indexed vaultManager);

    error OnlyVaultManager();
    error InsufficientBalance();

    modifier onlyVaultManager() {
        if (msg.sender != vaultManager) revert OnlyVaultManager();
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address usdg_, address owner_) {
        usdg = IERC20(usdg_);
        _disableAndMaybeSetOwner(owner_);
    }

    function initialize(address owner_) external initializer {
        _initOwner(owner_);
    }

    function setVaultManager(address vaultManager_) external onlyOwner {
        vaultManager = vaultManager_;
        emit VaultManagerUpdated(vaultManager_);
    }

    function deposit(uint256 amount) external nonReentrant {
        usdg.safeTransferFrom(msg.sender, address(this), amount);
        balanceOf[msg.sender] += amount;
        totalDeposits += amount;
        emit Deposited(msg.sender, amount);
    }

    function withdraw(uint256 amount) external nonReentrant {
        if (balanceOf[msg.sender] < amount) revert InsufficientBalance();
        balanceOf[msg.sender] -= amount;
        totalDeposits -= amount;
        usdg.safeTransfer(msg.sender, amount);
        emit Withdrawn(msg.sender, amount);
    }

    /// @notice Called by VaultManager during liquidation to spend pooled USDG.
    function payDebt(address to, uint256 amount) external onlyVaultManager {
        usdg.safeTransfer(to, amount);
    }
}
