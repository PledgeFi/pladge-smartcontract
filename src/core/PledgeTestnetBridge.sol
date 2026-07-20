// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

/// @title PledgeTestnetBridge
/// @notice Cross-chain ingress with EIP-712 source attestation and destination settlement.
/// @dev Users sign a source-chain transfer intent off-chain, then complete settlement on Robinhood.
contract PledgeTestnetBridge is Ownable, ReentrancyGuard, EIP712 {
    using SafeERC20 for IERC20;

    bytes32 public constant BRIDGE_TYPEHASH = keccak256(
        "BridgeInitiation(address user,uint256 sourceChainId,bytes32 tokenKey,uint256 amount,uint256 nonce,uint256 deadline)"
    );

    uint256 public constant COOLDOWN = 24 hours;

    struct Route {
        address token;
        uint256 minAmount;
        uint256 maxAmount;
        bool enabled;
    }

    mapping(bytes32 routeId => Route route) private _routes;
    mapping(address user => mapping(bytes32 routeId => uint256 timestamp)) public lastClaimAt;
    mapping(address user => uint256 nonce) public nonces;

    event RouteSet(
        uint256 indexed sourceChainId,
        bytes32 indexed tokenKey,
        address token,
        uint256 minAmount,
        uint256 maxAmount,
        bool enabled
    );
    event SourceAttested(
        address indexed user,
        uint256 indexed sourceChainId,
        bytes32 indexed tokenKey,
        uint256 amount,
        uint256 nonce,
        uint256 deadline
    );
    event Bridged(
        address indexed user, uint256 indexed sourceChainId, bytes32 indexed tokenKey, address token, uint256 amount
    );
    event Funded(address indexed token, uint256 amount);

    error RouteDisabled();
    error AmountOutOfRange(uint256 minAmount, uint256 maxAmount);
    error CooldownActive(uint256 availableAt);
    error InsufficientLiquidity();
    error Expired();
    error InvalidNonce();
    error InvalidSignature();

    constructor(address owner_) Ownable(owner_) EIP712("Pledge Bridge", "2") {}

    function routeKey(string calldata tokenSymbol) public pure returns (bytes32) {
        return keccak256(bytes(tokenSymbol));
    }

    function routeId(uint256 sourceChainId, bytes32 tokenKey) public pure returns (bytes32) {
        return keccak256(abi.encode(sourceChainId, tokenKey));
    }

    function setRoute(
        uint256 sourceChainId,
        string calldata tokenSymbol,
        address token,
        uint256 minAmount,
        uint256 maxAmount,
        bool enabled
    ) external onlyOwner {
        bytes32 key = routeKey(tokenSymbol);
        bytes32 id = routeId(sourceChainId, key);
        _routes[id] = Route({token: token, minAmount: minAmount, maxAmount: maxAmount, enabled: enabled});
        emit RouteSet(sourceChainId, key, token, minAmount, maxAmount, enabled);
    }

    function fund(address token, uint256 amount) external {
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        emit Funded(token, amount);
    }

    function computeDigest(
        address user,
        uint256 sourceChainId,
        string calldata tokenSymbol,
        uint256 amount,
        uint256 nonce_,
        uint256 deadline
    ) external view returns (bytes32) {
        bytes32 key = routeKey(tokenSymbol);
        bytes32 structHash =
            keccak256(abi.encode(BRIDGE_TYPEHASH, user, sourceChainId, key, amount, nonce_, deadline));
        return _hashTypedDataV4(structHash);
    }

    function completeBridge(
        uint256 sourceChainId,
        string calldata tokenSymbol,
        uint256 amount,
        uint256 nonce_,
        uint256 deadline,
        bytes calldata signature
    ) external nonReentrant {
        if (block.timestamp > deadline) revert Expired();
        if (nonce_ != nonces[msg.sender]) revert InvalidNonce();

        bytes32 key = routeKey(tokenSymbol);
        bytes32 id = routeId(sourceChainId, key);

        bytes32 digest = this.computeDigest(msg.sender, sourceChainId, tokenSymbol, amount, nonce_, deadline);
        address signer = ECDSA.recover(digest, signature);
        if (signer != msg.sender) revert InvalidSignature();

        emit SourceAttested(msg.sender, sourceChainId, key, amount, nonce_, deadline);
        nonces[msg.sender] = nonce_ + 1;

        Route memory route = _routes[id];
        if (!route.enabled || route.token == address(0) || route.maxAmount == 0) revert RouteDisabled();
        if (amount < route.minAmount || amount > route.maxAmount) {
            revert AmountOutOfRange(route.minAmount, route.maxAmount);
        }

        uint256 last = lastClaimAt[msg.sender][id];
        if (last != 0) {
            uint256 availableAt = last + COOLDOWN;
            if (block.timestamp < availableAt) revert CooldownActive(availableAt);
        }
        lastClaimAt[msg.sender][id] = block.timestamp;

        if (IERC20(route.token).balanceOf(address(this)) < amount) revert InsufficientLiquidity();
        IERC20(route.token).safeTransfer(msg.sender, amount);

        emit Bridged(msg.sender, sourceChainId, key, route.token, amount);
    }

    function cooldownRemaining(address user, uint256 sourceChainId, string calldata tokenSymbol)
        external
        view
        returns (uint256)
    {
        bytes32 id = routeId(sourceChainId, routeKey(tokenSymbol));
        uint256 last = lastClaimAt[user][id];
        if (last == 0) return 0;
        uint256 availableAt = last + COOLDOWN;
        if (block.timestamp >= availableAt) return 0;
        return availableAt - block.timestamp;
    }

    function getRoute(uint256 sourceChainId, string calldata tokenSymbol)
        external
        view
        returns (address token, uint256 minAmount, uint256 maxAmount, bool enabled)
    {
        Route memory route = _routes[routeId(sourceChainId, routeKey(tokenSymbol))];
        return (route.token, route.minAmount, route.maxAmount, route.enabled);
    }

    function liquidity(address token) external view returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }
}
