// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {PledgeVaultManager} from "../src/core/PledgeVaultManager.sol";
import {PledgeStabilityPool} from "../src/core/PledgeStabilityPool.sol";

/// @notice Register NVDA/SPY/AAPL, pause the old vault, point the pool at the new proxy.
contract ConfigureProxiedVaultMainnet is Script {
    address internal constant ORACLE = 0x195287cbcd53eF058a3DeC4c6DC8f17Bf79A28d9;
    address internal constant PROXY = 0x1757a7BD9078001adD29d98Ba712DA7ba154C1AE;
    address internal constant OLD_VAULT = 0xf486F332A162CC4bb844506254a649C300D64e9b;
    address internal constant POOL = 0x8570a571CC83f87B3Ca4249B71646Cc807350e14;
    address internal constant NVDA = 0xd0601CE157Db5bdC3162BbaC2a2C8aF5320D9EEC;
    address internal constant SPY = 0x117cc2133c37B721F49dE2A7a74833232B3B4C0C;
    address internal constant AAPL = 0xaF3D76f1834A1d425780943C99Ea8A608f8a93f9;

    function run() external {
        uint256 deployerKey = _deployerPrivateKey();
        address deployer = vm.addr(deployerKey);
        PledgeVaultManager vault = PledgeVaultManager(PROXY);

        require(vault.owner() == deployer, "not proxy owner");

        vm.startBroadcast(deployerKey);
        _registerIfMissing(vault, NVDA, 6000, 16600);
        _registerIfMissing(vault, SPY, 7500, 13300);
        _registerIfMissing(vault, AAPL, 6500, 15300);
        _pauseMarket(PledgeVaultManager(OLD_VAULT), NVDA);
        _pauseMarket(PledgeVaultManager(OLD_VAULT), SPY);
        _pauseMarket(PledgeVaultManager(OLD_VAULT), AAPL);
        PledgeStabilityPool(POOL).setVaultManager(PROXY);
        vm.stopBroadcast();

        console2.log("Configured proxy", PROXY);
    }

    function _registerIfMissing(PledgeVaultManager vault, address token, uint16 maxLtv, uint16 liqRatio) internal {
        (address existing,,,,,,,) = vault.markets(token);
        if (existing != address(0)) return;
        vault.registerMarket(token, ORACLE, maxLtv, liqRatio, 500, 120, 50);
    }

    function _pauseMarket(PledgeVaultManager vault, address token) internal {
        (address existing,,,,,,,) = vault.markets(token);
        if (existing == address(0)) return;
        vault.setMarketActive(token, false);
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
