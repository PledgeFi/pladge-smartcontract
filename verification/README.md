# Blockscout verification — Robinhood Mainnet 4663

All ten protocol contracts (five implementations + five branded proxies) are an **exact match** on [Sourcify](https://sourcify.dev) and are fully verified on Blockscout.

Explorer: https://robinhoodchain.blockscout.com

This folder exists because the Blockscout instance sits behind Cloudflare and rejects automated requests, so `forge verify-contract` cannot reach it. Verification has to be done from a browser.

The Blockscout dropdown on this chain does not offer a Sourcify method. Use **Solidity (Standard JSON Input)** and the JSON files in this folder.

---

## Form values (every contract)

Reuse these fields on every submission:

| Form field | Value |
|---|---|
| **Contract licence / License** | **MIT License (MIT)** |
| **Verification method** | **Solidity (Standard JSON Input)** |
| Is Yul contract | **No** / off |
| Compilation via IR | **No** / off |
| **Compiler** | **v0.8.24+commit.e11b9ed9** |
| **EVM version** | **cancun** |
| **Optimization enabled** | **Yes** |
| **Optimization runs** | **200** |
| Autodetect constructor args | **Yes** (if the toggle exists) |
| **Constructor Arguments** | **leave empty** — do not paste anything |
| Contract libraries | leave empty |

Do not select Sourcify, Flattened, Multi-part, or Vyper.

The only fields that change per contract are the page URL, **Contract name**, and the `.json` file to upload.

---

## Cheat sheet

All ten are verified. Re-run a row only if an explorer page loses its source.

| # | Status | Contract name | Upload this file |
|---|---|---|---|
| 1 | done | `PledgeChainlinkOracle` | `07-oracle-impl.json` |
| 2 | done | `PledgeSurplusBuffer` | `08-surplus-impl.json` |
| 3 | done | `PledgeStabilityPool` | `09-pool-impl.json` |
| 4 | done | `PledgeStaking` | `10-staking-impl.json` |
| 5 | done | `PledgeVaultManager` | `06-vault-impl.json` |
| 6 | done | `PledgeFinanceVault` | `01-vault-proxy.json` |
| 7 | done | `PledgeFinanceOracle` | `02-oracle-proxy.json` |
| 8 | done | `PledgeFinanceSurplusBuffer` | `03-surplus-proxy.json` |
| 9 | done | `PledgeFinanceStabilityPool` | `04-pool-proxy.json` |
| 10 | done | `PledgeFinanceStaking` | `05-staking-proxy.json` |

**Contract name must match exactly.** Each proxy JSON (`01`–`05`) contains all five named proxies. Submitting `PledgeFinanceVault` against the oracle address will fail bytecode matching.

Pages:

1. `PledgeChainlinkOracle` — https://robinhoodchain.blockscout.com/address/0x428AceFE3bc2Da5a4B9b1615Ae066Bf81Be794cc/contract-verification
2. `PledgeSurplusBuffer` — https://robinhoodchain.blockscout.com/address/0x5df0d2c7aB8443f41B84e684027eEB656e303C12/contract-verification
3. `PledgeStabilityPool` — https://robinhoodchain.blockscout.com/address/0x3fc952F815f63dE054446D4c3C16c57d6467635D/contract-verification
4. `PledgeStaking` — https://robinhoodchain.blockscout.com/address/0x4de94A31e0725270b047820293e784bb62363Be3/contract-verification
5. `PledgeVaultManager` — https://robinhoodchain.blockscout.com/address/0x0b8E032242A54a5373aed9968FEF01a9A0e0ec6F/contract-verification
6. `PledgeFinanceVault` — https://robinhoodchain.blockscout.com/address/0x83B6F15BD3A7385C0F55BA3C685f688511279B00/contract-verification
7. `PledgeFinanceOracle` — https://robinhoodchain.blockscout.com/address/0xB11951Dba2A7cAF846e0A3484237d8E5844428b7/contract-verification
8. `PledgeFinanceSurplusBuffer` — https://robinhoodchain.blockscout.com/address/0xc6D477491ACE30fa5651ac61C735C2B636B095c4/contract-verification
9. `PledgeFinanceStabilityPool` — https://robinhoodchain.blockscout.com/address/0xf70D2a727E72b6890Bd269f5f8AdE7c86F3D244D/contract-verification
10. `PledgeFinanceStaking` — https://robinhoodchain.blockscout.com/address/0xEe8c2E6ED39B79Cd6806926d96CD570F5b94bF07/contract-verification

## Constructor arguments — leave empty

On Standard JSON Input, Blockscout derives constructor arguments from the creation transaction. Pasting them by hand double-counts the suffix and verification fails with a bytecode mismatch. That is the usual failure mode: the first contract submitted with an empty field succeeded; every submission that pasted args failed.

The `.args.txt` files in this folder are a fallback if Blockscout ever requires the field. Their contents match the creation-tx input suffix. If needed:

```
cd verification
pbcopy < 01-vault-proxy.args.txt
```

If the version without `0x` is rejected, retry with a `0x` prefix.

---

## Order of work

Verify the five implementations first, then the five proxies. See [Why implementations first](#why-implementations-first).

## Success

After **Verify & publish**, wait 10–30 seconds. On success the page moves to the **Contract** tab with a green check, the contract name next to the address, and **Read contract** / **Write contract** tabs.

For the five proxies, **Read as Proxy** and **Write as Proxy** appear once Blockscout has linked the proxy to its implementation.

## Why implementations first

Blockscout detects EIP-1967 proxies automatically, but **Read as Proxy** / **Write as Proxy** only appear after the implementation behind the proxy is already verified. Verifying only the proxy leaves the page named `PledgeFinanceVault` with no callable functions.

## Failure modes

**Bytecode mismatch** — confirm Constructor Arguments is empty. Blockscout already derived the args, so a pasted value is counted twice. If an empty field still fails, try the matching `.args.txt`, first without `0x`, then with `0x`.

**Compiler version mismatch** — must be exactly `v0.8.24+commit.e11b9ed9`. Do not pick a nightly `0.8.24` or a different commit.

**Optimization mismatch** — enabled **Yes**, runs **200**. Blockscout sometimes defaults to 200 and sometimes to empty; always check.

**Already verified** — skip to the next address.

## Regenerating the files in this folder

```
forge verify-contract <address> <path>:<Name> --show-standard-json-input > out.json
```

Run this outside a sandbox; Foundry needs write access to its own cache directory.

## Addresses

| Module | Proxy | Implementation |
|---|---|---|
| Vault | `0x83B6F15BD3A7385C0F55BA3C685f688511279B00` | `0x0b8E032242A54a5373aed9968FEF01a9A0e0ec6F` |
| Oracle | `0xB11951Dba2A7cAF846e0A3484237d8E5844428b7` | `0x428AceFE3bc2Da5a4B9b1615Ae066Bf81Be794cc` |
| Surplus Buffer | `0xc6D477491ACE30fa5651ac61C735C2B636B095c4` | `0x5df0d2c7aB8443f41B84e684027eEB656e303C12` |
| Stability Pool | `0xf70D2a727E72b6890Bd269f5f8AdE7c86F3D244D` | `0x3fc952F815f63dE054446D4c3C16c57d6467635D` |
| Staking | `0xEe8c2E6ED39B79Cd6806926d96CD570F5b94bF07` | `0x4de94A31e0725270b047820293e784bb62363Be3` |
