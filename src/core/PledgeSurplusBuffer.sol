// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {PledgeUupsOwnable} from "../upgrade/PledgeUupsOwnable.sol";

/// @title PledgeSurplusBuffer
/// @author Pledge Finance
/// @notice Pledge Finance protocol treasury for stability fees and origination fees (USDG).
/// @dev Production: deploy behind ERC1967Proxy. Tests may pass owner in the constructor.
contract PledgeSurplusBuffer is PledgeUupsOwnable {
    using SafeERC20 for IERC20;

    IERC20 public immutable usdg;

    event FeeReceived(address indexed from, uint256 amount, bytes32 reason);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address usdg_, address owner_) {
        usdg = IERC20(usdg_);
        _disableAndMaybeSetOwner(owner_);
    }

    function initialize(address owner_) external initializer {
        _initOwner(owner_);
    }

    function receiveFee(uint256 amount, bytes32 reason) external {
        usdg.safeTransferFrom(msg.sender, address(this), amount);
        emit FeeReceived(msg.sender, amount, reason);
    }

    function withdraw(address to, uint256 amount) external onlyOwner {
        if (to == address(0)) revert ZeroAddress();
        usdg.safeTransfer(to, amount);
    }
}
