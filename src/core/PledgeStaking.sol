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
    /// @dev 10_000 bps = 1.00x. A pool's `maxBoostBps` of 30_000 means 3.00x at the longest lock.
    uint256 public constant BPS = 10_000;

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

    // --- Lock boost. Appended after poolNames; slots 0-4 above are untouched so this ships as a
    //     plain implementation upgrade. Weight, not principal, is what rewards are divided by.
    //     PoolInfo could not carry these: it lives in a dynamic array, where adding a field shifts
    //     every element. Parallel mappings sidestep that entirely.

    /// @notice Sum of every staker's weight in a pool. Rewards are divided by this, not totalStaked.
    mapping(uint256 poolId => uint256) public totalWeight;
    /// @notice A staker's `amount * multiplier`. Rebuilt whenever their stake or lock changes.
    mapping(uint256 poolId => mapping(address account => uint256)) public userWeight;
    /// @notice Multiplier at the pool's longest lock, in bps. 0 or <= BPS disables the boost.
    mapping(uint256 poolId => uint256) public maxBoostBps;

    event PoolAdded(
        uint256 indexed poolId, address stakeToken, address rewardToken, uint256 minLockDuration, uint256 lockDuration
    );
    event Staked(
        uint256 indexed poolId, address indexed user, uint256 amount, uint256 lockDuration, uint256 lockedUntil
    );
    event Unstaked(uint256 indexed poolId, address indexed user, uint256 amount);
    event EmergencyWithdrawn(uint256 indexed poolId, address indexed user, uint256 amount);
    event RewardClaimed(uint256 indexed poolId, address indexed user, uint256 amount);
    event RewardRateUpdated(uint256 indexed poolId, uint256 rewardRatePerSecond);
    event PoolActiveUpdated(uint256 indexed poolId, bool active);
    event LockDurationUpdated(uint256 indexed poolId, uint256 minLockDuration, uint256 lockDuration);
    event RewardsFunded(uint256 indexed poolId, address indexed from, uint256 amount);
    event RewardsWithdrawn(uint256 indexed poolId, address indexed to, uint256 amount);
    event PoolNamed(uint256 indexed poolId, string name);
    event MaxBoostUpdated(uint256 indexed poolId, uint256 maxBoostBps);
    event WeightUpdated(uint256 indexed poolId, address indexed user, uint256 weight, uint256 totalWeight);

    error PoolInactive();
    error ZeroAmount();
    error InsufficientStake();
    error LockActive();
    error InvalidPool();
    error InsufficientRewardReserve();
    error InvalidLockDuration();
    error InvalidBoost();
    error PoolNotEmpty();

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

    /// @notice Set the multiplier earned at the pool's longest lock. `BPS` (10_000) disables it.
    /// @dev Rebuilding every staker's weight here would be an unbounded loop, so open positions
    ///      keep their old weight until something syncs them. That is self-correcting: if the boost
    ///      was lowered, the other stakers are diluted until they call `syncWeight` on the stale
    ///      position; if it was raised, the staker is short-changed until they sync themselves.
    function setMaxBoostBps(uint256 poolId, uint256 boostBps) external onlyOwner {
        _pool(poolId);
        // A cap keeps one long-locked whale from crowding everyone else out of the emission.
        if (boostBps != 0 && (boostBps < BPS || boostBps > 10 * BPS)) revert InvalidBoost();
        _updatePool(poolId);
        maxBoostBps[poolId] = boostBps;
        emit MaxBoostUpdated(poolId, boostBps);
    }

    /// @notice What a stake would earn per year, in bps of the staked amount, at a given lock.
    /// @dev Quoted as if `addedAmount` were staked now and nothing else changed. It is a
    ///      projection, not a promise: every later stake dilutes it, and it runs only as long as
    ///      `rewardReserve` lasts. Returns 0 once the reserve is empty, because that is the truth.
    function projectedAprBps(uint256 poolId, uint256 addedAmount, uint256 lockDuration)
        external
        view
        returns (uint256)
    {
        PoolInfo storage pool = _pool(poolId);
        if (addedAmount == 0 || pool.rewardRatePerSecond == 0 || pool.rewardReserve == 0 || !pool.active) return 0;

        uint256 weight = (addedAmount * multiplierBps(poolId, lockDuration)) / BPS;
        uint256 newTotalWeight = totalWeight[poolId] + weight;
        if (newTotalWeight == 0) return 0;

        uint256 annualEmission = pool.rewardRatePerSecond * 365 days;
        uint256 share = (annualEmission * weight) / newTotalWeight;
        return (share * BPS) / addedAmount;
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

    /// @dev Uses the STORED weight, not `weightOf`. Rewards accrue against whatever weight the pool
    ///      is currently counting, so an expired position keeps earning at its old boost until
    ///      someone calls `syncWeight`. Quoting the fresh weight here would report rewards the
    ///      contract will not actually pay.
    function pendingReward(uint256 poolId, address account) public view returns (uint256) {
        _pool(poolId);
        uint256 weight = userWeight[poolId][account];
        if (weight == 0) return 0;

        uint256 acc = _pools[poolId].accRewardPerShare;
        uint256 reward = _pendingEmission(poolId);
        if (reward > 0) {
            acc += (reward * ACC_PRECISION) / totalWeight[poolId];
        }

        uint256 accumulated = (weight * acc) / ACC_PRECISION;
        uint256 debt = users[poolId][account].rewardDebt;
        if (accumulated <= debt) return 0;
        return accumulated - debt;
    }

    /// @notice Bring an account's weight up to date. Anyone may call this for anyone.
    /// @dev Permissionless on purpose. A position whose lock has expired keeps its boost until it
    ///      is synced, diluting everyone else, so the other stakers have both the motive and the
    ///      means to fix it. The same call also picks up a `maxBoostBps` change.
    function syncWeight(uint256 poolId, address account) external nonReentrant returns (uint256 weight) {
        _updatePool(poolId);
        _harvest(poolId, account);
        return _syncWeight(poolId, account);
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
        if (user.amount == 0) {
            user.lockDuration = 0;
            user.lockedUntil = 0;
        }
        pool.totalStaked -= amount;

        _syncWeight(poolId, msg.sender);

        pool.stakeToken.safeTransfer(msg.sender, amount);

        emit Unstaked(poolId, msg.sender, amount);
    }

    function claim(uint256 poolId) external nonReentrant {
        _updatePool(poolId);
        _harvest(poolId, msg.sender);
    }

    /// @notice Withdraw principal without touching the reward token, forfeiting unclaimed rewards.
    /// @dev `unstake` harvests first, so a reward token that reverts on transfer would strand
    ///      principal. This path never calls the reward token, so principal is always recoverable.
    ///      The lock is still enforced; this is an escape from a broken reward leg, not from the lock.
    function emergencyWithdraw(uint256 poolId) external nonReentrant returns (uint256 amount) {
        PoolInfo storage pool = _pool(poolId);
        UserInfo storage user = users[poolId][msg.sender];

        amount = user.amount;
        if (amount == 0) revert InsufficientStake();
        if (block.timestamp < user.lockedUntil) revert LockActive();

        // Settle accrual at the current totalStaked before shrinking it. Skipping this would
        // re-divide the elapsed emission among the remaining stakers, retroactively handing
        // them the leaver's share. This is pure arithmetic with no external call, so it cannot
        // reintroduce the failure mode this function exists to escape.
        _updatePool(poolId);

        user.amount = 0;
        user.rewardDebt = 0;
        user.lockedUntil = 0;
        user.lockDuration = 0;
        pool.totalStaked -= amount;

        totalWeight[poolId] -= userWeight[poolId][msg.sender];
        userWeight[poolId][msg.sender] = 0;
        emit WeightUpdated(poolId, msg.sender, 0, totalWeight[poolId]);

        pool.stakeToken.safeTransfer(msg.sender, amount);

        emit EmergencyWithdrawn(poolId, msg.sender, amount);
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
        pool.totalStaked += amount;

        uint256 newLockedUntil = block.timestamp + lockDuration;
        if (newLockedUntil > user.lockedUntil) {
            user.lockedUntil = newLockedUntil;
            user.lockDuration = lockDuration;
        } else {
            // The existing lock runs longer, so it stands. Record what is still outstanding rather
            // than the shorter duration just requested: topping up a position must not quietly
            // demote the boost it is still committed to earning.
            user.lockDuration = user.lockedUntil - block.timestamp;
        }

        _syncWeight(poolId, msg.sender);

        emit Staked(poolId, msg.sender, amount, user.lockDuration, user.lockedUntil);
    }

    function _harvest(uint256 poolId, address account) internal {
        PoolInfo storage pool = _pools[poolId];
        UserInfo storage user = users[poolId][account];
        uint256 accumulated = (userWeight[poolId][account] * pool.accRewardPerShare) / ACC_PRECISION;
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
        uint256 reward = _pendingEmission(poolId);
        if (reward > 0) {
            pool.accRewardPerShare += (reward * ACC_PRECISION) / totalWeight[poolId];
            pool.rewardReserve -= reward;
        }
        pool.lastUpdateTime = block.timestamp;
    }

    /// @dev Gated on totalWeight, not totalStaked: it is the divisor in `_updatePool`, and the two
    ///      differ once a boost is live. Emitting while the divisor is zero would burn reserve.
    function _pendingEmission(uint256 poolId) internal view returns (uint256 reward) {
        PoolInfo storage pool = _pools[poolId];
        if (!pool.active || totalWeight[poolId] == 0 || pool.rewardRatePerSecond == 0 || pool.rewardReserve == 0) {
            return 0;
        }
        uint256 elapsed = block.timestamp - pool.lastUpdateTime;
        if (elapsed == 0) return 0;
        reward = elapsed * pool.rewardRatePerSecond;
        if (reward > pool.rewardReserve) reward = pool.rewardReserve;
    }

    /// @notice Multiplier in bps a given lock would earn in this pool. BPS (10_000) means 1.00x.
    /// @dev Linear from 1.00x at `minLockDuration` to `maxBoostBps` at `lockDuration`.
    function multiplierBps(uint256 poolId, uint256 lockDuration) public view returns (uint256) {
        PoolInfo storage pool = _pool(poolId);
        uint256 maxBoost = maxBoostBps[poolId];
        if (maxBoost <= BPS) return BPS;

        uint256 span = pool.lockDuration - pool.minLockDuration;
        if (span == 0) return BPS;

        if (lockDuration <= pool.minLockDuration) return BPS;
        uint256 over = lockDuration - pool.minLockDuration;
        if (over > span) over = span;

        return BPS + ((maxBoost - BPS) * over) / span;
    }

    /// @notice Weight this account should carry right now.
    /// @dev Once the lock has run out the boost is gone: an expired position earns at 1.00x like
    ///      any unlocked one. The stored weight only catches up when something calls `_syncWeight`,
    ///      which is why `syncWeight` is permissionless.
    function weightOf(uint256 poolId, address account) public view returns (uint256) {
        UserInfo storage user = users[poolId][account];
        if (user.amount == 0) return 0;
        if (block.timestamp >= user.lockedUntil) return user.amount;
        return (user.amount * multiplierBps(poolId, user.lockDuration)) / BPS;
    }

    /// @dev Writes the weight and keeps `totalWeight` in step. Callers MUST `_updatePool` and
    ///      `_harvest` first: `rewardDebt` is denominated in the old weight, so changing the weight
    ///      without settling would silently re-price every reward already earned.
    function _syncWeight(uint256 poolId, address account) internal returns (uint256 weight) {
        weight = weightOf(poolId, account);
        uint256 previous = userWeight[poolId][account];
        if (weight != previous) {
            totalWeight[poolId] = totalWeight[poolId] - previous + weight;
            userWeight[poolId][account] = weight;
            emit WeightUpdated(poolId, account, weight, totalWeight[poolId]);
        }
        users[poolId][account].rewardDebt = (weight * _pools[poolId].accRewardPerShare) / ACC_PRECISION;
    }

    function _pool(uint256 poolId) internal view returns (PoolInfo storage pool) {
        if (poolId >= _pools.length) revert InvalidPool();
        return _pools[poolId];
    }
}
