# cursor-gustop.md — Pledge Finance: Full Project & Smart Contract Audit Briefing

> **For:** Gustop (smart contract auditor) 
> **From:** Pledge team 
> **Date:** 2026-09-06 
> **How to use:** keep this file at the repo root. In your Cursor, open the repo and prompt: *"Read `cursor-gustop.md` and `AGENTS.md` before answering anything."*

This is the only file you need to start. It covers **what the product is, why it exists, where it is going**, then the architecture, the math, every contract, the issues we already know about, the current on-chain state, and what we hope to get back from you.

If this file conflicts with the code → **the code wins**. Canonical mainnet addresses are in [`deployments/4663.json`](deployments/4663.json). Solidity in **this** repo lives at `src/` (not a nested `contracts/` tree). The live vault is `0x0dfd39ff00aFa2283A8c37770dB972aeC08AaB62` — do **not** treat `0x1757…` as canonical.

---

# PART I — THE PRODUCT

## 1. What Pledge is, in one paragraph

**Pledge Finance** is an **overcollateralized CDP protocol on Robinhood Chain**. A user locks **tokenized equity or ETFs** (NVDA, AAPL, SPY, …) into an isolated vault and borrows **USDG that already exists** in the vault's inventory.

Pledge is **not** a stablecoin minter. On mainnet, USDG is **Paxos USDG**. On testnet it is a mock ERC-20. We never create dollars; we lend dollars someone already put in the vault.

Loans are **perpetual**: no maturity date, no monthly bill. Interest is a **time-based stability fee APR**, paid **at repayment**, and shown to the user as a receipt (principal, time borrowed, interest, total due). Liquidation happens **only when the health factor drops below 1**. A rising share price **does not** raise the borrow APR — the upside stays with the user.

Pledge is not a broker, not a bank, not a pawn shop, not a term lender. Each vault is **isolated: one user × one collateral × one USDG debt**. There is no cross-margin and no global debt pool.

## 2. The problem we're solving (why this exists)

Someone holds $50k of NVDA. They need $20k of liquidity for six months. Their options today:

| Option | What it costs them |
|---|---|
| Sell the shares | Loses the position. If NVDA doubles, they lose that upside permanently. Plus a taxable event in most jurisdictions. |
| Broker margin loan | Available, but it's a margin *account*: the broker can force-liquidate on their terms, rates move, and it's tied to one institution. |
| Personal loan | Credit check, income docs, fixed term, monthly payments, and it doesn't use the asset they already own. |

Pledge's answer: **keep the shares, borrow against them, pay interest only for the time you actually borrow, and never get called on a healthy position.**

The product promise, in the user's words: *"I didn't sell. My shares are still mine. I have cash. Nobody can take my shares as long as I stay overcollateralized."*

This is only possible now because equities are being tokenized on-chain. Robinhood Chain is where those tokens live, which is why Pledge lives there.

## 3. The five protected narrative statements

These are not marketing lines. They are **design constraints**, and they determine what counts as a bug in the audit.

1. The user **does not sell**. Shares are locked in the vault; they are still the user's position.
2. **No term, no maturity.** They can hold the loan for years.
3. **No seizure of a healthy vault** (HF ≥ 1). The platform is not a collections desk.
4. Interest **follows time**, and is paid **at repayment** — not invoiced monthly.
5. The stock pumping **improves** the health factor. The APR **does not** follow the pump.

### Permanently rejected (do not recommend these, even if they are "industry standard")

- Seizure because N months elapsed / anything term-loan shaped
- Mandatory monthly USDG payments
- APR that tracks the stock price or its volatility
- A contract named **`RiskEngine`** — rejected for narrative reasons, not technical ones. It sounds like a credit desk deciding whether you deserve money. Risk in Pledge is just: LTV/liquidation ratio per stock, HF, oracle staleness, and how much USDG we seeded.
- Pledge minting its own USDG
- A second worthless governance token
- Claiming "audited" / "licensed lender" / "legal in your country" / "tax = 0" in any copy

### What this means for your audit

If you find *"there is no mechanism to force a user to pay"* — that's a **feature**, not a finding. The actual bugs are the inverse:

- A **healthy** vault can lose its collateral → **critical**
- An **unhealthy** vault cannot be liquidated → **critical**
- Interest can be avoided, or charged where it shouldn't be → **high**
- A price increase makes the user's position worse → **critical** (breaks statement 5)

## 4. How Pledge makes money

Two revenue lines, both on-chain, both simple:

| Line | Mechanism | Where it lands today |
|---|---|---|
| **Origination fee** | Charged once at `borrow`. Deducted from the payout; the recorded debt is the **gross** amount. | `PledgeSurplusBuffer` — transferred directly in `borrow()` |
| **Stability fee (interest)** | Time-based APR, accrues on the debt, collected when the user repays | **Stays in the vault's USDG inventory** — never swept to the surplus buffer |

That asymmetry is worth your attention (see §11 and K-9). Interest revenue is currently indistinguishable from lendable principal sitting in the vault.

There is **no** protocol revenue from liquidations (the bonus goes entirely to the liquidator), and **no** revenue from the stability pool.

## 5. Where the project is going (direction)

This matters for the audit because we're asking you to review code we're about to change.

### 5.1 Right now — get one real loan to work on mainnet

Mainnet is currently an address with **zero USDG inventory**. The honest status sentence we use internally and externally is: *"vault staged on 4663, not public-ready."* Before anything else:

1. Oracle at `0x195287cbcd53eF058a3DeC4c6DC8f17Bf79A28d9` is **`PledgeChainlinkOracle`** (manifest + `AUDIT.md`). Default `maxStaleness` in code is 24h; mainnet is **4 days** (`345600`)
2. Seed a **small** amount of 6-decimal USDG into the vault proxy **`0x0dfd39…`**
3. Run the four-step smoke test ourselves: deposit → borrow → `getRepayBreakdown` → repay → withdraw
4. If any step fails, stop and fix

### 5.2 Next — one vault upgrade, before anyone else deposits

We want **one** `upgradeToAndCall` on proxy **`0x0dfd39…`**, not `0x1757…`. The implementation in this repo already contains:

- **Pause fix (K-1):** `active=false` blocks only `deposit`/`borrow`; repay/withdraw/liquidate stay open
- **`setMarketParams` (K-3)** with bounds, events, and non-retroactive APR checkpoints
- **K-10:** `lastAccrual` is not reset when truncated interest is 0
- **K-2 Option B:** the stability pool is USDG parking; `payDebt` reverts and is **not** wired into `liquidate`

Do not broadcast to chain 4663 unless we ask.

### 5.3 Then — app, then a soft open

Point the hosted app at chain 4663, verify the 6-decimal paths end to end in a browser, strip the marketing copy that promises things the contracts don't do (debt ceilings, market close, pool backstop). Then open with a **small** inventory and a liquidator wallet that we fund ourselves, because there is no liquidation bot.

### 5.4 Later — the actual roadmap

| Direction | What it means | Why |
|---|---|---|
| More markets | **8 markets already live** (NVDA, SPY, AAPL, QQQ, MSFT, AMZN, META, GOOGL). Add further names only after the feed is verified | Every market is a new oracle trust assumption |
| Raise APR parameters when float is thin | Same mechanism, different number | Rationing scarce inventory by price, not by rejecting users |
| **LP / PSM** so USDG doesn't only come from treasury | Third parties supply the lendable USDG | Treasury-funded inventory doesn't scale |
| **PLG → vePLG** lock + timelock governance | Real governance over parameters | Single-EOA ownership is the biggest risk in the system |
| **Multisig owner** before meaningful TVL | Removes the single-key failure mode | See §12 |

**What we are deliberately *not* becoming:** an Aave-style supply/borrow market with pooled lenders, a bank, a broker, or anything with credit underwriting. If a recommendation of yours implies one of those, flag it but give us an alternative that fits §3.

### 5.5 Explicitly not now

Governance contracts, PSM, mainnet staking, a production bridge, an on-chain debt ceiling, automated market-hours pausing, token buybacks, and any promise of dates, audits, or yield.

## 6. Build history (how we got here)

Useful context for judging code maturity.

### Testnet phase — the core actually works

The CDP was written in Foundry (`src/` at the repo root): vault, surplus buffer, stability pool, oracle, staking, a test bridge, mock ERC-20s, mock price feeds. This checkout does **not** contain `web/`, `AGENTS.md`, or `docs/product.md` — use [`AUDIT.md`](AUDIT.md) and [`MAINNET_SCRIPT_AUDIT.md`](MAINNET_SCRIPT_AUDIT.md) for operational notes.

The credit narrative was locked into `docs/product.md` and `.cursor/rules/credit-policy.mdc` during this phase — perpetual, receipt-style repayment, HF-only liquidation. Governance and PSM exist **only as preview UI**; there is no Governor and no PSM contract. The bridge is an EIP-712 attestation flow on the RH testnet, **not** a production bridge.

### Mainnet phase (chain 4663) — harder than expected

Mock USDG was replaced with **Paxos USDG at 6 decimals**, and the app learned to read `usdgDecimals` from its deployment manifest instead of assuming 18. Collateral became real chain stock tokens.

The **first** mainnet vault (`0xf486…`) was **not** behind a proxy and had **no `withdrawLiquidity`**. About **10 USDG is permanently stuck** in it. We paused its market after draining what we could. We are not going to try to recover it, and it must never be treated as the live vault again.

That mistake produced the standing rule: **every protocol deploy must be an ERC1967 proxy** (`.cursor/rules/proxy-deploys.mdc`). All protocol contracts were converted to UUPS via `PledgeUupsOwnable`.

Deploying on 4663 was genuinely difficult — gas estimation, `maxFeePerGas`, and a single `--gas-limit` blocking subsequent transactions. We had to split deployment into `DeployVaultImplMainnet` → `DeployVaultProxyMainnet` → `ConfigureProxiedVaultMainnet`.

Canonical live vault (this repo): proxy **`0x0dfd39ff00aFa2283A8c37770dB972aeC08AaB62`**. **Eight** markets are registered (NVDA, SPY, AAPL, QQQ, MSFT, AMZN, META, GOOGL). Scripts call `registerMarket(..., 500, 120, 50)` which is **`liqBonusBps=500` (5%), `stabilityFeeAprBps=120` (1.2%), `originationFeeBps=50` (0.5%)** — not the reverse. Oracle is `PledgeChainlinkOracle` at `0x195287cb…`. Surplus buffer and stability pool remain the old unproxied contracts.

`0x1757a7BD9078001adD29d98Ba712DA7ba154C1AE` is hardcoded in `script/ConfigureProxiedVaultMainnet.s.sol`; [`MAINNET_SCRIPT_AUDIT.md`](MAINNET_SCRIPT_AUDIT.md) marks that script **unsafe**. Do not upgrade or seed `0x1757…`.

Verification note: Blockscout's API on this chain sits behind Cloudflare, so `forge verify-contract` fails against it. We verified via **Sourcify** instead (exact match).

### Deliberately not built yet

Mainnet staking, bridge, governance, PSM. Audit. Multisig. Repo CI. Wiring the pool into liquidation (K-2 chose **not** to — it is parking only).

---

# PART II — THE AUDIT

## 7. TL;DR for the auditor

| | |
|---|---|
| Chain | Robinhood Chain **mainnet 4663** (staged), **testnet 46630** (public testers) |
| Framework | Foundry, `solc 0.8.24`, optimizer 200 runs, `via_ir = false`, OpenZeppelin **5.0.2** (vendored in `lib/`) |
| Upgradeability | **UUPS** / ERC1967 proxy for all protocol contracts. Owner = **one EOA**, no timelock |
| Core in scope | `PledgeVaultManager`, `VaultMath`, `PledgeUupsOwnable`, `PledgeOracle`, `PledgeChainlinkOracle`, `PledgeSurplusBuffer`, `PledgeStabilityPool` |
| Core size | ~900 lines of Solidity total. Small enough to read in a day |
| Live vault | proxy `0x0dfd39ff00aFa2283A8c37770dB972aeC08AaB62` (canonical). Do **not** use `0x1757…` |
| USDG inventory in vault | **0** — `borrow` reverts with `InsufficientLiquidity` |
| What worries us most | (1) upgrade/storage layout on the next `upgradeToAndCall`, (2) the blanket trust in `getPrice` returning 18 decimals, (3) single-EOA owner |

### Hard rules while auditing

1. **Never broadcast a transaction to mainnet 4663.** Fork tests and dry runs only. Broadcasting happens only if we ask explicitly.
2. **Never commit `.env`** or any private key. That file has real contents on our machines; you don't need it.
3. Audit from the repo root (`src/`, `test/`, `script/`). There is no `contracts/` or `contracts-github/` folder here.
4. Don't propose anything that breaks §3. If a finding's natural fix is "add a term and seize", write the finding, then give us an alternative that fits.

## 8. Setup, ten minutes

```bash
git clone <repo> && cd pladge-smartcontract

# Solidity — lib/ is vendored (OZ 5.0.2 + forge-std), no forge install needed
forge build
forge test -vv          # must be green before you start
```

Cursor rules that auto-load (read them so you know the team's constraints):

- `.cursor/rules/pledge-context.mdc` → pointer to `AGENTS.md`
- `.cursor/rules/credit-policy.mdc` → perpetual, HF-only, time-based APR
- `.cursor/rules/proxy-deploys.mdc` → every protocol deploy is an ERC1967 proxy
- `.cursor/rules/pledge-ui.mdc` → the `/borrow/*` design system

Companion documents:

| File | Contents |
|---|---|
[`AUDIT.md`](AUDIT.md) | Mainnet audit scope |
[`MAINNET_SCRIPT_AUDIT.md`](MAINNET_SCRIPT_AUDIT.md) | Which scripts are safe vs unsafe on 4663 |
[`deployments/4663.json`](deployments/4663.json) | Canonical live addresses and 8 markets |
[`README.md`](README.md) | Integrator-facing architecture and parameters |

## 9. Architecture and money flow

### 9.1 Two USDG pots — never conflate them

| Pot | Contract | Role |
|---|---|---|
| **Vault inventory** | `PledgeVaultManager` | **The only source of borrowable USDG.** Filled by `fundLiquidity` (treasury) and by user repayments |
| **Stability pool** | `PledgeStabilityPool` | **USDG parking only.** Not a liquidation backstop. `payDebt` reverts (`PayDebtUnimplemented`) |

`PledgeVaultManager.liquidate()` pulls USDG from the **liquidator's wallet**. Do not wire `payDebt` until offset accounting exists (K-2 Option B).

If the vault inventory is empty, `borrow` reverts. Existing loans are **not** force-closed, and an empty pool does **not** block borrowing.

### 9.2 User flow

```
deposit(collateral, amt)        equity token → vault
borrow(collateral, amt)         debt += amt (GROSS)
                                user receives amt − originationFee
                                fee → PledgeSurplusBuffer
repay(collateral, amt)          interest first, then principal
                                USDG returns to inventory
withdraw(collateral, amt)       allowed while HF stays ≥ 1
liquidate(user, collateral)     only when HF < 1; liquidator pays the FULL
                                debt from their own wallet, receives
                                collateral + bonus
```

Holding longer means more interest. That is the **only** pressure on a healthy vault. Not seizure.

### 9.3 Fee routing (note the asymmetry)

- **Origination fee** → `usdg.safeTransfer(address(surplusBuffer), fee)` inside `borrow()`. A plain transfer, **not** `surplusBuffer.receiveFee()`, so the `FeeReceived` event **never fires** in production.
- **Stability fee (interest)** → repaid into the vault and **left in inventory**, never swept to the surplus buffer. The owner would have to call `withdrawLiquidity` manually, and there is no way to distinguish interest revenue from lendable principal.

Intentional or not? **We want your opinion.** Revenue and inventory accounting are not separated today.

## 10. File map (in scope vs out of scope)

```
src/
  core/
    PledgeVaultManager.sol      ← THE CORE. priority #1
    PledgeSurplusBuffer.sol     ← fee treasury
    PledgeStabilityPool.sol     ← USDG parking (not a backstop; payDebt reverts)
    PledgeStaking.sol           ← testnet only (OUT of mainnet scope)
    PledgeTestnetBridge.sol     ← testnet only (OUT of mainnet scope)
  oracle/
    PledgeOracle.sol            ← manual prices, owner setPrice (testnet)
    PledgeChainlinkOracle.sol   ← production AggregatorV3 adapter
  libraries/
    VaultMath.sol               ← ALL the math. priority #2
  upgrade/
    PledgeUupsOwnable.sol       ← owner + _authorizeUpgrade. priority #3
  interfaces/IOracle.sol
  mocks/                        ← MockERC20, MockChainlinkFeed, TestnetEthFaucet (OUT)
  PledgeProtocol.sol            ← string constants only
script/                         ← deploy/ops scripts. review the *Mainnet*.s.sol ones
test/                           ← Foundry tests
lib/                            ← OZ 5.0.2 + forge-std (vendored, tracked in git)
deployments/4663.json           ← canonical mainnet manifest
```

### Priorities we're asking for

| Priority | Target | Why |
|---|---|---|
| **P0** | `PledgeVaultManager.sol` + `VaultMath.sol` | All user money flows through here |
| **P0** | `PledgeUupsOwnable.sol` + storage layout for the next upgrade | We are about to `upgradeToAndCall` on a live proxy |
| **P1** | `PledgeOracle` / `PledgeChainlinkOracle` | The vault trusts `getPrice` completely |
| **P1** | `PledgeSurplusBuffer`, `PledgeStabilityPool` | Treasury and depositor funds |
| **P1** | Behavior at **6-decimal** USDG (mainnet) vs 18 (testnet) | Rounding and truncation |
| **P2** | `script/*Mainnet.s.sol` | A wrong parameter is permanent — there is no setter yet |
| **Out** | Staking, bridge, faucet, mocks | Testnet-only, never going to 4663 |

## 11. `PledgeVaultManager` — full walkthrough

Path: `src/core/PledgeVaultManager.sol`. Inherits `PledgeUupsOwnable` and `ReentrancyGuard`.

### 11.1 Immutables and storage

```39:50:src/core/PledgeVaultManager.sol
    IERC20 public immutable usdg;
    uint8 public immutable usdgDecimals;
    PledgeSurplusBuffer public immutable surplusBuffer;

    mapping(address collateral => Market) public markets;
    mapping(address collateral => mapping(address user => Position)) public positions;
    /// @dev Borrowed principal still outstanding (excludes accrued stability fee).
    mapping(address collateral => mapping(address user => uint256)) public principalDebt;
    /// @dev First borrow timestamp for the current debt cycle; 0 when fully repaid.
    mapping(address collateral => mapping(address user => uint256)) public debtOpenedAt;

    address[] public marketList;
```

Important: `usdg`, `usdgDecimals`, and `surplusBuffer` are **immutable**, so they live in the implementation bytecode, **not** in proxy storage. Replacing the surplus buffer therefore requires a **new implementation plus an upgrade**, not a setter. And `usdgDecimals` is read via `_decimals(usdg_)` **in the implementation's constructor**, which means the implementation must be deployed with the correct USDG address for its chain.

The `Market` struct:

```22:31:src/core/PledgeVaultManager.sol
    struct Market {
        address collateral;
        address oracle;
        uint16 maxLtvBps;
        uint16 liqRatioBps;
        uint16 liqBonusBps;
        uint16 stabilityFeeAprBps;
        uint16 originationFeeBps;
        bool active;
    }
```

### 11.2 Functions and access control

| Function | Access | Guards | Notes |
|---|---|---|---|
| `registerMarket` | `onlyOwner` | — | Bounds via `_validateMarketParams` |
| `setMarketActive` | `onlyOwner` | — | `active=false` blocks **only** deposit/borrow (K-1 fixed in this tree) |
| `setMarketOracle` | `onlyOwner` | — | Owner can swap the oracle at any time |
| `setMarketParams` | `onlyOwner` | — | LTV/liq/fees; APR change is checkpointed (not retroactive) |
| `fundLiquidity` | **public** | `nonReentrant` | Anyone may seed. No `amount != 0` check |
| `withdrawLiquidity` | `onlyOwner` | `nonReentrant` | Owner can pull the **entire** USDG inventory |
| `deposit` | public | `nonReentrant`, `_requireActiveMarket` | |
| `withdraw` | public | `nonReentrant`, `_requireKnownMarket`, `_requireHealthy` | Works on a paused market |
| `borrow` | public | `nonReentrant`, `_requireActiveMarket`, LTV, liquidity | |
| `repay` | public | `nonReentrant`, `_requireKnownMarket` | Works on a paused market |
| `liquidate` | public | `nonReentrant`, `_requireKnownMarket`, `HF < 1`, anti-self-liq | Full debt only, no partial; works on a paused market |

Views: `getHealthFactor`, `getBorrowable`, `getMarketCount`, `getRepayBreakdown`.

### 11.3 `borrow` — watch the ordering of checks

```187:219:src/core/PledgeVaultManager.sol
    function borrow(address collateral, uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        Market memory market = _requireActiveMarket(collateral);

        Position storage pos = positions[collateral][msg.sender];
        _accrue(pos, market.stabilityFeeAprBps);

        uint256 fee = (amount * market.originationFeeBps) / VaultMath.BPS;
        uint256 payout = amount - fee;
        require(payout > 0, "fee exceeds amount");

        uint256 newDebt = pos.debt + amount;
        uint256 collateralUsd = _collateralUsd(pos.collateral, collateral, market.oracle);
        uint256 newDebtUsd = VaultMath.toUsdScale(newDebt, usdgDecimals);
        if (newDebtUsd > VaultMath.maxDebt(collateralUsd, market.maxLtvBps)) revert ExceedsMaxLtv();
        if (usdg.balanceOf(address(this)) < amount) revert InsufficientLiquidity();
        // ... principal / debtOpenedAt bookkeeping ...
        usdg.safeTransfer(msg.sender, payout);
        if (fee > 0) usdg.safeTransfer(address(surplusBuffer), fee);
        emit Borrowed(msg.sender, collateral, payout, fee);
    }
```

Please verify:

- **Recorded debt is the gross `amount`** while the user only receives `amount − fee`. That's intentional (the fee is the cost of opening the loan) and the LTV check uses the gross amount. Confirm there is no path where a user's payout can exceed their recorded debt.
- The liquidity check uses `amount` (gross) while the transfers out total `payout + fee = amount`. Consistent — but `balanceOf(address(this))` also counts USDG that is economically **protocol interest revenue**. There's no segregation.
- `emit Borrowed(..., payout, fee)` reports the **payout**, not the debt increase. Indexers and the frontend could compute total debt incorrectly from events. Cross-check `web/src/lib/indexer/`.

### 11.4 `repay` and `_applyPrincipalRepay` — the subtlest logic

```335:356:src/core/PledgeVaultManager.sol
    function _applyPrincipalRepay(
        address collateral,
        address user,
        Position storage pos,
        uint256 repayAmount
    ) internal {
        uint256 prin = principalDebt[collateral][user];
        if (prin == 0) prin = pos.debt;
        if (prin > pos.debt) prin = pos.debt;

        uint256 interestOwed = pos.debt - prin;
        uint256 fromPrincipal = repayAmount > interestOwed ? repayAmount - interestOwed : 0;
        if (fromPrincipal > prin) fromPrincipal = prin;

        pos.debt -= repayAmount;
        if (pos.debt == 0) {
            principalDebt[collateral][user] = 0;
            debtOpenedAt[collateral][user] = 0;
        } else {
            principalDebt[collateral][user] = prin - fromPrincipal;
        }
    }
```

Specific things to check:

- Is the invariant `principalDebt ≤ pos.debt` actually preserved across **every** path — repeated `borrow`, many partial repayments, after a large `_accrue`, after `liquidate`?
- The `prin == 0` fallback treats the whole position as principal. That covers legacy positions from before this bookkeeping existed — but can it be used to **reset** accrued interest?
- `pos.debt -= repayAmount` relies on the caller clamping (`amount > pos.debt ? pos.debt : amount`). Confirm no underflow path.
- Can accrued interest be "lost" if a user partially repays and then borrows again, given that `principalDebt += amount` while the interest component is already folded into `pos.debt`?

### 11.5 `liquidate` — full debt, no partial

```236:265:src/core/PledgeVaultManager.sol
    function liquidate(address user, address collateral) external nonReentrant {
        if (msg.sender == user) revert SelfLiquidationNotAllowed();
        Market memory market = _requireActiveMarket(collateral);
        Position storage pos = positions[collateral][user];
        _accrue(pos, market.stabilityFeeAprBps);

        uint256 collateralUsd = _collateralUsd(pos.collateral, collateral, market.oracle);
        uint256 debtUsd = VaultMath.toUsdScale(pos.debt, usdgDecimals);
        uint256 hf = VaultMath.healthFactor(collateralUsd, debtUsd, market.liqRatioBps);
        if (hf >= HF_WAD) revert NotLiquidatable();

        uint256 debt = pos.debt;
        uint256 price = IOracle(market.oracle).getPrice(collateral);
        uint8 decimals = _decimals(collateral);

        uint256 collateralToSeize =
            (debtUsd * (VaultMath.BPS + market.liqBonusBps) * (10 ** uint256(decimals))) / (price * VaultMath.BPS);
        if (collateralToSeize > pos.collateral) collateralToSeize = pos.collateral;

        pos.debt = 0;
        principalDebt[collateral][user] = 0;
        debtOpenedAt[collateral][user] = 0;
        pos.collateral -= collateralToSeize;

        usdg.safeTransferFrom(msg.sender, address(this), debt);
        IERC20(collateral).safeTransfer(msg.sender, collateralToSeize);
        emit Liquidated(user, msg.sender, collateral, debt, collateralToSeize);
    }
```

What we know and want you to quantify:

- **No partial liquidation.** The liquidator must hold USDG equal to the **full debt**. Large positions may have no one able to liquidate them, so bad debt persists. There is no liquidation bot.
- If `collateralToSeize` is **capped** at `pos.collateral`, the liquidator still pays the full debt but receives less collateral, so the rational choice is **not** to liquidate — and the insolvent position stays open. Please compute the price at which liquidation stops being profitable. Mainnet `liqBonusBps` is **500 (5%)** (see K-4/K-5 correction).
- `getPrice` is called **twice** (once inside `_collateralUsd`, once directly). Chainlink can't change mid-transaction, but the manual `PledgeOracle` can be updated by the owner — is there an inconsistency window?
- After liquidation, **leftover collateral remains in the user's position**. Confirm the user can still `withdraw` it (debt is 0, so HF is `max`).
- `_accrue` before the HF check means interest alone can push a position under HF 1 with no price movement. That is **intentional** (interest is the only pressure). Confirm interest can't be applied twice in one transaction.

### 11.6 `_accrue` — the finding we suspect most

```328:332:src/core/PledgeVaultManager.sol
    function _accrue(Position storage pos, uint16 stabilityFeeAprBps) internal {
        uint256 interest = VaultMath.accrueInterest(pos.debt, stabilityFeeAprBps, pos.lastAccrual);
        if (interest > 0) pos.debt += interest;
        pos.lastAccrual = block.timestamp;
    }
```

`lastAccrual` was reset **unconditionally**, including when `interest == 0` due to truncation. **Fixed in this tree:** `_accrue` returns without updating `lastAccrual` when `interest == 0` (debt=0 still stamps the clock). Covered by `test_sixDecimalUsdgGrindDoesNotResetLastAccrual`.

The math at **6-decimal** USDG (mainnet) with a 120 bps APR:

```
interest = debt * 120 * elapsed / (365 days * 10_000)
         = debt * 120 * elapsed / 3.1536e11

interest > 0  ⟺  elapsed > 3.1536e11 / (debt * 120)
```

- debt = 2 USDG (`2_000_000` units) → `elapsed > ~1314 s` (≈ 22 minutes)
- debt = 100 USDG (`100_000_000` units) → `elapsed > ~26 s`
- debt = 10,000 USDG → `elapsed > ~0.26 s` (so every block already accrues)

Meaning: a user can call **any function that triggers `_accrue`** (e.g. `deposit(1 wei)`) just before the threshold, reset `lastAccrual`, and pay **zero interest indefinitely**. Economically viable for small positions on a cheap-gas chain.

Please confirm it, compute the break-even gas threshold, and propose a fix that doesn't violate §3. Candidates: store an `accruedRemainder`, or simply don't update `lastAccrual` when `interest == 0`.

Note that the suite now has 6-decimal borrow, liquidation, and grind tests. Default happy paths still use 18-decimal mock USDG.

### 11.7 `_decimals` via `staticcall`

```374:378:src/core/PledgeVaultManager.sol
    function _decimals(address token) internal view returns (uint8) {
        (bool ok, bytes memory data) = token.staticcall(abi.encodeWithSignature("decimals()"));
        require(ok && data.length >= 32, "decimals");
        return abi.decode(data, (uint8));
    }
```

Called from `_collateralUsd` on every deposit/withdraw/borrow/repay/liquidate and on every view. Check the gas cost, tokens without `decimals()`, tokens returning a non-`uint8`, and whether caching is worthwhile.

## 12. `VaultMath` — the complete math spec

Path: `src/libraries/VaultMath.sol`. `WAD = 1e18`, `BPS = 10_000`.

| Function | Formula | Notes |
|---|---|---|
| `collateralValue(amt, priceUsd, dec)` | `amt * priceUsd / 10**dec` | `priceUsd` **must be 18 dp**. Output is USD at 18 dp |
| `toUsdScale(amt, dec)` | scale up/down to 18 dp | 6-dp USDG → `× 1e12` |
| `fromUsdScale(usd, dec)` | back to native units | **truncates** when scaling down |
| `maxDebt(collateralUsd, maxLtvBps)` | `collateralUsd * maxLtvBps / BPS` | USD at 18 dp |
| `healthFactor(cUsd, dUsd, liqRatioBps)` | `cUsd * WAD * BPS / (dUsd * liqRatioBps)` | `dUsd == 0` → `type(uint256).max` |
| `accrueInterest(debt, aprBps, lastAccrual)` | `debt * aprBps * elapsed / (365 days * BPS)` | **linear**, not compounding |

**`liqRatioBps` is not an Aave-style threshold.** It is a **minimum collateralization ratio**: `16600 = 166%`. A position is liquidatable **iff HF < 1e18**.

Worked example (good starting point for unit tests):

```
collateral: 10 NVDA @ $500 = $5,000
maxLtv 6000 (60%)  → max_debt = 3,000 USDG
liqRatio 16600

borrow 3,000 → HF = 5000e18 * 1e18 * 1e4 / (3000e18 * 16600) = 1.0040e18   → HF ≈ 1.004
price falls to $498       → HF ≈ 0.9999  → LIQUIDATABLE
```

The buffer at max LTV is only **0.4%**. That isn't a bug per se, but it means a user who borrows the maximum will be liquidatable within hours purely from interest. We'd like your opinion on whether `maxLtv` and `liqRatio` need more separation — for 60% LTV, `liqRatio` below 16666 would leave actual headroom.

Things to check in the math:

- Overflow in `collateralUsd * WAD * BPS`: needs `cUsd < ~1.16e55`. Check realistic bounds, since an 18-dp price times an 18-dp amount already gets large.
- `collateralValue` truncates down, which lowers HF and favors the protocol. Confirm rounding is **always** conservative for the protocol, in every function.
- `fromUsdScale` in `getBorrowable` truncates, so the user can't borrow the last unit. Safe — but confirm `borrow(getBorrowable())` **never** reverts with `ExceedsMaxLtv` (an off-by-one UX bug).
- Interest is linear per touch: a long idle window is applied in one shot, with no compounding. Confirm no path folds interest into `principalDebt`, which would be hidden compounding.

## 13. The oracle — a total trust dependency

The vault **always** calls `IOracle(market.oracle).getPrice(collateral)` and expects **USD at 18 decimals**. Stale prices revert with `"ORACLE: stale"` (default `maxStaleness = 24 hours`).

Two implementations exist:

**`PledgeOracle`** (manual) — `prices[asset]` plus `updatedAt[asset]`, with `setPrice` gated by `onlyOwner`. The owner has full control over prices, so the owner can make any position liquidatable, or prevent liquidation. This is the single largest centralization risk in the system; please assign it a severity you consider fair.

**`PledgeChainlinkOracle`** (an `AggregatorV3Interface` adapter) — `feeds[asset]`, normalizes `feedDecimals` to 18 dp, requires `answer > 0` and `block.timestamp - feedUpdatedAt <= maxStaleness`.

To check:

- `latestRoundData` is used without checking `answeredInRound >= roundId`. Does it matter here?
- `maxStaleness` of **24 hours** for equities whose market closes on weekends: is 24h too loose (Friday's price used Monday morning) or too tight (a feed that stops updating over the weekend freezes the whole vault, including repay and withdraw)? This is a genuine open design question for us.
- `getPrice` makes **two** external calls (`latestRoundData()` and `decimals()`) — a malicious or upgradeable feed is a manipulation vector.
- `setMaxStaleness` has no bounds. The owner can set 100 years (stale prices treated as fresh) or 0 (everything frozen).
- There is **no circuit breaker** for extreme price jumps. That's deliberate (we rejected a "RiskEngine"), but please document the consequence.

**Operational fact:** the mainnet oracle at `0x195287cbcd53eF058a3DeC4c6DC8f17Bf79A28d9` **is** `PledgeChainlinkOracle` (`deployments/4663.json`, `AUDIT.md`). `maxStaleness` on mainnet is **4 days** (`345600`). Do not wire the manual `PledgeOracle` on 4663.

Testnet has a different problem: the UI reads a **mock Chainlink feed** while the vault reads **`PledgeOracle` storage**. If the operator forgets to sync (`SyncTestnetOracleFromFeeds.s.sol`), the UI shows price A and transactions fail against price B.

## 14. Upgradeability — where we most need your eyes

`PledgeUupsOwnable` (`src/upgrade/PledgeUupsOwnable.sol`):

```9:43:src/upgrade/PledgeUupsOwnable.sol
abstract contract PledgeUupsOwnable is Initializable, UUPSUpgradeable {
    address public owner;
    // ...
    function _disableAndMaybeSetOwner(address owner_) internal {
        if (owner_ != address(0)) { owner = owner_; emit OwnershipTransferred(address(0), owner_); }
        _disableInitializers();
    }
    function _initOwner(address owner_) internal {
        if (owner_ == address(0)) revert ZeroAddress();
        owner = owner_;
        emit OwnershipTransferred(address(0), owner_);
    }
    function transferOwnership(address newOwner) external onlyOwner { /* ... */ }
    function _authorizeUpgrade(address) internal override onlyOwner {}
}
```

Please examine:

1. **Storage layout and upgrade safety.** `owner` sits at slot 0 (OZ 5's `Initializable` and `UUPSUpgradeable` use ERC-7201 namespaced storage, so they don't occupy slot 0). There is **no `uint256[50] __gap`** anywhere. We intend to add storage variables in the next upgrade (§16). Map the current layout of `PledgeVaultManager` slot by slot and give us a concrete rule for where new variables must go.
2. **The dual constructor pattern.** `_disableAndMaybeSetOwner(owner_)` sets the owner and *then* calls `_disableInitializers()`. In production `owner_ = address(0)`, so it only disables. In tests the owner is passed via the constructor. Can this produce an implementation that both has an owner and can be called directly (not through the proxy) with harmful effect? Note the `PledgeVaultManager` implementation holds `usdg`/`surplusBuffer` as immutables — if someone sends tokens to the **implementation address**, what becomes possible?
3. **`initialize` never calls `__UUPSUpgradeable_init()` or a reentrancy-guard initializer.** The non-upgradeable OZ 5 `ReentrancyGuard` is used inside upgradeable contracts, so its status lives in regular storage and starts at 0 rather than `NOT_ENTERED`. Verify that OZ 5.0.2's `ReentrancyGuard` is safe with an uninitialized slot. **We consider this high priority.**
4. **`_authorizeUpgrade` is `onlyOwner` with no timelock.** The owner is one EOA who can swap the implementation for anything and take every user's collateral. From a user's perspective this is risk #1. We know; we need a severity rating and a recommendation (multisig plus timelock) we can put in public documentation.
5. `transferOwnership` is single-step, not `Ownable2Step`. A wrong address means the protocol can never be upgraded again.
6. `PledgeChainlinkOracle` uses `constructor() { _disableInitializers(); }` while the others use `_disableAndMaybeSetOwner`. Inconsistent — check the implications.

Deployment helpers: `contracts/script/ProxyDeploy.sol`, `VaultProxyDeploy.sol`, `OracleProxyDeploy.sol`. All use `new ERC1967Proxy(impl, abi.encodeCall(X.initialize, (owner)))`.

**Actual mainnet state:** the vault and oracle sit behind proxies. The **surplus buffer and stability pool are still the old contracts and are NOT behind proxies.** And because `surplusBuffer` is `immutable` in the vault, proxying the surplus buffer requires a new vault implementation.

## 15. Trust model and privileged actions

The owner (one EOA, `0x82FB…9e92`, a Robinhood Wallet) can:

| Action | Maximum impact |
|---|---|
| `upgradeToAndCall` on the vault proxy | **Total** — take all collateral and all inventory |
| `setMarketOracle` | Point to a malicious oracle and liquidate every position |
| `PledgeOracle.setPrice` | Same, with no deployment required |
| `setMarketActive(false)` | Freeze new deposits/borrows only (K-1 fixed in this tree); repay/withdraw/liquidate remain |
| `withdrawLiquidity` | Drain the entire USDG inventory (not user collateral) |
| `PledgeSurplusBuffer.withdraw` | Take all accumulated fees |
| `PledgeStabilityPool.setVaultManager` | Point `payDebt` at a malicious contract and drain pool deposits |
| `registerMarket` | Add a fake collateral with a fake oracle and mint debt against worthless tokens |

There is no multisig, no timelock, no guardian, no global pause, no emergency shutdown, and no role separation. If the key is lost, the protocol can never be upgraded. If the key leaks, the funds are gone.

Please write a **centralization risk section we can publish**, in honest language. We'd rather disclose this plainly than dress it up.

## 16. The other contracts, briefly

**`PledgeSurplusBuffer`** — `receiveFee(amount, reason)` (public, uses `transferFrom`) plus `withdraw(to, amount)` (`onlyOwner`). No `ReentrancyGuard` (does it need one?). No internal accounting, just the token balance. The vault transfers fees directly, so `receiveFee` is unused in production.

**`PledgeStabilityPool`** — 1:1 `deposit`/`withdraw` (no shares, no yield), `totalDeposits` plus `balanceOf`. **K-2 Option B:** this is USDG parking, not a backstop. `payDebt` now reverts (`PayDebtUnimplemented`) so it cannot be wired into `liquidate` without offset accounting. A raw transfer would have left `Σ balanceOf > usdg.balanceOf(pool)`.

**`PledgeStaking`** (testnet) — MasterChef-style with `accRewardPerShare` and lock durations. `fundRewards` is public with no accounting, so rewards can be underfunded and `claim` will revert. Out of mainnet scope.

**`PledgeTestnetBridge`** (testnet) — EIP-712, but:

```186:186:src/core/PledgeTestnetBridge.sol
        if (ECDSA.recover(digest, signature) != user) revert InvalidSignature();
```

The attestation is signed **by the user themselves**, not by a relayer or validator, so there is no proof that funds ever existed on the source chain. This may **only** live on testnet. If you ever see a plan to move it to mainnet, object loudly. Out of mainnet scope, but worth recording.

**Mocks** — `MockERC20` (configurable decimals), `MockChainlinkFeed`, `TestnetEthFaucet`. Unproxied, never for mainnet.

## 17. Known issues — the team already knows these

Please don't spend audit hours rediscovering them. What we want: **confirm the severity, give a concrete exploit path, and propose a fix that respects §3.** If you disagree with our assessment, say so.

| ID | Issue | Team status |
|---|---|---|
| **K-1** | **Pause trap.** `_requireActiveMarket` used to wrap repay/withdraw/liquidate. | **Fixed in this tree:** `active=false` blocks only deposit/borrow. Not yet upgraded on-chain |
| **K-2** | **The stability pool is not a backstop.** `liquidate` pulls USDG from the liquidator's wallet. | **Option B:** parking only; `payDebt` reverts; copy updated |
| **K-3** | **No `setMarketParams`.** | **Fixed in this tree:** setter with bounds, event, APR checkpoints. Not yet upgraded on-chain |
| **K-4 / K-5** | Briefing previously swapped origination and liquidation bonus. Signature is `registerMarket(..., liqBonusBps, stabilityFeeAprBps, originationFeeBps)`. Scripts and tests use `500, 120, 50` → **bonus 5%, APR 1.2%, origination 0.5%**. Verify on-chain `markets(token)` at `0x0dfd39…` before changing fees | **Misread args — not a 5% origination typo** |
| **K-6** | **Owner is a single EOA with no timelock**, able to upgrade and to set prices. | Known. Multisig before meaningful TVL |
| **K-7** | **No storage gaps** in the upgradeable contracts. | Append-only for the next upgrade; `__gap` optional at the very end |
| **K-8** | **No partial liquidation.** Requires a liquidator holding the full debt in USDG. No bot exists. | Known; operational mitigation is a small inventory |
| **K-9** | **Interest is never swept to the surplus buffer** and mixes with inventory. The `Borrowed` event reports `payout`, not the debt increase. | We want your opinion |
| **K-10** | **`_accrue` truncation** at 6-decimal USDG with unconditional `lastAccrual` reset. | **Fixed in this tree:** do not reset `lastAccrual` when `interest == 0`. Grind test added |
| **K-11** | **Fee-on-transfer or rebasing collateral** would corrupt `pos.collateral` accounting. No check exists. | Current mitigation is owner curation of markets |
| **K-12** | `marketList` is unbounded and there is no `removeMarket`. | Low |
| **K-13** | The old vault `0xf486…` (not a proxy, no `withdrawLiquidity`) has **~10 USDG permanently stuck**. Its market is paused. | Accepted loss. **Do not** attempt recovery |
| **K-14** | Mainnet oracle type at `0x1952…`. | **Resolved:** `PledgeChainlinkOracle`, `maxStaleness` = 4 days |

## 18. Test suite and coverage gaps

```
test/
  PledgeVaultManager.t.sol      ← happy paths, pause trap, 6-dp grind, setMarketParams, upgrade storage, bad-debt cap
  ProxyDeploy.t.sol             ← proxy init; payDebt unimplemented
  PledgeChainlinkOracle.t.sol   ← scale, stale, zero/negative, non-8 decimals
  PledgeStaking.t.sol
  PledgeTestnetBridge.t.sol
  MockERC20.t.sol
```

Default setup still uses `MockERC20(..., 18)` for USDG. **6-decimal paths that now exist:** `test_borrowWithSixDecimalUsdg`, `test_liquidationSeizesCorrectlyWithSixDecimalUsdg`, `test_sixDecimalUsdgGrindDoesNotResetLastAccrual`.

Still missing (nice-to-have):

- Invariant and fuzz tests (see §19)
- Collateral tokens with 6 and 8 decimals, not just 18
- `principalDebt <= pos.debt` fuzz

## 19. Invariants we claim — please prove or break them

Good targets for `forge test --fuzz` and invariant testing.

**Solvency and accounting**

1. `principalDebt[c][u] <= positions[c][u].debt`, always.
2. `positions[c][u].debt == 0` ⟹ `principalDebt[c][u] == 0 && debtOpenedAt[c][u] == 0`.
3. `Σ positions[c][u].collateral <= IERC20(c).balanceOf(vault)` for every collateral `c`.
4. USDG leaves the vault only via `borrow` payout, the origination fee transfer, and `withdrawLiquidity`.

**Health factor**

5. A successful `withdraw` with `debt > 0` ⟹ `HF >= 1e18` afterwards.
6. A successful `borrow` ⟹ `debtUsd <= maxDebt(collateralUsd, maxLtvBps)`.
7. A successful `liquidate` ⟹ HF **before** execution was `< 1e18`.
8. `liquidate` can never be called by the position owner (`SelfLiquidationNotAllowed`).
9. HF can only fall because the price fell, interest accrued, or the user withdrew. **Never** because of a third party's action.

**Interest**

10. `getRepayBreakdown().total == positions.debt + pending`, and `principal + interest == total`.
11. Interest is monotonically increasing in time for a fixed debt. (K-10 grind path is covered in unit tests.)
12. Full repayment followed by a new borrow resets `debtOpenedAt`; interest does not carry over.

**Narrative invariants (product-level, not just technical)**

13. No function can move a user's collateral out of their position while `HF >= 1e18` — except `upgradeToAndCall` by the owner.
14. No function can increase a user's debt other than that user's own `borrow` and time-based interest accrual.
15. A rise in the collateral price **never** increases `stabilityFeeAprBps` or `debt`.

If 13, 14, or 15 can be broken, we consider it **critical** by definition, even if the dollar loss is small, because it breaks the product promise.

## 20. The next upgrade — review it before we deploy

We plan **one** vault upgrade (`upgradeToAndCall` on proxy **`0x0dfd39…`**, never `0x1757…`) containing the implementation already in this tree:

1. **The pause fix** (K-1): `active == false` blocks only `deposit` and `borrow`.
2. **`setMarketParams`** (K-3): bounds + event; APR checkpoints so already-accrued interest is not rewritten.
3. **The pool decision** (K-2 Option B): parking only; do not wire `payDebt`.
4. **K-10:** do not reset `lastAccrual` when `interest == 0`.

Storage rule: **append-only**. New variables at the end of the live layout (`aprCheckpoints` mapping). Do not insert in the middle. `__gap` is optional hygiene at the very end — not required to unlock funds.

`surplusBuffer` is `immutable`, so it cannot be swapped with a setter, only with a new implementation. Please don't propose `setStorage`. Do not broadcast to 4663 unless we ask.

## 21. Current on-chain state

### Mainnet — Robinhood Chain 4663

| Contract | Address | Notes |
|---|---|---|
| Vault (proxy) | `0x0dfd39ff00aFa2283A8c37770dB972aeC08AaB62` | **LIVE. Canonical. From [`deployments/4663.json`](deployments/4663.json)** |
| Oracle | `0x195287cbcd53eF058a3DeC4c6DC8f17Bf79A28d9` | **`PledgeChainlinkOracle`**, `maxStaleness` = 4 days |
| Surplus buffer | `0xEa30446c46D61514f19c897224E65b13Fb0A826c` | **Not a proxy** (legacy contract) |
| Stability pool | `0x8570a571CC83f87B3Ca4249B71646Cc807350e14` | **Not a proxy**; parking only, not a backstop |
| USDG (Paxos) | `0x5fc5360D0400a0Fd4f2af552ADD042D716F1d168` | **6 decimals** |
| Old vault | `0xf486F332A162CC4bb844506254a649C300D64e9b` | Deprecated, ~10 USDG stuck (K-13) |
| Non-canonical vault | `0x1757a7BD9078001adD29d98Ba712DA7ba154C1AE` | Unsafe script target — **do not upgrade** |

Explorer: `robinhoodchain.blockscout.com`. Its API sits behind Cloudflare, so `forge verify-contract` usually fails; we use **Sourcify**.

**Eight markets** on the canonical vault. `registerMarket` args `500, 120, 50` mean **liq bonus 5% / APR 1.2% / origination 0.5%**. `liqRatioBps` is **not** 16600 for every name (SPY 13300, AAPL/MSFT 15300, etc. — see §22).

**USDG inventory in the vault proxy is 0.** The four-step smoke test has **not** been run on this proxy yet.

### Testnet — Robinhood Chain 46630

Vault: see [`deployments/46630.json`](deployments/46630.json). Mock USDG at **18 decimals**. Mock collateral `mNVDA`, `mAAPL`, and others.

**Testnet is the safest place for you to experiment.** If you need mock tokens or prices, ask us rather than guessing.

## 22. Market parameters (reference)

Canonical mainnet values from [`deployments/4663.json`](deployments/4663.json). Shared fee triplet on all names: **`liqBonusBps=500` (5%), `stabilityFeeAprBps=120` (1.2%), `originationFeeBps=50` (0.5%)**.

| Market | Max LTV | `liqRatioBps` |
|---|---|---|
| NVDA | 60% (6000) | 16600 (166%) |
| SPY | 75% (7500) | 13300 (133%) |
| AAPL / MSFT | 65% (6500) | 15300 (153%) |
| QQQ | 70% (7000) | 14300 (143%) |
| AMZN | 58% (5800) | 17200 (172%) |
| META | 62% (6200) | 16100 (161%) |
| GOOGL | 60% (6000) | 16600 (166%) |

The authoritative source is on-chain `markets(collateral)` at vault `0x0dfd39…`, then the manifest. `0x1757…` is not canonical.