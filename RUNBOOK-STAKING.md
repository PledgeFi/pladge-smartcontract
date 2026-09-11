# Runbook: Opening PLG Staking

This document lists the on-chain steps the contract owner must run.
Website and admin-dashboard code fixes are already done — the steps below
cannot be done from code because they need a signature from the owner wallet.

Chain inspection date: 12 September 2026.

---

## 1. Current state

| Item | Value |
| --- | --- |
| Live staking contract | `0xEe8c2E6ED39B79Cd6806926d96CD570F5b94bF07` |
| Old staking contract (do not use) | `0xA317886027c83183C22d9526bd09e9837CBc38F6` |
| Live PLG token | `0x1BE3010124C86e8a03c6Fb6e91c534D4A2b1fFCf` |
| Owner of every contract | `0x82FBf39835a885C1CdA3D756FB6AA79802f29e92` |
| Timelock (not in use yet) | `0x1195e53E30A7645edf1EE7171B5C1CC0e55ebbFD` |

The live staking contract has 3 pools:

| # | On-chain name today | Stake token | Status | Plan |
| --- | --- | --- | --- | --- |
| 0 | `PLG Staking` | **old** PLG `0xDfC0a301…` | inactive | rename to `PLG Staking (retired)` |
| 1 | `USDG Staking` | USDG `0x5fc5360D…` | inactive | rename to `USDG Staking (retired)` |
| 2 | `PONS Staking` | **PLG `0x1BE30101…`** | active | rename to `PLG Staking` — this is the only pool in use |

Pool 2 emits 6,111.11 PLG per day, with a 1–90 day lock. The stake token and the
reward token are both `0x1BE3010124C86e8a03c6Fb6e91c534D4A2b1fFCf`.

The "On-chain name today" column records what is actually on the blockchain
today, not what we want. Run Step 2 and that column changes.

### What cannot be done

**Pools 0 and 1 cannot be deleted, and their tokens cannot be switched to the new PLG.**

This is a contract limit, not a choice. The pool list inside the contract can only
grow — there is no function to remove a pool. A pool's tokens are set once at
creation, and there is no function to change them. So pool 0 will forever hold the
old PLG, and pool 1 will forever hold USDG.

Three things can be done, and all three are already done or will be:

1. Deactivated so nobody can enter — **done**, both are `active = false`.
2. Given clear names so they cannot be confused — Step 2.
3. Hidden from the website — **done**, the website and admin dashboard only
   show live pools. Admin has a "Show retired" button if needed.

The end result: users only see one pool, pool 2 with PLG `0x1BE30101…`.
Pools 0 and 1 remain on the blockchain, but they are not visible and cannot
be entered.

### Trap: two tokens with the same name

The old PLG `0xDfC0a301…` **also** uses the symbol `PLG`. So if you distinguish
them by name or symbol, they look identical. Always match on the address.

| Token | Address | In use? |
| --- | --- | --- |
| Live PLG | `0x1BE3010124C86e8a03c6Fb6e91c534D4A2b1fFCf` | **yes, this is the only one** |
| Old PLG (launchpad) | `0xDfC0a301CA6F62c32800C4827974ECac64BC7e38` | no, do not touch it |

On the old staking contract, pools 0 and 1 are still active. There are no user
funds in them (total stake is zero), but while they stay active people can still
deposit into them.

**What I could not confirm:** the 1 billion PLG that has been minted is not in
any wallet recorded in this repo, including the owner wallet. You need to
confirm which wallet holds the PLG before running step 4.

---

## 2. Step order

The order matters. Step 6 is last because after that every change must wait 48 hours.

### Step 1 — Close pools on the old contract

This is the most urgent step. While the old pools stay active, someone can deposit
tokens into a contract that is no longer in use.

```bash
export PATH="$HOME/.foundry/bin:$PATH"
RPC=https://rpc.mainnet.chain.robinhood.com
OLD=0xA317886027c83183C22d9526bd09e9837CBc38F6

cast send $OLD "setPoolActive(uint256,bool)" 0 false --rpc-url $RPC --private-key $OWNER_KEY
cast send $OLD "setPoolActive(uint256,bool)" 1 false --rpc-url $RPC --private-key $OWNER_KEY
```

Verify — the ninth field must be `false`:

```bash
cast call $OLD "pools(uint256)(address,address,uint256,uint256,uint256,uint256,uint256,uint256,bool,uint256)" 0 --rpc-url $RPC
```

### Step 2 — Remove the name "PONS", make it "PLG Staking"

Pool names are stored in the contract and the website displays them as-is. So
until this transaction lands, users still see "PONS Staking", no matter how
clean the rest of the code is.

The script below renames all three pools in one go:

| # | From | To |
| --- | --- | --- |
| 0 | `PLG Staking` | `PLG Staking (retired)` |
| 1 | `USDG Staking` | `USDG Staking (retired)` |
| 2 | `PONS Staking` | `PLG Staking` |

The order matters: pool 0 **already** uses the name `"PLG Staking"` even though
it holds the old token. If pool 2 is renamed first, two pools would share the
same name and users could not tell them apart. The script already orders them
correctly. Before sending anything it also checks that each pool holds the
expected token — matched by address — and that pools 0 and 1 are already
inactive, so the "retired" label is not a lie. If even one check fails, the
script stops without sending a transaction.

```bash
export DEPLOYER_PRIVATE_KEY=...   # owner wallet 0x82FBf398…
RPC=https://rpc.mainnet.chain.robinhood.com

# 1. Dry-run with no send — required
forge script script/mainnet/13_RenameStakingPools.s.sol --rpc-url $RPC

# 2. If the log looks right, then broadcast
forge script script/mainnet/13_RenameStakingPools.s.sol --rpc-url $RPC --broadcast
```

The first command does not send a transaction; it only simulates. Read the log:
it must print the name before and after. If anything looks off, do not continue.

You can also do this from the admin dashboard if that is easier: press "Show
retired" to see pools 0 and 1, rename those two first, then rename pool 2 to
`PLG Staking`.

Afterward, check the result:

```bash
NEW=0xEe8c2E6ED39B79Cd6806926d96CD570F5b94bF07
for i in 0 1 2; do cast call $NEW "poolNames(uint256)(string)" $i --rpc-url $RPC; done
```

It must print `PLG Staking (retired)`, `USDG Staking (retired)`, `PLG Staking`.
There must be no remaining PONS label.

### Step 2b — Install the lock-boost upgrade

Without this step, the 1–90 day slider only hurts the people who use it: the
reward is the same, but the funds stay locked longer. This upgrade is what
makes a longer lock actually pay more — 1.00x at 1 day up to 3.00x at 90 days.

**This is not a new contract.** The address stays `0xEe8c2E6ED39B79Cd6806926d96CD570F5b94bF07`.
Only the new bytecode is deployed, then the existing address is pointed at it.
The pool list, names, reward balances, and owner are all untouched. The website
and admin dashboard do not need to be changed or redeployed — both already wait
for this feature and turn it on once the upgrade lands.

This upgrade also brings `emergencyWithdraw`, an exit that returns principal
without touching the reward token.

**Hard requirement: nobody may be staking.** This upgrade changes the reward
accounting unit from "per token" to "per weight". Reward debt on existing
positions is recorded in the old unit, and there is no way to rewrite it —
the contract does not store a list of stakers. Open positions would therefore
be miscalculated. The script checks this itself and stops if anyone is staking.
All three pools are empty today, so it is safe — but that is a strong reason
to **run it before the pool is funded and opened**.

Must be run **before** ownership is moved to the timelock.

```bash
export DEPLOYER_PRIVATE_KEY=...   # owner wallet 0x82FBf398…
RPC=https://rpc.mainnet.chain.robinhood.com

# 1. Dry-run with no send — required
forge script script/mainnet/14_UpgradeStakingWithBoost.s.sol --rpc-url $RPC

# 2. If the log looks right, then broadcast
forge script script/mainnet/14_UpgradeStakingWithBoost.s.sol --rpc-url $RPC --broadcast
```

The log must show multipliers of 10000 at 1 day, 16516 at 30 days, and 30000 at
90 days — that is 1.00x, 1.65x, and 3.00x. After sending, the script also
checks for itself that the new code is actually live; if not, it fails with a
clear message.

Record the implementation address printed in the log into `deployments/4663.json`.

Check the result:

```bash
NEW=0xEe8c2E6ED39B79Cd6806926d96CD570F5b94bF07
cast call $NEW "maxBoostBps(uint256)(uint256)" 2 --rpc-url $RPC          # 30000
cast call $NEW "multiplierBps(uint256,uint256)(uint256)" 2 86400 --rpc-url $RPC   # 10000
cast call $NEW "multiplierBps(uint256,uint256)(uint256)" 2 7776000 --rpc-url $RPC # 30000
```

The 3.00x figure can be changed at any time from the admin dashboard, field
"Reward multiplier at the longest lock", with no further upgrade. The bound is
locked between 1x and 10x so that a single long-locked whale cannot soak up
the entire emission.

### Step 3 — Set the lock range

It is currently 1 day to 90 days. The user picks a value inside that range.
To change it, use the admin dashboard: fill in "Min lock days" and "Max lock
days", then the "Set lock" button.

The change only applies to new stakes. People who already staked keep the lock
duration they got at the time.

### Step 4 — Fund the reward reserve

This is what actually makes staking work. Without it the pool accepts tokens
but pays nothing.

At the current rate, 6,111.11 PLG per day:

| How long it should run | PLG needed |
| --- | --- |
| 30 days | 183,334 |
| 90 days | 550,000 |
| 180 days | 1,100,000 |

`fundRewards` is deliberately not owner-gated — there is no `onlyOwner` on it —
so any wallet that holds PLG can fill the reward reserve directly, without
going through the owner wallet.

**Chosen path: send PLG directly to the owner wallet `0x82FBf398…`.** Not because
the contract requires it, but because that wallet already holds native for gas.
A wallet that has PLG but zero gas cannot send any transaction — including
moving its own PLG out. That is not theoretical: on 12 September 2026,
`0x876f12d8043cD7a87D0eb512c29d5Ad58C92B055` received 1,017 PLG with a native
balance of zero, and that PLG could not be moved until the wallet was given gas.

So if you use a wallet other than the owner, **fund gas first, then send the PLG.**

```bash
PLG=0x1BE3010124C86e8a03c6Fb6e91c534D4A2b1fFCf
AMOUNT=550000000000000000000000   # 550,000 PLG

cast send $PLG "approve(address,uint256)" $NEW $AMOUNT --rpc-url $RPC --private-key $OWNER_KEY
cast send $NEW "fundRewards(uint256,uint256)" 2 $AMOUNT --rpc-url $RPC --private-key $OWNER_KEY
```

The easiest path is the admin dashboard: connect the wallet that holds PLG,
open `/staking`, then use the "Fund rewards" card. Approve is automatic. That
card is not locked to the owner, so any wallet can use it.

If the available PLG balance is smaller than the table above, do not force it:
at 6,111.11 PLG per day, 1,000 PLG lasts about 4 hours. Either add more PLG or
lower `setRewardRate` so the budget lasts as planned.

Verify — the last number must equal the amount funded:

```bash
cast call $NEW "pools(uint256)(address,address,uint256,uint256,uint256,uint256,uint256,uint256,bool,uint256)" 2 --rpc-url $RPC
```

After this the website will show an APR and a "Rewards last" column of 90 days.
While the reward reserve is still zero, the website refuses stakes and shows a
warning.

### Step 4b — Reopen pool 2

Pool 2 was closed on 12 September 2026 with `setPoolActive(2, false)`, because
the reward reserve was zero at the time. Leaving it open would trap people:
their funds lock for up to 90 days while the yield is zero, and the staking
page promises a 3.00x bonus that cannot be paid.

Do not run this before Step 4 is done and the balance has been verified.

This is the only step in the funding flow that **must** come from the owner wallet.

```bash
cast send $NEW "setPoolActive(uint256,bool)" 2 true --rpc-url $RPC --private-key $OWNER_KEY
```

You can also do this from the admin dashboard, using the active/inactive toggle
on the pool edit card.

### Step 5 — Upgrade the implementation to add `emergencyWithdraw`

This function is already written and tested in `src/core/PledgeStaking.sol`.
Its purpose: return principal without touching the reward token. `unstake`
pays rewards first, so if the reward transfer fails, the user's principal is
stuck with it. This is the way out.

This function **does not add any storage variables**. That was verified by
comparing `forge inspect PledgeStaking storage-layout` before and after — the
output is identical. So it is enough to swap the implementation; **the proxy
and all of its data stay**.

```bash
cd pladge-smartcontract
forge build

# Deploy the new implementation
forge create src/core/PledgeStaking.sol:PledgeStaking \
  --constructor-args 0x0000000000000000000000000000000000000000 \
  --rpc-url $RPC --private-key $OWNER_KEY

# Point the proxy at the new implementation (replace $NEW_IMPL with the address above)
cast send $NEW "upgradeToAndCall(address,bytes)" $NEW_IMPL 0x \
  --rpc-url $RPC --private-key $OWNER_KEY
```

Verify afterward — it must return `0`, not an error:

```bash
cast call $NEW "getPosition(uint256,address)(uint256,uint256,uint256,uint256,uint256)" 2 $DEPLOYER --rpc-url $RPC
```

Do this **before** step 6. After ownership moves to the timelock, an upgrade
must queue for 48 hours.

Note: the website and admin dashboard do not call this function yet, because
calling it before the upgrade would fail. After the upgrade is in place, the
button can be added.

### Step 6 — Hand ownership to the timelock

Do this last, after every figure above is final. After this, every settings
change must queue for 48 hours.

```bash
TIMELOCK=0x1195e53E30A7645edf1EE7171B5C1CC0e55ebbFD
cast send $NEW "transferOwnership(address)" $TIMELOCK --rpc-url $RPC --private-key $OWNER_KEY
```

---

## 3. What is not done here

**Vault, oracle, stability pool, and surplus buffer addresses are not changed.**
The website still points at the old contract set for the lending product. That
is intentional: the old vault still holds 2.01 USDG while the new vault is
empty. Moving the addresses now would turn lending off. That move is a separate
project — the new vault must be funded first and its market checked.

**What is still missing in the contract.** The three items below need a **new
proxy**, not just an upgrade, because they change the storage layout:

- The upgradeable reentrancy guard — it currently uses the plain variant that
  occupies slot 1, so the contract inheritance list must not change.
- `__gap` for future extra variables.
- Extra fields inside `PoolInfo`, for example a reward multiplier for long locks.

While total stake is still zero as it is today, replacing the proxy hurts
nobody. The longer it is delayed, the more expensive it gets.

**Pending product decision:** lock duration currently has no effect on reward
size at all — splitting is purely by token amount. So there is no reason for a
user to pick 90 days over 1 day. The options: collapse the lock to a single
fixed value (set min = max from admin), or add a reward multiplier — the
second needs a new proxy.
