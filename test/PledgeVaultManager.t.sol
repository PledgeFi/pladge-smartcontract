// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {PledgeVaultManager} from "../src/core/PledgeVaultManager.sol";
import {PledgeSurplusBuffer} from "../src/core/PledgeSurplusBuffer.sol";
import {PledgeStabilityPool} from "../src/core/PledgeStabilityPool.sol";
import {PledgeOracle} from "../src/oracle/PledgeOracle.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {VaultProxyDeploy} from "../script/VaultProxyDeploy.sol";
import {VaultMath} from "../src/libraries/VaultMath.sol";

contract PledgeVaultManagerTest is Test {
    PledgeVaultManager internal vault;
    PledgeSurplusBuffer internal surplus;
    PledgeStabilityPool internal pool;
    PledgeOracle internal oracle;
    MockERC20 internal usdg;
    MockERC20 internal mNvda;

    address internal admin = address(this);
    address internal alice = address(0xA11CE);
    address internal bob = address(0xB0B);

    uint256 internal constant NVDA_PRICE = 500e18;
    uint16 internal constant MAX_LTV_BPS = 6000;
    uint16 internal constant LIQ_RATIO_BPS = 16600;

    function setUp() public {
        usdg = new MockERC20("Pledge Finance USDG", "USDG", 18);
        mNvda = new MockERC20("Pledge Finance mNVDA", "mNVDA", 18);
        oracle = new PledgeOracle(admin);
        surplus = new PledgeSurplusBuffer(address(usdg), admin);
        vault = new PledgeVaultManager(address(usdg), address(surplus), admin);
        pool = new PledgeStabilityPool(address(usdg), admin);

        oracle.setPrice(address(mNvda), NVDA_PRICE);

        vault.registerMarket(address(mNvda), address(oracle), MAX_LTV_BPS, LIQ_RATIO_BPS, 500, 120, 50);

        usdg.mint(admin, 1_000_000e18);
        usdg.approve(address(vault), type(uint256).max);
        vault.fundLiquidity(500_000e18);

        mNvda.mint(alice, 100e18);
        vm.prank(alice);
        mNvda.approve(address(vault), type(uint256).max);
    }

    function test_depositAndBorrow() public {
        vm.startPrank(alice);
        vault.deposit(address(mNvda), 10e18);
        vault.borrow(address(mNvda), 3000e18);
        vm.stopPrank();

        (uint256 collateral, uint256 debt,) = vault.positions(address(mNvda), alice);
        assertEq(collateral, 10e18);
        assertEq(debt, 3000e18);

        uint256 hf = vault.getHealthFactor(alice, address(mNvda));
        assertGt(hf, VaultMath.WAD);
    }

    function test_repayUnlocksWithdraw() public {
        vm.startPrank(alice);
        vault.deposit(address(mNvda), 10e18);
        vault.borrow(address(mNvda), 2000e18);

        usdg.mint(alice, 3000e18);
        usdg.approve(address(vault), type(uint256).max);
        vault.repay(address(mNvda), 2000e18);
        vault.withdraw(address(mNvda), 10e18);
        vm.stopPrank();

        assertEq(mNvda.balanceOf(alice), 100e18);
    }

    function test_cannotBorrowAboveLtv() public {
        vm.startPrank(alice);
        vault.deposit(address(mNvda), 10e18);
        vm.expectRevert(PledgeVaultManager.ExceedsMaxLtv.selector);
        vault.borrow(address(mNvda), 3001e18);
        vm.stopPrank();
    }

    function test_cannotSelfLiquidate() public {
        vm.startPrank(alice);
        vault.deposit(address(mNvda), 10e18);
        vault.borrow(address(mNvda), 3000e18);
        vm.stopPrank();

        oracle.setPrice(address(mNvda), 280e18);

        usdg.transfer(alice, 5000e18);
        vm.startPrank(alice);
        usdg.approve(address(vault), type(uint256).max);
        vm.expectRevert(PledgeVaultManager.SelfLiquidationNotAllowed.selector);
        vault.liquidate(alice, address(mNvda));
        vm.stopPrank();
    }

    function test_liquidationAfterPriceDrop() public {
        vm.startPrank(alice);
        vault.deposit(address(mNvda), 10e18);
        vault.borrow(address(mNvda), 3000e18);
        vm.stopPrank();

        oracle.setPrice(address(mNvda), 280e18);

        usdg.transfer(bob, 5000e18);
        vm.startPrank(bob);
        usdg.approve(address(vault), type(uint256).max);
        vault.liquidate(alice, address(mNvda));
        vm.stopPrank();

        (uint256 collateral, uint256 debt,) = vault.positions(address(mNvda), alice);
        assertEq(debt, 0);
        assertLt(collateral, 10e18);
        assertGt(mNvda.balanceOf(bob), 0);
    }

    function test_healthFactorAtBoundary() public pure {
        uint256 hf = VaultMath.healthFactor(5000e18, 3000e18, 16600);
        assertGt(hf, VaultMath.WAD);
    }

    function test_borrowWithSixDecimalUsdg() public {
        MockERC20 usdg6 = new MockERC20("USDG", "USDG", 6);
        PledgeSurplusBuffer surplus6 = new PledgeSurplusBuffer(address(usdg6), admin);
        PledgeVaultManager vault6 = new PledgeVaultManager(address(usdg6), address(surplus6), admin);

        vault6.registerMarket(address(mNvda), address(oracle), MAX_LTV_BPS, LIQ_RATIO_BPS, 500, 120, 50);

        usdg6.mint(admin, 1_000_000e6);
        usdg6.approve(address(vault6), type(uint256).max);
        vault6.fundLiquidity(500_000e6);

        vm.startPrank(alice);
        mNvda.approve(address(vault6), type(uint256).max);
        vault6.deposit(address(mNvda), 10e18);
        vault6.borrow(address(mNvda), 3000e6);
        vm.stopPrank();

        (uint256 collateral, uint256 debt,) = vault6.positions(address(mNvda), alice);
        assertEq(collateral, 10e18);
        assertEq(debt, 3000e6);
        assertGt(vault6.getHealthFactor(alice, address(mNvda)), VaultMath.WAD);
    }

    function test_liquidationSeizesCorrectlyWithSixDecimalUsdg() public {
        MockERC20 usdg6 = new MockERC20("USDG", "USDG", 6);
        PledgeSurplusBuffer surplus6 = new PledgeSurplusBuffer(address(usdg6), admin);
        PledgeVaultManager vault6 = new PledgeVaultManager(address(usdg6), address(surplus6), admin);

        vault6.registerMarket(address(mNvda), address(oracle), MAX_LTV_BPS, LIQ_RATIO_BPS, 500, 120, 50);

        usdg6.mint(admin, 1_000_000e6);
        usdg6.approve(address(vault6), type(uint256).max);
        vault6.fundLiquidity(500_000e6);

        vm.startPrank(alice);
        mNvda.approve(address(vault6), type(uint256).max);
        vault6.deposit(address(mNvda), 10e18);
        vault6.borrow(address(mNvda), 3000e6);
        vm.stopPrank();

        oracle.setPrice(address(mNvda), 400e18);

        usdg6.transfer(bob, 5000e6);
        uint256 bobSharesBefore = mNvda.balanceOf(bob);
        vm.startPrank(bob);
        usdg6.approve(address(vault6), type(uint256).max);
        vault6.liquidate(alice, address(mNvda));
        vm.stopPrank();

        (uint256 collateral, uint256 debt,) = vault6.positions(address(mNvda), alice);
        assertEq(debt, 0);
        // 3000 USDG * 1.05 bonus / $400 = 7.875 shares seized, 2.125 left.
        assertEq(collateral, 2.125e18);
        assertEq(mNvda.balanceOf(bob) - bobSharesBefore, 7.875e18);
    }

    function test_repayBreakdownAccruesWithTime() public {
        vm.startPrank(alice);
        vault.deposit(address(mNvda), 10e18);
        vault.borrow(address(mNvda), 2000e18);
        vm.stopPrank();

        (uint256 principal, uint256 interest, uint256 total, uint256 openedAt, uint16 aprBps) =
            vault.getRepayBreakdown(alice, address(mNvda));
        assertEq(principal, 2000e18);
        assertEq(interest, 0);
        assertEq(total, 2000e18);
        assertGt(openedAt, 0);
        assertEq(aprBps, 120);

        vm.warp(block.timestamp + 365 days);

        (principal, interest, total,,) = vault.getRepayBreakdown(alice, address(mNvda));
        assertEq(principal, 2000e18);
        assertEq(interest, 24e18);
        assertEq(total, 2024e18);

        usdg.mint(alice, 2024e18);
        vm.startPrank(alice);
        usdg.approve(address(vault), type(uint256).max);
        vault.repay(address(mNvda), 24e18);
        vm.stopPrank();

        (principal, interest, total, openedAt,) = vault.getRepayBreakdown(alice, address(mNvda));
        assertEq(principal, 2000e18);
        assertEq(interest, 0);
        assertEq(total, 2000e18);
        assertGt(openedAt, 0);

        vm.startPrank(alice);
        vault.repay(address(mNvda), 2000e18);
        vm.stopPrank();

        (principal, interest, total, openedAt,) = vault.getRepayBreakdown(alice, address(mNvda));
        assertEq(principal, 0);
        assertEq(interest, 0);
        assertEq(total, 0);
        assertEq(openedAt, 0);
    }

    function test_inactiveMarketBlocksDepositAndBorrow() public {
        vm.startPrank(alice);
        vault.deposit(address(mNvda), 10e18);
        vault.borrow(address(mNvda), 2000e18);
        vm.stopPrank();

        vault.setMarketActive(address(mNvda), false);

        vm.startPrank(alice);
        vm.expectRevert(PledgeVaultManager.MarketNotActive.selector);
        vault.deposit(address(mNvda), 1e18);
        vm.expectRevert(PledgeVaultManager.MarketNotActive.selector);
        vault.borrow(address(mNvda), 1e18);
        vm.stopPrank();
    }

    function test_inactiveMarketAllowsRepayAndWithdraw() public {
        vm.startPrank(alice);
        vault.deposit(address(mNvda), 10e18);
        vault.borrow(address(mNvda), 2000e18);
        vm.stopPrank();

        vault.setMarketActive(address(mNvda), false);

        usdg.transfer(alice, 2000e18);
        vm.startPrank(alice);
        usdg.approve(address(vault), type(uint256).max);
        vault.repay(address(mNvda), 2000e18);
        vault.withdraw(address(mNvda), 10e18);
        vm.stopPrank();

        assertEq(mNvda.balanceOf(alice), 100e18);
        (uint256 collateral, uint256 debt,) = vault.positions(address(mNvda), alice);
        assertEq(collateral, 0);
        assertEq(debt, 0);
    }

    function test_inactiveMarketAllowsLiquidation() public {
        vm.startPrank(alice);
        vault.deposit(address(mNvda), 10e18);
        vault.borrow(address(mNvda), 3000e18);
        vm.stopPrank();

        oracle.setPrice(address(mNvda), 280e18);
        vault.setMarketActive(address(mNvda), false);

        usdg.transfer(bob, 5000e18);
        vm.startPrank(bob);
        usdg.approve(address(vault), type(uint256).max);
        vault.liquidate(alice, address(mNvda));
        vm.stopPrank();

        (, uint256 debt,) = vault.positions(address(mNvda), alice);
        assertEq(debt, 0);
        assertGt(mNvda.balanceOf(bob), 0);
    }

    function test_unknownMarketStillRevertsOnExitPaths() public {
        address unknown = address(0xDEAD);
        vm.startPrank(alice);
        vm.expectRevert(PledgeVaultManager.MarketUnknown.selector);
        vault.repay(unknown, 1e18);
        vm.expectRevert(PledgeVaultManager.MarketUnknown.selector);
        vault.withdraw(unknown, 1e18);
        vm.expectRevert(PledgeVaultManager.MarketUnknown.selector);
        vault.liquidate(bob, unknown);
        vm.stopPrank();
    }

    function test_ownerCanWithdrawLiquidity() public {
        uint256 beforeBal = usdg.balanceOf(admin);
        vault.withdrawLiquidity(admin, 1000e18);
        assertEq(usdg.balanceOf(admin), beforeBal + 1000e18);
    }

    function test_proxyInitializeAndWithdraw() public {
        (PledgeVaultManager proxied,) = VaultProxyDeploy.deploy(address(usdg), address(surplus), admin);
        assertEq(proxied.owner(), admin);
        assertEq(address(proxied.usdg()), address(usdg));

        proxied.registerMarket(address(mNvda), address(oracle), MAX_LTV_BPS, LIQ_RATIO_BPS, 500, 120, 50);
        usdg.approve(address(proxied), 5_000e18);
        proxied.fundLiquidity(5_000e18);
        proxied.withdrawLiquidity(bob, 5_000e18);
        assertEq(usdg.balanceOf(bob), 5_000e18);
    }
}
