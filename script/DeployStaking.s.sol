// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {PledgeProtocol} from "../src/PledgeProtocol.sol";
import {PledgeStaking} from "../src/core/PledgeStaking.sol";
import {PledgeToken} from "../src/token/PledgeToken.sol";
import {ProxyDeploy} from "./ProxyDeploy.sol";

/// @title DeployStaking
/// @notice UUPS-proxied PledgeStaking on Robinhood Mainnet (4663).
/// @dev PLG is already live. This script does not deploy or mint the token.
contract DeployStaking is Script {
    uint256 internal constant MAINNET_CHAIN_ID = 4663;
    address internal constant USDG = 0x5fc5360D0400a0Fd4f2af552ADD042D716F1d168;
    address internal constant PLG = 0xDfC0a301CA6F62c32800C4827974ECac64BC7e38;
    uint256 internal constant STAKING_REWARDS = 550_000e18;
    uint256 internal constant PROGRAM_DURATION = 90 days;

    function run() external {
        require(block.chainid == MAINNET_CHAIN_ID, "DeployStaking: mainnet 4663 only");
        require(USDG.code.length > 0, "DeployStaking: Paxos USDG missing");
        require(PLG.code.length > 0, "DeployStaking: PLG missing");

        uint256 deployerKey = _deployerPrivateKey();
        address deployer = vm.addr(deployerKey);
        PledgeToken plg = PledgeToken(PLG);
        uint256 plgRate = STAKING_REWARDS / PROGRAM_DURATION;

        console2.log("Protocol:", PledgeProtocol.NAME);
        console2.log("Staking:", PledgeProtocol.STAKING_NAME);
        console2.log("Deployer:", deployer);
        console2.log("ETH:", deployer.balance);
        console2.log("PLG:", PLG);
        console2.log("USDG:", USDG);
        console2.log("PLG rate/sec:", plgRate);

        require(plg.owner() == deployer, "DeployStaking: not PLG owner");
        require(keccak256(bytes(plg.name())) == keccak256(bytes(PledgeProtocol.PLG_NAME)), "DeployStaking: bad PLG name");
        require(plg.balanceOf(deployer) >= STAKING_REWARDS, "DeployStaking: need 550k PLG");
        require(deployer.balance >= 0.003 ether, "need ~0.003 ETH on 4663 for staking CREATE");

        vm.startBroadcast(deployerKey);

        (PledgeStaking staking, address implementation) = ProxyDeploy.staking(deployer);

        uint256 plgPool = staking.addPool(PLG, PLG, plgRate, 1 days, 90 days, true);
        staking.setPoolName(plgPool, "PLG Staking");

        uint256 usdgPool = staking.addPool(USDG, PLG, 0, 0, true);
        staking.setPoolName(usdgPool, "USDG Staking");

        plg.approve(address(staking), STAKING_REWARDS);
        staking.fundRewards(plgPool, STAKING_REWARDS);

        vm.stopBroadcast();

        console2.log("PledgeStaking implementation", implementation);
        console2.log("PledgeStaking proxy", address(staking));
        console2.log("PledgeStaking name", staking.name());
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
