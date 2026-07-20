// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {PledgeProtocol} from "../src/PledgeProtocol.sol";
import {PledgeTestnetBridge} from "../src/core/PledgeTestnetBridge.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";

/// @title DeployBridge
/// @notice Deploy and fund PledgeTestnetBridge on Robinhood testnet (46630).
contract DeployBridge is Script {
    uint256 internal constant ETH_MAINNET = 1;
    uint256 internal constant BASE = 8453;
    uint256 internal constant ARBITRUM = 42161;

    uint256 internal constant USDG_MIN = 10e18;
    uint256 internal constant USDG_MAX = 10_000e18;
    uint256 internal constant USDC_MIN = 25e18;
    uint256 internal constant USDC_MAX = 10_000e18;
    uint256 internal constant EQUITY_MIN = 1e18;
    uint256 internal constant EQUITY_MAX = 1_000e18;

    uint256 internal constant FUND_USDG = 2_000_000e18;
    uint256 internal constant FUND_EQUITY = 2_000e18;

    function run() external {
        uint256 deployerKey = _deployerPrivateKey();
        address deployer = vm.addr(deployerKey);

        address usdg = vm.envAddress("USDG_TOKEN");

        console2.log("Protocol:", PledgeProtocol.NAME);
        console2.log("Deployer:", deployer);

        vm.startBroadcast(deployerKey);

        PledgeTestnetBridge bridge = new PledgeTestnetBridge(deployer);

        _configureRoutes(bridge, usdg);

        _fundToken(bridge, usdg, FUND_USDG, deployer);
        _fundToken(bridge, 0x635d4c04cAB57B5a1f5753862c8E2A4f3d1C7c5f, FUND_EQUITY, deployer);
        _fundToken(bridge, 0x729d77494d287e0F60d4a3d0DAfc0bFa884bA250, FUND_EQUITY, deployer);
        _fundToken(bridge, 0x6FC38E8038278B8991466629c8a849112bb43ACe, FUND_EQUITY, deployer);
        _fundToken(bridge, 0xf486F332A162CC4bb844506254a649C300D64e9b, FUND_EQUITY, deployer);
        _fundToken(bridge, 0x8F59FE3b42bEb9b0578870ebf354C66A830edd13, FUND_EQUITY, deployer);
        _fundToken(bridge, 0x824f4060B0E368c87F75ce27b4E8816BEfE140E8, FUND_EQUITY, deployer);
        _fundToken(bridge, 0x604024d1E16120679AccBBdb664Ede3D0A0A90EE, FUND_EQUITY, deployer);

        vm.stopBroadcast();

        console2.log("PledgeTestnetBridge", address(bridge));
    }

    function _configureRoutes(PledgeTestnetBridge bridge, address usdg) internal {
        string[7] memory equities = ["mNVDA", "mSPY", "mAAPL", "mQQQ", "mMSFT", "mAMZN", "mMETA"];
        address[7] memory tokens = [
            0x635d4c04cAB57B5a1f5753862c8E2A4f3d1C7c5f,
            0x729d77494d287e0F60d4a3d0DAfc0bFa884bA250,
            0x6FC38E8038278B8991466629c8a849112bb43ACe,
            0xf486F332A162CC4bb844506254a649C300D64e9b,
            0x8F59FE3b42bEb9b0578870ebf354C66A830edd13,
            0x824f4060B0E368c87F75ce27b4E8816BEfE140E8,
            0x604024d1E16120679AccBBdb664Ede3D0A0A90EE
        ];

        uint256[3] memory chains = [ETH_MAINNET, BASE, ARBITRUM];

        for (uint256 c = 0; c < chains.length; c++) {
            uint256 chainId = chains[c];
            bridge.setRoute(chainId, "USDG", usdg, USDG_MIN, USDG_MAX, true);
            bridge.setRoute(chainId, "USDC", usdg, USDC_MIN, USDC_MAX, true);

            for (uint256 i = 0; i < equities.length; i++) {
                bridge.setRoute(chainId, equities[i], tokens[i], EQUITY_MIN, EQUITY_MAX, true);
            }
        }
    }

    function _fundToken(PledgeTestnetBridge bridge, address token, uint256 amount, address deployer) internal {
        MockERC20(token).mint(deployer, amount);
        IERC20(token).approve(address(bridge), amount);
        bridge.fund(token, amount);
        console2.log("Funded", token, amount);
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
