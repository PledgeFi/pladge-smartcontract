# Pledge Finance — Product Specification

> Canonical product spec for testers, operators, and internal decisions.  
> Last updated: 2026-09-02  
> Status: **public testnet live** (Robinhood Chain 46630). **Mainnet target: on or about 5 September 2026** (about three days from this update) on chain **4663** — staged deploy already in progress. Treat the date as a **target, not a guarantee**.  
> Related: [README](../README.md) · [testnet roadmap](./public-testnet-roadmap.md) · [risk calculator](./risk-calculator.md) · in-app `/docs`

This document is the source of truth for **what Pledge is, how money moves, what we will not do, and how to answer users**.

**Use this file to train / ground any support AI, Discord bot, or social-reply agent.** If this spec and a tweet/landing line conflict, **this spec wins**. If something is not in this file, say you don’t know — do not invent tokenomics, APRs, buybacks, or seizure rules.

---

## 0. Instructions for AIs (read first)

### 0.1 How to answer

- Match the user’s language (whatever they write in).
- Lead with the direct yes/no, then one short why.
- Separate **live now** vs **planned** vs **rejected**. Never present a roadmap item as if it already ships.
- Never give financial advice (“you should borrow / buy PLG”). Explain mechanics only.
- Never promise audits, yields, buybacks, or a **guaranteed** mainnet clock. The only date in this file is a **target** (§4 / header).
- **Tax:** follow §22. Never invent a rate, form, or “you owe $0.”
- **Bugs / incidents:** follow §21. Never say the protocol is bug-free or that losses will be reimbursed unless the team has announced it.
- Testnet USDG and m-tokens are **mocks**. Say so when the user might think they are Paxos or real stocks.
- Launchpad **PLG** ≠ testnet mock PLG address. Don’t mix chains.
- **Legal / tax / licensing questions:** follow §0.4, §20, and §22. Never invent a license, regulator approval, or “this is legal in your country.”

### 0.2 Never say

| Don’t say | Say instead |
|---|---|
| “Pledge mints USDG against your shares” | You **borrow existing** USDG from vault inventory |
| “If you don’t repay, the platform takes the shares” | Only if **HF < 1**; no due date; no seizure of a healthy vault |
| “You must pay interest every month” | Interest **accrues** and is paid **when you repay** |
| “The longer you wait we confiscate” | The longer you wait, **interest is higher** at repayment |
| “If the stock pumps we raise your rate” | Rate is **time-based APR only**; pump **helps** HF |
| “Fees buy back and burn PLG” | Fees go to **Surplus Buffer**. Burn is **not live** |
| “Governance is live / PLG = 1 token 1 vote” | Governance is **preview**. Direction: **lock PLG → vePLG** |
| “Stability Pool USDG is lent to borrowers” | Two pots. Pool is a **liquidation backstop**, not lend inventory |
| “This is risk-free / like a bank deposit” | Overcollateralized DeFi credit; liquidation and smart-contract risk exist |
| “We are a licensed bank / broker / licensed lender anywhere” | We are a **global smart-contract protocol**. This spec claims **no** license or registration |
| “This is legal in every country / no tax anywhere” | **Not legal or tax advice.** Each user must follow **their** local law |
| “m-tokens are registered securities we issued” | Testnet = **mocks**. Mainnet stocks = **issuer/chain tokens**, not minted by Pledge |
| “There are no bugs / we will refund all losses” | Software can fail. Report it. Compensation is **not** automatic |
| “The IRS / HMRC said Pledge is tax-free” | Those agencies have **general** crypto/property rules. They have **not** ruled on Pledge |

### 0.4 Legal questions (mandatory) — global market

Audience is **worldwide**, not one domestic regulator. Do not lead with any local authority. Do not name-drop country licenses to sound official.

This spec is **not** a legal opinion. Counsel has not signed it.

When someone asks law, license, tax, securities, KYC, “is this legal in my country?”:

1. Say: **not legal, tax, or investment advice.**
2. Use **product facts** in §20 (what the software is / is not). Tax → **§22**. Incidents → **§21**.
3. Legality **where they live** → we do **not** certify it. They need counsel **in that jurisdiction**. Do not guess or cite any regulator as if we are registered there.
4. Never imply testnet mocks are Paxos USDG or real listed shares.
5. Never classify PLG as a security / not a security. **No classification.**
6. Escalate to the team (don’t invent policy) for: ToS, geo-blocks, sanctioned persons, airdrop rules, “can users in country X use this.”

### 0.3 MVP vs later (so the AI doesn’t oversell)

**MVP (what we ship / are shipping on testnet, core story):**

- Deposit tokenized equity → borrow USDG → repay anytime → withdraw shares.
- **Perpetual** loan: no maturity, no monthly bill.
- **Interest grows with time**, itemized on the repay receipt (principal + duration + interest + total).
- Liquidation **only** at HF < 1.00.
- Stability Pool, faucet (testnet), staking, liquidator UI, analytics, operator price admin.
- Team/treasury seeds vault USDG (`fundLiquidity`).

**Explicitly not MVP (do not describe as live):**

- Buyback-and-burn.
- On-chain Governor / vePLG voting (UI preview only).
- PSM contract.
- Production cross-chain bridge.
- User LPs earning borrow interest (Aave-style supply).
- Utilization-based APR (planned direction, not coded as auto).
- Term-loan seizure (rejected, not “coming later”).
- Second valueless unswappable governance token (rejected).
- Interest that tracks the stock price (rejected).

**Likely next (after MVP, if asked “what’s next?”):**

- Raise stability fee if team float is the bottleneck (e.g. toward ~6% APR) — **same model**, just the number.
- Redeploy vault so repay receipt is fully on-chain (`getRepayBreakdown`).
- Fix analytics lookback / indexer lag.
- Align USD display rounding with the ticker.
- LP / PSM so the team is not the only USDG source.
- Lock PLG → vePLG + timelock.

---

## 1. One-sentence pitch

Pledge Finance lets holders of tokenized equities and ETFs on Robinhood Chain **borrow USDG without selling their shares**. Keep the upside. Pay interest when you repay. Liquidation only if the position becomes unsafe.

---

## 2. What Pledge is / is not

| Pledge **is** | Pledge **is not** |
|---|---|
| An overcollateralized CDP (collateralized debt position) | A share sale, broker, or prime brokerage |
| Isolated vaults: one user × one collateral asset × one USDG debt | Cross-margin across all stocks in one account |
| A lender of **existing** USDG sitting in the vault | A minter of a new stablecoin |
| Perpetual credit: no due date, no monthly bill | A term loan / pawn shop with seizure at maturity |
| Liquidation only when health factor **< 1.00** | A collections desk that seizes healthy vaults |
| Testnet: mock USDG + mock m-tokens | Mainnet-ready Paxos USDG + real stock tokens until those rails are live |

**Narrative we protect (do not break in product or copy):**

- You are **not selling** the shares.
- There is **no loan term**.
- There is **no seizure of a healthy position**.
- Interest **accrues with time** and is paid **at repayment**.
- A rising share price is **your** upside. The borrow APR does **not** go up because the stock went up.

---

## 3. Who it is for

| Persona | Job to be done |
|---|---|
| Equity holder | Unlock USD cashflow without selling NVDA / AAPL / SPY exposure — **global**, on Robinhood Chain |
| USDG holder / pool depositor | Park USDG in the Stability Pool; earn liquidation spread if vaults blow up |
| PLG holder | Stake for rewards today; later lock for vote-escrow governance |
| Liquidator | Buy distressed collateral at a bonus by repaying USDG debt |
| Operator / team | Seed vault USDG, sync oracles, set market params, run Price Admin on testnet |

---

## 4. Networks

| | Testnet | Mainnet (target) |
|---|---|---|
| Chain | Robinhood Chain Testnet | Robinhood Chain |
| Chain ID | **46630** | **4663** |
| RPC | `https://rpc.testnet.chain.robinhood.com` | `https://rpc.mainnet.chain.robinhood.com` |
| Explorer | `https://explorer.testnet.chain.robinhood.com` | `https://robinhoodchain.blockscout.com` |
| USDG | Mock ERC-20, **18 decimals** | Paxos USDG `0x5fc5…d168`, **6 decimals** |
| Collateral | Mock `mNVDA`, `mAAPL`, … | Real tokenized equities when listed |
| Oracle | MockChainlinkFeed + `PledgeOracle` sync | `PledgeChainlinkOracle` + production feeds |
| Faucet | Live (48h / token) | Off |
| Manifest | `web/src/lib/deployments/46630.json` | `web/src/lib/deployments/4663.json` |
| Go-live | Live now | **Target ~5 September 2026** (team-stated; can slip). Confirm on official channels. |

Frontend chain is selected with `NEXT_PUBLIC_PLEDGE_CHAIN_ID`.

---

## 5. User journeys

### 5.1 Happy path — borrow and return shares

1. Connect wallet on Robinhood Chain (testnet: 46630).
2. Get gas ETH (network faucet).
3. Testnet: claim mock shares + mock USDG at `/borrow/faucet`.
4. **Deposit** mAAPL (etc.) into the vault. Shares leave the wallet and lock in `PledgeVaultManager`.
5. **Borrow** USDG up to the market max LTV. Origination fee is taken immediately; user receives `amount − fee`; debt recorded is the **gross** amount.
6. Use USDG (hold, pool, transfer). Shares still belong to the user as a vault position.
7. **Repay** principal + accrued interest (receipt shows the split).
8. **Withdraw** shares back to the wallet.

You can repay in part. Interest is paid **first**, then principal.

### 5.2 Hold for years

Allowed. No due date.

- Stock **up** → collateral value up → health factor **improves**. Interest still accrues.
- Stock **flat** → HF slowly declines as debt grows with interest.
- Stock **down** → HF falls faster; if HF < 1.00 the vault can be liquidated.

Example at **1.2% APR** (current on-chain testnet param), 214 USDG principal:

| Time borrowed | Interest (simple, if untouched) | Total due |
|---|---|---|
| 1 month | ~0.21 | ~214.2 |
| 8 months | ~1.71 | ~215.7 |
| 2 years | ~5.14 | ~219.1 |
| 4 years | ~10.3 | ~224.3 |

A **6% APR** (product direction if team USDG is the float) would be ~5× those interest numbers. The **mechanism** does not change: still accrued, still paid at repay, still no monthly bill.

### 5.3 Get liquidated (test)

1. Open a **small** borrow (faucet USDG for liquidators is limited).
2. Borrow near max LTV so HF is close to 1.00.
3. Operator drops the mock feed (~25%+ on a conservative book) and **syncs** the vault oracle.
4. A **second wallet** with USDG ≥ full debt opens `/borrow/liquidator` and liquidates.
5. UI blocks **self-liquidation**.

---

## 6. Credit policy (locked)

These rules are also in `.cursor/rules/credit-policy.mdc`.

1. **Perpetual.** No maturity. No “unpaid for N months → seize.”
2. **No monthly USDG coupon.** Interest is not a calendar bill.
3. **Repayment receipt** must show: principal, time borrowed, interest, total due.
4. **APR is time-based only.** It must not track the equity’s price. Taxing upside breaks the narrative.
5. **Liquidation = HF < 1.00 only.** Not a way to recycle team capital.
6. Recycle USDG via: repayments, higher APR, utilization (later), LP/PSM (later) — **not** seizure of healthy vaults.

**Rejected ideas (do not ship):**

- Max tenor then confiscate shares while HF ≥ 1.
- Mandatory monthly repayments (implies a penalty, which becomes seizure).
- “Stock pumped so we raise your rate.”

---

## 7. Protocol architecture

```
User wallet
    │
    ├─ PledgeVaultManager     CDP: deposit / borrow / repay / withdraw / liquidate
    │       ├─ PledgeOracle   price used for LTV, HF, liquidation
    │       ├─ USDG balance   **borrow liquidity** (seeded via fundLiquidity)
    │       └─ PledgeSurplusBuffer   origination fees (USDG)
    │
    ├─ PledgeStabilityPool    **separate** USDG pot — liquidation backstop, not lend inventory
    ├─ PledgeStaking          PLG / USDG stake → PLG rewards
    ├─ PledgeTestnetBridge    attestation ingress (testnet only)
    └─ Mock / real feeds      UI ticker; vault must be synced on testnet
```

**One vault manager for all markets** (not one contract per stock). Positions are keyed `(collateral, user)`.

### 7.1 Two USDG pots (do not confuse)

| Pot | Contract | Who fills it | Who takes it out | If empty |
|---|---|---|---|---|
| **Vault liquidity** | `PledgeVaultManager` USDG balance | Team/treasury `fundLiquidity()`, plus user **repays** | Borrowers | **New borrows fail** (`InsufficientLiquidity`). Existing loans stay. Pool withdrawals unaffected. |
| **Stability Pool** | `PledgeStabilityPool` | Users depositing USDG | Those users withdrawing; (designed) liquidation `payDebt` | Depositors cannot withdraw more than pool holdings. **Does not fund borrows.** |

Current `liquidate()` pays from the **liquidator’s wallet**, not from the pool. Pool `payDebt` exists but is not wired in the live liquidation path yet. Docs sometimes say “pool covers debt”; treat that as the **intended** Liquity-style path, not the exact testnet path today.

This is **not** fractional-reserve banking. Pool USDG is not lent to borrowers.

---

## 8. Math (on-chain)

Constants: `BPS = 10_000`, `WAD = 1e18`.

### 8.1 Max debt

```
max_debt = collateral_usd × maxLtvBps / 10_000
```

Example: $10,000 mNVDA, 60% LTV → **6,000 USDG** max.

Borrowing at the cap leaves almost **no** price buffer (HF ≈ 1.00).

### 8.2 Health factor

On-chain (`VaultMath.healthFactor`):

```
HF = collateral_usd × 10_000 / (debt_usd × liqRatioBps)
```

`liqRatioBps` is a **minimum collateralization ratio** (16600 = 166%), **not** an Aave-style 80% liquidation threshold.

Liquidatable when **HF < 1**.

**Worked example (tester book):** 2 mAAPL, price $219.80, debt 214 USDG, liq ratio 153%:

```
collateral = 439.60
HF = 439.60 / (214 × 1.53) ≈ 1.34
```

Raw `439.60 / 214 ≈ 2.05` is **CR**, not HF. UI HF of 1.34 is correct.

### 8.3 Interest (core product — longer hold = more interest)

This is the mechanism we chose instead of seizure or a due date.

**User-facing rule**

- You do **not** send USDG every month.
- While the loan is open, a **stability fee APR** ticks in the background.
- When you tap **Repay**, the screen is a **receipt**:
  - Principal (what you borrowed, gross)
  - Time borrowed (e.g. 8 months 12 days)
  - Interest accrued
  - **Total due**
- Stay 1 month → small interest. Stay 2 years → more interest. That is the only “pressure” to repay a healthy vault.

**On-chain formula** (simple / linear per accrual window):

```
interest = debt × aprBps × elapsed / (365 days × 10_000)
```

Applied when the user (or a liquidator) interacts: deposit, withdraw, borrow, repay, liquidate. If they go silent, the next touch applies the whole elapsed window on **stored debt** (not continuously compounded every block).

Repay **interest first**, then principal. Full repay resets the debt clock (`debtOpenedAt = 0`).

**APR must not follow the stock price.** A rising share is the user’s upside.

**Worked receipts — 214 USDG principal**

At **1.2% APR** (live testnet param today):

| Time borrowed | Interest | Total due |
|---|---|---|
| 1 month | ~0.21 | ~214.2 |
| 8 months | ~1.71 | ~215.7 |
| 2 years | ~5.14 | ~219.1 |
| 4 years | ~10.3 | ~224.3 |

At **~6% APR** (product direction if team USDG is the float — **not** live until params change):

| Time borrowed | Interest | Total due |
|---|---|---|
| 1 month | ~1.07 | ~215.1 |
| 8 months | ~8.6 | ~222.6 |
| 2 years | ~25.7 | ~239.7 |
| 4 years | ~51.4 | ~265.4 |

If asked “what is the rate today?” → **1.2% APR on current testnet markets**, unless a market was registered with a different `stabilityFeeAprBps`. Do not tell users 6% is already live.

### 8.4 Origination

```
fee = borrow_amount × originationFeeBps / 10_000
payout = borrow_amount − fee
debt += borrow_amount
```

Typical testnet: **0.5%**. Fee USDG goes to **Surplus Buffer**. User still owes the gross amount.

### 8.5 Liquidation seize

Liquidator pays **full debt** (after accrual), receives:

```
collateral_seized = debt × (1 + liqBonusBps/10_000) / price
```

Capped at the vault’s collateral. Typical bonus **5%** (`500` bps). Remainder stays in the user’s vault. Self-liquidation reverts.

---

## 9. Markets (testnet params)

| Market | Max LTV | Liq. ratio | Meaning at max borrow |
|---|---|---|---|
| mSPY | 75% | 133% | Highest LTV; tightest buffer |
| mQQQ | 70% | 143% | |
| mAAPL / mMSFT | 65% | 153% | |
| mMETA | 62% | 161% | |
| mNVDA | 60% | 166% | |
| mAMZN | 58% | 172% | Lowest LTV; widest CR |
| mGOOGL | — | — | **Pending**, not deployed |

Shared testnet fees (unless a market was registered differently):

| Fee | Param | Typical |
|---|---|---|
| Stability fee | `stabilityFeeAprBps` | **1.2% APR** (`120`) |
| Origination | `originationFeeBps` | **0.5%** (`50`) |
| Liq bonus | `liqBonusBps` | **5%** (`500`) |

Product note: 1.2% is cheap if **team USDG** is the lend float. A later raise (e.g. 6% APR) is a parameter change, not a new credit model. Utilization-based rates are a later upgrade.

---

## 10. USDG supply — the capital problem

Pledge **does not mint USDG** on borrow. Docs:

```
USDG_borrowed = Σ debt + fees     // borrowed, not protocol-minted
```

So **max simultaneous loans ≈ USDG sitting in the vault**.

| Environment | Where USDG comes from |
|---|---|
| Testnet | Deployer mints mock USDG and `fundLiquidity()` (e.g. 500,000) |
| Mainnet | Protocol must **source Paxos USDG** (buy / partner / LP / PSM) and seed the vault |

If demand > inventory: new `borrow` reverts. Old borrowers are **not** force-closed.

**How to scale without only team capital**

| Tool | Status | Effect |
|---|---|---|
| Treasury seed | Live (`fundLiquidity`, permissionless send, **no LP receipt**) | Team/partners put USDG in |
| Repay recycle | Live | USDG returns to vault |
| Raise APR | Param (owner/governance) | Demand down, repay up |
| Debt ceilings | Design / per-market LTV already limits size | One ticker cannot eat all USDG |
| User LPs earn the stability fee | **Not live** | Market supplies the float |
| PSM 1:1 other stables → USDG | **Preview UI only** | Inventory without team buying 100% |
| Mint a Pledge stable | **Rejected for now** | Would not be Paxos USDG |

`fundLiquidity` does **not** give the sender a claim token. USDG sent in is protocol inventory until borrowers repay.

---

## 11. Tokens

| Token | Role | Tradable? |
|---|---|---|
| **USDG** | Debt asset borrowed; Paxos on mainnet, mock on testnet | Yes (mainnet). Mock on testnet. |
| **mNVDA, mAAPL, …** | Vault collateral (testnet mocks) | Testnet mocks; mainnet = real tokenized stocks |
| **PLG** | Protocol token. Launchpad listing is the **economic** token. Staking rewards. | Yes |
| **vePLG** (planned) | Voting power from **locking PLG** | **No.** Not a second DEX coin. |
| Soulbound “gov” with no value | Tester badge only | Must **not** govern treasury / vault params |

**Do not ship a second valueless unswappable governance coin.** Sybil, confusion, and a rug on launchpad holders.

**Do not let unlocked liquid PLG vote 1:1.** Launchpad snipers could take fee/LTV/Surplus Buffer.

Governance path:

1. Now: team / multisig operators.
2. PLG staking (already on testnet).
3. Later: lock PLG → vePLG + timelock on execution.
4. Buyback-and-burn of PLG: **not live**. Fees → Surplus Buffer. Any burn is a **future governance** choice.

---

## 12. Surplus Buffer

- Receives **origination** USDG on each borrow.
- Stability interest: accrued onto debt; when repaid, USDG returns to **vault liquidity** (current code), not a separate transfer to the buffer. In-app copy that says “routed to Surplus Buffer over time” is **aspirational / simplified**.
- `withdraw` is **owner-only**. First job of the reserve: absorb bad debt before pool depositors take losses (policy). Not an automatic buyback contract.

---

## 13. Modules & routes

| Route | Status | Notes |
|---|---|---|
| `/borrow` | Live | Deposit / borrow / repay / withdraw + receipt |
| `/borrow/pool` | Live | Stability Pool USDG |
| `/borrow/faucet` | Testnet live | 200 USDG, 50 PLG, 2 m-token; **48h** / token / wallet |
| `/borrow/staking` | Live | PLG lock ~7d; USDG pool no lock; rewards in PLG |
| `/borrow/bridge` | Partial | EIP-712 attestation on RH testnet — **not** a real L1 bridge |
| `/borrow/liquidator` | Live | Auto-scan HF < 1; need USDG ≥ full debt |
| `/borrow/analytics` | Live | Chain KPIs; activity lookback limited (see FAQ) |
| `/borrow/admin/prices` | Testnet operators | Mock feed ± presets; must **sync** vault oracle |
| `/borrow/governance` | Preview | No Governor |
| `/borrow/psm` | Preview | No contract |
| `/docs` | Live | Public docs |

---

## 14. Testnet operations

### Faucet

- Mock ERC-20 mint, **48 hours** per token per wallet.
- ETH gas: Robinhood testnet faucet / in-app ETH faucet (~0.01 ETH, 24h) if configured.
- Liquidation tests: keep debt **small**; faucet is 200 USDG / 48h.

### Oracles

- UI ticker reads `latestRoundData` on mock feeds (and may **animate** the last cents).
- Vault risk uses **PledgeOracle** storage. If feed ≠ oracle, borrow/withdraw can block as **stale**.
- Operators: Price Admin or `SyncTestnetOracleFromFeeds.s.sol`.

### Indexer

- Optional Postgres. Without it, RPC `getLogs` lookback **500,000 blocks** ≈ **~34 days** on this chain.
- Live KPIs (TVL, prices, collateral balances) read **state**, not that window.
- `syncVaultEventsUntilCaughtUp` only advances a few 20k-block chunks per request — activity can lag.

### Self-liquidation

- UI + contract error `SelfLiquidationNotAllowed`.
- Deployed 46630 vault may lag repo; confirm before promising on-chain enforcement.

---

## 15. UI truthfulness

| Surface | Behavior |
|---|---|
| Locked collateral KPI | Rounded to **whole dollars** (`$439.60` → `$440`) |
| Oracle ticker | 2 decimals + rolling digits + slight jitter | Can look ≠ 2 × price |
| Repay tab | Principal / interest / duration / total | Needs vault with `getRepayBreakdown` |
| HF gauge | On-chain HF, liquidation at 1.00, target 2.50 | Not collateral/debt |

Older vaults without `getRepayBreakdown`: UI falls back to pending interest since last interaction only.

---

## 16. Contracts (testnet 46630)

Authoritative list: `web/src/lib/deployments/46630.json`.

| Name | Address |
|---|---|
| PledgeVaultManager | `0x73a805Ffdefe8cC514238f68BC9400a884945bCa` |
| PledgeStabilityPool | `0xE65c5A7075447Bf9fCf8678717a2671Bf951B0B4` |
| PledgeOracle | `0x5eF13a368Cc96e3f324a79cBEf5a9Cd81eA1Efdf` |
| PledgeSurplusBuffer | `0x65A5979a947dE7dBbdeA42E1B168E2F2479fb5C8` |
| PledgeFinanceUSDG (mock) | `0xF10AA239c709025238F2181812330Ba706ecA9E7` |
| PledgeFinancePLG (mock on this chain) | `0x046320362ff989E11DA762B5125d3099fd27075E` |
| PledgeStaking | `0xd90F9Feb90b13C126F09bB833C52e24f01751d47` |
| PledgeTestnetBridge | `0x4d01aef8a2f1c8663dba8d9aebfa56e5be0d9cd5` |

Launchpad PLG is a **separate** listing from testnet mock PLG. Do not mix addresses in public answers without checking the chain.

---

## 17. FAQ

### A. Borrowing, interest, and redeeming shares

**Can I pledge shares, take USDG, then return USDG and get the shares back?**  
Yes. Deposit → borrow → repay (principal + accrued interest) → withdraw. You did not sell the shares.

**Do I have to repay on a schedule / every month?**  
No. No due date, no monthly USDG bill. You can sit as long as HF ≥ 1.

**Then how does interest work? Longer loan = more interest?**  
Yes. That is the product. APR runs in the background. You pay it **at repayment**, with a breakdown: principal, how long, interest, total. 8 months costs more than 1 month. 4 years costs more than 8 months.

**Is that the same as a monthly installment?**  
No. Installment = you must send money on a calendar or you default. Pledge = optional repay anytime; unpaid interest **adds to what you owe later**, it does not auto-seize a healthy vault.

**Does paying later ruin the “keep your shares” story?**  
No. Showing a honest receipt **supports** the story. What would ruin it: a due date, a monthly mandate, or seizing shares while HF ≥ 1.

**Where do I see interest?**  
Repay tab: principal, time borrowed, interest, total due. Until the upgraded vault is redeployed, some testnet books may only show interest since the last vault action.

**If the stock goes up, does my rate go up?**  
No. That would tax your upside. APR is time-based only. A higher stock price **improves** health factor.

**If I never repay for 4 years and the stock rips, what happens?**  
You still own the vault. Debt is a bit larger (interest). HF is usually **safer**. Unlock shares by repaying the higher total. The platform does not seize because you waited.

**Can I repay a little at a time?**  
Yes. Interest is cleared first, then principal.

**Why did I receive less USDG than my debt?**  
Origination fee (~0.5%) is taken at borrow. Debt is the gross size; wallet gets net.

---

### B. Default, “mortgage,” liquidation

**If I don’t pay, does the platform take my shares?**  
Not automatically, and not because time passed. Healthy vaults (HF ≥ 1) are not confiscated.

**When can someone take the shares?**  
Only if **HF < 1.00** (price crash and/or too much debt vs the liquidation ratio). A liquidator pays your USDG debt and receives collateral at a ~5% bonus. Leftover shares stay yours.

**Is that the company treasury mortgaging me?**  
No. It is an open liquidation. The liquidator (or, in the intended design, Stability Pool depositors) is the counterparty.

**Can I liquidate myself to test?**  
No. Self-liquidation is blocked. Use a second wallet.

**Why is it so hard to get liquidated on stocks?**  
Equities move slower than crypto. From HF 1.33 you may need a ~25% drop (e.g. mAMZN). That is by design. Testnet operators can crash mock feeds.

**Why is HF 1.34 when 440/214 ≈ 2.05?**  
HF uses the **liquidation ratio** (e.g. 153%), not collateral ÷ debt.

---

### C. USDG liquidity & the pool

**Who is the lender?**  
Protocol inventory: team/treasury (and anyone who calls `fundLiquidity`) plus recycled repays. Not Stability Pool depositors. Not minted USDG.

**Does the team need a lot of capital?**  
On mainnet, yes, **if** only the team seeds Paxos USDG. Scale later via LP yield, PSM, partners — not by minting fake USDG.

**Borrow failed: insufficient liquidity.**  
The vault’s USDG balance is too low. Wait for repays, smaller borrow, or wait for a seed. Check Analytics “vault USDG liquidity.”

**I deposited in the Stability Pool. Vault USDG is all lent out. Can I withdraw?**  
Yes, if your USDG is still **in the pool**. Vault emptiness does not freeze pool withdrawals. Different pots.

**Will pool depositors lose USDG if everyone borrowed?**  
Not from lending. They only give up USDG if that USDG is used to **cover a liquidation** (intended path). Then they receive collateral at a discount instead.

---

### D. Fees, treasury, buyback

**What does the protocol earn?**  
Origination (to Surplus Buffer) + stability interest (grows user debt; repay restocks vault USDG today).

**Is revenue used to buy back and burn PLG?**  
**Not now.** Surplus Buffer is a reserve (incl. bad-debt backstop), owner-gated. Buyback/burn would be governance later — do not promise it.

**Are fees hidden?**  
They must not be. Origination at borrow; interest on the repay receipt.

---

### E. PLG & governance

**I launched PLG on a launchpad. Is that the governance token?**  
That PLG is the **economic** token. Do not launch a second worthless unswappable “gov” coin.

**How will voting work?**  
Lock PLG → **vePLG** (non-transferable voting units). Unlocked PLG should not be 1:1 votes.

**Is governance live?**  
No. UI preview. Operators/multisig run the protocol today.

---

### F. Testnet app bugs & limits

**Analytics only shows “34d ago” / 24h activity is 0.**  
Known. Event scan lookback ≈ 500k blocks ≈ 34 days. Live prices and TVL can still be current. New txs may lag until indexer catch-up or lookback is extended. Not a wallet bug.

**Locked collateral $440 vs price $219.80 × 2.**  
Rounding to whole dollars + ticker animation. Protocol math uses full precision. We should align display precision.

**Oracle stale / borrow blocked.**  
Vault oracle not synced to the feed. Operator sync; testers wait or ping the team.

**MetaMask wants thousands of ETH gas.**  
The tx would revert (wrong network, stale oracle, insufficient allowance, HF, liquidity). Switch to **46630**, refresh, check the revert reason.

**Faucet says cooldown.**  
48h per mock token per wallet. ETH gas is a separate faucet.

**Bridge: balance didn’t drop / weird gas.**  
Testnet bridge is attestation + in-app settlement, not a production lock-and-mint bridge. After a bridge redeploy, hard-refresh. v2 vs v3 address mismatch is a common issue.

**Charts 24h % look fake.**  
Testnet can use a synthetic curve from the latest price. Not a full historical index.

---

### G. Mainnet / legal / risk

**Is USDG “real dollars”?**  
On mainnet: Paxos USDG on Robinhood Chain. On testnet: **mock**. Never imply mock USDG is Paxos.

**Are m-tokens real stocks?**  
Testnet mocks. Mainnet depends on Robinhood-listed tokenized equities actually registered as collateral.

**Market hours?**  
Equities don’t price 24/7 like ETH. Oracle should use last close off-hours. Pre-close borrow pauses are **planned**, not active on testnet.

**Smart contract risk?**  
Unaudited for a polished public launch. Conservative LTVs, debt ceilings, staged rollout. Surplus Buffer + Stability Pool are the economic backstops — not a guarantee.

**Oracle / feed risk?**  
Wrong or stale prices → wrong HF. Testnet mocks can be admin-set. Mainnet must use production Chainlink-style equity feeds + staleness checks.

**What if USDG depegs?**  
Debt is USDG-denominated. Peg is Paxos’s problem on mainnet plus protocol overcollateralization. PSM is the planned in-protocol peg tool (not live).

**Is this legal in my country? Are you licensed? A bank?**  
See **§20**. Short version: **not legal advice.** Pledge is **on-chain software** for a global audience. We do **not** claim to be a bank, broker, or licensed lender in any jurisdiction. Whether *you* may use it is **your** local law — we don’t certify it.

**KYC? Taxes?**  
KYC: wallet-in, no KYC in the product today — not a legal green light. **Tax:** see **§22**. We do not compute your bill.

**When is mainnet?**  
Team target: **on or about 5 September 2026** (about three days after this spec’s 2 September 2026 update), chain ID **4663**. Staged contracts are already being deployed. Dates move — check the official account/app. Not a guaranteed SLA.

**What if there is a bug?**  
See **§21**. Possible. Report it. Testnet losses are mock. Mainnet: don’t keep feeding a suspected exploit; we may pause markets. Reimbursement is not automatic.

---

### H. Product shape people will compare

**Is this a bank loan / pawn shop?**  
Closer to Maker/Liquity-style DeFi credit than a pawn ticket. No maturity. Collateral stays yours until HF < 1 (or you withdraw after repay).

**Can I have several stocks at once?**  
Yes, but **isolated**: one vault per asset (mAAPL debt is not mixed with mNVDA debt).

**Can I short the stock?**  
No. You stay **long** the pledged shares. You borrowed USDG; you did not sell the equity.

**Do I get dividends on pledged shares?**  
Not modeled on testnet mocks. Do not invent a dividend pass-through unless a mainnet token’s real issuer documents it — out of scope for MVP.

**Staking USDG vs Stability Pool vs vault seed — what’s the difference?**  
- **Borrow vault USDG:** inventory to lend; filled by team `fundLiquidity` + repays; you don’t “deposit to earn” there in MVP.  
- **Stability Pool:** you deposit USDG as a backstop; not lent to borrowers; intended to take liquidation flow.  
- **Staking USDG:** separate reward pool (PLG emissions on testnet), not the lend inventory.

**Landing page / old copy says “mint USDG”.**  
Outdated wording. **Correct:** borrow USDG that already sits in the vault. AI must not repeat “mint.”

**Is the app audited? Is PLG a good investment?**  
No audit promised here. No investment advice.

**Which chain do I add?**  
Public testers: **Robinhood Chain Testnet, chain ID 46630**. Mainnet 4663 is staged and not the tester default unless the hosted app says so.

**WalletConnect / gas / wrong network?**  
Use the in-app connect flow. Absurd gas ≈ the tx would revert. Switch to 46630, refresh, check oracle, allowance, HF, vault USDG liquidity.

---

### I. “How do I explain this in one breath?”

Pledge: lock tokenized shares, borrow USDG, keep the stock. No sale, no due date, no monthly bill. Interest grows with time and is paid when you repay (receipt: principal + duration + interest). Nobody takes a healthy vault. If the stock crashes through the liquidation line, a liquidator closes the debt. Fees sit in a surplus reserve today — not a PLG burn. PLG is the launch token; voting later is lock-to-vote, not a second valueless coin.

---

## 18. Copy-paste replies (public)

**Short**  
Yes — pledge shares → borrow USDG → repay anytime → unlock shares. No due date, no auto-seizure. Interest accrues with time and is paid at repayment. Liquidation only if HF < 1. Fees go to the Surplus Buffer today, not buyback-and-burn.

**Long — the three classic questions** (pledge / default / buyback)

Good question.

Yes. You pledge tokenized shares into a vault, borrow USDG against them, then return the USDG whenever you want and withdraw the same shares. You are not selling. You keep the upside if the stock goes up.

If you don’t repay, the platform does not automatically take the shares. There is no due date and no monthly bill. Interest just accrues with time, so a longer loan costs more at repayment. That is the incentive to pay back — not seizure of a healthy position.

Shares are only liquidated if health factor falls below 1.00, which usually means a sharp price drop, not “you waited too long.” A third-party liquidator (or the Stability Pool) closes the USDG debt and receives collateral at a bonus. Leftover shares stay in your vault. The company treasury does not mortgage them as its own.

Platform fees today (origination fee on borrow + stability interest over time) go to the Surplus Buffer as protocol reserves, including a backstop for bad debt. There is no live buyback-and-burn. If PLG is later used for repurchase and destroy, that would be a governance decision — it is not how revenue works right now.

---

## 19. Implementation map

| Concern | Code |
|---|---|
| Vault / HF / liquidate / interest | `contracts/src/core/PledgeVaultManager.sol` |
| Interest formula | `contracts/src/libraries/VaultMath.sol` |
| Repay receipt (principal, interest, openedAt) | `getRepayBreakdown` + mappings `principalDebt`, `debtOpenedAt` |
| Pool | `contracts/src/core/PledgeStabilityPool.sol` |
| Surplus | `contracts/src/core/PledgeSurplusBuffer.sol` |
| Testnet markets | `web/src/lib/deployments/46630.json` |
| Repay UI | `web/src/components/app/VaultActionPanel.tsx` |
| Credit rules for agents | `.cursor/rules/credit-policy.mdc` |

Redeploy the vault after `getRepayBreakdown` for the full receipt on an already-live testnet.

---

## 20. Global legal positioning (not a legal opinion)

**Market:** global. Users anywhere can ask. Answers stay **jurisdiction-agnostic**. Never frame Pledge as a product of one country’s regulator.

**Disclaimer (always available):** Nothing in this spec or in AI replies is legal, tax, investment, or accounting advice. No lawyer has approved these lines as compliance.

### 20.1 What we are (product facts)

| Fact | Meaning for answers |
|---|---|
| Smart contracts on **Robinhood Chain** | Users transact with software + a wallet. Not a branch, not a teller. |
| CDP: pledge tokenized equity, **borrow existing USDG** | Credit **mechanics**, not a claim that we are a licensed consumer lender. |
| Mainnet USDG is **Paxos-issued** (when live) | Pledge does **not** issue the stablecoin. |
| Tokenized stocks / ETFs | Issued / listed on the chain by **those issuers**, not minted by Pledge as “our shares.” Testnet `m*` tokens are **mocks**. |
| Interface is **wallet-in** | No KYC flow in the current app. Do **not** say “therefore no regulation applies.” |
| Experimental / testnet + staged mainnet | Unaffected by slogans. No audit promised in this spec. |
| PLG on a launchpad | Tradable protocol token. **Do not** call it a registered offering or say it is / isn’t a security. |

### 20.2 What we are not (do not claim)

- A bank, credit union, broker-dealer, exchange, ATS, or money transmitter **license** in any country.
- A registered securities offering by Pledge of Apple/NVIDIA/etc. shares.
- A custodian in the traditional legal sense (assets sit in the vault contract; that is not a licensed custody pitch).
- “Approved,” “regulated as,” or “licensed by” any named authority.
- Tax software. We do not compute or file tax.

### 20.3 How to answer typical global legal questions

**“Is Pledge legal?”**  
We don’t certify legality worldwide. The protocol is public smart-contract software. **You** must follow the laws that apply to you (including crypto, securities, lending, and sanctions). For a legal determination, ask qualified counsel where you live.

**“Are you a bank / money lender?”**  
No. We don’t take deposits like a bank. Users lock collateral in a vault and borrow USDG from protocol inventory, on-chain.

**“Is this a security? Are the stocks real?”**  
Pledge does not issue Apple or NVDA. On **testnet**, m-tokens are fakes for testing. On **mainnet**, collateral is whatever tokenized equity the chain/issuer already lists — their disclosures apply, not a Pledge share prospectus. We don’t classify PLG.

**“Do I need KYC / can OFAC / sanctioned wallets use this?”**  
The current app does not collect KYC. Access control, geo-blocking, and sanctions screening are **team/policy** topics — escalate; don’t invent a list. Users remain responsible for not violating sanctions or local bans.

**“Do I pay tax on the borrow / on liquidation?”**  
See **§22**. Maybe, depending on where you are. **We don’t know your tax** and we don’t compute it. Keep records; ask a tax professional.

**“Who owns the shares while pledged?”**  
Product: they remain **your vault position** until you withdraw or a **HF < 1** liquidation moves collateral to a liquidator. That is protocol logic, not a court ruling on property law in your country.

**“Can we onboard users in [country]?”**  
Escalate to the team. AI must not greenlight a market.

### 20.4 One-liner for global comms

Pledge Finance is a **global, on-chain** protocol on Robinhood Chain: borrow USDG against tokenized equities without selling them. It is **not** a licensed bank or broker. Using it is the user’s responsibility under **their** local law. Not legal advice.

---

## 21. Bugs, incidents, and how to answer them

Smart contracts and apps can fail. This protocol is **not promised audited** in this spec. A bug is not a reason to invent a refund policy.

### 21.1 Classes of failure

| Class | Examples | What to tell users |
|---|---|---|
| User / wallet | Wrong network, no gas, failed approve, HF too low | How to fix. Not a protocol insolvency. |
| UI / indexer | “34d ago” activity, USD rounding, rolling price | Known or likely display issues. On-chain state is source of truth. Explorer > UI. |
| Oracle / ops | Stale vault price, feed ≠ oracle | Borrow/withdraw may halt until sync. Testnet: operators. Mainnet: treat as risk. |
| Smart contract | Unexpected revert, exploit, wrong accounting | **Escalate to the team immediately.** Do not walk the user through draining funds. Do not post exploit steps in public. |

On-chain pause lever (product fact): owner can `setMarketActive(false)` per market. There is no magic “undo all txs” button.

### 21.2 Testnet vs mainnet

| | Testnet | Mainnet |
|---|---|---|
| Assets | Mocks | Paxos USDG + real listed tokens (when live) |
| If funds look “lost” | Almost always mock. Still report. | Real value. Collect evidence; team incident process. |
| Public disclosure | OK for UX bugs | **Exploit:** private report first if a bounty/contact exists; otherwise team. Don’t copy-paste payloads. |

### 21.3 What the AI must collect

- Chain ID (46630 vs 4663)
- Tx hash, vault/market, wallet (user can redact)
- Screenshot + whether explorer agrees with the UI
- Expected vs actual

Then: thank them, don’t promise a timeline or a payout, route to the team.

### 21.4 What not to say

- “Impossible to lose funds.”
- “We’ll airdrop you whole.” (unless the team posted that)
- “Keep retrying the same tx” on a suspected exploit.
- Step-by-step exploit reproduction.

### 21.5 One-liner

Bugs happen. Explorer is truth. Report with a tx hash. Testnet is mock value. Mainnet incidents go to the team; refunds are not automatic.

---

## 22. Tax — research notes for AI (not tax advice)

Checked against **primary** sources on **2026-09-02**. Not a legal opinion. Laws change; links can move.

**Hard rules for the AI**

- Never file, never compute a number, never say “you owe 0.”
- Never say “the IRS / HMRC / IRAS approved Pledge.”
- Current product: Pledge does **not** issue tax forms or withhold tax. Do not promise that will never change.
- Tokenized **equities** may be taxed like **shares**, not like bitcoin. Do not mash everything into “crypto tax.”
- Testnet mocks generally have **no economic substance** (no real Paxos, no real stock) — still don’t give a legal conclusion.
- Always: **not tax advice; talk to a qualified adviser where you are; keep your own records (tx hashes, timestamps, fiat values).**

### 22.1 Protocol facts a tax analysis usually cares about

These are **how the software works**, not a tax ruling:

- Deposit: tokens move into `PledgeVaultManager`; the position is still keyed to **your** address until withdraw or liquidation.
- Borrow: you receive USDG; debt is recorded. Pledge does **not** mint USDG.
- Repay: you return USDG (principal + accrued interest).
- Liquidation (HF < 1): a third party pays the USDG debt and receives collateral (+ bonus). You may keep leftover collateral.
- Stability Pool / staking: separate from the borrow inventory.

Whether a tax authority treats deposit as a **disposal** often turns on **beneficial ownership** — a legal/tax facts question. The AI must **not** decide it.

### 22.2 Pattern seen in several systems (not your return)

Across **many** (not all) income-tax systems, commentators and some manuals draw this **economic** split:

| Event | Often discussed as… |
|---|---|
| Borrow USDG while you still own the collateral | **Not** the same as selling the shares (loan proceeds usually aren’t “income” just because you borrowed) |
| Repay and withdraw the same tokens | Often **not** a sale of the shares if ownership never left you |
| **Liquidation** of collateral | Often treated like a **disposal/sale** of the seized tokens, even if you didn’t click “sell” |
| Interest you **pay** | Sometimes non-deductible personal interest; sometimes deductible if rules for investment interest are met — **jurisdiction-specific** |
| Interest / rewards you **earn** (pool, staking) | Often **income** when received, if your country taxes that |

This table is a **map of common analysis**, not a promise that your country uses it.

### 22.3 United States (federal) — what is actually published

**Cited**

- IRS [Notice 2014-21](https://www.irs.gov/pub/irs-drop/n-14-21.pdf) (16 Apr 2014): convertible **virtual currency** is **property**; sale or exchange can be a taxable gain or loss. Scope is convertible virtual currency. It does **not** mention Pledge, DeFi CDPs, or tokenized stocks.
- IRS [digital asset FAQs](https://www.irs.gov/individuals/international-taxpayers/frequently-asked-questions-on-digital-asset-transactions): digital assets are **property**; general property principles apply. Broker information-reporting (including Form 1099-DA for some brokers) has been expanding. That does **not** make Pledge a broker, and it also does **not** mean users have nothing to report.

**What is *not* an IRS Pledge ruling**

No located IRS notice says “depositing tokenized Apple shares into a smart-contract vault is / is not a taxable event.” US writers often **analogize** crypto-backed loans to ordinary collateralized loans: **borrowing is generally not a sale**; **forced liquidation generally is** a disposition (gain/loss vs basis). That analogy is **commentary**, not a Pledge-specific regulation.

**Extra caution:** Notice 2014-21 is about **virtual currency**. Mainnet collateral is **tokenized equity**. Equities can follow **securities** tax principles instead of, or in addition to, digital-asset FAQs. Do not say “Notice 2014-21 means your stock loan is tax-free.”

Interest you pay: US personal-interest deductibility is limited. **Do not tell a user they can deduct Pledge interest.**

### 22.4 United Kingdom — what HMRC / HMT actually published

**Current HMRC manual (guidance, not a Pledge ruling)**

[CRYPTO61640](https://www.gov.uk/hmrc-internal-manuals/cryptoassets-manual/crypto61640) — DeFi collateral, chargeable gains:

- Whether **posting collateral** is a CGT disposal depends on whether **beneficial ownership** passed (look at what the platform can do with the tokens).
- If the borrower **kept** beneficial ownership: withdrawing collateral has no CG; **liquidation** is treated as the **borrower’s** disposal at **sterling market value** (nominee analysis under TCGA 1992 s.26). Example computation: [CRYPTO61675](https://www.gov.uk/hmrc-internal-manuals/cryptoassets-manual/crypto61675).
- If beneficial ownership **already passed** on deposit: that deposit was the disposal; later liquidation may have **no further** CG (already disposed).
- Extra collateral taken as a **penalty/bonus** is described as **not** an allowable deduction under TCGA s.38.

The AI must **not** decide whether Pledge’s vault transferred beneficial ownership. That is a UK legal/tax facts question.

**Draft law — not current law, and likely a poor fit for tokenized stocks**

HMRC/HMT [policy paper](https://www.gov.uk/government/publications/cryptoasset-loans-and-liquidity-pools/tax-treatment-of-cryptoasset-loans-and-liquidity-pools) (published **13 July 2026**): proposed **no gain / no loss** treatment for certain cryptoasset loans and liquidity pools, **operative from 6 April 2027**. Draft clauses: [accessible draft](https://www.gov.uk/government/publications/cryptoasset-loans-and-liquidity-pools/draft-legislation-accessible-version).

Until that is enacted and in force, **do not apply it**. Even after 6 April 2027, the draft defines a **qualifying cryptoasset** as **neither a security nor a tokenised asset** (a cryptoasset that represents a right in respect of another asset, with limited exceptions). **Tokenized equities are the kind of asset that draft is written to exclude.** Do not tell a UK user “from April 2027 your Pledge stock vault is NGNL.”

### 22.5 Singapore — what IRAS actually published

**Income tax / CGT**

- IRAS [gains from sale of property, shares and financial instruments](https://www.iras.gov.sg/taxes/individual-income-tax/basics-of-individual-income-tax/what-is-taxable-what-is-not/gains-from-sale-of-property-shares-and-financial-instruments): profits or losses from buying and selling shares or other financial instruments **(including digital tokens)** are **generally viewed as personal investments** (typically not taxable). Trading-like activity can still be income — facts and circumstances.
- IRAS e-Tax Guide [Income Tax Treatment of Digital Tokens](https://www.iras.gov.sg/docs/default-source/e-tax/etaxguide_cit_income-tax-treatment-of-digital-tokens_091020.pdf) (9 Oct 2020): treatment follows **payment / utility / security** token character. **Security-token** returns depend on their nature (interest, dividend, or other distributions). **No located IRAS circular** that analyses a Robinhood-Chain equity CDP like Pledge.
- IRAS [corporate page on digital tokens](https://www.iras.gov.sg/taxes/corporate-income-tax/income-deductions-for-companies/taxable-non-taxable-income): businesses trading tokens are taxed on profits; long-term investment **capital** gains are generally not taxed because Singapore has **no general CGT**. Capital vs revenue is case-specific.

**GST (business GST — not “users pay no income tax”)**

IRAS [Digital payment tokens](https://www.iras.gov.sg/taxes/goods-services-tax-(gst)/specific-business-sectors/digital-payment-tokens): from **1 Jan 2020**, supplies of **digital payment tokens** that meet IRAS’s tests (including **not pegged by its issuer to any currency**) can be GST-exempt (exchange; **loans of DPTs**). Tokenized stocks are **not** Bitcoin-style DPTs. **USDG is issuer-pegged to USD**, so it likely **fails** the “not pegged to any currency” DPT test. Do **not** tell a user “your Pledge loan is GST-exempt.”

### 22.6 Everyone else (EU, etc.)

- **Tax is national.** EU **MiCA** is market regulation, **not** a personal tax code.
- Germany, France, UAE, Indonesia, etc.: **do not invent rates or “no tax” slogans.**
- Same instruction: protocol facts, local counsel, keep records.

### 22.7 Practical record-keeping (non-advice)

Users who care about tax typically... (3 KB left)