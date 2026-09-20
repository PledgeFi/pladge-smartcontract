// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {console2} from "forge-std/Script.sol";
import {PledgeReferralClaim} from "../../src/core/PledgeReferralClaim.sol";
import {MainnetBase} from "./MainnetBase.sol";

/// @notice Deploy origination-fee referral claim. User pays gas; contract pays USDG.
/// @dev After deploy, owner funds it: SurplusBuffer.withdraw(claim, amount).
///      Backend signs with REFERRAL_CLAIM_PRIVATE_KEY matching REFERRAL_CLAIM_SIGNER.
contract DeployReferralClaim is MainnetBase {
    function run() external onlyMainnet {
        uint256 key = deployerKey();
        address deployer = vm.addr(key);
        address signer_ = vm.envAddress("REFERRAL_CLAIM_SIGNER");
        address owner_ = vm.envOr("REFERRAL_CLAIM_OWNER", deployer);

        require(signer_ != address(0), "REFERRAL_CLAIM_SIGNER is zero");

        console2.log("Deployer", deployer);
        console2.log("USDG", USDG);
        console2.log("Signer", signer_);
        console2.log("Owner", owner_);

        vm.startBroadcast(key);
        PledgeReferralClaim claim = new PledgeReferralClaim(USDG, signer_, owner_);
        vm.stopBroadcast();

        console2.log("PledgeReferralClaim", address(claim));
        logExport("REFERRAL_CLAIM_ADDRESS", address(claim));
        logExport("NEXT_PUBLIC_REFERRAL_CLAIM_ADDRESS", address(claim));
        console2.log("Fund next: SurplusBuffer.withdraw(claim, amount) from the protocol owner.");
    }
}
