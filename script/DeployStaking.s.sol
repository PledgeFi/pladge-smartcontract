// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {PledgeProtocol} from "../src/PledgeProtocol.sol";
import {PledgeStaking} from "../src/core/PledgeStaking.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";

/// @title DeployStaking
/// @notice Deploy PLG token + PledgeStaking on existing Robinhood testnet deployment.
/// @dev Requires DEPLOYER_PRIVATE_KEY, USDG_TOKEN in `.env`.
contract DeployStaking is Script {
    function run() external {
        uint256 deployerKey = _deployerPrivateKey();
        address deployer = vm.addr(deployerKey);
        address usdg = vm.envAddress("USDG_TOKEN");

        console2.log("Protocol:", PledgeProtocol.NAME);
        console2.log("Deployer:", deployer);
        console2.log("USDG:", usdg);

        vm.startBroadcast(deployerKey);

        MockERC20 plg = new MockERC20("Pledge Finance PLG", "PLG", 18);
        PledgeStaking staking = new PledgeStaking(deployer);

        // ~0.864 PLG/day total emission per pool at 1e16/sec
        uint256 plgPool = staking.addPool(address(plg), address(plg), 1e16, 7 days, true);
        uint256 usdgPool = staking.addPool(usdg, address(plg), 5e15, 0, true);

        plg.mint(deployer, 2_000_000e18);
        plg.approve(address(staking), type(uint256).max);
        staking.fundRewards(plgPool, 500_000e18);
        staking.fundRewards(usdgPool, 500_000e18);

        vm.stopBroadcast();

        console2.log("PledgeFinancePLG", address(plg));
        console2.log("PledgeStaking", address(staking));
        console2.log("PLG pool id", plgPool);
        console2.log("USDG pool id", usdgPool);
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
