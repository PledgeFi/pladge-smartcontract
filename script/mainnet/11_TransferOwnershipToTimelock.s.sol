// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {console2} from "forge-std/Script.sol";
import {PledgeUupsOwnable} from "../../src/upgrade/PledgeUupsOwnable.sol";
import {MainnetBase} from "./MainnetBase.sol";

/// @title TransferOwnershipToTimelockMainnet
/// @notice Step 11, final and irreversible. Hands all five proxies to the Timelock.
/// @dev `transferOwnership` is SINGLE STEP: there is no pendingOwner and no acceptOwnership, so
///      ownership moves the instant this broadcasts. A wrong TIMELOCK address permanently bricks
///      every admin action, including upgrades. Run without --broadcast first and read the logs.
///
///      After this, changing anything requires: Safe collects 3-of-4 signatures to schedule() on
///      the Timelock, wait out the delay, then Safe calls execute().
contract TransferOwnershipToTimelockMainnet is MainnetBase {
    function run() external onlyMainnet {
        uint256 key = deployerKey();
        address deployer = vm.addr(key);
        address timelock = vm.envAddress("PLEDGE_TIMELOCK");
        require(timelock != address(0), "timelock: PLEDGE_TIMELOCK not set");
        require(timelock.code.length > 0, "timelock: not a contract");

        address oracle = requireDeployed("PLEDGE_ORACLE_PROXY");
        address surplus = requireDeployed("PLEDGE_SURPLUS_PROXY");
        address vault = requireDeployed("PLEDGE_VAULT_PROXY");
        address pool = requireDeployed("PLEDGE_POOL_PROXY");
        address staking = requireDeployed("PLEDGE_STAKING_PROXY");

        console2.log("deployer", deployer);
        console2.log("new owner (timelock)", timelock);

        vm.startBroadcast(key);
        _transfer(oracle, "oracle", timelock, deployer);
        _transfer(surplus, "surplus", timelock, deployer);
        _transfer(vault, "vault", timelock, deployer);
        _transfer(pool, "pool", timelock, deployer);
        _transfer(staking, "staking", timelock, deployer);
        vm.stopBroadcast();

        console2.log("Done. The deployer EOA no longer controls these contracts.");
    }

    function _transfer(address target, string memory label, address newOwner, address deployer) internal {
        PledgeUupsOwnable ownable = PledgeUupsOwnable(target);
        require(ownable.owner() == deployer, string.concat(label, ": deployer is not the owner"));
        ownable.transferOwnership(newOwner);
        require(ownable.owner() == newOwner, string.concat(label, ": transfer failed"));
        console2.log(string.concat("transferred ", label), target);
    }
}
