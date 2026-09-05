// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {PledgeUupsOwnable} from "../upgrade/PledgeUupsOwnable.sol";

/// @title PledgeTestnetBridge
/// @notice Cross-chain ingress with EIP-712 source attestation, on-chain payment, and destination settlement.
/// @dev Production: deploy behind ERC1967Proxy. Tests may pass owner in the constructor.
contract PledgeTestnetBridge is PledgeUupsOwnable, ReentrancyGuard, EIP712 {
    using SafeERC20 for IERC20;

    bytes32 public constant PAY_ETH = keccak256("ETH");
    bytes32 public constant PAY_USDC = keccak256("USDC");
    bytes32 public constant PAY_USDG = keccak256("USDG");

    bytes32 public constant BRIDGE_TYPEHASH = keccak256(
        "BridgeInitiation(address user,uint256 sourceChainId,bytes32 tokenKey,uint256 amount,bytes32 payAssetKey,uint256 payAmount,uint256 nonce,uint256 deadline)"
    );

    uint256 public cooldownDuration;
    address public usdgPayToken;

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
    event UsdgPayTokenSet(address indexed token);
    event SourceAttested(
        address indexed user,
        uint256 indexed sourceChainId,
        bytes32 indexed tokenKey,
        uint256 amount,
        bytes32 payAssetKey,
        uint256 payAmount,
        uint256 nonce,
        uint256 deadline
    );
    event PaymentReceived(address indexed user, bytes32 indexed payAssetKey, uint256 amount);
    event Bridged(
        address indexed user, uint256 indexed sourceChainId, bytes32 indexed tokenKey, address token, uint256 amount
    );
    event Funded(address indexed token, uint256 amount);
    event NativeWithdrawn(address indexed to, uint256 amount);

    error RouteDisabled();
    error AmountOutOfRange(uint256 minAmount, uint256 maxAmount);
    error CooldownActive(uint256 availableAt);
    error InsufficientLiquidity();
    error Expired();
    error InvalidNonce();
    error InvalidSignature();
    error InvalidPayment();
    error UnsupportedPayAsset();
    error PaymentTokenNotSet();
    error ZeroPayAmount();

    constructor(address owner_) EIP712("Pledge Bridge", "3") {
        _disableAndMaybeSetOwner(owner_);
    }

    function initialize(address owner_) external initializer {
        _initOwner(owner_);
    }

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

    function setUsdgPayToken(address token) external onlyOwner {
        usdgPayToken = token;
        emit UsdgPayTokenSet(token);
    }

    function setCooldownDuration(uint256 duration) external onlyOwner {
        cooldownDuration = duration;
    }

    function fund(address token, uint256 amount) external {
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        emit Funded(token, amount);
    }

    function withdrawNative(address to, uint256 amount) external onlyOwner {
        (bool ok,) = to.call{value: amount}("");
        require(ok, "withdraw failed");
        emit NativeWithdrawn(to, amount);
    }

    function computeDigest(
        address user,
        uint256 sourceChainId,
        string calldata tokenSymbol,
        uint256 amount,
        bytes32 payAssetKey,
        uint256 payAmount,
        uint256 nonce_,
        uint256 deadline
    ) external view returns (bytes32) {
        bytes32 key = routeKey(tokenSymbol);
        bytes32 structHash = keccak256(
            abi.encode(BRIDGE_TYPEHASH, user, sourceChainId, key, amount, payAssetKey, payAmount, nonce_, deadline)
        );
        return _hashTypedDataV4(structHash);
    }

    function completeBridge(
        uint256 sourceChainId,
        string calldata tokenSymbol,
        uint256 amount,
        bytes32 payAssetKey,
        uint256 payAmount,
        uint256 nonce_,
        uint256 deadline,
        bytes calldata signature
    ) external payable nonReentrant {
        if (block.timestamp > deadline) revert Expired();
        if (nonce_ != nonces[msg.sender]) revert InvalidNonce();
        if (payAmount == 0) revert ZeroPayAmount();

        bytes32 key = routeKey(tokenSymbol);
        _verifyBridgeSignature(
            msg.sender, sourceChainId, tokenSymbol, amount, payAssetKey, payAmount, nonce_, deadline, signature
        );

        emit SourceAttested(msg.sender, sourceChainId, key, amount, payAssetKey, payAmount, nonce_, deadline);
        nonces[msg.sender] = nonce_ + 1;

        _collectPayment(payAssetKey, payAmount);

        bytes32 id = routeId(sourceChainId, key);
        address token = _prepareRoute(id, amount, msg.sender);
        _releaseTokens(msg.sender, sourceChainId, key, token, amount);
    }

    function _verifyBridgeSignature(
        address user,
        uint256 sourceChainId,
        string calldata tokenSymbol,
        uint256 amount,
        bytes32 payAssetKey,
        uint256 payAmount,
        uint256 nonce_,
        uint256 deadline,
        bytes calldata signature
    ) internal view {
        bytes32 digest =
            this.computeDigest(user, sourceChainId, tokenSymbol, amount, payAssetKey, payAmount, nonce_, deadline);
        if (ECDSA.recover(digest, signature) != user) revert InvalidSignature();
    }

    function _prepareRoute(bytes32 id, uint256 amount, address user) internal returns (address token) {
        Route memory route = _routes[id];
        if (!route.enabled || route.token == address(0) || route.maxAmount == 0) revert RouteDisabled();
        if (amount < route.minAmount || amount > route.maxAmount) {
            revert AmountOutOfRange(route.minAmount, route.maxAmount);
        }

        if (cooldownDuration > 0) {
            uint256 last = lastClaimAt[user][id];
            if (last != 0) {
                uint256 availableAt = last + cooldownDuration;
                if (block.timestamp < availableAt) revert CooldownActive(availableAt);
            }
            lastClaimAt[user][id] = block.timestamp;
        }

        if (IERC20(route.token).balanceOf(address(this)) < amount) revert InsufficientLiquidity();
        return route.token;
    }

    function _releaseTokens(
        address user,
        uint256 sourceChainId,
        bytes32 key,
        address token,
        uint256 amount
    ) internal {
        IERC20(token).safeTransfer(user, amount);
        emit Bridged(user, sourceChainId, key, token, amount);
    }

    function _collectPayment(bytes32 payAssetKey, uint256 payAmount) internal {
        if (payAssetKey == PAY_ETH) {
            if (msg.value != payAmount) revert InvalidPayment();
            emit PaymentReceived(msg.sender, payAssetKey, payAmount);
            return;
        }

        if (msg.value != 0) revert InvalidPayment();

        if (payAssetKey == PAY_USDC || payAssetKey == PAY_USDG) {
            if (usdgPayToken == address(0)) revert PaymentTokenNotSet();
            IERC20(usdgPayToken).safeTransferFrom(msg.sender, address(this), payAmount);
            emit PaymentReceived(msg.sender, payAssetKey, payAmount);
            return;
        }

        revert UnsupportedPayAsset();
    }

    function cooldownRemaining(address user, uint256 sourceChainId, string calldata tokenSymbol)
        external
        view
        returns (uint256)
    {
        if (cooldownDuration == 0) return 0;

        bytes32 id = routeId(sourceChainId, routeKey(tokenSymbol));
        uint256 last = lastClaimAt[user][id];
        if (last == 0) return 0;
        uint256 availableAt = last + cooldownDuration;
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
