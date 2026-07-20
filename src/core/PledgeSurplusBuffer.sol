// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title PledgeSurplusBuffer
/// @author Pledge Finance
/// @notice Pledge Finance protocol treasury for stability fees and origination fees (USDG).
contract PledgeSurplusBuffer is Ownable {
    using SafeERC20 for IERC20;

    IERC20 public immutable usdg;

    event FeeReceived(address indexed from, uint256 amount, bytes32 reason);

    constructor(address usdg_, address owner_) Ownable(owner_) {
        usdg = IERC20(usdg_);
    }

    function receiveFee(uint256 amount, bytes32 reason) external {
        usdg.safeTransferFrom(msg.sender, address(this), amount);
        emit FeeReceived(msg.sender, amount, reason);
    }

    function withdraw(address to, uint256 amount) external onlyOwner {
        usdg.safeTransfer(to, amount);
    }
}
