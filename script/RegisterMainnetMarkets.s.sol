// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {PledgeProtocol} from "../src/PledgeProtocol.sol";
import {PledgeVaultManager} from "../src/core/PledgeVaultManager.sol";
import {PledgeChainlinkOracle} from "../src/oracle/PledgeChainlinkOracle.sol";

/// @title RegisterMainnetMarkets
/// @notice Register Robinhood stock token markets on mainnet vault.
/// @dev Set VAULT_MANAGER, PLEDGE_ORACLE, and optional CHAINLINK_* feed env vars.
contract RegisterMainnetMarkets is Script {
    struct MarketConfig {
        string symbol;
        address token;
        address feed;
        uint16 maxLtvBps;
        uint16 liqRatioBps;
    }

    function run() external {
        uint256 deployerKey = _deployerPrivateKey();
        address vaultAddr = vm.envAddress("VAULT_MANAGER");
        address oracleAddr = vm.envAddress("PLEDGE_ORACLE");

        PledgeVaultManager vault = PledgeVaultManager(vaultAddr);
        PledgeChainlinkOracle oracle = PledgeChainlinkOracle(oracleAddr);

        MarketConfig[] memory markets = _markets();

        console2.log("Protocol:", PledgeProtocol.NAME);
        console2.log("VaultManager:", vaultAddr);
        console2.log("Oracle:", oracleAddr);
        console2.log("Markets:", markets.length);

        vm.startBroadcast(deployerKey);

        oracle.setMaxStaleness(4 days);

        for (uint256 i = 0; i < markets.length; i++) {
            MarketConfig memory m = markets[i];
            if (m.feed != address(0)) {
                oracle.setFeed(m.token, m.feed);
            }

            vault.registerMarket(m.token, oracleAddr, m.maxLtvBps, m.liqRatioBps, 500, 120, 50);

            console2.log("---");
            console2.log("Symbol", m.symbol);
            console2.log("Token", m.token);
            console2.log("Feed", m.feed);
            console2.log("MaxLTV bps", m.maxLtvBps);
        }

        vm.stopBroadcast();
    }

    function _markets() internal view returns (MarketConfig[] memory) {
        MarketConfig[] memory markets = new MarketConfig[](8);

        markets[0] = MarketConfig({
            symbol: "NVDA",
            token: 0xd0601CE157Db5bdC3162BbaC2a2C8aF5320D9EEC,
            feed: _feed("CHAINLINK_NVDA_FEED", 0x379EC4f7C378F34a1B47E4F3cbeBCbAC3E8E9F15),
            maxLtvBps: 6000,
            liqRatioBps: 16600
        });
        markets[1] = MarketConfig({
            symbol: "SPY",
            token: 0x117cc2133c37B721F49dE2A7a74833232B3B4C0C,
            feed: _feed("CHAINLINK_SPY_FEED", 0x319724394D3A0e3669269846abE664Cd621f9f6A),
            maxLtvBps: 7500,
            liqRatioBps: 13300
        });
        markets[2] = MarketConfig({
            symbol: "AAPL",
            token: 0xaF3D76f1834A1d425780943C99Ea8A608f8a93f9,
            feed: _feed("CHAINLINK_AAPL_FEED", 0x6B22A786bAa607d76728168703a39Ea9C99f2cD0),
            maxLtvBps: 6500,
            liqRatioBps: 15300
        });
        markets[3] = MarketConfig({
            symbol: "QQQ",
            token: 0xD5f3879160bc7c32ebb4dC785F8a4F505888de68,
            feed: _feed("CHAINLINK_QQQ_FEED", 0x072A3A0C04Cf8CDcaf5B4A73a4Ed4fF5A841531f),
            maxLtvBps: 7000,
            liqRatioBps: 14300
        });
        markets[4] = MarketConfig({
            symbol: "MSFT",
            token: 0xe93237C50D904957Cf27E7B1133b510C669c2e74,
            feed: _feed("CHAINLINK_MSFT_FEED", 0x914c40a644493b47336de847b0404E729e06C68d),
            maxLtvBps: 6500,
            liqRatioBps: 15300
        });
        markets[5] = MarketConfig({
            symbol: "AMZN",
            token: 0x12f190a9F9d7D37a250758b26824B97CE941bF54,
            feed: _feed("CHAINLINK_AMZN_FEED", 0xD5a1508ceD74c084eBf3cBe853e2C968fB2a651C),
            maxLtvBps: 5800,
            liqRatioBps: 17200
        });
        markets[6] = MarketConfig({
            symbol: "META",
            token: 0xc0D6457C16Cc70d6790Dd43521C899C87ce02f35,
            feed: _feed("CHAINLINK_META_FEED", 0xBdC53E50b1167cE1199bFaD54A034f7ab1741051),
            maxLtvBps: 6200,
            liqRatioBps: 16100
        });
        markets[7] = MarketConfig({
            symbol: "GOOGL",
            token: 0x2e0847E8910a9732eB3fb1bb4b70a580ADAD4FE3,
            feed: _feed("CHAINLINK_GOOGL_FEED", 0x15636CE4C0EdE55335f84E6386f8F49C897c077d),
            maxLtvBps: 6000,
            liqRatioBps: 16600
        });

        return markets;
    }

    function _feed(string memory key, address fallbackFeed) internal view returns (address) {
        try vm.envAddress(key) returns (address feed) {
            return feed;
        } catch {
            return fallbackFeed;
        }
    }

    function _optionalFeed(string memory key) internal view returns (address) {
        try vm.envAddress(key) returns (address feed) {
            return feed;
        } catch {
            return address(0);
        }
    }

    function _deployerPrivateKey() private view returns (uint256) {
        string memory raw = vm.envString("DEPLOYER_PRIVATE_KEY");
        bytes memory chars = bytes(raw);
        if (chars.length >= 2 && chars[0] == "0" && chars[1] == "x") {
            return vm.parseUint(raw);
        }
        return vm.parseUint(string.concat("0x", raw));
    }
}
