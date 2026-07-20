# Changelog

All notable changes to this project are documented here.

Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [1.0.0] - 2026-07-20

### Added

- Monolithic Foundry repo — oracle + protocol in one tree
- `PledgeVaultManager`, `PledgeSurplusBuffer`, `PledgeStabilityPool`, `VaultMath`
- `PledgeOracle`, `PledgeChainlinkOracle`, `IOracle`
- Testnet modules: `PledgeStaking`, `PledgeTestnetBridge`, `MockERC20`, `MockChainlinkFeed`
- Foundry deploy scripts for testnet and mainnet
- Deployment manifests: `deployments/46630.json`, `deployments/4663.json`
- CI: build, test, fmt check, deployment manifest verification
- Audit and security documentation

[1.0.0]: https://github.com/pledge-finance/pladge-smartcontract/releases/tag/v1.0.0
