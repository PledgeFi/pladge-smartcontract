@echo off
setlocal EnableExtensions
cd /d "%~dp0"

if exist ".env" (
  for /f "usebackq eol=# tokens=1,* delims==" %%A in (".env") do (
    if /i "%%A"=="ROBINHOOD_MAINNET_RPC" set "ROBINHOOD_MAINNET_RPC=%%B"
    if /i "%%A"=="MAINNET_ORACLE" set "MAINNET_ORACLE=%%B"
  )
)

if not defined MAINNET_ORACLE set "MAINNET_ORACLE=0x195287cbcd53eF058a3DeC4c6DC8f17Bf79A28d9"
if not defined ROBINHOOD_MAINNET_RPC (
  echo ROBINHOOD_MAINNET_RPC is not set. Add your QuickNode URL to contracts\.env
  goto :end
)

echo.
echo [1/2] Local Foundry tests
echo.
forge test --match-contract PledgeChainlinkOracleTest -vv
if errorlevel 1 (
  echo.
  echo Local tests FAILED.
  goto :end
)

echo.
echo [2/2] Mainnet oracle check (read-only, no tx)
echo.
forge script script/CheckOracle.s.sol --rpc-url %ROBINHOOD_MAINNET_RPC% --chain-id 4663 -vv
if errorlevel 1 (
  echo.
  echo Mainnet check FAILED. Local tests above are still valid.
)

:end
echo.
pause
endlocal
