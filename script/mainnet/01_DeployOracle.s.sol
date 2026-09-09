// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {console2} from "forge-std/Script.sol";
import {PledgeFinanceOracle} from "../../src/upgrade/PledgeFinanceProxies.sol";
import {PledgeChainlinkOracle} from "../../src/oracle/PledgeChainlinkOracle.sol";
import {MainnetBase} from "./MainnetBase.sol";

/// @title DeployOracleMainnet
/// @notice Step 01. PledgeChainlinkOracle implementation + branded ERC1967 proxy. Owner = deployer.
contract DeployOracleMainnet is MainnetBase {
    function run() external onlyMainnet {
        uint256 key = deployerKey();
        address deployer = vm.addr(key);

        vm.startBroadcast(key);
        PledgeChainlinkOracle implementation = new PledgeChainlinkOracle();
        PledgeFinanceOracle proxy = new PledgeFinanceOracle(
            address(implementation), abi.encodeCall(PledgeChainlinkOracle.initialize, (deployer))
        );
        vm.stopBroadcast();

        PledgeChainlinkOracle oracle = PledgeChainlinkOracle(address(proxy));
        require(oracle.owner() == deployer, "oracle: owner mismatch");
        require(oracle.maxStaleness() == 24 hours, "oracle: initialize did not run");

        console2.log("implementation", address(implementation));
        console2.log("proxy (use this)", address(proxy));
        console2.log("owner", oracle.owner());
        console2.log("Next:");
        logExport("PLEDGE_ORACLE_IMPL", address(implementation));
        logExport("PLEDGE_ORACLE_PROXY", address(proxy));
    }
}
