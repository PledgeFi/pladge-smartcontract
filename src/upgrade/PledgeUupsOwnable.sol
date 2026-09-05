// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";

/// @title PledgeUupsOwnable
/// @notice Shared UUPS owner for protocol contracts. Production: constructor owner = 0, then ERC1967 `initialize`.
abstract contract PledgeUupsOwnable is Initializable, UUPSUpgradeable {
    address public owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    error NotOwner();
    error ZeroAddress();

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    function _disableAndMaybeSetOwner(address owner_) internal {
        if (owner_ != address(0)) {
            owner = owner_;
            emit OwnershipTransferred(address(0), owner_);
        }
        _disableInitializers();
    }

    function _initOwner(address owner_) internal {
        if (owner_ == address(0)) revert ZeroAddress();
        owner = owner_;
        emit OwnershipTransferred(address(0), owner_);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}
}
