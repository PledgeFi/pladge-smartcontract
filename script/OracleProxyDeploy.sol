// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {PledgeChainlinkOracle} from "../src/oracle/PledgeChainlinkOracle.sol";
import {ProxyDeploy} from "./ProxyDeploy.sol";

library OracleProxyDeploy {
    function deploy(address owner) internal returns (PledgeChainlinkOracle oracle, address implementation) {
        return ProxyDeploy.chainlinkOracle(owner);
    }
}
