// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {PledgeChainlinkOracle} from "../src/oracle/PledgeChainlinkOracle.sol";
import {MockChainlinkFeed} from "../src/mocks/MockChainlinkFeed.sol";
import {PledgeVaultManager} from "../src/core/PledgeVaultManager.sol";
import {PledgeSurplusBuffer} from "../src/core/PledgeSurplusBuffer.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";

contract PledgeChainlinkOracleTest is Test {
    PledgeChainlinkOracle internal oracle;
    MockChainlinkFeed internal feed;
    MockERC20 internal mNvda;
    PledgeVaultManager internal vault;

    address internal alice = address(0xA11CE);

    function setUp() public {
        mNvda = new MockERC20("Pledge Finance mNVDA", "mNVDA", 18);
        feed = new MockChainlinkFeed("mNVDA / USD", 500_00000000, address(this));
        oracle = new PledgeChainlinkOracle(address(this));
        oracle.setMaxStaleness(4 days);
        oracle.setFeed(address(mNvda), address(feed));

        MockERC20 usdg = new MockERC20("USDG", "USDG", 18);
        PledgeSurplusBuffer surplus = new PledgeSurplusBuffer(address(usdg), address(this));
        vault = new PledgeVaultManager(address(usdg), address(surplus), address(this));

        vault.registerMarket(address(mNvda), address(oracle), 6000, 16600, 500, 120, 50);

        usdg.mint(address(this), 1_000_000e18);
        usdg.approve(address(vault), type(uint256).max);
        vault.fundLiquidity(500_000e18);

        mNvda.mint(alice, 100e18);
        vm.prank(alice);
        mNvda.approve(address(vault), type(uint256).max);
    }

    function test_getPrice_scalesEightDecimalsToEighteen() public view {
        uint256 price = oracle.getPrice(address(mNvda));
        assertEq(price, 500e18);
    }

    function test_borrowUsesChainlinkPrice() public {
        vm.startPrank(alice);
        vault.deposit(address(mNvda), 10e18);
        vault.borrow(address(mNvda), 3000e18);
        vm.stopPrank();

        uint256 hf = vault.getHealthFactor(alice, address(mNvda));
        assertGt(hf, 1e18);
    }

    function test_setMarketOracle_switchesFeed() public {
        MockChainlinkFeed cheaper = new MockChainlinkFeed("mNVDA / USD", 250_00000000, address(this));
        PledgeChainlinkOracle oracle2 = new PledgeChainlinkOracle(address(this));
        oracle2.setMaxStaleness(4 days);
        oracle2.setFeed(address(mNvda), address(cheaper));

        vault.setMarketOracle(address(mNvda), address(oracle2));
        assertEq(oracle2.getPrice(address(mNvda)), 250e18);
    }
}
