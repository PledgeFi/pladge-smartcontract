# Security Policy

## Supported versions

| Version | Supported |
|---|---|
| 1.0.x | Yes |

## Reporting a vulnerability

Email **security@pledge.finance** with reproduction steps, affected chain/address, and impact.

Do not disclose critical issues in public GitHub issues before coordination.

## Scope

Primary audit targets in this monolith (mainnet production path):

- `PledgeVaultManager`
- `PledgeSurplusBuffer`
- `PledgeStabilityPool`
- `VaultMath`
- `PledgeChainlinkOracle` / `IOracle`

The same contracts are also published in split repos for focused review:

- [`pledge-oracle`](../pledge-oracle) — oracle layer
- [`pledge-protocol`](../pledge-protocol) — vault and protocol layer

Review oracle and protocol together for end-to-end CDP safety.

## Live deployments

Reference manifests (do not treat as authoritative over on-chain state):

| Network | Chain ID | Manifest |
|---|---|---|
| Robinhood Mainnet | 4663 | [`deployments/4663.json`](./deployments/4663.json) |
| Robinhood Testnet | 46630 | [`deployments/46630.json`](./deployments/46630.json) |

Production integrations must use **mainnet** addresses only.

## Non-production components

The following are intended for Robinhood Testnet development and must **not** be deployed or integrated on mainnet:

- `PledgeStaking`
- `PledgeTestnetBridge`
- `PledgeOracle` (manual oracle — superseded by `PledgeChainlinkOracle` on mainnet)
- `MockERC20`, `MockChainlinkFeed`, `TestnetEthFaucet`
