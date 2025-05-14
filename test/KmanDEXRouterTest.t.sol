// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../src/KmanDEXRouter.sol";
import {Test} from "../lib/forge-std/src/Test.sol";
import {ERC20Mock} from "./ERC20Mock.sol";

contract KmanDEXRouterTest is Test {
    KmanDEXFactory public factory;
    address public uniswapRouter;
    address public feeCollector;

    function setUp() public {
        factory = new KmanDEXFactory();
        uniswapRouter = address(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
        feeCollector = address(0x300);
    }

    function testSwapWithExistingPool() public {
        ERC20Mock tokenA = new ERC20Mock("TokenA", "TKA");
        ERC20Mock tokenB = new ERC20Mock("TokenB", "TKB");

        address pool = factory.createPool(address(tokenA), address(tokenB));

        //Authorize investment in pool
        IERC20(tokenA).approve(pool, type(uint256).max);
        IERC20(tokenB).approve(pool, type(uint256).max);

        KmanDEXPoolInterface(pool).investLiquidity(10_000, 5_000, 1);
        KmanDEXRouter router = new KmanDEXRouter(address(factory), uniswapRouter, feeCollector);
        IERC20(tokenA).approve(address(router), 1_000);

        vm.expectCall(pool, abi.encodeWithSelector(KmanDEXPoolInterface.swap.selector, tokenA, 1_000, 1));

        /*
            Just like when we called the pool directly, testing just one case is enough, we don't really need because we checked
            that the router delegated correctly to the pool, but we keep it for clarity
        */
        uint256 amountOut = router.swap(address(tokenA), address(tokenB), 1_000, 1);
        assertEq(amountOut, 454, "Amount out should be 454");
    }
}
