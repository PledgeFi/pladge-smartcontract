// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/// @title Pledge Finance branded proxies
/// @notice Named ERC1967 proxies, one per protocol module.
/// @dev These add no behavior whatsoever — every one is an empty subclass of `ERC1967Proxy` and
///      forwards its constructor unchanged. They exist purely so the deployed address carries a
///      Pledge Finance name in its verified metadata instead of the generic `ERC1967Proxy`, which
///      is what a block explorer displays. A contract's name is bound to its bytecode, so this is
///      the only way to brand an address; it cannot be retrofitted onto an already-deployed proxy.
///
///      Upgrades are unaffected: storage, the ERC1967 implementation slot, and the UUPS
///      `upgradeToAndCall` path all behave exactly as with a plain `ERC1967Proxy`.

contract PledgeFinanceVault is ERC1967Proxy {
    constructor(address implementation, bytes memory data) ERC1967Proxy(implementation, data) {}
}

contract PledgeFinanceOracle is ERC1967Proxy {
    constructor(address implementation, bytes memory data) ERC1967Proxy(implementation, data) {}
}

contract PledgeFinanceSurplusBuffer is ERC1967Proxy {
    constructor(address implementation, bytes memory data) ERC1967Proxy(implementation, data) {}
}

contract PledgeFinanceStabilityPool is ERC1967Proxy {
    constructor(address implementation, bytes memory data) ERC1967Proxy(implementation, data) {}
}

contract PledgeFinanceStaking is ERC1967Proxy {
    constructor(address implementation, bytes memory data) ERC1967Proxy(implementation, data) {}
}
