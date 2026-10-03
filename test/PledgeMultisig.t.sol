// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import {Enum} from "safe-smart-account/contracts/common/Enum.sol";
import {SafeProxy} from "safe-smart-account/contracts/proxies/SafeProxy.sol";
import {Safe} from "safe-smart-account/contracts/Safe.sol";
import {SafeL2} from "safe-smart-account/contracts/SafeL2.sol";
import {PledgeReferralClaim} from "../src/core/PledgeReferralClaim.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {PledgeSafe} from "../script/PledgeSafe.sol";

contract BumpTarget {
    uint256 public n;
    address public lastCaller;

    function bump() external {
        n += 1;
        lastCaller = msg.sender;
    }
}

contract PledgeMultisigTest is Test, PledgeSafe {
    uint256 internal key1 = 0xA11;
    uint256 internal key2 = 0xB22;
    uint256 internal key3 = 0xC33;

    function test_setupRejectsDuplicateOwner() public {
        SafeL2 singleton = new SafeL2();
        SafeProxy proxy = new SafeProxy(address(singleton));
        address[] memory owners = new address[](3);
        owners[0] = vm.addr(key1);
        owners[1] = vm.addr(key2);
        owners[2] = vm.addr(key1);

        vm.expectRevert(bytes("GS204"));
        Safe(payable(address(proxy))).setup(owners, 2, address(0), "", address(0), address(0), 0, payable(address(0)));
    }

    function test_setupRejectsThresholdAboveOwnerCount() public {
        SafeL2 singleton = new SafeL2();
        SafeProxy proxy = new SafeProxy(address(singleton));
        address[] memory owners = new address[](2);
        owners[0] = vm.addr(key1);
        owners[1] = vm.addr(key2);

        vm.expectRevert(bytes("GS201"));
        Safe(payable(address(proxy))).setup(owners, 3, address(0), "", address(0), address(0), 0, payable(address(0)));
    }

    function test_setupRejectsZeroThreshold() public {
        SafeL2 singleton = new SafeL2();
        SafeProxy proxy = new SafeProxy(address(singleton));
        address[] memory owners = new address[](1);
        owners[0] = vm.addr(key1);

        vm.expectRevert(bytes("GS202"));
        Safe(payable(address(proxy))).setup(owners, 0, address(0), "", address(0), address(0), 0, payable(address(0)));
    }

    function test_pledgeSafeIsTwoOfThreeAndTimelockIsSafeOnly() public {
        SafeInfra memory infra = resolveSafeInfra();
        assertTrue(infra.deployedFresh);

        address safe = createPledgeSafe(infra);
        TimelockController timelock = deployPledgeTimelock(safe, address(this));

        Safe wallet = Safe(payable(safe));
        assertEq(wallet.getThreshold(), 2);
        assertEq(wallet.getOwners().length, 3);
        assertTrue(wallet.isOwner(SIGNER_1));
        assertTrue(wallet.isOwner(SIGNER_2));
        assertTrue(wallet.isOwner(SIGNER_3));
        assertEq(timelock.getMinDelay(), 48 hours);
        assertTrue(timelock.hasRole(timelock.PROPOSER_ROLE(), safe));
        assertTrue(timelock.hasRole(timelock.EXECUTOR_ROLE(), safe));
        assertTrue(timelock.hasRole(timelock.CANCELLER_ROLE(), safe));
        assertTrue(timelock.hasRole(timelock.DEFAULT_ADMIN_ROLE(), address(timelock)));
        assertFalse(timelock.hasRole(timelock.DEFAULT_ADMIN_ROLE(), address(this)));
        assertFalse(timelock.hasRole(timelock.PROPOSER_ROLE(), address(this)));
    }

    function test_reusesCanonicalInfraWhenPresent() public {
        SafeInfra memory fresh = resolveSafeInfra();
        vm.etch(CANONICAL_FACTORY, fresh.factory.code);
        vm.etch(CANONICAL_HANDLER, fresh.handler.code);
        vm.etch(CANONICAL_SAFE_L2, fresh.singleton.code);

        SafeInfra memory reused = resolveSafeInfra();
        assertFalse(reused.deployedFresh);
        assertEq(reused.factory, CANONICAL_FACTORY);
        assertEq(reused.handler, CANONICAL_HANDLER);
        assertEq(reused.singleton, CANONICAL_SAFE_L2);
    }

    function test_fallsBackToCanonicalSingletonWhenL2IsMissing() public {
        SafeInfra memory fresh = resolveSafeInfra();
        address l1 = address(new Safe());
        vm.etch(CANONICAL_FACTORY, fresh.factory.code);
        vm.etch(CANONICAL_HANDLER, fresh.handler.code);
        vm.etch(CANONICAL_SAFE, l1.code);

        SafeInfra memory reused = resolveSafeInfra();
        assertFalse(reused.deployedFresh);
        assertEq(reused.singleton, CANONICAL_SAFE);
    }

    function test_twoSignersScheduleAndExecute_oneSignerCannot() public {
        SafeInfra memory infra = resolveSafeInfra();
        address[] memory owners = new address[](3);
        owners[0] = vm.addr(key1);
        owners[1] = vm.addr(key2);
        owners[2] = vm.addr(key3);
        address safeAddr = createSafe(owners, 2, infra, 1);
        Safe safe = Safe(payable(safeAddr));
        TimelockController timelock = deployTimelock(safeAddr);
        BumpTarget target = new BumpTarget();

        bytes memory bump = abi.encodeCall(BumpTarget.bump, ());
        bytes memory scheduleData =
            abi.encodeCall(TimelockController.schedule, (address(target), 0, bump, bytes32(0), bytes32(0), 48 hours));

        uint256[] memory one = new uint256[](1);
        one[0] = key1;
        bytes memory loneSignature = _sign(safe, _sorted(one), address(timelock), scheduleData);
        vm.expectRevert(bytes("GS020"));
        safe.execTransaction(
            address(timelock),
            0,
            scheduleData,
            Enum.Operation.Call,
            0,
            0,
            0,
            address(0),
            payable(address(0)),
            loneSignature
        );
        assertEq(safe.nonce(), 0);

        address signer = vm.addr(key1);
        bytes32 proposerRole = timelock.PROPOSER_ROLE();
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, signer, proposerRole)
        );
        vm.prank(signer);
        timelock.schedule(address(target), 0, bump, bytes32(0), bytes32(0), 48 hours);

        uint256[] memory two = new uint256[](2);
        two[0] = key1;
        two[1] = key3;
        _exec(safe, two, address(timelock), scheduleData);
        assertEq(safe.nonce(), 1);

        vm.warp(block.timestamp + 48 hours);
        bytes memory executeData =
            abi.encodeCall(TimelockController.execute, (address(target), 0, bump, bytes32(0), bytes32(0)));
        _exec(safe, two, address(timelock), executeData);

        assertEq(target.n(), 1);
        assertEq(target.lastCaller(), address(timelock));
    }

    function test_referralOwnerMovesToTimelockSignerStays() public {
        SafeInfra memory infra = resolveSafeInfra();
        address safe = createPledgeSafe(infra);
        TimelockController timelock = deployPledgeTimelock(safe, address(this));
        address claimSigner = address(0xBEEF);
        PledgeReferralClaim claim =
            new PledgeReferralClaim(address(new MockERC20("USDG", "USDG", 6)), claimSigner, address(this));

        claim.transferOwnership(address(timelock));

        assertEq(claim.owner(), address(timelock));
        assertEq(claim.signer(), claimSigner);
    }

    function _exec(Safe safe, uint256[] memory keys, address to, bytes memory data) internal {
        bytes memory signatures = _sign(safe, _sorted(keys), to, data);
        bool ok = safe.execTransaction(
            to, 0, data, Enum.Operation.Call, 0, 0, 0, address(0), payable(address(0)), signatures
        );
        assertTrue(ok);
    }

    function _sign(Safe safe, uint256[] memory ordered, address to, bytes memory data)
        internal
        view
        returns (bytes memory signatures)
    {
        bytes32 hash = _txHash(safe, to, data, safe.nonce());
        for (uint256 i = 0; i < ordered.length; i++) {
            signatures = abi.encodePacked(signatures, _oneSig(ordered[i], hash));
        }
    }

    function _txHash(Safe safe, address to, bytes memory data, uint256 nonce) internal view returns (bytes32) {
        return safe.getTransactionHash(to, 0, data, Enum.Operation.Call, 0, 0, 0, address(0), address(0), nonce);
    }

    function _oneSig(uint256 key, bytes32 hash) internal pure returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(key, hash);
        return abi.encodePacked(r, s, v);
    }

    function _sorted(uint256[] memory keys) internal pure returns (uint256[] memory ordered) {
        ordered = new uint256[](keys.length);
        for (uint256 i = 0; i < keys.length; i++) {
            ordered[i] = keys[i];
        }
        for (uint256 i = 0; i < ordered.length; i++) {
            for (uint256 j = i + 1; j < ordered.length; j++) {
                if (vm.addr(ordered[j]) < vm.addr(ordered[i])) {
                    (ordered[i], ordered[j]) = (ordered[j], ordered[i]);
                }
            }
        }
    }
}
