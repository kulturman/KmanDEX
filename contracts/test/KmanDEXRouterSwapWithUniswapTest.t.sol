// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../lib/forge-std/src/Test.sol";
import {KmanDEXPool, IKmanDEXPool} from "../src/KmanDEXPool.sol";
import {Test} from "../lib/forge-std/src/Test.sol";
import {ERC20Mock} from "./ERC20Mock.sol";
import {IERC20} from "../lib/forge-std/src/interfaces/IERC20.sol";
import {KmanDEXRouter} from "../src/KmanDEXRouter.sol";

contract KmanDEXSwapWithUniswapTest is Test {
    KmanDEXRouter kmanDEXRouter;
    address public USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; // USDC
    address public WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; // WETH
    address public contractOwner = address(200);

    function setUp() public {
        string memory rpcUrl = vm.rpcUrl("main_net");
        uint256 mainNet = vm.createFork(rpcUrl, 22476889);
        vm.selectFork(mainNet);

        vm.prank(contractOwner);
        kmanDEXRouter = new KmanDEXRouter();
        deal(USDC, address(this), 10000);
        IERC20(USDC).approve(address(kmanDEXRouter), type(uint256).max);
    }

    function testSwapWithUniswapWhenPoolDoesNotExist() public {
        uint256 usdcBalanceBefore = IERC20(USDC).balanceOf(address(kmanDEXRouter));
        uint256 wethBalanceBefore = IERC20(WETH).balanceOf(address(kmanDEXRouter));

        kmanDEXRouter.swap(USDC, WETH, 10000, 1);

        assertEq(IERC20(USDC).balanceOf(address(kmanDEXRouter)), usdcBalanceBefore, "USDC balance should be the same");
        assertEq(IERC20(WETH).balanceOf(address(kmanDEXRouter)), wethBalanceBefore, "ETH balance should be the same");

        //Contract owner should have the fees
        assertEq(
            IERC20(USDC).balanceOf(contractOwner),
            10000 / kmanDEXRouter.UNISWAP_ROUTING_FEE(),
            "Contract owner should have the fees"
        );
    }
}
