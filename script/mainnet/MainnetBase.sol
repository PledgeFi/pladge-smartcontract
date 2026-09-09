// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";

/// @title MainnetBase
/// @notice Shared constants and helpers for the Robinhood Mainnet (4663) redeploy scripts.
/// @dev External addresses (Paxos USDG, Robinhood stock tokens, Chainlink feeds, PLG, Timelock)
///      are hardcoded because they are already live and outside our control. Every Pledge
///      contract this redeploy produces is read from the environment instead, so no script can
///      ever silently target a stale protocol address.
abstract contract MainnetBase is Script {
    uint256 internal constant CHAIN_ID = 4663;

    // --- External, already-live addresses ---
    address internal constant USDG = 0x5fc5360D0400a0Fd4f2af552ADD042D716F1d168;
    address internal constant PLG = 0xDfC0a301CA6F62c32800C4827974ECac64BC7e38;

    address internal constant NVDA = 0xd0601CE157Db5bdC3162BbaC2a2C8aF5320D9EEC;
    address internal constant SPY = 0x117cc2133c37B721F49dE2A7a74833232B3B4C0C;

    address internal constant NVDA_FEED = 0x379EC4f7C378F34a1B47E4F3cbeBCbAC3E8E9F15;
    address internal constant SPY_FEED = 0x319724394D3A0e3669269846abE664Cd621f9f6A;

    // --- Market parameters ---
    // registerMarket(collateral, oracle, maxLtvBps, liqRatioBps, liqBonusBps, stabilityFeeAprBps, originationFeeBps)
    uint16 internal constant NVDA_MAX_LTV_BPS = 6000;
    uint16 internal constant NVDA_LIQ_RATIO_BPS = 16600;
    uint16 internal constant SPY_MAX_LTV_BPS = 7500;
    uint16 internal constant SPY_LIQ_RATIO_BPS = 13300;

    uint16 internal constant LIQ_BONUS_BPS = 500; // 5%
    uint16 internal constant STABILITY_FEE_APR_BPS = 120; // 1.2%
    uint16 internal constant ORIGINATION_FEE_BPS = 50; // 0.5%

    uint256 internal constant ORACLE_MAX_STALENESS = 4 days;

    /// @dev Chain guard. Every script inherits it so a wrong `--rpc-url` aborts before broadcasting.
    modifier onlyMainnet() {
        require(block.chainid == CHAIN_ID, "wrong chain: expected Robinhood mainnet 4663");
        _;
    }

    function deployerKey() internal view returns (uint256) {
        string memory raw = vm.envString("DEPLOYER_PRIVATE_KEY");
        bytes memory chars = bytes(raw);
        if (chars.length >= 2 && chars[0] == "0" && chars[1] == "x") {
            return vm.parseUint(raw);
        }
        return vm.parseUint(string.concat("0x", raw));
    }

    /// @dev Reads a previously deployed Pledge contract from the environment and proves it exists
    ///      on chain. Catches the most common operator mistake: forgetting to export the address
    ///      produced by the previous step, or pasting one from the abandoned deployment.
    function requireDeployed(string memory key) internal view returns (address addr) {
        addr = vm.envAddress(key);
        require(addr != address(0), string.concat(key, " is zero"));
        require(addr.code.length > 0, string.concat(key, " has no code on chain"));
    }

    function logExport(string memory key, address value) internal pure {
        console2.log(string.concat("  export ", key, "="), value);
    }
}
