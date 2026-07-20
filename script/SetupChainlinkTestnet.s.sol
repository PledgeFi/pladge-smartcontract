// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {PledgeProtocol} from "../src/PledgeProtocol.sol";
import {PledgeOracle} from "../src/oracle/PledgeOracle.sol";
import {MockChainlinkFeed} from "../src/mocks/MockChainlinkFeed.sol";

/// @title SetupChainlinkTestnet
/// @notice Deploy Chainlink-compatible feeds on testnet and sync PledgeOracle from feed prices.
/// @dev Existing vault keeps PledgeOracle; UI reads feeds directly via latestRoundData().
contract SetupChainlinkTestnet is Script {
    struct MarketFeed {
        string symbol;
        address collateral;
        int256 priceUsd8;
    }

    function run() external {
        uint256 deployerKey = _deployerPrivateKey();
        address deployer = vm.addr(deployerKey);
        address oracleAddr = vm.envAddress("PLEDGE_ORACLE");

        PledgeOracle oracle = PledgeOracle(oracleAddr);
        MarketFeed[] memory markets = _markets();

        console2.log("Protocol:", PledgeProtocol.NAME);
        console2.log("PledgeOracle:", oracleAddr);
        console2.log("Deployer:", deployer);
        console2.log("Markets:", markets.length);

        vm.startBroadcast(deployerKey);

        for (uint256 i = 0; i < markets.length; i++) {
            MarketFeed memory m = markets[i];
            MockChainlinkFeed feed =
                new MockChainlinkFeed(string.concat("m", m.symbol, " / USD"), m.priceUsd8, deployer);

            uint256 price18 = uint256(m.priceUsd8) * 1e10;
            oracle.setPrice(m.collateral, price18);

            console2.log("---");
            console2.log("Symbol", m.symbol);
            console2.log("Collateral", m.collateral);
            console2.log("ChainlinkFeed", address(feed));
            console2.log("OraclePrice18", price18);
        }

        vm.stopBroadcast();

        console2.log("Add chainlinkFeed addresses to deployments/46630.json");
    }

    function _markets() internal pure returns (MarketFeed[] memory) {
        MarketFeed[] memory markets = new MarketFeed[](7);

        markets[0] = MarketFeed("NVDA", 0x635d4c04cAB57B5a1f5753862c8E2A4f3d1C7c5f, 509_00000000);
        markets[1] = MarketFeed("SPY", 0x729d77494d287e0F60d4a3d0DAfc0bFa884bA250, 521_40000000);
        markets[2] = MarketFeed("AAPL", 0x6FC38E8038278B8991466629c8a849112bb43ACe, 219_80000000);
        markets[3] = MarketFeed("QQQ", 0xf486F332A162CC4bb844506254a649C300D64e9b, 448_60000000);
        markets[4] = MarketFeed("MSFT", 0x8F59FE3b42bEb9b0578870ebf354C66A830edd13, 415_30000000);
        markets[5] = MarketFeed("AMZN", 0x824f4060B0E368c87F75ce27b4E8816BEfE140E8, 198_40000000);
        markets[6] = MarketFeed("META", 0x604024d1E16120679AccBBdb664Ede3D0A0A90EE, 512_70000000);

        return markets;
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
