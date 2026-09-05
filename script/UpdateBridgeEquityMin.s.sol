// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {PledgeTestnetBridge} from "../src/core/PledgeTestnetBridge.sol";

/// @notice Set equity bridge routes to no practical minimum (1 wei) on testnet.
contract UpdateBridgeEquityMin is Script {
    uint256 internal constant ETH_MAINNET = 1;
    uint256 internal constant BASE = 8453;
    uint256 internal constant ARBITRUM = 42161;
    uint256 internal constant EQUITY_MIN = 1;
    uint256 internal constant EQUITY_MAX = 1_000e18;

    function run() external {
        uint256 deployerKey = _deployerPrivateKey();
        address bridgeAddr = vm.envAddress("PLEDGE_BRIDGE");
        PledgeTestnetBridge bridge = PledgeTestnetBridge(bridgeAddr);

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

        console2.log("Bridge:", bridgeAddr);
        console2.log("Equity min (wei):", EQUITY_MIN);

        vm.startBroadcast(deployerKey);

        for (uint256 c = 0; c < chains.length; c++) {
            uint256 chainId = chains[c];
            for (uint256 i = 0; i < equities.length; i++) {
                bridge.setRoute(chainId, equities[i], tokens[i], EQUITY_MIN, EQUITY_MAX, true);
                console2.log("Updated", chainId, equities[i]);
            }
        }

        vm.stopBroadcast();
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
