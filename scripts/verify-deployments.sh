#!/usr/bin/env bash
# Assert deployments/4663.json contract keys match .env.example addresses.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="$ROOT/.env.example"
DEPLOY_FILE="$ROOT/deployments/4663.json"

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
check_pair MAINNET_VAULT_MANAGER PledgeVaultManager || fail=1
check_pair MAINNET_ORACLE PledgeChainlinkOracle || fail=1
check_pair SURPLUS_BUFFER PledgeSurplusBuffer || fail=1
check_pair STABILITY_POOL PledgeStabilityPool || fail=1
check_pair USDG_TOKEN PaxosUSDG || fail=1
check_pair NVDA_TOKEN RobinhoodNVDA || fail=1
check_pair SPY_TOKEN RobinhoodSPY || fail=1
check_pair AAPL_TOKEN RobinhoodAAPL || fail=1
check_pair QQQ_TOKEN RobinhoodQQQ || fail=1
check_pair MSFT_TOKEN RobinhoodMSFT || fail=1
check_pair AMZN_TOKEN RobinhoodAMZN || fail=1
check_pair META_TOKEN RobinhoodMETA || fail=1
check_pair GOOGL_TOKEN RobinhoodGOOGL || fail=1

if [[ "$fail" -ne 0 ]]; then
  exit 1
fi

echo "deployments/4663.json matches .env.example"
