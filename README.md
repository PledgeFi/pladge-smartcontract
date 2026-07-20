# pladge-smartcontract

Canonical **monolithic** Foundry repository for [Pledge Finance](https://github.com/pledge-finance) on Robinhood Chain. Contains the full oracle + protocol stack in one tree, byte-aligned with the live testnet deployment and mainnet manifest.

This repo **coexists** with the audit-friendly split repos in the parent monorepo — see [Split-repo mapping](#split-repo-mapping).

## Contracts

| Area | Contracts |
|---|---|
| Oracle | `IOracle`, `PledgeOracle`, `PledgeChainlinkOracle` |
| Core | `PledgeVaultManager`, `PledgeSurplusBuffer`, `PledgeStabilityPool`, `VaultMath` |
| Testnet | `PledgeStaking`, `PledgeTestnetBridge`, `MockERC20`, `MockChainlinkFeed` |

## Live deployments

| Network | Chain ID | Manifest | Explorer |
|---|---|---|---|
| Robinhood Testnet | 46630 | [`deployments/46630.json`](./deployments/46630.json) | [explorer.testnet.chain.robinhood.com](https://explorer.testnet.chain.robinhood.com) |
| Robinhood Mainnet | 4663 | [`deployments/4663.json`](./deployments/4663.json) | [robinhoodchain.blockscout.com](https://robinhoodchain.blockscout.com) |

### Testnet core addresses (46630)

| Contract | Address |
|---|---|
| PledgeVaultManager | `0x73a805Ffdefe8cC514238f68BC9400a884945bCa` |
| PledgeOracle | `0x5eF13a368Cc96e3f324a79cBEf5a9Cd81eA1Efdf` |
| PledgeStabilityPool | `0xE65c5A7075447Bf9fCf8678717a2671Bf951B0B4` |
| PledgeSurplusBuffer | `0x65A5979a947dE7dBbdeA42E1B168E2F2479fb5C8` |

Full token, staking, and bridge addresses are in `deployments/46630.json` and [`.env.example`](./.env.example).

## Setup

Requires [Foundry](https://book.getfoundry.sh/getting-started/installation) (1.5+ recommended).

```bash
make install
cp .env.example .env
# fill DEPLOYER_PRIVATE_KEY and RPC URLs
```

Pinned dependencies:

- `forge-std@v1.9.6`
- `openzeppelin-contracts@v5.0.2`

## Test

```bash
make test
make fmt-check
make verify-deployments
```

### Known test failure (preserved for parity)

`test_liquidationAfterPriceDrop` fails in this repo and in the upstream `Stocks-Vault/contracts` source — the admin faucet cooldown on `MockERC20.mint` blocks the liquidation setup step. This is documented, not fixed, to keep bytecode parity with the canonical source.

## Deploy

All scripts read `DEPLOYER_PRIVATE_KEY` from `.env` via Foundry.

### Testnet — fresh core deploy

```bash
forge script script/Deploy.s.sol:DeployPledge \
  --rpc-url $ROBINHOOD_TESTNET_RPC \
  --broadcast \
  --chain-id 46630
```

### Testnet — add markets

```bash
forge script script/AddMarkets.s.sol:AddMarkets \
  --rpc-url $ROBINHOOD_TESTNET_RPC \
  --broadcast \
  --chain-id 46630
```

### Testnet — mock Chainlink feeds + oracle sync

```bash
forge script script/SetupChainlinkTestnet.s.sol:SetupChainlinkTestnet \
  --rpc-url $ROBINHOOD_TESTNET_RPC \
  --broadcast \
  --chain-id 46630

forge script script/SyncTestnetOracleFromFeeds.s.sol:SyncTestnetOracleFromFeeds \
  --rpc-url $ROBINHOOD_TESTNET_RPC \
  --broadcast \
  --chain-id 46630
```

### Testnet — staking, bridge, seed

```bash
forge script script/DeployStaking.s.sol:DeployStaking \
  --rpc-url $ROBINHOOD_TESTNET_RPC \
  --broadcast \
  --chain-id 46630

forge script script/DeployBridge.s.sol:DeployBridge \
  --rpc-url $ROBINHOOD_TESTNET_RPC \
  --broadcast \
  --chain-id 46630

forge script script/Seed.s.sol:SeedPledgeTestnet \
  --rpc-url $ROBINHOOD_TESTNET_RPC \
  --broadcast \
  --chain-id 46630
```

### Mainnet

```bash
forge script script/DeployMainnet.s.sol:DeployPledgeMainnet \
  --rpc-url $ROBINHOOD_MAINNET_RPC \
  --broadcast \
  --chain-id 4663

forge script script/RegisterMainnetMarkets.s.sol:RegisterMainnetMarkets \
  --rpc-url $ROBINHOOD_MAINNET_RPC \
  --broadcast \
  --chain-id 4663
```

After deploying, update `deployments/*.json` and `.env.example` with new addresses.

## Market parameters (testnet)

| Market | max LTV | liq ratio |
|---|---|---|
| mNVDA | 6000 bps | 16600 bps |
| mSPY | 7500 bps | 13300 bps |
| mAAPL | 6500 bps | 15300 bps |
| mQQQ | 7000 bps | 14300 bps |
| mMSFT | 6500 bps | 15300 bps |
| mAMZN | 5800 bps | 17200 bps |
| mMETA | 6200 bps | 16100 bps |

See `deployments/46630.json` → `markets` for collateral and feed addresses.

## Split-repo mapping

Option **2b**: this monolith is the **canonical deploy + test** repo. Split repos exist for focused audit and modular integration.

| Role | Repo |
|---|---|
| **pladge-smartcontract** (this repo) | Full monolith — deploy, full test suite, live deployment manifests |
| [`pledge-oracle`](../pledge-oracle) | Audit-friendly oracle-only split |
| [`pledge-protocol`](../pledge-protocol) | Audit-friendly protocol split (depends on oracle) |
| [`pledge-sdk`](../pledge-sdk) / [`pledge-mcp`](../pledge-mcp) | Off-chain integration (unchanged) |

### Path mapping (monolith → split)

| Monolith path | pledge-oracle | pledge-protocol |
|---|---|---|
| `src/interfaces/IOracle.sol` | `src/interfaces/IOracle.sol` | via `lib/pledge-oracle` |
| `src/oracle/PledgeOracle.sol` | `src/PledgeOracle.sol` | — |
| `src/oracle/PledgeChainlinkOracle.sol` | `src/PledgeChainlinkOracle.sol` | — |
| `src/mocks/MockChainlinkFeed.sol` | `src/testnet/MockChainlinkFeed.sol` | — |
| `src/core/PledgeVaultManager.sol` | — | `src/core/PledgeVaultManager.sol` |
| `src/core/PledgeSurplusBuffer.sol` | — | `src/core/PledgeSurplusBuffer.sol` |
| `src/core/PledgeStabilityPool.sol` | — | `src/core/PledgeStabilityPool.sol` |
| `src/core/PledgeStaking.sol` | — | `src/core/PledgeStaking.sol` |
| `src/core/PledgeTestnetBridge.sol` | — | `src/core/PledgeTestnetBridge.sol` |
| `src/libraries/VaultMath.sol` | — | `src/libraries/VaultMath.sol` |
| `src/mocks/MockERC20.sol` | — | `src/mocks/MockERC20.sol` |
| `src/PledgeProtocol.sol` | — | `src/PledgeProtocol.sol` |

**Sync rule:** any Solidity change lands in `pladge-smartcontract` first, then is mirrored to split repos with import-path adjustments only.

## Audit

See [AUDIT.md](./AUDIT.md) for mainnet vs testnet scope. See [SECURITY.md](./SECURITY.md) for vulnerability reporting.

## License

MIT — see [LICENSE](./LICENSE).
