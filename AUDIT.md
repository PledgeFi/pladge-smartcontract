# Audit Scope — pladge-smartcontract v1.0.0

Monolithic Foundry repository containing all Pledge Finance on-chain contracts. Production deployments run on **Robinhood Mainnet (chain 4663)**; see [`deployments/4663.json`](./deployments/4663.json).

## In scope (mainnet)

| File | Notes |
|---|---|
| `src/interfaces/IOracle.sol` | Shared price feed interface |
| `src/oracle/PledgeChainlinkOracle.sol` | Production Chainlink adapter (UUPS proxy) |
| `src/core/PledgeVaultManager.sol` | CDP lifecycle, LTV, liquidation, interest accrual |
| `src/core/PledgeSurplusBuffer.sol` | Fee custody |
| `src/core/PledgeStabilityPool.sol` | USDG backstop |
| `src/libraries/VaultMath.sol` | HF, collateral valuation, interest math |

## Out of scope (testnet / auxiliary)

| File | Reason |
|---|---|
| `src/oracle/PledgeOracle.sol` | Legacy manual oracle — testnet only; must not be wired on mainnet vaults |
| `src/core/PledgeStaking.sol` | Testnet incentives |
| `src/core/PledgeTestnetBridge.sol` | Testnet ingress only |
| `src/mocks/MockERC20.sol` | Test token faucet |
| `src/mocks/MockChainlinkFeed.sol` | Testnet infrastructure only |
| `src/mocks/TestnetEthFaucet.sol` | Testnet gas faucet |
| `script/*` | Deployment automation |
| `test/*` | Test harness |

## Assumptions

1. Oracle owner is a multisig or timelock-controlled admin on mainnet.
2. `maxStaleness` is set conservatively (default 24h in contract; mainnet deploy uses 4 days).
3. All prices are USD with **18 decimals** regardless of feed native decimals.
4. Chainlink feeds return positive `answer` values; zero/negative answers revert.
5. USDG on mainnet is Paxos `0x5fc5360D0400a0Fd4f2af552ADD042D716F1d168` — external stablecoin, not protocol-minted.

## Key invariants

1. **Solvency:** Vault USDG balance ≥ sum of outstanding debt (modulo liquidity funding model).
2. **LTV:** `borrow` reverts when post-borrow debt exceeds `maxLtvBps` of collateral USD value.
3. **Health factor:** `withdraw` reverts when HF < 1e18 at `liqRatioBps`.
4. **Liquidation:** Positions with HF < 1e18 are liquidatable; liquidator repays full debt for collateral + bonus.
5. **Interest:** Linear APR accrual matches `VaultMath.accrueInterest` (no compounding within accrual tick).
6. **Reentrancy:** All state-changing user paths guarded by `nonReentrant`.

## Trust boundaries

- **Owner** can wire Chainlink feeds, change staleness, pause markets, and rotate oracles on mainnet.
- **Consumers** trust `getPrice()` and must not call stale feeds (enforced on-chain).

## Related: mainnet scripts

Operational Foundry scripts (register markets, oracle feeds, fund liquidity, smoke tests, cutover) are audited separately in [`MAINNET_SCRIPT_AUDIT.md`](./MAINNET_SCRIPT_AUDIT.md). That document covers safe vs unsafe scripts for the live deployment, the critical `ConfigureProxiedVaultMainnet` address bug, and the required production runbook order.

## Integration checklist (mainnet)

- [ ] Feed addresses verified against Chainlink docs for Robinhood mainnet
- [ ] `PledgeVaultManager.markets(collateral).oracle` points to `PledgeChainlinkOracle` deployment
- [ ] Staleness window reviewed against Chainlink heartbeat per asset
- [ ] Legacy `PledgeOracle` is **not** wired on any mainnet vault market
- [ ] Live addresses match [`deployments/4663.json`](./deployments/4663.json)
- [ ] Deprecated vault `0xf486F332A162CC4bb844506254a649C300D64e9b` is not integrated

## Testnet reference

Robinhood Testnet (chain `46630`) uses mock infrastructure documented in [`deployments/46630.json`](./deployments/46630.json). Testnet contracts listed under "Out of scope" must not appear in production integrations.
