# Pledge Finance — Smart Contracts

Production-grade overcollateralized vault protocol on **Robinhood Chain**. Users deposit tokenized equities as collateral and borrow **USDG** (Paxos USDG on mainnet).

## Network

| Property | Value |
|---|---|
| Network | Robinhood Mainnet |
| Chain ID | `4663` |
| RPC | `https://rpc.mainnet.chain.robinhood.com` |
| Explorer | [Blockscout](https://robinhoodchain.blockscout.com) |
| Deployment manifest | [`deployments/4663.json`](./deployments/4663.json) |

## Architecture

| Contract | Role |
|---|---|
| `PledgeVaultManager` | CDP vault — deposit collateral, borrow USDG, repay, withdraw, liquidate |
| `PledgeSurplusBuffer` | Protocol fee treasury (USDG) |
| `PledgeStabilityPool` | USDG backstop for liquidations |
| `PledgeChainlinkOracle` | Chainlink-backed price oracle (USD, 18 decimals) |
| `VaultMath` | Health factor, collateral valuation, interest accrual |

Collateral assets are official Robinhood tokenized equities (NVDA, SPY, AAPL, QQQ, MSFT, AMZN, META, GOOGL). USDG is the external Paxos stablecoin — not minted by this protocol on mainnet.

## Live deployments (mainnet)

Canonical addresses are recorded in [`deployments/4663.json`](./deployments/4663.json). Key contracts:

| Contract | Address |
|---|---|
| `PledgeVaultManager` | `0x0dfd39ff00aFa2283A8c37770dB972aeC08AaB62` |
| `PledgeChainlinkOracle` | `0x195287cbcd53eF058a3DeC4c6DC8f17Bf79A28d9` |
| `PledgeSurplusBuffer` | `0xEa30446c46D61514f19c897224E65b13Fb0A826c` |
| `PledgeStabilityPool` | `0x8570a571CC83f87B3Ca4249B71646Cc807350e14` |
| Paxos USDG | `0x5fc5360D0400a0Fd4f2af552ADD042D716F1d168` |

> Treat on-chain state as authoritative. The manifest is a convenience reference for integrators.

## Development setup

**Requirements:** [Foundry](https://book.getfoundry.sh/getting-started/installation), Solidity 0.8.24, OpenZeppelin v5.

```bash
forge install
cp .env.example .env   # set DEPLOYER_PRIVATE_KEY and RPC endpoints
make build
make test
```

## Testing

```bash
forge test -vv
# or
make test
```

Unit tests cover vault lifecycle, oracle adapters, interest accrual, liquidation paths, and proxy initialization. Run the full suite before any mainnet script broadcast.

## Mainnet operations

All mainnet scripts target chain `4663` and use `ROBINHOOD_MAINNET_RPC` (or the `robinhood_mainnet` alias in `foundry.toml`).

```bash
# Register collateral markets on the live vault
forge script script/RegisterMainnetMarkets.s.sol \
  --rpc-url $ROBINHOOD_MAINNET_RPC \
  --broadcast \
  --chain-id 4663

# Wire Chainlink feeds on the oracle proxy (owner only)
forge script script/SetOracleFeeds.s.sol \
  --rpc-url $ROBINHOOD_MAINNET_RPC \
  --broadcast \
  --chain-id 4663

# Fund vault USDG liquidity
forge script script/FundLiquidityMainnet.s.sol \
  --rpc-url $ROBINHOOD_MAINNET_RPC \
  --broadcast \
  --chain-id 4663
```

Required environment variables are documented in [`.env.example`](./.env.example).

Verify that `.env.example` matches the deployment manifest:

```bash
make verify-deployments
```

## Risk parameters (mainnet)

| Market | Max LTV | Liquidation ratio |
|---|---|---|
| NVDA | 60% | 166% |
| AAPL / MSFT | 65% | 153% |
| SPY | 75% | 133% |
| QQQ | 70% | 143% |
| AMZN | 58% | 172% |
| META | 62% | 161% |
| GOOGL | 60% | 166% |

Oracle staleness on mainnet is configured to **4 days** (`SetOracleFeeds.s.sol`). Review against Chainlink heartbeat per asset before changing.

## Security and audit

- Audit scope: [`AUDIT.md`](./AUDIT.md)
- Mainnet script audit: [`MAINNET_SCRIPT_AUDIT.md`](./MAINNET_SCRIPT_AUDIT.md)
- Vulnerability reporting: [`SECURITY.md`](./SECURITY.md)

Mainnet integrations must use `PledgeChainlinkOracle` — never wire the legacy manual `PledgeOracle` used on testnet.

Operators: read [`MAINNET_SCRIPT_AUDIT.md`](./MAINNET_SCRIPT_AUDIT.md) before broadcasting any mainnet script. Do not run deprecated/cutover scripts against the live vault.

## Local development (Anvil)

For isolated local testing without touching mainnet:

```bash
anvil &
export DEPLOYER_PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784681bf6f756
forge script script/Deploy.s.sol --rpc-url http://127.0.0.1:8545 --broadcast
```

## Testnet (development only)

Robinhood Testnet (chain `46630`) uses mock tokens, a manual oracle, and auxiliary contracts (`PledgeTestnetBridge`, `PledgeStaking`, mocks). These components are **not** deployed or supported on mainnet.

| Property | Value |
|---|---|
| Chain ID | `46630` |
| Manifest | [`deployments/46630.json`](./deployments/46630.json) |
| Deploy script | `script/Deploy.s.sol` |

Use testnet exclusively for integration experiments. Production integrations must reference mainnet addresses in [`deployments/4663.json`](./deployments/4663.json).
