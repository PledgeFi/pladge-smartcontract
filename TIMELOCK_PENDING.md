# ⏳ Pending Timelock Action — Oracle Upgrade (fallback feed + price bounds)

**Status:** `schedule()` executed on-chain. Waiting for the 48h delay before `execute()` can run.

## Key facts

| Item | Value |
|---|---|
| Ready to execute at (unix) | `1788893085` |
| Ready to execute at (readable) | **Wednesday, 09 September 2026, 01:44 WIB (UTC+7)** |
| Timelock | `0x1195e53E30A7645edf1EE7171B5C1CC0e55ebbFD` |
| Safe (3-of-4) | `0x509dC4A81045F6FA42D388A68e2C65d20d493560` |
| Oracle proxy (target) | `0x195287cbcd53eF058a3DeC4c6DC8f17Bf79A28d9` |
| New implementation (already deployed, not yet live) | `0xF80cf3468Cda4275e29867E75C54219040Ca5498` |
| Operation ID | `0x29c124f1a2795acdaea0ad66f2205d3fd7c3ac9f54c4069c1e8ede6c161f741b` |

## Check readiness on-chain anytime

```bash
cast call 0x1195e53E30A7645edf1EE7171B5C1CC0e55ebbFD \
  "isOperationReady(bytes32)(bool)" \
  0x29c124f1a2795acdaea0ad66f2205d3fd7c3ac9f54c4069c1e8ede6c161f741b \
  --rpc-url robinhood_mainnet
```

## Next step once ready: Safe → Timelock `execute()`

In Safe UI (https://app.safe.global/home?safe=robinhood:0x509dC4A81045F6FA42D388A68e2C65d20d493560):

1. New transaction → Contract interaction → address `0x1195e53E30A7645edf1EE7171B5C1CC0e55ebbFD`
2. Paste the same ABI used for `schedule` (includes `execute`)
3. Select method **`execute`**, fill in (identical to the `schedule` call, minus `delay`):

| Field | Value |
|---|---|
| `target` | `0x195287cbcd53eF058a3DeC4c6DC8f17Bf79A28d9` |
| `value` | `0` |
| `data` | `0x4f1ef286000000000000000000000000f80cf3468cda4275e29867e75c54219040ca549800000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000000` |
| `predecessor` | `0x0000000000000000000000000000000000000000000000000000000000000000` |
| `salt` | `0xcaaf0f8c8901d9c52d1ee8200c9befc48a65e13dd4248bfdb259a5274316b98d` |

4. Submit → collect 3-of-4 signatures → Execute

## After execute() succeeds

- Verify on-chain: implementation slot, `owner()`, `maxStaleness()`, `getPrice()` for all 8 markets (same checks as the direct mainnet upgrade done earlier — see chat history).
- Then configure per-market `setFallbackFeed` and `setPriceBounds` — each of those ALSO requires a separate Safe → Timelock schedule+execute cycle (48h delay each), since the oracle is now Timelock-owned.
- Delete this file once the upgrade + follow-up configuration is complete.
