// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import {CompatibilityFallbackHandler} from "safe-smart-account/contracts/handler/CompatibilityFallbackHandler.sol";
import {SafeProxyFactory} from "safe-smart-account/contracts/proxies/SafeProxyFactory.sol";
import {Safe} from "safe-smart-account/contracts/Safe.sol";
import {SafeL2} from "safe-smart-account/contracts/SafeL2.sol";

/// @title PledgeSafe
/// @notice Deploys the Pledge 2-of-3 Safe and the 48h timelock it controls.
/// @dev Protocol proxies are not modified here. On a chain that already has the Safe 1.4.1
///      canonical factory, singleton, and fallback handler, those are reused. Otherwise fresh
///      copies are deployed. The three signers are hardcoded so a broadcast cannot swap them
///      through an environment variable.
abstract contract PledgeSafe {
    /// @dev Sorted ascending. Safe signature checks require this order.
    address internal constant SIGNER_1 = 0x229CA6EFbC034bBd0a2c5D4a2a3369A07eD2D829;
    address internal constant SIGNER_2 = 0xBB445d38EE937A88AC87b7c58f16F085dB721A93;
    address internal constant SIGNER_3 = 0xDAe2D6D7d1b58899a8E9aB9834b9de38a21877Ca;

    uint256 internal constant SAFE_THRESHOLD = 2;
    /// @dev Mixed into the CREATE2 salt. Combined with chain id by `createChainSpecificProxyWithNonce`.
    uint256 internal constant SAFE_SALT_NONCE = 0x504c45444745;
    uint256 internal constant TIMELOCK_MIN_DELAY = 48 hours;

    /// @dev Safe 1.4.1 addresses from safe-global/safe-deployments. Same on every chain that used
    ///      the canonical singleton factory.
    address internal constant CANONICAL_SAFE = 0x41675C099F32341bf84BFc5382aF534df5C7461a;
    address internal constant CANONICAL_SAFE_L2 = 0x29fCb43b46531bCA003DDC8fcb67E61280C9732f;
    address internal constant CANONICAL_FACTORY = 0x4e1DCf7AD4e460CfD30791CCC4F9c8a4f820ec67;
    address internal constant CANONICAL_HANDLER = 0xfd0732Dc9E303f09fCEf3a7388Ad10A83459Ec99;

    /// @dev Previous 3-of-4 Safe and the timelock locked to it. Neither can be adopted by the new signers.
    address internal constant RETIRED_SAFE = 0x509dC4A81045F6FA42D388A68e2C65d20d493560;
    address internal constant RETIRED_TIMELOCK = 0x1195e53E30A7645edf1EE7171B5C1CC0e55ebbFD;

    struct SafeInfra {
        address singleton;
        address factory;
        address handler;
        bool deployedFresh;
    }

    function pledgeSigners() public pure returns (address[] memory signers) {
        signers = new address[](3);
        signers[0] = SIGNER_1;
        signers[1] = SIGNER_2;
        signers[2] = SIGNER_3;
    }

    /// @notice Uses the canonical Safe 1.4.1 contracts when all three are already on this chain.
    ///         Deploys a SafeL2 singleton, proxy factory, and fallback handler otherwise.
    function resolveSafeInfra() public returns (SafeInfra memory infra) {
        bool factoryLive = CANONICAL_FACTORY.code.length > 0;
        bool handlerLive = CANONICAL_HANDLER.code.length > 0;
        bool l2Live = CANONICAL_SAFE_L2.code.length > 0;
        bool singletonLive = l2Live || CANONICAL_SAFE.code.length > 0;
        if (factoryLive && handlerLive && singletonLive) {
            infra.singleton = l2Live ? CANONICAL_SAFE_L2 : CANONICAL_SAFE;
            infra.factory = CANONICAL_FACTORY;
            infra.handler = CANONICAL_HANDLER;
            return infra;
        }

        infra.singleton = address(new SafeL2());
        infra.factory = address(new SafeProxyFactory());
        infra.handler = address(new CompatibilityFallbackHandler());
        infra.deployedFresh = true;
    }

    function createSafe(address[] memory owners, uint256 threshold, SafeInfra memory infra, uint256 saltNonce)
        public
        returns (address safe)
    {
        bytes memory initializer = abi.encodeCall(
            Safe.setup, (owners, threshold, address(0), bytes(""), infra.handler, address(0), 0, payable(address(0)))
        );
        safe = address(
            SafeProxyFactory(infra.factory).createChainSpecificProxyWithNonce(infra.singleton, initializer, saltNonce)
        );
    }

    function createPledgeSafe(SafeInfra memory infra) public returns (address safe) {
        safe = createSafe(pledgeSigners(), SAFE_THRESHOLD, infra, SAFE_SALT_NONCE);
        assertPledgeSafe(safe);
    }

    function assertPledgeSafe(address safe) public view {
        require(safe != RETIRED_SAFE, "safe: retired");
        require(safe.code.length > 0, "safe: no code");
        Safe wallet = Safe(payable(safe));
        require(wallet.getThreshold() == SAFE_THRESHOLD, "safe: threshold");
        address[] memory expected = pledgeSigners();
        require(wallet.getOwners().length == expected.length, "safe: owner count");
        for (uint256 i = 0; i < expected.length; i++) {
            require(wallet.isOwner(expected[i]), "safe: missing signer");
        }
    }

    function deployTimelock(address proposer) public returns (TimelockController timelock) {
        address[] memory proposers = new address[](1);
        proposers[0] = proposer;
        address[] memory executors = new address[](1);
        executors[0] = proposer;
        timelock = new TimelockController(TIMELOCK_MIN_DELAY, proposers, executors, address(0));
    }

    function deployPledgeTimelock(address safe, address deployer) public returns (TimelockController timelock) {
        assertPledgeSafe(safe);
        timelock = deployTimelock(safe);
        assertPledgeTimelock(address(timelock), safe, deployer);
    }

    function assertPledgeTimelock(address timelock, address safe, address deployer) public view {
        require(timelock != RETIRED_TIMELOCK, "timelock: retired");
        require(timelock != safe, "timelock: same as safe");
        require(timelock.code.length > 0, "timelock: no code");
        TimelockController controller = TimelockController(payable(timelock));
        require(controller.getMinDelay() == TIMELOCK_MIN_DELAY, "timelock: delay");
        require(controller.hasRole(controller.PROPOSER_ROLE(), safe), "timelock: proposer");
        require(controller.hasRole(controller.EXECUTOR_ROLE(), safe), "timelock: executor");
        require(controller.hasRole(controller.CANCELLER_ROLE(), safe), "timelock: canceller");
        require(controller.hasRole(controller.DEFAULT_ADMIN_ROLE(), timelock), "timelock: self admin");
        require(!controller.hasRole(controller.DEFAULT_ADMIN_ROLE(), deployer), "timelock: deployer admin");
        require(!controller.hasRole(controller.DEFAULT_ADMIN_ROLE(), safe), "timelock: safe admin");
        require(!controller.hasRole(controller.PROPOSER_ROLE(), deployer), "timelock: deployer proposer");
    }
}
