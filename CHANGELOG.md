# Changelog

All notable changes to this project are documented here.

Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added

- `MAINNET_SCRIPT_AUDIT.md` — production-readiness audit of Foundry mainnet scripts (safe/unsafe set, critical address bug, runbook)

### Changed

- Documentation and deployment manifests now target Robinhood Mainnet (chain 4663) as the production reference
- README rewritten for production-grade integrator and operator workflows
- `.env.example` and `verify-deployments.sh` aligned with `deployments/4663.json`

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
