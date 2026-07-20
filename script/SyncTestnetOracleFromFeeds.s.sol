// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {PledgeOracle} from "../src/oracle/PledgeOracle.sol";

interface AggregatorV3Interface {
    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);
}

/// @title SyncTestnetOracleFromFeeds
/// @notice Pull MockChainlinkFeed prices into PledgeOracle so vault HF matches UI.
contract SyncTestnetOracleFromFeeds is Script {
    struct MarketFeed {
        string symbol;
        address collateral;
        address feed;
    }

    function run() external {
        uint256 deployerKey = _deployerPrivateKey();
        address oracleAddr = vm.envAddress("PLEDGE_ORACLE");
        PledgeOracle oracle = PledgeOracle(oracleAddr);
        MarketFeed[] memory markets = _markets();

        vm.startBroadcast(deployerKey);

        for (uint256 i = 0; i < markets.length; i++) {
            MarketFeed memory m = markets[i];
            (, int256 answer,,,) = AggregatorV3Interface(m.feed).latestRoundData();
            require(answer > 0, "bad feed answer");

            uint256 price18 = uint256(answer) * 1e10;
            oracle.setPrice(m.collateral, price18);

            console2.log(string.concat(m.symbol, " price18"));
            console2.log(price18);
        }

        vm.stopBroadcast();
    }

    function _markets() internal pure returns (MarketFeed[] memory) {
        MarketFeed[] memory markets = new MarketFeed[](7);

        markets[0] = MarketFeed("NVDA", 0x635d4c04cAB57B5a1f5753862c8E2A4f3d1C7c5f, 0xFd4c378bfc9566fFa4d2005c4eA108Ec0A05682f);
        markets[1] = MarketFeed("SPY", 0x729d77494d287e0F60d4a3d0DAfc0bFa884bA250, 0x9fF9D1B31EEAa93E8C3aA423B4fcf60FCF8739e6);
        markets[2] = MarketFeed("AAPL", 0x6FC38E8038278B8991466629c8a849112bb43ACe, 0x9b5d5decE85ff5d92f391067a93b09081623a0fe);
        markets[3] = MarketFeed("QQQ", 0xf486F332A162CC4bb844506254a649C300D64e9b, 0xA73198e50C2cEfbA1fC49Cd437a8eB2A736d8aC4);
        markets[4] = MarketFeed("MSFT", 0x8F59FE3b42bEb9b0578870ebf354C66A830edd13, 0x4dFC4e7cFf63ce9973f813031625CB89DbA67be5);
        markets[5] = MarketFeed("AMZN", 0x824f4060B0E368c87F75ce27b4E8816BEfE140E8, 0x1757a7BD9078001adD29d98Ba712DA7ba154C1AE);
        markets[6] = MarketFeed("META", 0x604024d1E16120679AccBBdb664Ede3D0A0A90EE, 0x72Ec1C0edaBFCFE2D9dCAf34bf72F6e29FDdCc48);

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
