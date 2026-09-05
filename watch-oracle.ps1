# Live Chainlink / Pledge oracle ticker. Ctrl+C to stop.
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

if (Test-Path ".env") {
  Get-Content ".env" | ForEach-Object {
    if ($_ -match "^\s*#" -or $_ -notmatch "=") { return }
    $k, $v = $_.Split("=", 2)
    Set-Item -Path "Env:$($k.Trim())" -Value $v.Trim()
  }
}

$rpc = $env:ROBINHOOD_MAINNET_RPC
$oracle = if ($env:MAINNET_ORACLE) { $env:MAINNET_ORACLE } else { "0x195287cbcd53eF058a3DeC4c6DC8f17Bf79A28d9" }
if (-not $rpc) {
  Write-Host "ROBINHOOD_MAINNET_RPC is not set. Add your QuickNode URL to contracts\.env"
  exit 1
}

$markets = @(
  @{ s = "SPY"; t = "0x117cc2133c37B721F49dE2A7a74833232B3B4C0C"; f = "0x319724394D3A0e3669269846abE664Cd621f9f6A" }
  @{ s = "NVDA"; t = "0xd0601CE157Db5bdC3162BbaC2a2C8aF5320D9EEC"; f = "0x379EC4f7C378F34a1B47E4F3cbeBCbAC3E8E9F15" }
  @{ s = "AAPL"; t = "0xaF3D76f1834A1d425780943C99Ea8A608f8a93f9"; f = "0x6B22A786bAa607d76728168703a39Ea9C99f2cD0" }
  @{ s = "QQQ"; t = "0xD5f3879160bc7c32ebb4dC785F8a4F505888de68"; f = "0x80901d846d5D7B030F26B480776EE3b29374C2ae" }
  @{ s = "MSFT"; t = "0xe93237C50D904957Cf27E7B1133b510C669c2e74"; f = "0x45C3C877C15E6BA2EBB19eA114Ea508d14C1Af2E" }
  @{ s = "AMZN"; t = "0x12f190a9F9d7D37a250758b26824B97CE941bF54"; f = "0xD5a1508ceD74c084eBf3cBe853e2C968fB2a651C" }
  @{ s = "META"; t = "0xc0D6457C16Cc70d6790Dd43521C899C87ce02f35"; f = "0x7C38C00C30BEe9378381E7B6135d7283356D71b1" }
  @{ s = "GOOGL"; t = "0x2e0847E8910a9732eB3fb1bb4b70a580ADAD4FE3"; f = "0xF6f373a037c30F0e5010d854385cA89185AE638b" }
)

function Invoke-Cast([string[]]$castArgs) {
  $out = & cast @castArgs 2>&1 | Out-String
  if ($LASTEXITCODE -ne 0) { throw $out.Trim() }
  return $out.Trim()
}

function Get-CastUintLines([string]$raw) {
  [string[]]$vals = @(
    $raw -split "`r?`n" |
      ForEach-Object { ($_ -split "\s+")[0] } |
      Where-Object { $_ -match "^\d+$" }
  )
  return ,$vals
}

function Get-Usd($answer, $decimals) {
  return [decimal]$answer / [math]::Pow(10, [int]$decimals)
}

$intervalSec = 5
Write-Host "Polling every ${intervalSec}s via QuickNode. Ctrl+C to stop."
Start-Sleep -Milliseconds 400

while ($true) {
  $now = Get-Date
  $rows = @()
  foreach ($m in $markets) {
    $chainlink = "err"
    $age = "-"
    $pledge = "no feed"
    try {
      $round = Invoke-Cast @(
        "call", $m.f,
        "latestRoundData()(uint80,int256,uint256,uint256,uint80)",
        "--rpc-url", $rpc
      )
      $parts = Get-CastUintLines $round
      $answer = $parts[1]
      $updatedAt = [int64]$parts[3]
      $decOut = Invoke-Cast @("call", $m.f, "decimals()(uint8)", "--rpc-url", $rpc)
      $usd = Get-Usd $answer $decOut
      $chainlink = ("{0:N2}" -f $usd)
      $ageSec = [int]([DateTimeOffset]::UtcNow.ToUnixTimeSeconds() - $updatedAt)
      if ($ageSec -lt 0) { $ageSec = 0 }
      $age = "${ageSec}s"
    } catch {
      $chainlink = "revert"
    }
    try {
      $priceRaw = Invoke-Cast @(
        "call", $oracle, "getPrice(address)(uint256)", $m.t, "--rpc-url", $rpc
      )
      $priceWei = (Get-CastUintLines $priceRaw)[0]
      $pledge = ("{0:N2}" -f ([decimal]$priceWei / 1e18))
    } catch {
      $pledge = "revert"
    }
    $rows += [pscustomobject]@{
      Symbol    = $m.s
      Chainlink = $chainlink
      Age       = $age
      Oracle    = $pledge
    }
  }

  Clear-Host
  Write-Host "Pledge Finance Oracle  $($now.ToString('yyyy-MM-dd HH:mm:ss'))  |  Ctrl+C to stop"
  Write-Host "Proxy  $oracle"
  Write-Host ""
  $rows | Format-Table -AutoSize | Out-String | Write-Host
  Write-Host "Chainlink = aggregator. Oracle = Pledge getPrice."
  Start-Sleep -Seconds $intervalSec
}
