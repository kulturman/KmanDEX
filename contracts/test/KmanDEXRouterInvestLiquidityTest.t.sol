// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import {IKmanDEXPool, KmanDEXPool} from "../src/KmanDEXPool.sol";
import {ERC20Mock} from "./ERC20Mock.sol";
import {Test} from "../lib/forge-std/src/Test.sol";
import {KmanDEXRouter} from "../src/KmanDEXRouter.sol";
import {IKmanDEXFactory} from "../src/KmanDEXFactory.sol";

contract KmanDEXPoolInvestLiquidityTest is Test {
    KmanDEXPool public kmanDEXPool;
    ERC20Mock public tokenA;
    ERC20Mock public tokenB;
    address public contractAddress;
    address public contractOwner = address(2);
    KmanDEXRouter router;

    function setUp() public {
        tokenA = new ERC20Mock("TokenA", "TKA");
        tokenB = new ERC20Mock("TokenB", "TKB");
        contractAddress = address(this);
        router = new KmanDEXRouter();
        address pool = IKmanDEXFactory(router.factory()).createPool(address(tokenA), address(tokenB));
        kmanDEXPool = KmanDEXPool(pool);

        tokenA.approve(address(router), type(uint256).max);
        tokenB.approve(address(router), type(uint256).max);
    }

    function testInvestLiquidityWithEmptyPool() public {
        vm.expectEmit();
        emit IKmanDEXPool.LiquidityAdded(contractAddress, 10000, 5000);
        //kmanDEXPool.investLiquidity(address(this), 10000, 5000, 1);
        router.investLiquidity(address(tokenA), address(tokenB), 10000, 5000, 0);

        assertEq(kmanDEXPool.totalShares(), kmanDEXPool.INITIAL_SHARES(), "Total shares should be 1000");
        assertEq(kmanDEXPool.shares(contractAddress), kmanDEXPool.INITIAL_SHARES(), "Sender shares should be 1000");

        assertEq(kmanDEXPool.tokenAAmount(), 10000);
        assertEq(kmanDEXPool.tokenBAmount(), 5000);

        assertEq(kmanDEXPool.invariant(), 10000 * 5000);

        assertEq(tokenA.balanceOf(address(kmanDEXPool)), 10000, "Contract should have 10000 TokenA");
        assertEq(tokenB.balanceOf(address(kmanDEXPool)), 5000, "Contract should have 5000 TokenB");
    }

    function testRevertsWhenMinimumSharesNotMetOnEmptyPool() public {
        vm.expectRevert(abi.encodeWithSelector(IKmanDEXPool.MinimumSharesNotMet.selector, 2000, 1000));
        router.investLiquidity(address(tokenA), address(tokenB), 10000, 5000, 2000);
    }

    function testRevertsWhenMinimumSharesNotMetOnNonEmptyPool() public {
        router.investLiquidity(address(tokenA), address(tokenB), 10000, 5000, 1);
        vm.expectRevert(abi.encodeWithSelector(IKmanDEXPool.MinimumSharesNotMet.selector, 2000, 1000));
        router.investLiquidity(address(tokenA), address(tokenB), 10000, 5000, 2000);
    }

    function testInvestLiquidityWithNonEmptyPool() public {
        address firstInvestor = contractAddress;
        address secondInvestor = address(0x123);

        tokenA.transfer(firstInvestor, 100_000);
        tokenB.transfer(firstInvestor, 100_000);

        tokenA.transfer(secondInvestor, 100_000);
        tokenB.transfer(secondInvestor, 100_000);

        router.investLiquidity(address(tokenA), address(tokenB), 20_000, 10_000, 1);


        vm.startPrank(secondInvestor);
        tokenA.approve(address(router), type(uint256).max);
        tokenB.approve(address(router), type(uint256).max);
        router.investLiquidity(address(tokenA), address(tokenB), 10_000, 5000, 1);
        vm.stopPrank();

        assertEq(kmanDEXPool.shares(firstInvestor), 1_000, "First investor should have 1000 shares");
        assertEq(kmanDEXPool.shares(secondInvestor), 500, "Second investor should have 500 shares");

        assertEq(kmanDEXPool.totalShares(), 1_500, "Total shares should be 1500");

        assertEq(tokenA.balanceOf(address(kmanDEXPool)), 30_000, "Contract should have 30000 TokenA");
        assertEq(tokenB.balanceOf(address(kmanDEXPool)), 15_000, "Contract should have 15000 TokenB");

        assertEq(kmanDEXPool.tokenAAmount(), 30_000, "TokenA amount should be 30000");
        assertEq(kmanDEXPool.tokenBAmount(), 15_000, "TokenB amount should be 15000");
    }

    function testInvestLiquidityCumulatesForSameInvestor() public {
        router.investLiquidity(address(tokenA), address(tokenB), 20_000, 10_000, 1);
        router.investLiquidity(address(tokenA), address(tokenB), 30_000, 15_000, 1);

        assertEq(kmanDEXPool.shares(contractAddress), 2_500, "First investor should have all shares (1000 + 1500)");
        assertEq(kmanDEXPool.totalShares(), 2_500, "Total shares should be 2500");

        assertEq(tokenA.balanceOf(address(kmanDEXPool)), 50_000, "Contract should have 50000 TokenA");
        assertEq(tokenB.balanceOf(address(kmanDEXPool)), 25_000, "Contract should have 25000 TokenB");

        assertEq(kmanDEXPool.tokenAAmount(), 50_000, "TokenA amount should be 50000");
        assertEq(kmanDEXPool.tokenBAmount(), 25_000, "TokenB amount should be 25000");
    }
}
