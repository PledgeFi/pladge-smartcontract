// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ISwapRouter02 {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    function exactInputSingle(ExactInputSingleParams calldata params)
        external
        payable
        returns (uint256 amountOut);
}

/// @notice Swap a small ETH amount for Paxos USDG on Uniswap v3, then seed the vault.
contract SwapEthForUsdg is Script {
    address internal constant WETH = 0x0Bd7D308f8E1639FAb988df18A8011f41EAcAD73;
    address internal constant USDG = 0x5fc5360D0400a0Fd4f2af552ADD042D716F1d168;
    address internal constant ROUTER = 0xCaf681a66D020601342297493863E78C959E5cb2;
    uint24 internal constant FEE = 100;
    uint256 internal constant AMOUNT_IN = 0.002 ether;
    uint256 internal constant MIN_OUT = 4_650_000; // ~4.65 USDG, ~2.5% below quote

    function run() external {
        uint256 deployerKey = _deployerPrivateKey();
        address deployer = vm.addr(deployerKey);

        console2.log("Deployer", deployer);
        console2.log("ETH in", AMOUNT_IN);

        vm.startBroadcast(deployerKey);
        uint256 amountOut = ISwapRouter02(ROUTER).exactInputSingle{value: AMOUNT_IN}(
            ISwapRouter02.ExactInputSingleParams({
                tokenIn: WETH,
                tokenOut: USDG,
                fee: FEE,
                recipient: deployer,
                amountIn: AMOUNT_IN,
                amountOutMinimum: MIN_OUT,
                sqrtPriceLimitX96: 0
            })
        );
        vm.stopBroadcast();

        console2.log("USDG out", amountOut);
        console2.log("Wallet USDG", IERC20(USDG).balanceOf(deployer));
    }

    function _deployerPrivateKey() private view returns (uint256) {
        string memory raw = vm.envString("DEPLOYER_PRIVATE_KEY");
        bytes memory chars = bytes(raw);
        if (chars.length >= 2 && chars[0] == "0" && chars[1] == "x") {
            return vm.parseUint(raw);
        }
        return vm.parseUint(string.concat("0x", raw));
    }
}
