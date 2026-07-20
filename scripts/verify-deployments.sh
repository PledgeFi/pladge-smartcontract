#!/usr/bin/env bash
# Assert deployments/46630.json contract keys match .env.example addresses.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="$ROOT/.env.example"
DEPLOY_FILE="$ROOT/deployments/46630.json"

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required for verify-deployments.sh" >&2
  exit 1
fi

env_val() {
  grep "^$1=" "$ENV_FILE" | cut -d= -f2- | tr -d '[:space:]'
}

json_val() {
  jq -r --arg k "$1" '.contracts[$k]' "$DEPLOY_FILE"
}

check_pair() {
  local env_key="$1"
  local json_key="$2"
  local env_addr json_addr

  env_addr="$(env_val "$env_key")"
  json_addr="$(json_val "$json_key")"

  if [[ -z "$env_addr" || "$env_addr" == "0x" ]]; then
    echo "missing .env.example key: $env_key" >&2
    return 1
  fi

  if [[ "$env_addr" != "$json_addr" ]]; then
    echo "mismatch for $env_key ($json_key): .env=$env_addr json=$json_addr" >&2
    return 1
  fi
}

fail=0
check_pair VAULT_MANAGER PledgeVaultManager || fail=1
check_pair PLEDGE_ORACLE PledgeOracle || fail=1
check_pair SURPLUS_BUFFER PledgeSurplusBuffer || fail=1
check_pair STABILITY_POOL PledgeStabilityPool || fail=1
check_pair USDG_TOKEN PledgeFinanceUSDG || fail=1
check_pair MNVDA_TOKEN PledgeFinanceMNVDA || fail=1
check_pair MSPY_TOKEN PledgeFinanceMSPY || fail=1
check_pair MAAPL_TOKEN PledgeFinanceMAAPL || fail=1
check_pair MQQQ_TOKEN PledgeFinanceMQQQ || fail=1
check_pair MMSFT_TOKEN PledgeFinanceMMSFT || fail=1
check_pair MAMZN_TOKEN PledgeFinanceMAMZN || fail=1
check_pair MMETA_TOKEN PledgeFinanceMMETA || fail=1
check_pair PLG_TOKEN PledgeFinancePLG || fail=1
check_pair PLEDGE_STAKING PledgeStaking || fail=1
check_pair PLEDGE_BRIDGE PledgeTestnetBridge || fail=1

if [[ "$fail" -ne 0 ]]; then
  exit 1
fi

echo "deployments/46630.json matches .env.example"
