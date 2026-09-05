// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {PledgeChainlinkOracle} from "../src/oracle/PledgeChainlinkOracle.sol";

/// @title SetOracleFeeds
/// @notice Wire Chainlink feeds on the mainnet UUPS oracle proxy. Owner-only.
contract SetOracleFeeds is Script {
    address internal constant DEFAULT_ORACLE = 0x195287cbcd53eF058a3DeC4c6DC8f17Bf79A28d9;

    struct Market {
        string symbol;
        address token;
        address feed;
    }

    function run() external {
        uint256 deployerKey = _deployerPrivateKey();
        address deployer = vm.addr(deployerKey);
        address oracleAddr = vm.envOr("MAINNET_ORACLE", DEFAULT_ORACLE);
        PledgeChainlinkOracle oracle = PledgeChainlinkOracle(oracleAddr);

        require(oracle.owner() == deployer, "SetOracleFeeds: not owner");

        Market[] memory markets = _markets();

        vm.startBroadcast(deployerKey);
        oracle.setMaxStaleness(4 days);
        for (uint256 i = 0; i < markets.length; i++) {
            oracle.setFeed(markets[i].token, markets[i].feed);
        }
        vm.stopBroadcast();

        console2.log("oracle", oracleAddr);
        console2.log("maxStaleness", oracle.maxStaleness());
        for (uint256 i = 0; i < markets.length; i++) {
            uint256 price = oracle.getPrice(markets[i].token);
            console2.log(markets[i].symbol);
            console2.log("feed", markets[i].feed);
            console2.log("getPrice 18dec", price);
            console2.log("getPrice USD", price / 1e18);
        }
    }

    function _markets() internal pure returns (Market[] memory markets) {
        markets = new Market[](8);
        markets[0] = Market("SPY", 0x117cc2133c37B721F49dE2A7a74833232B3B4C0C, 0x319724394D3A0e3669269846abE664Cd621f9f6A);
        markets[1] = Market("NVDA", 0xd0601CE157Db5bdC3162BbaC2a2C8aF5320D9EEC, 0x379EC4f7C378F34a1B47E4F3cbeBCbAC3E8E9F15);
        markets[2] = Market("AAPL", 0xaF3D76f1834A1d425780943C99Ea8A608f8a93f9, 0x6B22A786bAa607d76728168703a39Ea9C99f2cD0);
        markets[3] = Market("QQQ", 0xD5f3879160bc7c32ebb4dC785F8a4F505888de68, 0x80901d846d5D7B030F26B480776EE3b29374C2ae);
        markets[4] = Market("MSFT", 0xe93237C50D904957Cf27E7B1133b510C669c2e74, 0x45C3C877C15E6BA2EBB19eA114Ea508d14C1Af2E);
        markets[5] = Market("AMZN", 0x12f190a9F9d7D37a250758b26824B97CE941bF54, 0xD5a1508ceD74c084eBf3cBe853e2C968fB2a651C);
        markets[6] = Market("META", 0xc0D6457C16Cc70d6790Dd43521C899C87ce02f35, 0x7C38C00C30BEe9378381E7B6135d7283356D71b1);
        markets[7] = Market("GOOGL", 0x2e0847E8910a9732eB3fb1bb4b70a580ADAD4FE3, 0xF6f373a037c30F0e5010d854385cA89185AE638b);
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
