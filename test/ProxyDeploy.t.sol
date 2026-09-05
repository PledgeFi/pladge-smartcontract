// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {PledgeSurplusBuffer} from "../src/core/PledgeSurplusBuffer.sol";
import {PledgeStabilityPool} from "../src/core/PledgeStabilityPool.sol";
import {PledgeStaking} from "../src/core/PledgeStaking.sol";
import {PledgeTestnetBridge} from "../src/core/PledgeTestnetBridge.sol";
import {PledgeOracle} from "../src/oracle/PledgeOracle.sol";
import {ProxyDeploy} from "../script/ProxyDeploy.sol";

contract ProxyDeployTest is Test {
    function test_coreContractsInitializeOnProxy() public {
        address admin = makeAddr("admin");
        MockERC20 usdg = new MockERC20("USDG", "USDG", 18);

        (PledgeSurplusBuffer surplus, address surplusImpl) = ProxyDeploy.surplus(address(usdg), admin);
        (PledgeStabilityPool pool, address poolImpl) = ProxyDeploy.pool(address(usdg), admin);
        (PledgeOracle oracle,) = ProxyDeploy.oracle(admin);
        (PledgeStaking staking,) = ProxyDeploy.staking(admin);
        (PledgeTestnetBridge bridge,) = ProxyDeploy.bridge(admin);

        assertEq(surplus.owner(), admin);
        assertEq(pool.owner(), admin);
        assertEq(oracle.owner(), admin);
        assertEq(staking.owner(), admin);
        assertEq(bridge.owner(), admin);
        assertTrue(address(surplus) != surplusImpl);
        assertTrue(address(pool) != poolImpl);
        assertEq(oracle.maxStaleness(), 24 hours);

        usdg.mint(admin, 100e18);
        vm.startPrank(admin);
        usdg.approve(address(surplus), 40e18);
        surplus.receiveFee(40e18, keccak256("test"));
        surplus.withdraw(admin, 40e18);
        pool.setVaultManager(makeAddr("vault"));
        vm.stopPrank();

        assertEq(usdg.balanceOf(admin), 100e18);
        assertEq(pool.vaultManager(), makeAddr("vault"));
    }

    function test_implementationCannotInitializeTwice() public {
        address admin = makeAddr("admin");
        MockERC20 usdg = new MockERC20("USDG", "USDG", 18);
        (, address implementation) = ProxyDeploy.surplus(address(usdg), admin);
        vm.expectRevert();
        PledgeSurplusBuffer(implementation).initialize(admin);
    }
}
