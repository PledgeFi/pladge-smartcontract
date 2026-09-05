@echo off
setlocal EnableExtensions
cd /d "%~dp0"

if exist ".env" (
  for /f "usebackq eol=# tokens=1,* delims==" %%A in (".env") do (
    if /i "%%A"=="ROBINHOOD_MAINNET_RPC" set "ROBINHOOD_MAINNET_RPC=%%B"
    if /i "%%A"=="MAINNET_VAULT_MANAGER" set "MAINNET_VAULT_MANAGER=%%B"
    if /i "%%A"=="MAINNET_ORACLE" set "MAINNET_ORACLE=%%B"
  )
)

if not defined MAINNET_VAULT_MANAGER set "MAINNET_VAULT_MANAGER=0x0dfd39ff00aFa2283A8c37770dB972aeC08AaB62"
if not defined MAINNET_ORACLE set "MAINNET_ORACLE=0x195287cbcd53eF058a3DeC4c6DC8f17Bf79A28d9"
if not defined ROBINHOOD_MAINNET_RPC (
  echo ROBINHOOD_MAINNET_RPC is not set. Add your QuickNode URL to contracts\.env
  goto :end
)

echo.
echo Top up deployer 0x82FBf39835a885C1CdA3D756FB6AA79802f29e92 with ~0.002 ETH first.
echo.

echo [1/2] Register remaining markets
echo.
set REGISTER_LIMIT=8
forge script script/RegisterMainnetMarkets.s.sol --rpc-url %ROBINHOOD_MAINNET_RPC% --broadcast --chain-id 4663 --with-gas-price 360000000 --gas-estimate-multiplier 130 --slow -vv
if errorlevel 1 (
  echo.
  echo Market registration FAILED. Check deployer ETH balance.
  goto :end
)

echo.
echo [2/2] Deploy stability pool
echo.
forge script script/DeployPoolMainnet.s.sol --rpc-url %ROBINHOOD_MAINNET_RPC% --broadcast --chain-id 4663 --with-gas-price 360000000 --gas-estimate-multiplier 180 --slow -vv
if errorlevel 1 (
  echo.
  echo Stability pool deploy FAILED. Markets above may still be registered.
)

:end
echo.
pause
endlocal
