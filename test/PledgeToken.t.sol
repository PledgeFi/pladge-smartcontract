// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {PledgeToken} from "../src/token/PledgeToken.sol";

contract PledgeTokenTest is Test {
    PledgeToken internal plg;
    address internal admin = makeAddr("admin");
    address internal alice = makeAddr("alice");

    function setUp() public {
        plg = new PledgeToken(admin);
    }

    function test_metadata() public view {
        assertEq(plg.name(), "Pledge Finance");
        assertEq(plg.symbol(), "PLG");
        assertEq(plg.decimals(), 18);
        assertEq(plg.MAX_SUPPLY(), 55_000_000e18);
    }

    function test_ownerMintsToCap() public {
        vm.prank(admin);
        plg.mint(alice, 55_000_000e18);
        assertEq(plg.totalSupply(), 55_000_000e18);
        assertEq(plg.balanceOf(alice), 55_000_000e18);

        vm.prank(admin);
        vm.expectRevert(PledgeToken.CapExceeded.selector);
        plg.mint(alice, 1);
    }

    function test_nonOwnerCannotMint() public {
        vm.prank(alice);
        vm.expectRevert();
        plg.mint(alice, 1e18);
    }
}
