// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

/// @title PledgeReferralClaim
/// @notice Cumulative EIP-712 claim of origination-fee share. User pays gas.
/// @dev Fund by owner `withdraw` from `PledgeSurplusBuffer` into this contract.
contract PledgeReferralClaim is EIP712 {
    using SafeERC20 for IERC20;

    bytes32 public constant CLAIM_TYPEHASH = keccak256("Claim(address wallet,uint256 amount,uint256 deadline)");

    IERC20 public immutable usdg;
    address public owner;
    address public signer;
    bool public paused;
    mapping(address wallet => uint256 lifetime) public claimed;

    event Claimed(address indexed wallet, uint256 payout, uint256 lifetime);
    event SignerUpdated(address indexed signer);
    event PauseSet(bool paused);
    event Withdrawn(address indexed to, uint256 amount);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    error NotOwner();
    error Unauthorized();
    error Expired();
    error NothingToClaim();
    error BadSignature();
    error ZeroAddress();
    error ClaimPaused();
    error ZeroAmount();

    constructor(address usdg_, address signer_, address owner_) EIP712("PledgeReferralClaim", "1") {
        if (usdg_ == address(0) || signer_ == address(0) || owner_ == address(0)) revert ZeroAddress();
        usdg = IERC20(usdg_);
        signer = signer_;
        owner = owner_;
        emit OwnershipTransferred(address(0), owner_);
        emit SignerUpdated(signer_);
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    /// @param amount Lifetime earned USDG (raw). Pays `amount - claimed[msg.sender]`.
    function claim(uint256 amount, uint256 deadline, bytes calldata signature) external {
        if (paused) revert ClaimPaused();
        if (block.timestamp > deadline) revert Expired();
        if (!_verify(msg.sender, amount, deadline, signature)) revert BadSignature();

        uint256 already = claimed[msg.sender];
        if (amount <= already) revert NothingToClaim();
        uint256 payout = amount - already;
        claimed[msg.sender] = amount;
        usdg.safeTransfer(msg.sender, payout);
        emit Claimed(msg.sender, payout, amount);
    }

    function digest(address wallet, uint256 amount, uint256 deadline) public view returns (bytes32) {
        return _hashTypedDataV4(keccak256(abi.encode(CLAIM_TYPEHASH, wallet, amount, deadline)));
    }

    function setSigner(address signer_) external onlyOwner {
        if (signer_ == address(0)) revert ZeroAddress();
        signer = signer_;
        emit SignerUpdated(signer_);
    }

    function setPaused(bool paused_) external onlyOwner {
        paused = paused_;
        emit PauseSet(paused_);
    }

    function withdraw(address to, uint256 amount) external onlyOwner {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        usdg.safeTransfer(to, amount);
        emit Withdrawn(to, amount);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function _verify(address wallet, uint256 amount, uint256 deadline, bytes calldata signature)
        private
        view
        returns (bool)
    {
        address recovered = ECDSA.recover(digest(wallet, amount, deadline), signature);
        return recovered == signer;
    }
}
