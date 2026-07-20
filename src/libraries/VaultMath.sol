// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title VaultMath
/// @notice Health factor and collateral valuation helpers for Pledge vaults.
library VaultMath {
    uint256 public constant WAD = 1e18;
    uint256 internal constant BPS = 10_000;

    /// @dev USD value of `amount` tokens at `priceUsd` (18 decimals).
    function collateralValue(uint256 amount, uint256 priceUsd, uint8 tokenDecimals)
        internal
        pure
        returns (uint256)
    {
        if (amount == 0 || priceUsd == 0) return 0;
        return (amount * priceUsd) / (10 ** uint256(tokenDecimals));
    }

    /// @dev Normalize token amount to 18-decimal USD scale for comparisons.
    function toUsdScale(uint256 amount, uint8 tokenDecimals) internal pure returns (uint256) {
        if (amount == 0) return 0;
        if (tokenDecimals == 18) return amount;
        if (tokenDecimals < 18) return amount * (10 ** uint256(18 - tokenDecimals));
        return amount / (10 ** uint256(tokenDecimals - 18));
    }

    /// @dev Convert 18-decimal USD scale back to token native units.
    function fromUsdScale(uint256 usdAmount, uint8 tokenDecimals) internal pure returns (uint256) {
        if (usdAmount == 0) return 0;
        if (tokenDecimals == 18) return usdAmount;
        if (tokenDecimals < 18) return usdAmount / (10 ** uint256(18 - tokenDecimals));
        return usdAmount * (10 ** uint256(tokenDecimals - 18));
    }

    /// @dev Max debt allowed at `maxLtvBps` (e.g. 6000 = 60%). Returns 18-decimal USD scale.
    function maxDebt(uint256 collateralUsd, uint16 maxLtvBps) internal pure returns (uint256) {
        return (collateralUsd * maxLtvBps) / BPS;
    }

    /// @dev HF with 1e18 precision. Liquidatable when HF < 1e18.
    /// `liqRatioBps` is minimum collateralization ratio (16600 = 166%).
    function healthFactor(uint256 collateralUsd, uint256 debtUsd, uint16 liqRatioBps)
        internal
        pure
        returns (uint256)
    {
        if (debtUsd == 0) return type(uint256).max;
        return (collateralUsd * WAD * BPS) / (debtUsd * liqRatioBps);
    }

    /// @dev Linear interest accrual: `debt * aprBps * elapsed / (365 days * BPS)`.
    function accrueInterest(uint256 debt, uint16 aprBps, uint256 lastAccrual) internal view returns (uint256) {
        if (debt == 0) return 0;
        uint256 elapsed = block.timestamp - lastAccrual;
        if (elapsed == 0) return 0;
        return (debt * aprBps * elapsed) / (365 days * BPS);
    }
}
