// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {PledgeReferralClaim} from "../src/core/PledgeReferralClaim.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";

contract PledgeReferralClaimTest is Test {
    PledgeReferralClaim internal claim;
    MockERC20 internal usdg;

    uint256 internal signerKey = 0xA11CE;
    address internal signer;
    address internal admin = address(this);
    address internal alice = address(0xA11CE);

    function setUp() public {
        signer = vm.addr(signerKey);
        usdg = new MockERC20("USDG", "USDG", 6);
        claim = new PledgeReferralClaim(address(usdg), signer, admin);
        usdg.mint(address(claim), 1_000e6);
    }

    function test_claimPaysDifference() public {
        uint256 lifetime = 10e6;
        uint256 deadline = block.timestamp + 1 hours;
        bytes memory sig = _sign(alice, lifetime, deadline);

        uint256 beforeBal = usdg.balanceOf(alice);
        vm.prank(alice);
        claim.claim(lifetime, deadline, sig);

        assertEq(usdg.balanceOf(alice) - beforeBal, 10e6);
        assertEq(claim.claimed(alice), 10e6);
    }

    function test_secondClaimPaysOnlyDelta() public {
        uint256 firstDeadline = block.timestamp + 1 hours;
        bytes memory firstSig = _sign(alice, 5e6, firstDeadline);
        vm.prank(alice);
        claim.claim(5e6, firstDeadline, firstSig);

        uint256 secondDeadline = block.timestamp + 1 hours;
        bytes memory secondSig = _sign(alice, 12e6, secondDeadline);
        vm.prank(alice);
        claim.claim(12e6, secondDeadline, secondSig);

        assertEq(usdg.balanceOf(alice), 12e6);
        assertEq(claim.claimed(alice), 12e6);
    }

    function test_rejectReplayAndBadSigner() public {
        uint256 deadline = block.timestamp + 1 hours;
        bytes memory sig = _sign(alice, 4e6, deadline);
        vm.prank(alice);
        claim.claim(4e6, deadline, sig);

        vm.expectRevert(PledgeReferralClaim.NothingToClaim.selector);
        vm.prank(alice);
        claim.claim(4e6, deadline, sig);

        uint256 otherKey = 0xB0B;
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(otherKey, claim.digest(alice, 8e6, deadline));
        bytes memory bad = abi.encodePacked(r, s, v);
        vm.expectRevert(PledgeReferralClaim.BadSignature.selector);
        vm.prank(alice);
        claim.claim(8e6, deadline, bad);
    }

    function test_rejectExpiredAndPaused() public {
        vm.warp(1_000);
        uint256 deadline = 999;
        bytes memory expiredSig = _sign(alice, 1e6, deadline);
        vm.expectRevert(PledgeReferralClaim.Expired.selector);
        vm.prank(alice);
        claim.claim(1e6, deadline, expiredSig);

        claim.setPaused(true);
        uint256 live = block.timestamp + 1 hours;
        bytes memory liveSig = _sign(alice, 1e6, live);
        vm.expectRevert(PledgeReferralClaim.ClaimPaused.selector);
        vm.prank(alice);
        claim.claim(1e6, live, liveSig);
    }

    function _sign(address wallet, uint256 amount, uint256 deadline) private view returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerKey, claim.digest(wallet, amount, deadline));
        return abi.encodePacked(r, s, v);
    }
}
