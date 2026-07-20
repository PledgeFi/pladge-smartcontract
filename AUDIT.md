# Audit Scope — pladge-smartcontract v1.0.0

Monolithic Foundry repo containing all Pledge Finance on-chain contracts. This document combines the audit scopes of the split [`pledge-oracle`](../pledge-oracle/AUDIT.md) and [`pledge-protocol`](../pledge-protocol/AUDIT.md) repositories.

## In scope (mainnet)

| File | Notes |
|---|---|
| `src/interfaces/IOracle.sol` | Shared price feed interface |
| `src/oracle/PledgeOracle.sol` | Testnet manual oracle (must not be wired on mainnet vaults) |
| `src/oracle/PledgeChainlinkOracle.sol` | Mainnet Chainlink adapter |
| `src/core/PledgeVaultManager.sol` | CDP lifecycle, LTV, liquidation, interest accrual |
| `src/core/PledgeSurplusBuffer.sol` | Fee custody |
| `src/core/PledgeStabilityPool.sol` | USDG backstop |
| `src/libraries/VaultMath.sol` | HF, collateral valuation, interest math |

## Out of scope (testnet / auxiliary)

| File | Reason |
|---|---|
| `src/core/PledgeStaking.sol` | Testnet incentives |
| `src/core/PledgeTestnetBridge.sol` | Testnet ingress only |
| `src/mocks/MockERC20.sol` | Test token faucet |
| `src/mocks/MockChainlinkFeed.sol` | Testnet infrastructure only |
| `script/*` | Deployment automation |
| `test/*` | Test harness |

## Assumptions

1. Oracle owner is a multisig or timelock-controlled admin on mainnet.
2. `maxStaleness` is set conservatively (default 24h; mainnet deploy uses 4 days).
3. All prices are USD with **18 decimals** regardless of feed native decimals.
4. Chainlink feeds return positive `answer` values; zero/negative answers revert.
5. USDG (mainnet) is Paxos `0x5fc5360D0400a0Fd4f2af552ADD042D716F1d168` — external stablecoin.

## Key invariants

1. **Solvency:** Vault USDG balance ≥ sum of outstanding debt (modulo liquidity funding model).
2. **LTV:** `borrow` reverts when post-borrow debt exceeds `maxLtvBps` of collateral USD value.
3. **Health factor:** `withdraw` reverts when HF < 1e18 at `liqRatioBps`.
4. **Liquidation:** Positions with HF < 1e18 are liquidatable; liquidator repays full debt for collateral + bonus.
5. **Interest:** Linear APR accrual matches `VaultMath.accrueInterest` (no compounding within accrual tick).
6. **Reentrancy:** All state-changing user paths guarded by `nonReentrant`.

## Trust boundaries

- **Owner** can set prices (testnet) or wire feeds (mainnet), change staleness, pause markets, and rotate oracles.
- **Consumers** trust `getPrice()` and must not call stale feeds (enforced on-chain).

## Integration checklist

- [ ] Feed addresses verified against Chainlink docs for Robinhood mainnet
- [ ] `PledgeVaultManager.markets(collateral).oracle` points to audited oracle deployment
- [ ] Staleness window reviewed against Chainlink heartbeat per asset
- [ ] Testnet `PledgeOracle` not wired on mainnet vaults
- [ ] Live addresses match `deployments/46630.json` (testnet) or `deployments/4663.json` (mainnet)

## Split-repo equivalents

For audit-friendly review in smaller repos, see the path mapping in [README.md](./README.md#split-repo-mapping).
