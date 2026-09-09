// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {console2} from "forge-std/Script.sol";
import {PledgeFinanceSurplusBuffer} from "../../src/upgrade/PledgeFinanceProxies.sol";
import {PledgeSurplusBuffer} from "../../src/core/PledgeSurplusBuffer.sol";
import {MainnetBase} from "./MainnetBase.sol";

/// @title DeploySurplusMainnet
/// @notice Step 03. Surplus buffer behind a proxy — unlike the abandoned deployment, where it was
///         a bare contract. Must precede the vault: `surplusBuffer` is immutable in the vault, so
///         this proxy address is baked into the vault implementation bytecode at step 04.
contract DeploySurplusMainnet is MainnetBase {
    function run() external onlyMainnet {
        uint256 key = deployerKey();
        address deployer = vm.addr(key);

        vm.startBroadcast(key);
        PledgeSurplusBuffer implementation = new PledgeSurplusBuffer(USDG, address(0));
        PledgeFinanceSurplusBuffer proxy = new PledgeFinanceSurplusBuffer(
            address(implementation), abi.encodeCall(PledgeSurplusBuffer.initialize, (deployer))
        );
        vm.stopBroadcast();

        PledgeSurplusBuffer surplus = PledgeSurplusBuffer(address(proxy));
        require(surplus.owner() == deployer, "surplus: owner mismatch");
        require(address(surplus.usdg()) == USDG, "surplus: wrong USDG");

        console2.log("implementation", address(implementation));
        console2.log("proxy (use this)", address(proxy));
        console2.log("Next:");
        logExport("PLEDGE_SURPLUS_IMPL", address(implementation));
        logExport("PLEDGE_SURPLUS_PROXY", address(proxy));
    }
}
