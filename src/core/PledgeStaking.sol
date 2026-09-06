// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {PledgeUupsOwnable} from "../upgrade/PledgeUupsOwnable.sol";

/// @title PledgeStaking
/// @author Pledge Finance
/// @notice Isolated staking pools with linear, reserve-capped reward emissions.
/// @dev Production: deploy behind ERC1967Proxy. Tests may pass owner in the constructor.
///      `active=false` blocks new stakes only; unstake and claim stay available.
///      Users pick `lockDuration` in `[minLockDuration, lockDuration]`. `stake(pool, amt)` uses the max.
contract PledgeStaking is PledgeUupsOwnable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint256 public constant ACC_PRECISION = 1e18;
    uint256 public constant EPOCH_DURATION = 7 days;

    string public constant name = "Pledge Finance Staking";
    string public constant version = "1.0.0";

    struct PoolInfo {
        IERC20 stakeToken;
        IERC20 rewardToken;
        uint256 rewardRatePerSecond;
        uint256 totalStaked;
        uint256 accRewardPerShare;
        uint256 lastUpdateTime;
        uint256 minLockDuration;
        uint256 lockDuration;
        bool active;
        /// @dev Reward tokens still available to emit (not yet added to accRewardPerShare).
        uint256 rewardReserve;
    }

    struct UserInfo {
        uint256 amount;
        uint256 rewardDebt;
        uint256 lockedUntil;
        uint256 lockDuration;
    }

    PoolInfo[] private _pools;
    mapping(uint256 poolId => mapping(address account => UserInfo)) public users;
    mapping(uint256 poolId => string) public poolNames;

    event PoolAdded(
        uint256 indexed poolId, address stakeToken, address rewardToken, uint256 minLockDuration, uint256 lockDuration
    );
    event Staked(
        uint256 indexed poolId, address indexed user, uint256 amount, uint256 lockDuration, uint256 lockedUntil
    );
    event Unstaked(uint256 indexed poolId, address indexed user, uint256 amount);
    event RewardClaimed(uint256 indexed poolId, address indexed user, uint256 amount);
    event RewardRateUpdated(uint256 indexed poolId, uint256 rewardRatePerSecond);
    event PoolActiveUpdated(uint256 indexed poolId, bool active);
    event LockDurationUpdated(uint256 indexed poolId, uint256 minLockDuration, uint256 lockDuration);
    event RewardsFunded(uint256 indexed poolId, address indexed from, uint256 amount);
    event RewardsWithdrawn(uint256 indexed poolId, address indexed to, uint256 amount);
    event PoolNamed(uint256 indexed poolId, string name);

    error PoolInactive();
    error ZeroAmount();
    error InsufficientStake();
    error LockActive();
    error InvalidPool();
    error InsufficientRewardReserve();
    error InvalidLockDuration();

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address owner_) {
        _disableAndMaybeSetOwner(owner_);
    }

    function initialize(address owner_) external initializer {
        _initOwner(owner_);
    }

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
            uint256 minLockDuration,
            uint256 lockDuration,
            bool active,
            uint256 rewardReserve
        )
    {
        PoolInfo storage pool = _pool(poolId);
        return (
            address(pool.stakeToken),
            address(pool.rewardToken),
            pool.rewardRatePerSecond,
            pool.totalStaked,
            pool.accRewardPerShare,
            pool.lastUpdateTime,
            pool.minLockDuration,
            pool.lockDuration,
            pool.active,
            pool.rewardReserve
        );
    }

    /// @notice Dashboard helper: stake, pending rewards, and remaining lock.
    function getPosition(uint256 poolId, address account)
        external
        view
        returns (uint256 amount, uint256 pending, uint256 lockedUntil, uint256 lockDuration, uint256 lockRemaining)
    {
        UserInfo memory user = users[poolId][account];
        amount = user.amount;
        pending = pendingReward(poolId, account);
        lockedUntil = user.lockedUntil;
        lockDuration = user.lockDuration;
        lockRemaining = lockedUntil > block.timestamp ? lockedUntil - block.timestamp : 0;
    }

    function nextEpochEnds() external view returns (uint256) {
        return ((block.timestamp / EPOCH_DURATION) + 1) * EPOCH_DURATION;
    }

    /// @notice Create a pool. `lockDuration` is the max and the default for `stake(pool, amount)`.
    function addPool(
        address stakeToken,
        address rewardToken,
        uint256 rewardRatePerSecond,
        uint256 lockDuration,
        bool active
    ) external onlyOwner returns (uint256 poolId) {
        return _addPool(stakeToken, rewardToken, rewardRatePerSecond, 0, lockDuration, active);
    }

    function addPool(
        address stakeToken,
        address rewardToken,
        uint256 rewardRatePerSecond,
        uint256 minLockDuration,
        uint256 lockDuration,
        bool active
    ) external onlyOwner returns (uint256 poolId) {
        return _addPool(stakeToken, rewardToken, rewardRatePerSecond, minLockDuration, lockDuration, active);
    }

    /// @notice Update allowed lock range. Does not rewrite `lockedUntil` on open positions.
    function setLockDuration(uint256 poolId, uint256 minLockDuration, uint256 lockDuration) external onlyOwner {
        _pool(poolId);
        if (minLockDuration > lockDuration) revert InvalidLockDuration();
        _pools[poolId].minLockDuration = minLockDuration;
        _pools[poolId].lockDuration = lockDuration;
        emit LockDurationUpdated(poolId, minLockDuration, lockDuration);
    }

    function setPoolName(uint256 poolId, string calldata name_) external onlyOwner {
        _pool(poolId);
        poolNames[poolId] = name_;
        emit PoolNamed(poolId, name_);
    }

    function setRewardRate(uint256 poolId, uint256 rewardRatePerSecond) external onlyOwner {
        _updatePool(poolId);
        _pools[poolId].rewardRatePerSecond = rewardRatePerSecond;
        emit RewardRateUpdated(poolId, rewardRatePerSecond);
    }

    /// @notice Pause new stakes. Unstake and claim remain available.
    function setPoolActive(uint256 poolId, bool active) external onlyOwner {
        _updatePool(poolId);
        _pools[poolId].active = active;
        emit PoolActiveUpdated(poolId, active);
    }

    function fundRewards(uint256 poolId, uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        _updatePool(poolId);
        PoolInfo storage pool = _pools[poolId];
        pool.rewardToken.safeTransferFrom(msg.sender, address(this), amount);
        pool.rewardReserve += amount;
        emit RewardsFunded(poolId, msg.sender, amount);
    }

    /// @notice Owner pulls unused reward inventory. Does not touch staked principal.
    function withdrawRewards(uint256 poolId, address to, uint256 amount) external onlyOwner nonReentrant {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        _updatePool(poolId);
        PoolInfo storage pool = _pools[poolId];
        if (amount > pool.rewardReserve) revert InsufficientRewardReserve();
        pool.rewardReserve -= amount;
        pool.rewardToken.safeTransfer(to, amount);
        emit RewardsWithdrawn(poolId, to, amount);
    }

    function pendingReward(uint256 poolId, address account) public view returns (uint256) {
        PoolInfo memory pool = _pool(poolId);
        UserInfo memory user = users[poolId][account];
        if (user.amount == 0) return 0;

        uint256 acc = pool.accRewardPerShare;
        uint256 reward = _pendingEmission(pool);
        if (reward > 0) {
            acc += (reward * ACC_PRECISION) / pool.totalStaked;
        }

        uint256 accumulated = (user.amount * acc) / ACC_PRECISION;
        if (accumulated <= user.rewardDebt) return 0;
        return accumulated - user.rewardDebt;
    }

    /// @notice Stake using the pool's maximum lock duration.
    function stake(uint256 poolId, uint256 amount) external nonReentrant {
        _stake(poolId, amount, _pool(poolId).lockDuration);
    }

    /// @notice Stake with a custom lock in `[minLockDuration, lockDuration]`.
    function stake(uint256 poolId, uint256 amount, uint256 lockDuration) external nonReentrant {
        _stake(poolId, amount, lockDuration);
    }

    function unstake(uint256 poolId, uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        PoolInfo storage pool = _pool(poolId);

        _updatePool(poolId);
        _harvest(poolId, msg.sender);

        UserInfo storage user = users[poolId][msg.sender];
        if (user.amount < amount) revert InsufficientStake();
        if (block.timestamp < user.lockedUntil) revert LockActive();

        user.amount -= amount;
        user.rewardDebt = (user.amount * pool.accRewardPerShare) / ACC_PRECISION;
        if (user.amount == 0) {
            user.lockDuration = 0;
            user.lockedUntil = 0;
        }
        pool.totalStaked -= amount;
        pool.stakeToken.safeTransfer(msg.sender, amount);

        emit Unstaked(poolId, msg.sender, amount);
    }

    function claim(uint256 poolId) external nonReentrant {
        _updatePool(poolId);
        _harvest(poolId, msg.sender);
    }

    function _addPool(
        address stakeToken,
        address rewardToken,
        uint256 rewardRatePerSecond,
        uint256 minLockDuration,
        uint256 lockDuration,
        bool active
    ) internal returns (uint256 poolId) {
        if (stakeToken == address(0) || rewardToken == address(0)) revert ZeroAddress();
        if (minLockDuration > lockDuration) revert InvalidLockDuration();

        poolId = _pools.length;
        _pools.push(
            PoolInfo({
                stakeToken: IERC20(stakeToken),
                rewardToken: IERC20(rewardToken),
                rewardRatePerSecond: rewardRatePerSecond,
                totalStaked: 0,
                accRewardPerShare: 0,
                lastUpdateTime: block.timestamp,
                minLockDuration: minLockDuration,
                lockDuration: lockDuration,
                active: active,
                rewardReserve: 0
            })
        );
        emit PoolAdded(poolId, stakeToken, rewardToken, minLockDuration, lockDuration);
    }

    function _stake(uint256 poolId, uint256 amount, uint256 lockDuration) internal {
        if (amount == 0) revert ZeroAmount();
        PoolInfo storage pool = _pool(poolId);
        if (!pool.active) revert PoolInactive();
        if (lockDuration < pool.minLockDuration || lockDuration > pool.lockDuration) revert InvalidLockDuration();

        _updatePool(poolId);
        _harvest(poolId, msg.sender);

        pool.stakeToken.safeTransferFrom(msg.sender, address(this), amount);

        UserInfo storage user = users[poolId][msg.sender];
        user.amount += amount;
        user.rewardDebt = (user.amount * pool.accRewardPerShare) / ACC_PRECISION;
        uint256 newLockedUntil = block.timestamp + lockDuration;
        if (newLockedUntil > user.lockedUntil) user.lockedUntil = newLockedUntil;
        user.lockDuration = lockDuration;
        pool.totalStaked += amount;

        emit Staked(poolId, msg.sender, amount, lockDuration, user.lockedUntil);
    }

    function _harvest(uint256 poolId, address account) internal {
        PoolInfo storage pool = _pools[poolId];
        UserInfo storage user = users[poolId][account];
        uint256 accumulated = (user.amount * pool.accRewardPerShare) / ACC_PRECISION;
        if (accumulated <= user.rewardDebt) {
            user.rewardDebt = accumulated;
            return;
        }

        uint256 pending = accumulated - user.rewardDebt;
        user.rewardDebt = accumulated;
        if (pending == 0) return;

        pool.rewardToken.safeTransfer(account, pending);
        emit RewardClaimed(poolId, account, pending);
    }

    function _updatePool(uint256 poolId) internal {
        PoolInfo storage pool = _pool(poolId);
        uint256 reward = _pendingEmission(pool);
        if (reward > 0) {
            pool.accRewardPerShare += (reward * ACC_PRECISION) / pool.totalStaked;
            pool.rewardReserve -= reward;
        }
        pool.lastUpdateTime = block.timestamp;
    }

    function _pendingEmission(PoolInfo memory pool) internal view returns (uint256 reward) {
        if (!pool.active || pool.totalStaked == 0 || pool.rewardRatePerSecond == 0 || pool.rewardReserve == 0) {
            return 0;
        }
        uint256 elapsed = block.timestamp - pool.lastUpdateTime;
        if (elapsed == 0) return 0;
        reward = elapsed * pool.rewardRatePerSecond;
        if (reward > pool.rewardReserve) reward = pool.rewardReserve;
    }

    function _pool(uint256 poolId) internal view returns (PoolInfo storage pool) {
        if (poolId >= _pools.length) revert InvalidPool();
        return _pools[poolId];
    }
}
