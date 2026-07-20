// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title PledgeStaking
/// @notice Testnet staking pools with proportional reward emissions.
contract PledgeStaking is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint256 public constant ACC_PRECISION = 1e18;
    uint256 public constant EPOCH_DURATION = 7 days;

    struct PoolInfo {
        IERC20 stakeToken;
        IERC20 rewardToken;
        uint256 rewardRatePerSecond;
        uint256 totalStaked;
        uint256 accRewardPerShare;
        uint256 lastUpdateTime;
        uint256 lockDuration;
        bool active;
    }

    struct UserInfo {
        uint256 amount;
        uint256 rewardDebt;
        uint256 lockedUntil;
    }

    PoolInfo[] private _pools;
    mapping(uint256 => mapping(address => UserInfo)) public users;

    event PoolAdded(uint256 indexed poolId, address stakeToken, address rewardToken, uint256 lockDuration);
    event Staked(uint256 indexed poolId, address indexed user, uint256 amount);
    event Unstaked(uint256 indexed poolId, address indexed user, uint256 amount);
    event RewardClaimed(uint256 indexed poolId, address indexed user, uint256 amount);
    event RewardRateUpdated(uint256 indexed poolId, uint256 rewardRatePerSecond);
    event PoolActiveUpdated(uint256 indexed poolId, bool active);

    error PoolInactive();
    error ZeroAmount();
    error InsufficientStake();
    error LockActive();
    error InvalidPool();

    constructor(address owner_) Ownable(owner_) {}

    function poolCount() external view returns (uint256) {
        return _pools.length;
    }

    function pools(uint256 poolId)
        external
        view
        returns (
            address stakeToken,
            address rewardToken,
            uint256 rewardRatePerSecond,
            uint256 totalStaked,
            uint256 accRewardPerShare,
            uint256 lastUpdateTime,
            uint256 lockDuration,
            bool active
        )
    {
        _requirePool(poolId);
        PoolInfo storage pool = _pools[poolId];
        return (
            address(pool.stakeToken),
            address(pool.rewardToken),
            pool.rewardRatePerSecond,
            pool.totalStaked,
            pool.accRewardPerShare,
            pool.lastUpdateTime,
            pool.lockDuration,
            pool.active
        );
    }

    function nextEpochEnds() external view returns (uint256) {
        return ((block.timestamp / EPOCH_DURATION) + 1) * EPOCH_DURATION;
    }

    function addPool(
        address stakeToken,
        address rewardToken,
        uint256 rewardRatePerSecond,
        uint256 lockDuration,
        bool active
    ) external onlyOwner returns (uint256 poolId) {
        poolId = _pools.length;
        _pools.push(
            PoolInfo({
                stakeToken: IERC20(stakeToken),
                rewardToken: IERC20(rewardToken),
                rewardRatePerSecond: rewardRatePerSecond,
                totalStaked: 0,
                accRewardPerShare: 0,
                lastUpdateTime: block.timestamp,
                lockDuration: lockDuration,
                active: active
            })
        );
        emit PoolAdded(poolId, stakeToken, rewardToken, lockDuration);
    }

    function setRewardRate(uint256 poolId, uint256 rewardRatePerSecond) external onlyOwner {
        _updatePool(poolId);
        _pools[poolId].rewardRatePerSecond = rewardRatePerSecond;
        emit RewardRateUpdated(poolId, rewardRatePerSecond);
    }

    function setPoolActive(uint256 poolId, bool active) external onlyOwner {
        _updatePool(poolId);
        _pools[poolId].active = active;
        emit PoolActiveUpdated(poolId, active);
    }

    function fundRewards(uint256 poolId, uint256 amount) external {
        if (amount == 0) revert ZeroAmount();
        _requirePool(poolId);
        _pools[poolId].rewardToken.safeTransferFrom(msg.sender, address(this), amount);
    }

    function pendingReward(uint256 poolId, address account) public view returns (uint256) {
        _requirePool(poolId);
        PoolInfo memory pool = _pools[poolId];
        UserInfo memory user = users[poolId][account];
        if (user.amount == 0) return 0;

        uint256 acc = pool.accRewardPerShare;
        if (pool.totalStaked > 0 && pool.active && pool.rewardRatePerSecond > 0) {
            uint256 elapsed = block.timestamp - pool.lastUpdateTime;
            acc += (elapsed * pool.rewardRatePerSecond * ACC_PRECISION) / pool.totalStaked;
        }

        return (user.amount * acc / ACC_PRECISION) - user.rewardDebt;
    }

    function stake(uint256 poolId, uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        _requirePool(poolId);
        PoolInfo storage pool = _pools[poolId];
        if (!pool.active) revert PoolInactive();

        _updatePool(poolId);
        _harvest(poolId, msg.sender);

        pool.stakeToken.safeTransferFrom(msg.sender, address(this), amount);

        UserInfo storage user = users[poolId][msg.sender];
        user.amount += amount;
        user.rewardDebt = user.amount * pool.accRewardPerShare / ACC_PRECISION;
        user.lockedUntil = block.timestamp + pool.lockDuration;
        pool.totalStaked += amount;

        emit Staked(poolId, msg.sender, amount);
    }

    function unstake(uint256 poolId, uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        _requirePool(poolId);

        _updatePool(poolId);
        _harvest(poolId, msg.sender);

        UserInfo storage user = users[poolId][msg.sender];
        if (user.amount < amount) revert InsufficientStake();
        if (block.timestamp < user.lockedUntil) revert LockActive();

        user.amount -= amount;
        user.rewardDebt = user.amount * _pools[poolId].accRewardPerShare / ACC_PRECISION;
        _pools[poolId].totalStaked -= amount;
        _pools[poolId].stakeToken.safeTransfer(msg.sender, amount);

        emit Unstaked(poolId, msg.sender, amount);
    }

    function claim(uint256 poolId) external nonReentrant {
        _requirePool(poolId);
        _updatePool(poolId);
        _harvest(poolId, msg.sender);
    }

    function _harvest(uint256 poolId, address account) internal {
        PoolInfo storage pool = _pools[poolId];
        UserInfo storage user = users[poolId][account];
        uint256 pending = (user.amount * pool.accRewardPerShare / ACC_PRECISION) - user.rewardDebt;
        if (pending == 0) return;
        user.rewardDebt = user.amount * pool.accRewardPerShare / ACC_PRECISION;
        pool.rewardToken.safeTransfer(account, pending);
        emit RewardClaimed(poolId, account, pending);
    }

    function _updatePool(uint256 poolId) internal {
        PoolInfo storage pool = _pools[poolId];
        if (!pool.active || pool.totalStaked == 0 || pool.rewardRatePerSecond == 0) {
            pool.lastUpdateTime = block.timestamp;
            return;
        }

        uint256 elapsed = block.timestamp - pool.lastUpdateTime;
        if (elapsed == 0) return;

        pool.accRewardPerShare += (elapsed * pool.rewardRatePerSecond * ACC_PRECISION) / pool.totalStaked;
        pool.lastUpdateTime = block.timestamp;
    }

    function _requirePool(uint256 poolId) internal view {
        if (poolId >= _pools.length) revert InvalidPool();
    }
}
