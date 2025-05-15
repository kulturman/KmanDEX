// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../src/KmanDEXPool.sol";
import "./ERC20Mock.sol";
import {Test} from "../lib/forge-std/src/Test.sol";
import {KmanDEXRouter} from "../src/KmanDEXRouter.sol";

contract KmanDEXPoolInvestLiquidityTest is Test {
    KmanDEXPool public kmanDEXPool;
    ERC20Mock public tokenA;
    ERC20Mock public tokenB;
    address public contractAddress;
    address public contractOwner = address(2);

    function setUp() public {
        tokenA = new ERC20Mock("TokenA", "TKA");
        tokenB = new ERC20Mock("TokenB", "TKB");
        kmanDEXPool = new KmanDEXPool(contractOwner, address(this), address(this), address(tokenA), address(tokenB));

        tokenA.approve(address(kmanDEXPool), type(uint256).max);
        tokenB.approve(address(kmanDEXPool), type(uint256).max);
        contractAddress = address(this);
    }

    function testInvestLiquidityWithEmptyPool() public {
        vm.expectEmit();
        emit KmanDEXPoolInterface.LiquidityAdded(contractAddress, 10000, 5000);
        kmanDEXPool.investLiquidity(address(this), 10000, 5000, 1);

        assertEq(kmanDEXPool.totalShares(), kmanDEXPool.INITIAL_SHARES(), "Total shares should be 1000");
        assertEq(kmanDEXPool.shares(contractAddress), kmanDEXPool.INITIAL_SHARES(), "Sender shares should be 1000");

        assertEq(kmanDEXPool.tokenAAmount(), 10000);
        assertEq(kmanDEXPool.tokenBAmount(), 5000);

        assertEq(kmanDEXPool.invariant(), 10000 * 5000);

        assertEq(tokenA.balanceOf(address(kmanDEXPool)), 10000, "Contract should have 10000 TokenA");
        assertEq(tokenB.balanceOf(address(kmanDEXPool)), 5000, "Contract should have 5000 TokenB");
    }

    function testRevertsWhenMinimumSharesNotMetOnEmptyPool() public {
        vm.expectRevert(abi.encodeWithSelector(KmanDEXPoolInterface.MinimumSharesNotMet.selector, 2000, 1000));
        kmanDEXPool.investLiquidity(address(this), 10000, 5000, 2000);
    }

    function testRevertsWhenMinimumSharesNotMetOnNonEmptyPool() public {
        kmanDEXPool.investLiquidity(address(this), 10000, 5000, 1);
        vm.expectRevert(abi.encodeWithSelector(KmanDEXPoolInterface.MinimumSharesNotMet.selector, 2000, 1000));
        kmanDEXPool.investLiquidity(address(this), 10000, 5000, 2000);
    }

    function testInvestLiquidityWithNonEmptyPool() public {
        address secondInvestor = address(0x123);

        tokenA.transfer(secondInvestor, 100_000);
        tokenB.transfer(secondInvestor, 100_000);

        kmanDEXPool.investLiquidity(address(this), 20_000, 10_000, 1);

        kmanDEXPool.changeRouterAddress(secondInvestor);
        vm.startPrank(secondInvestor);
        tokenA.approve(address(kmanDEXPool), type(uint256).max);
        tokenB.approve(address(kmanDEXPool), type(uint256).max);

        kmanDEXPool.investLiquidity(secondInvestor, 10_000, 5_000, 1);

        assertEq(kmanDEXPool.shares(contractAddress), 1_000, "First investor should have 1000 shares");
        assertEq(kmanDEXPool.shares(secondInvestor), 500, "Second investor should have 500 shares");

        assertEq(kmanDEXPool.totalShares(), 1_500, "Total shares should be 1500");

        assertEq(tokenA.balanceOf(address(kmanDEXPool)), 30_000, "Contract should have 30000 TokenA");
        assertEq(tokenB.balanceOf(address(kmanDEXPool)), 15_000, "Contract should have 15000 TokenB");

        assertEq(kmanDEXPool.tokenAAmount(), 30_000, "TokenA amount should be 30000");
        assertEq(kmanDEXPool.tokenBAmount(), 15_000, "TokenB amount should be 15000");
    }

    function testInvestLiquidityCumulatesForSameInvestor() public {
        kmanDEXPool.investLiquidity(address(this), 20_000, 10_000, 1);
        kmanDEXPool.investLiquidity(address(this), 30_000, 15_000, 1);

        assertEq(kmanDEXPool.shares(contractAddress), 2_500, "First investor should have all shares (1000 + 1500)");
        assertEq(kmanDEXPool.totalShares(), 2_500, "Total shares should be 2500");

        assertEq(tokenA.balanceOf(address(kmanDEXPool)), 50_000, "Contract should have 50000 TokenA");
        assertEq(tokenB.balanceOf(address(kmanDEXPool)), 25_000, "Contract should have 25000 TokenB");

        assertEq(kmanDEXPool.tokenAAmount(), 50_000, "TokenA amount should be 50000");
        assertEq(kmanDEXPool.tokenBAmount(), 25_000, "TokenB amount should be 25000");
    }
}
