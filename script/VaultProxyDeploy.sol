// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {PledgeVaultManager} from "../src/core/PledgeVaultManager.sol";
import {ProxyDeploy} from "./ProxyDeploy.sol";

library VaultProxyDeploy {
    function deploy(address usdg, address surplus, address owner)
        internal
        returns (PledgeVaultManager vault, address implementation)
    {
        return ProxyDeploy.vault(usdg, surplus, owner);
    }
}
