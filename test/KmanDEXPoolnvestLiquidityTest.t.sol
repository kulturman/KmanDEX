// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../src/KmanDEXPool.sol";
import "./ERC20Mock.sol";
import {Test} from "../lib/forge-std/src/Test.sol";

contract KmanDEXPoolInvestLiquidityTest is Test {
    KmanDEXPool public kmanDEXPool;
    ERC20Mock public tokenA;
    ERC20Mock public tokenB;
    address contractAddress;

    function setUp() public {
        tokenA = new ERC20Mock("TokenA", "TKA");
        tokenB = new ERC20Mock("TokenB", "TKB");
        kmanDEXPool = new KmanDEXPool(address(this), address(tokenA), address(tokenB));

        tokenA.approve(address(kmanDEXPool), type(uint256).max);
        tokenB.approve(address(kmanDEXPool), type(uint256).max);
        contractAddress = address(this);
    }

    function testInvestLiquidityWithEmptyPool() public {
        kmanDEXPool.investLiquidity(10000, 5000);

        assertEq(kmanDEXPool.totalShares(), kmanDEXPool.TOTAL_SHARES(), "Total shares should be 1000");
        assertEq(kmanDEXPool.shares(contractAddress), kmanDEXPool.TOTAL_SHARES(), "Sender shares should be 1000");

        assertEq(kmanDEXPool.tokenAAmount(), 10000);
        assertEq(kmanDEXPool.tokenBAmount(), 5000);

        assertEq(kmanDEXPool.invariant(), 10000 * 5000);

        assertEq(tokenA.balanceOf(address(kmanDEXPool)), 10000, "Contract should have 10000 TokenA");
        assertEq(tokenB.balanceOf(address(kmanDEXPool)), 5000, "Contract should have 5000 TokenB");
    }

    function testInvestLiquidityWithNonEmptyPool() public {
        address secondInvestor = address(0x123);

        tokenA.transfer(secondInvestor, 100_000);
        tokenB.transfer(secondInvestor, 100_000);

        kmanDEXPool.investLiquidity(20_000, 10_000);

        vm.startPrank(secondInvestor);
        tokenA.approve(address(kmanDEXPool), type(uint256).max);
        tokenB.approve(address(kmanDEXPool), type(uint256).max);

        kmanDEXPool.investLiquidity(10_000, 5_000);

        assertEq(kmanDEXPool.shares(contractAddress), 1_000, "First investor should have 1000 shares");
        assertEq(kmanDEXPool.shares(secondInvestor), 500, "Second investor should have 500 shares");

        assertEq(kmanDEXPool.totalShares(), 1_500, "Total shares should be 1500");

        assertEq(tokenA.balanceOf(address(kmanDEXPool)), 30_000, "Contract should have 30000 TokenA");
        assertEq(tokenB.balanceOf(address(kmanDEXPool)), 15_000, "Contract should have 15000 TokenB");

        assertEq(kmanDEXPool.tokenAAmount(), 30_000, "TokenA amount should be 30000");
        assertEq(kmanDEXPool.tokenBAmount(), 15_000, "TokenB amount should be 15000");
    }
}
