// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../lib/forge-std/src/Test.sol";
import "../src/KmanDEXPool.sol";
import {Test} from "../lib/forge-std/src/Test.sol";
import "./ERC20Mock.sol";

contract KmanDEXSwapWithUniswapTest is Test {
    KmanDEXPool public kmanDEXPool;
    address public USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; // USDC
    address public WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; // WETH
    address public contractAddress;
    address public uniswapV2Router = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address public currentUser = address(1);
    address public contractOwner = address(200);

    function setUp() public {
        string memory rpcUrl = vm.rpcUrl("main_net");
        uint256 mainNet = vm.createFork(rpcUrl, 22476889);
        vm.selectFork(mainNet);

        kmanDEXPool = new KmanDEXPool(contractOwner, address(this), address(this), USDC, WETH);
        deal(USDC, address(this), 10000);
        IERC20(USDC).approve(address(kmanDEXPool), type(uint256).max);
    }

    function testSwapWithUniswapWhenNotEnoughLiquidity() public {
        uint256 usdcBalanceBefore = IERC20(USDC).balanceOf(address(kmanDEXPool));
        uint256 wethBalanceBefore = IERC20(WETH).balanceOf(address(kmanDEXPool));

        kmanDEXPool.swap(address(this), USDC, 10000, 1);

        assertEq(IERC20(USDC).balanceOf(address(kmanDEXPool)), usdcBalanceBefore, "USDC balance should be the same");
        assertEq(IERC20(WETH).balanceOf(address(kmanDEXPool)), wethBalanceBefore, "ETH balance should be the same");

        //Contract owner should have the fees
        assertEq(
            IERC20(USDC).balanceOf(contractOwner),
            10000 / kmanDEXPool.UNISWAP_ROUTING_FEE(),
            "Contract owner should have the fees"
        );
    }
}
