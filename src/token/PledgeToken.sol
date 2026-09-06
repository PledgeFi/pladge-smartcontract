// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {PledgeProtocol} from "../PledgeProtocol.sol";

/// @title PledgeToken
/// @author Pledge Finance
/// @notice PLG ERC-20. Cap 55,000,000. Owner mints within the cap.
contract PledgeToken is ERC20, Ownable {
    uint256 public constant MAX_SUPPLY = 55_000_000e18;

    error CapExceeded();

    constructor(address owner_) ERC20(PledgeProtocol.PLG_NAME, PledgeProtocol.PLG_SYMBOL) Ownable(owner_) {}

    function mint(address to, uint256 amount) external onlyOwner {
        if (totalSupply() + amount > MAX_SUPPLY) revert CapExceeded();
        _mint(to, amount);
    }
}
