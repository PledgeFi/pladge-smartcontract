// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {PledgeProtocol} from "../src/PledgeProtocol.sol";
import {PledgeVaultManager} from "../src/core/PledgeVaultManager.sol";
import {PledgeOracle} from "../src/oracle/PledgeOracle.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";

/// @title AddMarkets
/// @author Pledge Finance
/// @notice Deploy collateral tokens and register additional markets on an existing vault.
/// @dev Requires VAULT_MANAGER and PLEDGE_ORACLE in `.env`.
contract AddMarkets is Script {
    struct MarketSeed {
        string symbol;
        uint256 priceUsd; // 18 decimals
        uint16 maxLtvBps;
        uint16 liqRatioBps;
        bool active;
    }

    function run() external {
        uint256 deployerKey = _deployerPrivateKey();
        address vaultAddr = vm.envAddress("VAULT_MANAGER");
        address oracleAddr = vm.envAddress("PLEDGE_ORACLE");

        PledgeVaultManager vault = PledgeVaultManager(vaultAddr);
        PledgeOracle oracle = PledgeOracle(oracleAddr);

        MarketSeed[] memory seeds = _marketSeeds();

        console2.log("Protocol:", PledgeProtocol.NAME);
        console2.log("VaultManager:", vaultAddr);
        console2.log("Oracle:", oracleAddr);
        console2.log("Markets to add:", seeds.length);

        vm.startBroadcast(deployerKey);

        for (uint256 i = 0; i < seeds.length; i++) {
            MarketSeed memory seed = seeds[i];
            string memory name = string.concat("Pledge Finance m", seed.symbol);

            MockERC20 token = new MockERC20(name, seed.symbol, 18);
            oracle.setPrice(address(token), seed.priceUsd);

            vault.registerMarket(
                address(token),
                oracleAddr,
                seed.maxLtvBps,
                seed.liqRatioBps,
                500,
                120,
                50
            );

            if (!seed.active) {
                vault.setMarketActive(address(token), false);
            }

            // Testnet faucet: 1,000 tokens per market to deployer
            token.mint(msg.sender, 1000e18);

            console2.log("---");
            console2.log("Symbol", seed.symbol);
            console2.log("Token", address(token));
            console2.log("MaxLTV bps", seed.maxLtvBps);
            console2.log("LiqRatio bps", seed.liqRatioBps);
            console2.log("Active", seed.active);
        }

        vm.stopBroadcast();
    }

    function _marketSeeds() internal pure returns (MarketSeed[] memory) {
        MarketSeed[] memory seeds = new MarketSeed[](6);

        seeds[0] = MarketSeed("SPY", 521_4e17, 7500, 13300, true);
        seeds[1] = MarketSeed("AAPL", 219_8e17, 6500, 15300, true);
        seeds[2] = MarketSeed("QQQ", 448_6e17, 7000, 14300, true);
        seeds[3] = MarketSeed("MSFT", 415_3e17, 6500, 15300, true);
        seeds[4] = MarketSeed("AMZN", 198_4e17, 5800, 17200, true);
        seeds[5] = MarketSeed("META", 512_7e17, 6200, 16100, true);

        return seeds;
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
