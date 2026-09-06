// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {PledgeChainlinkOracle} from "../src/oracle/PledgeChainlinkOracle.sol";
import {OracleProxyDeploy} from "../script/OracleProxyDeploy.sol";
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
        (oracle,) = OracleProxyDeploy.deploy(address(this));
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
        (PledgeChainlinkOracle oracle2,) = OracleProxyDeploy.deploy(address(this));
        oracle2.setMaxStaleness(4 days);
        oracle2.setFeed(address(mNvda), address(cheaper));

        vault.setMarketOracle(address(mNvda), address(oracle2));
        assertEq(oracle2.getPrice(address(mNvda)), 250e18);
    }

    function test_getPriceRevertsWhenStale() public {
        assertFalse(oracle.isStale(address(mNvda)));
        vm.warp(block.timestamp + 4 days + 1);
        assertTrue(oracle.isStale(address(mNvda)));
        vm.expectRevert(bytes("ORACLE: stale"));
        oracle.getPrice(address(mNvda));
    }

    function test_getPriceRevertsWhenAnswerIsZero() public {
        feed.setAnswerUnchecked(0);
        assertTrue(oracle.isStale(address(mNvda)));
        vm.expectRevert(bytes("ORACLE: bad price"));
        oracle.getPrice(address(mNvda));
    }

    function test_getPriceRevertsWhenAnswerIsNegative() public {
        feed.setAnswerUnchecked(-1);
        vm.expectRevert(bytes("ORACLE: bad price"));
        oracle.getPrice(address(mNvda));
    }

    function test_staleOracleBlocksVaultActions() public {
        vm.prank(alice);
        vault.deposit(address(mNvda), 10e18);

        vm.warp(block.timestamp + 4 days + 1);
        vm.prank(alice);
        vm.expectRevert(bytes("ORACLE: stale"));
        vault.borrow(address(mNvda), 1e18);
    }

    function test_getPrice_scalesEighteenDecimalFeed() public {
        MockFeedCustomDecimals feed18 = new MockFeedCustomDecimals(18, int256(500e18));
        oracle.setFeed(address(mNvda), address(feed18));
        assertEq(oracle.getPrice(address(mNvda)), 500e18);
    }

    function test_getPrice_scalesSixDecimalFeed() public {
        MockFeedCustomDecimals feed6 = new MockFeedCustomDecimals(6, int256(500e6));
        oracle.setFeed(address(mNvda), address(feed6));
        assertEq(oracle.getPrice(address(mNvda)), 500e18);
    }

    function test_setFeedRevertsOnZeroAddress() public {
        vm.expectRevert(PledgeChainlinkOracle.ZeroAddressFeed.selector);
        oracle.setFeed(address(mNvda), address(0));
    }

    function test_setFeedRevertsOnZeroAsset() public {
        vm.expectRevert(); // ZeroAddress
        oracle.setFeed(address(0), address(feed));
    }

    function test_setFeedRevertsOnEoaFeed() public {
        vm.expectRevert(PledgeChainlinkOracle.FeedNotAContract.selector);
        oracle.setFeed(address(mNvda), alice);
    }

    function test_getPriceRevertsWhenRoundIncomplete() public {
        MockFeedCustomDecimals feedIncomplete = new MockFeedCustomDecimals(8, 500_00000000);
        feedIncomplete.setStartedAt(0);
        oracle.setFeed(address(mNvda), address(feedIncomplete));
        vm.expectRevert(bytes("ORACLE: round incomplete"));
        oracle.getPrice(address(mNvda));
    }

    function test_getPriceRevertsWhenAnsweredInRoundIsStale() public {
        MockFeedCustomDecimals feedStaleRound = new MockFeedCustomDecimals(8, 500_00000000);
        feedStaleRound.setAnsweredInRound(0);
        oracle.setFeed(address(mNvda), address(feedStaleRound));
        vm.expectRevert(bytes("ORACLE: stale round"));
        oracle.getPrice(address(mNvda));
    }

    // --- Price bounds ---

    function test_priceBoundsDefaultOffDoesNotAffectExistingMarket() public view {
        // maxPriceUsd unset (0) => no bounds enforced, unchanged behavior.
        assertEq(oracle.getPrice(address(mNvda)), 500e18);
    }

    function test_setPriceBoundsRevertsWhenMinGteMax() public {
        vm.expectRevert(PledgeChainlinkOracle.InvalidPriceBounds.selector);
        oracle.setPriceBounds(address(mNvda), 100e18, 100e18);
    }

    function test_getPriceRevertsWhenBelowMinBound() public {
        oracle.setPriceBounds(address(mNvda), 600e18, 1000e18);
        vm.expectRevert(bytes("ORACLE: price out of bounds"));
        oracle.getPrice(address(mNvda)); // feed reports 500e18, below the 600e18 floor
    }

    function test_getPriceRevertsWhenAboveMaxBound() public {
        oracle.setPriceBounds(address(mNvda), 1e18, 100e18);
        vm.expectRevert(bytes("ORACLE: price out of bounds"));
        oracle.getPrice(address(mNvda)); // feed reports 500e18, above the 100e18 ceiling
    }

    function test_getPriceSucceedsWithinBounds() public {
        oracle.setPriceBounds(address(mNvda), 1e18, 1000e18);
        assertEq(oracle.getPrice(address(mNvda)), 500e18);
    }

    function test_clearPriceBoundsWithZeroMax() public {
        oracle.setPriceBounds(address(mNvda), 1e18, 100e18);
        oracle.setPriceBounds(address(mNvda), 0, 0);
        assertEq(oracle.getPrice(address(mNvda)), 500e18);
    }

    // --- Fallback feed ---

    function test_setFallbackFeedRevertsOnEoa() public {
        vm.expectRevert(PledgeChainlinkOracle.FeedNotAContract.selector);
        oracle.setFallbackFeed(address(mNvda), alice);
    }

    function test_fallbackFeedUsedWhenPrimaryStale() public {
        vm.warp(block.timestamp + 4 days + 1); // primary now stale
        // Fallback created fresh (after the warp) so it is not stale itself.
        MockChainlinkFeed fallbackFeed = new MockChainlinkFeed("mNVDA / USD", 510_00000000, address(this));
        oracle.setFallbackFeed(address(mNvda), address(fallbackFeed));

        assertEq(oracle.getPrice(address(mNvda)), 510e18);
        assertFalse(oracle.isStale(address(mNvda)));
    }

    function test_fallbackFeedUsedWhenPrimaryAnswerNegative() public {
        MockChainlinkFeed fallbackFeed = new MockChainlinkFeed("mNVDA / USD", 505_00000000, address(this));
        oracle.setFallbackFeed(address(mNvda), address(fallbackFeed));

        feed.setAnswerUnchecked(-1);
        assertEq(oracle.getPrice(address(mNvda)), 505e18);
    }

    function test_getPriceRevertsWhenPrimaryAndFallbackBothFail() public {
        MockChainlinkFeed fallbackFeed = new MockChainlinkFeed("mNVDA / USD", 505_00000000, address(this));
        oracle.setFallbackFeed(address(mNvda), address(fallbackFeed));

        vm.warp(block.timestamp + 4 days + 1);
        fallbackFeed.setAnswerUnchecked(0);
        vm.expectRevert(bytes("ORACLE: primary and fallback both failed"));
        oracle.getPrice(address(mNvda));
    }

    function test_isStaleTrueWhenPrimaryAndFallbackBothFail() public {
        MockChainlinkFeed fallbackFeed = new MockChainlinkFeed("mNVDA / USD", 505_00000000, address(this));
        oracle.setFallbackFeed(address(mNvda), address(fallbackFeed));

        vm.warp(block.timestamp + 4 days + 1);
        fallbackFeed.setAnswerUnchecked(0);
        assertTrue(oracle.isStale(address(mNvda)));
    }

    function test_priceBoundsAlsoApplyToFallbackPrice() public {
        oracle.setPriceBounds(address(mNvda), 1e18, 600e18);
        vm.warp(block.timestamp + 4 days + 1); // force fallback path
        // Fallback created fresh (after the warp) so it is not stale itself.
        MockChainlinkFeed fallbackFeed = new MockChainlinkFeed("mNVDA / USD", 999_00000000, address(this));
        oracle.setFallbackFeed(address(mNvda), address(fallbackFeed));

        vm.expectRevert(bytes("ORACLE: price out of bounds"));
        oracle.getPrice(address(mNvda));
    }

    function test_ownershipTransferIsOneStepAndRejectsZero() public {
        address newOwner = address(0xB0B);
        oracle.transferOwnership(newOwner);
        assertEq(oracle.owner(), newOwner);

        vm.prank(newOwner);
        vm.expectRevert(); // ZeroAddress
        oracle.transferOwnership(address(0));

        // Old owner lost access.
        vm.expectRevert(); // NotOwner
        oracle.setMaxStaleness(1 days);
    }
}

contract MockFeedCustomDecimals {
    uint8 public immutable decimals;
    int256 public answer;
    uint256 public updatedAt;
    uint256 public startedAt;
    uint80 public roundId = 1;
    uint80 public answeredInRound = 1;

    constructor(uint8 decimals_, int256 answer_) {
        decimals = decimals_;
        answer = answer_;
        updatedAt = block.timestamp;
        startedAt = block.timestamp;
    }

    function setStartedAt(uint256 startedAt_) external {
        startedAt = startedAt_;
    }

    function setAnsweredInRound(uint80 answeredInRound_) external {
        answeredInRound = answeredInRound_;
    }

    function latestRoundData()
        external
        view
        returns (uint80 roundId_, int256 answer_, uint256 startedAt_, uint256 updatedAt_, uint80 answeredInRound_)
    {
        return (roundId, answer, startedAt, updatedAt, answeredInRound);
    }
}
