// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IOracle} from "../interfaces/IOracle.sol";
import {VaultMath} from "../libraries/VaultMath.sol";
import {PledgeUupsOwnable} from "../upgrade/PledgeUupsOwnable.sol";
import {PledgeSurplusBuffer} from "./PledgeSurplusBuffer.sol";

/// @title PledgeVaultManager
/// @author Pledge Finance
/// @notice Pledge Finance isolated CDP vaults — deposit tokenized equity, borrow USDG on Robinhood Chain.
/// @dev Production: deploy behind ERC1967Proxy and call initialize(owner). Tests may pass owner in the constructor.
contract PledgeVaultManager is PledgeUupsOwnable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using VaultMath for uint256;

    uint256 public constant HF_WAD = 1e18;

    struct Market {
        address collateral;
        address oracle;
        uint16 maxLtvBps;
        uint16 liqRatioBps;
        uint16 liqBonusBps;
        uint16 stabilityFeeAprBps;
        uint16 originationFeeBps;
        bool active;
    }

    struct Position {
        uint256 collateral;
        uint256 debt;
        uint256 lastAccrual;
    }

    IERC20 public immutable usdg;
    uint8 public immutable usdgDecimals;
    PledgeSurplusBuffer public immutable surplusBuffer;

    mapping(address collateral => Market) public markets;
    mapping(address collateral => mapping(address user => Position)) public positions;
    /// @dev Borrowed principal still outstanding (excludes accrued stability fee).
    mapping(address collateral => mapping(address user => uint256)) public principalDebt;
    /// @dev First borrow timestamp for the current debt cycle; 0 when fully repaid.
    mapping(address collateral => mapping(address user => uint256)) public debtOpenedAt;

    address[] public marketList;

    event MarketRegistered(
        address indexed collateral,
        address oracle,
        uint16 maxLtvBps,
        uint16 liqRatioBps,
        uint16 liqBonusBps,
        uint16 stabilityFeeAprBps
    );
    event MarketUpdated(address indexed collateral, bool active);
    event MarketOracleUpdated(address indexed collateral, address oracle);
    event Deposited(address indexed user, address indexed collateral, uint256 amount);
    event Withdrawn(address indexed user, address indexed collateral, uint256 amount);
    event Borrowed(address indexed user, address indexed collateral, uint256 amount, uint256 fee);
    event Repaid(address indexed user, address indexed collateral, uint256 amount);
    event Liquidated(
        address indexed user,
        address indexed liquidator,
        address indexed collateral,
        uint256 debtRepaid,
        uint256 collateralSeized
    );
    event LiquidityFunded(address indexed from, uint256 amount);
    event LiquidityWithdrawn(address indexed to, uint256 amount);

    error MarketNotActive();
    error MarketExists();
    error MarketUnknown();
    error InsufficientLiquidity();
    error ExceedsMaxLtv();
    error HealthFactorTooLow();
    error NotLiquidatable();
    error SelfLiquidationNotAllowed();
    error ZeroAmount();

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address usdg_, address surplusBuffer_, address owner_) {
        usdg = IERC20(usdg_);
        usdgDecimals = _decimals(usdg_);
        surplusBuffer = PledgeSurplusBuffer(surplusBuffer_);
        _disableAndMaybeSetOwner(owner_);
    }

    function initialize(address owner_) external initializer {
        _initOwner(owner_);
    }

    // ── Admin ──────────────────────────────────────────────────────────────

    function registerMarket(
        address collateral,
        address oracle,
        uint16 maxLtvBps,
        uint16 liqRatioBps,
        uint16 liqBonusBps,
        uint16 stabilityFeeAprBps,
        uint16 originationFeeBps
    ) external onlyOwner {
        if (markets[collateral].collateral != address(0)) revert MarketExists();
        require(maxLtvBps > 0 && maxLtvBps < VaultMath.BPS, "invalid LTV");
        require(liqRatioBps > maxLtvBps, "liq ratio too low");

        markets[collateral] = Market({
            collateral: collateral,
            oracle: oracle,
            maxLtvBps: maxLtvBps,
            liqRatioBps: liqRatioBps,
            liqBonusBps: liqBonusBps,
            stabilityFeeAprBps: stabilityFeeAprBps,
            originationFeeBps: originationFeeBps,
            active: true
        });
        marketList.push(collateral);

        emit MarketRegistered(collateral, oracle, maxLtvBps, liqRatioBps, liqBonusBps, stabilityFeeAprBps);
    }

    /// @notice Pause or unpause a market. `active=false` blocks only `deposit` and `borrow`.
    /// @dev Repay, withdraw, and liquidate remain available so open positions are not trapped.
    function setMarketActive(address collateral, bool active) external onlyOwner {
        if (markets[collateral].collateral == address(0)) revert MarketUnknown();
        markets[collateral].active = active;
        emit MarketUpdated(collateral, active);
    }

    function setMarketOracle(address collateral, address oracle) external onlyOwner {
        if (markets[collateral].collateral == address(0)) revert MarketUnknown();
        require(oracle != address(0), "zero oracle");
        markets[collateral].oracle = oracle;
        emit MarketOracleUpdated(collateral, oracle);
    }

    /// @notice Treasury seeds USDG liquidity for borrowers.
    function fundLiquidity(uint256 amount) external nonReentrant {
        usdg.safeTransferFrom(msg.sender, address(this), amount);
        emit LiquidityFunded(msg.sender, amount);
    }

    /// @notice Owner pulls idle USDG inventory. Does not touch user equity collateral.
    function withdrawLiquidity(address to, uint256 amount) external onlyOwner nonReentrant {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        usdg.safeTransfer(to, amount);
        emit LiquidityWithdrawn(to, amount);
    }

    // ── User actions ───────────────────────────────────────────────────────

    function deposit(address collateral, uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        Market memory market = _requireActiveMarket(collateral);

        Position storage pos = positions[collateral][msg.sender];
        _accrue(pos, market.stabilityFeeAprBps);

        IERC20(collateral).safeTransferFrom(msg.sender, address(this), amount);
        pos.collateral += amount;

        emit Deposited(msg.sender, collateral, amount);
    }

    function withdraw(address collateral, uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        Market memory market = _requireKnownMarket(collateral);

        Position storage pos = positions[collateral][msg.sender];
        _accrue(pos, market.stabilityFeeAprBps);
        require(pos.collateral >= amount, "insufficient collateral");

        pos.collateral -= amount;
        _requireHealthy(pos, market);

        IERC20(collateral).safeTransfer(msg.sender, amount);
        emit Withdrawn(msg.sender, collateral, amount);
    }

    function borrow(address collateral, uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        Market memory market = _requireActiveMarket(collateral);

        Position storage pos = positions[collateral][msg.sender];
        _accrue(pos, market.stabilityFeeAprBps);

        uint256 fee = (amount * market.originationFeeBps) / VaultMath.BPS;
        uint256 payout = amount - fee;
        require(payout > 0, "fee exceeds amount");

        uint256 newDebt = pos.debt + amount;
        uint256 collateralUsd = _collateralUsd(pos.collateral, collateral, market.oracle);
        uint256 newDebtUsd = VaultMath.toUsdScale(newDebt, usdgDecimals);
        if (newDebtUsd > VaultMath.maxDebt(collateralUsd, market.maxLtvBps)) revert ExceedsMaxLtv();
        if (usdg.balanceOf(address(this)) < amount) revert InsufficientLiquidity();

        if (pos.debt > 0 && principalDebt[collateral][msg.sender] == 0) {
            principalDebt[collateral][msg.sender] = pos.debt;
        }
        if (debtOpenedAt[collateral][msg.sender] == 0) {
            debtOpenedAt[collateral][msg.sender] = block.timestamp;
        }
        principalDebt[collateral][msg.sender] += amount;
        pos.debt = newDebt;

        usdg.safeTransfer(msg.sender, payout);
        if (fee > 0) {
            usdg.safeTransfer(address(surplusBuffer), fee);
        }

        emit Borrowed(msg.sender, collateral, payout, fee);
    }

    function repay(address collateral, uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        Market memory market = _requireKnownMarket(collateral);

        Position storage pos = positions[collateral][msg.sender];
        _accrue(pos, market.stabilityFeeAprBps);

        uint256 repayAmount = amount > pos.debt ? pos.debt : amount;
        _applyPrincipalRepay(collateral, msg.sender, pos, repayAmount);

        usdg.safeTransferFrom(msg.sender, address(this), repayAmount);
        emit Repaid(msg.sender, collateral, repayAmount);
    }

    /// @notice Liquidate an undercollateralized position. Liquidator repays debt and receives collateral at a bonus.
    function liquidate(address user, address collateral) external nonReentrant {
        if (msg.sender == user) revert SelfLiquidationNotAllowed();

        Market memory market = _requireKnownMarket(collateral);
        Position storage pos = positions[collateral][user];
        _accrue(pos, market.stabilityFeeAprBps);

        uint256 collateralUsd = _collateralUsd(pos.collateral, collateral, market.oracle);
        uint256 debtUsd = VaultMath.toUsdScale(pos.debt, usdgDecimals);
        uint256 hf = VaultMath.healthFactor(collateralUsd, debtUsd, market.liqRatioBps);
        if (hf >= HF_WAD) revert NotLiquidatable();

        uint256 debt = pos.debt;
        uint256 price = IOracle(market.oracle).getPrice(collateral);
        uint8 decimals = _decimals(collateral);

        uint256 collateralToSeize =
            (debtUsd * (VaultMath.BPS + market.liqBonusBps) * (10 ** uint256(decimals))) / (price * VaultMath.BPS);
        if (collateralToSeize > pos.collateral) collateralToSeize = pos.collateral;

        pos.debt = 0;
        principalDebt[collateral][user] = 0;
        debtOpenedAt[collateral][user] = 0;
        pos.collateral -= collateralToSeize;

        usdg.safeTransferFrom(msg.sender, address(this), debt);
        IERC20(collateral).safeTransfer(msg.sender, collateralToSeize);

        emit Liquidated(user, msg.sender, collateral, debt, collateralToSeize);
    }

    // ── Views ──────────────────────────────────────────────────────────────

    function getHealthFactor(address user, address collateral) external view returns (uint256) {
        Market memory market = markets[collateral];
        if (market.collateral == address(0)) revert MarketUnknown();

        Position memory pos = positions[collateral][user];
        uint256 debt = pos.debt + VaultMath.accrueInterest(pos.debt, market.stabilityFeeAprBps, pos.lastAccrual);
        uint256 collateralUsd = _collateralUsd(pos.collateral, collateral, market.oracle);
        uint256 debtUsd = VaultMath.toUsdScale(debt, usdgDecimals);
        return VaultMath.healthFactor(collateralUsd, debtUsd, market.liqRatioBps);
    }

    function getBorrowable(address user, address collateral) external view returns (uint256) {
        Market memory market = markets[collateral];
        if (market.collateral == address(0)) revert MarketUnknown();

        Position memory pos = positions[collateral][user];
        uint256 debt = pos.debt + VaultMath.accrueInterest(pos.debt, market.stabilityFeeAprBps, pos.lastAccrual);
        uint256 collateralUsd = _collateralUsd(pos.collateral, collateral, market.oracle);
        uint256 debtUsd = VaultMath.toUsdScale(debt, usdgDecimals);
        uint256 maxDebtAllowed = VaultMath.maxDebt(collateralUsd, market.maxLtvBps);
        if (debtUsd >= maxDebtAllowed) return 0;
        return VaultMath.fromUsdScale(maxDebtAllowed - debtUsd, usdgDecimals);
    }

    function getMarketCount() external view returns (uint256) {
        return marketList.length;
    }

    /// @notice Principal, accrued interest, and time borrowed — paid at repay, not monthly.
    function getRepayBreakdown(address user, address collateral)
        external
        view
        returns (uint256 principal, uint256 interest, uint256 total, uint256 openedAt, uint16 aprBps)
    {
        Market memory market = markets[collateral];
        if (market.collateral == address(0)) revert MarketUnknown();

        Position memory pos = positions[collateral][user];
        uint256 pending = VaultMath.accrueInterest(pos.debt, market.stabilityFeeAprBps, pos.lastAccrual);
        total = pos.debt + pending;

        uint256 storedPrincipal = principalDebt[collateral][user];
        principal = storedPrincipal == 0 ? pos.debt : storedPrincipal;
        if (principal > total) principal = total;
        interest = total - principal;

        openedAt = debtOpenedAt[collateral][user];
        if (openedAt == 0 && pos.debt > 0) openedAt = pos.lastAccrual;
        aprBps = market.stabilityFeeAprBps;
    }

    // ── Internals ──────────────────────────────────────────────────────────

    function _requireKnownMarket(address collateral) internal view returns (Market memory market) {
        market = markets[collateral];
        if (market.collateral == address(0)) revert MarketUnknown();
    }

    function _requireActiveMarket(address collateral) internal view returns (Market memory market) {
        market = _requireKnownMarket(collateral);
        if (!market.active) revert MarketNotActive();
    }

    function _accrue(Position storage pos, uint16 stabilityFeeAprBps) internal {
        if (pos.debt == 0) {
            pos.lastAccrual = block.timestamp;
            return;
        }
        uint256 interest = VaultMath.accrueInterest(pos.debt, stabilityFeeAprBps, pos.lastAccrual);
        if (interest == 0) return;
        pos.debt += interest;
        pos.lastAccrual = block.timestamp;
    }

    /// @dev Repay interest first, then principal. Full repay clears the debt clock.
    function _applyPrincipalRepay(address collateral, address user, Position storage pos, uint256 repayAmount)
        internal
    {
        uint256 prin = principalDebt[collateral][user];
        if (prin == 0) prin = pos.debt;
        if (prin > pos.debt) prin = pos.debt;

        uint256 interestOwed = pos.debt - prin;
        uint256 fromPrincipal = repayAmount > interestOwed ? repayAmount - interestOwed : 0;
        if (fromPrincipal > prin) fromPrincipal = prin;

        pos.debt -= repayAmount;
        if (pos.debt == 0) {
            principalDebt[collateral][user] = 0;
            debtOpenedAt[collateral][user] = 0;
        } else {
            principalDebt[collateral][user] = prin - fromPrincipal;
        }
    }

    function _collateralUsd(uint256 amount, address collateral, address oracle) internal view returns (uint256) {
        uint256 price = IOracle(oracle).getPrice(collateral);
        return VaultMath.collateralValue(amount, price, _decimals(collateral));
    }

    function _requireHealthy(Position storage pos, Market memory market) internal view {
        uint256 collateralUsd = _collateralUsd(pos.collateral, market.collateral, market.oracle);
        uint256 debtUsd = VaultMath.toUsdScale(pos.debt, usdgDecimals);
        uint256 hf = VaultMath.healthFactor(collateralUsd, debtUsd, market.liqRatioBps);
        if (hf < HF_WAD) revert HealthFactorTooLow();
    }

    function _decimals(address token) internal view returns (uint8) {
        (bool ok, bytes memory data) = token.staticcall(abi.encodeWithSignature("decimals()"));
        require(ok && data.length >= 32, "decimals");
        return abi.decode(data, (uint8));
    }
}
