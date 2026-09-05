// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {PledgeVaultManager} from "../src/core/PledgeVaultManager.sol";
import {PledgeSurplusBuffer} from "../src/core/PledgeSurplusBuffer.sol";
import {PledgeStabilityPool} from "../src/core/PledgeStabilityPool.sol";
import {PledgeStaking} from "../src/core/PledgeStaking.sol";
import {PledgeTestnetBridge} from "../src/core/PledgeTestnetBridge.sol";
import {PledgeOracle} from "../src/oracle/PledgeOracle.sol";
import {PledgeChainlinkOracle} from "../src/oracle/PledgeChainlinkOracle.sol";

/// @notice Always return the ERC1967 proxy. Never treat the implementation as the live address.
library ProxyDeploy {
    function vault(address usdg, address surplusBuffer, address owner)
        internal
        returns (PledgeVaultManager proxied, address implementation)
    {
        implementation = address(new PledgeVaultManager(usdg, surplusBuffer, address(0)));
        proxied = PledgeVaultManager(_proxy(implementation, abi.encodeCall(PledgeVaultManager.initialize, (owner))));
    }

    function surplus(address usdg, address owner)
        internal
        returns (PledgeSurplusBuffer proxied, address implementation)
    {
        implementation = address(new PledgeSurplusBuffer(usdg, address(0)));
        proxied = PledgeSurplusBuffer(_proxy(implementation, abi.encodeCall(PledgeSurplusBuffer.initialize, (owner))));
    }

    function pool(address usdg, address owner)
        internal
        returns (PledgeStabilityPool proxied, address implementation)
    {
        implementation = address(new PledgeStabilityPool(usdg, address(0)));
        proxied = PledgeStabilityPool(_proxy(implementation, abi.encodeCall(PledgeStabilityPool.initialize, (owner))));
    }

    function chainlinkOracle(address owner)
        internal
        returns (PledgeChainlinkOracle proxied, address implementation)
    {
        implementation = address(new PledgeChainlinkOracle());
        proxied =
            PledgeChainlinkOracle(_proxy(implementation, abi.encodeCall(PledgeChainlinkOracle.initialize, (owner))));
    }

    function oracle(address owner) internal returns (PledgeOracle proxied, address implementation) {
        implementation = address(new PledgeOracle(address(0)));
        proxied = PledgeOracle(_proxy(implementation, abi.encodeCall(PledgeOracle.initialize, (owner))));
    }

    function staking(address owner) internal returns (PledgeStaking proxied, address implementation) {
        implementation = address(new PledgeStaking(address(0)));
        proxied = PledgeStaking(_proxy(implementation, abi.encodeCall(PledgeStaking.initialize, (owner))));
    }

    function bridge(address owner) internal returns (PledgeTestnetBridge proxied, address implementation) {
        implementation = address(new PledgeTestnetBridge(address(0)));
        proxied = PledgeTestnetBridge(_proxy(implementation, abi.encodeCall(PledgeTestnetBridge.initialize, (owner))));
    }

    function _proxy(address implementation, bytes memory initData) private returns (address) {
        return address(new ERC1967Proxy(implementation, initData));
    }
}
