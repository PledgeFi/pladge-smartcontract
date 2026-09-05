// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {PledgeVaultManager} from "../src/core/PledgeVaultManager.sol";
import {PledgeSurplusBuffer} from "../src/core/PledgeSurplusBuffer.sol";
import {PledgeStabilityPool} from "../src/core/PledgeStabilityPool.sol";
import {VaultProxyDeploy} from "./VaultProxyDeploy.sol";

/// @title CutoverVaultMainnet
/// @notice Deploy a UUPS-proxied vault, register markets, pause the old vault, retarget the pool.
contract CutoverVaultMainnet is Script {
    address internal constant USDG = 0x5fc5360D0400a0Fd4f2af552ADD042D716F1d168;
    address internal constant SURPLUS = 0xEa30446c46D61514f19c897224E65b13Fb0A826c;
    address internal constant ORACLE = 0x195287cbcd53eF058a3DeC4c6DC8f17Bf79A28d9;
    address internal constant OLD_VAULT = 0xf486F332A162CC4bb844506254a649C300D64e9b;
    address internal constant POOL = 0x8570a571CC83f87B3Ca4249B71646Cc807350e14;

    function run() external {
        uint256 deployerKey = _deployerPrivateKey();
        address deployer = vm.addr(deployerKey);
        uint256 surplusBal = IERC20(USDG).balanceOf(SURPLUS);
        uint256 walletUsdg = IERC20(USDG).balanceOf(deployer);

        console2.log("Deployer", deployer);
        console2.log("Old vault", OLD_VAULT);
        console2.log("ETH", deployer.balance);
        console2.log("Wallet USDG", walletUsdg);
        console2.log("Surplus USDG", surplusBal);
        require(deployer.balance >= 0.0018 ether, "need ~0.002 ETH for vault proxy cutover");

        vm.startBroadcast(deployerKey);

        if (surplusBal > 0 && PledgeSurplusBuffer(SURPLUS).owner() == deployer) {
            PledgeSurplusBuffer(SURPLUS).withdraw(deployer, surplusBal);
        }

        (PledgeVaultManager vault, address implementation) =
            VaultProxyDeploy.deploy(USDG, SURPLUS, deployer);
        _registerLiveMarkets(vault);
        _pauseOldVaultIfOwner(OLD_VAULT, deployer);
        PledgeStabilityPool(POOL).setVaultManager(address(vault));

        uint256 seed = IERC20(USDG).balanceOf(deployer);
        if (seed > 0) {
            IERC20(USDG).approve(address(vault), seed);
            vault.fundLiquidity(seed);
        }

        vm.stopBroadcast();

        console2.log("Implementation", implementation);
        console2.log("PledgeVaultManager proxy", address(vault));
        console2.log("Vault USDG", IERC20(USDG).balanceOf(address(vault)));
        console2.log("Old vault USDG still stuck", IERC20(USDG).balanceOf(OLD_VAULT));
    }

    function _registerLiveMarkets(PledgeVaultManager vault) internal {
        vault.registerMarket(
            0xd0601CE157Db5bdC3162BbaC2a2C8aF5320D9EEC,
            ORACLE,
            6000,
            16600,
            500,
            120,
            50
        );
        vault.registerMarket(
            0x117cc2133c37B721F49dE2A7a74833232B3B4C0C,
            ORACLE,
            7500,
            13300,
            500,
            120,
            50
        );
        vault.registerMarket(
            0xaF3D76f1834A1d425780943C99Ea8A608f8a93f9,
            ORACLE,
            6500,
            15300,
            500,
            120,
            50
        );
        console2.log("Registered NVDA SPY AAPL");
    }

    function _pauseOldVaultIfOwner(address oldVaultAddr, address deployer) internal {
        PledgeVaultManager oldVault = PledgeVaultManager(oldVaultAddr);
        if (oldVault.owner() != deployer) {
            console2.log("skip pause: not owner of old vault");
            return;
        }
        _pauseMarket(oldVault, 0xd0601CE157Db5bdC3162BbaC2a2C8aF5320D9EEC);
        _pauseMarket(oldVault, 0x117cc2133c37B721F49dE2A7a74833232B3B4C0C);
        _pauseMarket(oldVault, 0xaF3D76f1834A1d425780943C99Ea8A608f8a93f9);
        console2.log("Paused old vault markets");
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
