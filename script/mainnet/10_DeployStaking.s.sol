// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {console2} from "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {PledgeFinanceStaking} from "../../src/upgrade/PledgeFinanceProxies.sol";
import {PledgeStaking} from "../../src/core/PledgeStaking.sol";
import {MainnetBase} from "./MainnetBase.sol";

/// @title DeployStakingMainnet
/// @notice Step 10. Fresh staking proxy using the live PLG token.
/// @dev Two pools: PLG staked for PLG rewards over a 90 day program, and USDG staked for PLG at a
///      zero rate until a rate is set. `fundRewards` moves the whole reward reserve up front
///      because the contract has no accounting that would stop `claim` reverting if underfunded.
contract DeployStakingMainnet is MainnetBase {
    uint256 internal constant STAKING_REWARDS = 550_000e18;
    uint256 internal constant PROGRAM_DURATION = 90 days;

    function run() external onlyMainnet {
        uint256 key = deployerKey();
        address deployer = vm.addr(key);
        uint256 rewardRate = STAKING_REWARDS / PROGRAM_DURATION;

        require(PLG.code.length > 0, "staking: PLG missing");
        require(IERC20(PLG).balanceOf(deployer) >= STAKING_REWARDS, "staking: need 550k PLG");

        console2.log("PLG", PLG);
        console2.log("reward reserve", STAKING_REWARDS);
        console2.log("reward rate per second", rewardRate);

        vm.startBroadcast(key);
        PledgeStaking implementation = new PledgeStaking(address(0));
        PledgeFinanceStaking proxy =
            new PledgeFinanceStaking(address(implementation), abi.encodeCall(PledgeStaking.initialize, (deployer)));
        PledgeStaking staking = PledgeStaking(address(proxy));

        uint256 plgPool = staking.addPool(PLG, PLG, rewardRate, 1 days, 90 days, true);
        staking.setPoolName(plgPool, "PLG Staking");

        uint256 usdgPool = staking.addPool(USDG, PLG, 0, 0, true);
        staking.setPoolName(usdgPool, "USDG Staking");

        IERC20(PLG).approve(address(staking), STAKING_REWARDS);
        staking.fundRewards(plgPool, STAKING_REWARDS);
        vm.stopBroadcast();

        require(staking.owner() == deployer, "staking: owner mismatch");
        require(staking.poolCount() == 2, "staking: wrong pool count");

        console2.log("implementation", address(implementation));
        console2.log("proxy (use this)", address(proxy));
        console2.log("PLG pool id", plgPool);
        console2.log("USDG pool id", usdgPool);
        console2.log("Next:");
        logExport("PLEDGE_STAKING_IMPL", address(implementation));
        logExport("PLEDGE_STAKING_PROXY", address(proxy));
    }
}
