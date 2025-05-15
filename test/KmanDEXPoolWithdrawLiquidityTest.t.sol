// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../src/KmanDEXPool.sol";
import {Test} from "../lib/forge-std/src/Test.sol";
import "./ERC20Mock.sol";

contract KmanDEXPoolWithdrawLiquidityTest is Test {
    KmanDEXPool public kmanDEXPool;
    ERC20Mock public tokenA;
    ERC20Mock public tokenB;
    address contractAddress;

    function setUp() public {
        tokenA = new ERC20Mock("TokenA", "TKA");
        tokenB = new ERC20Mock("TokenB", "TKB");
        kmanDEXPool = new KmanDEXPool(address(2), address(this), address(this), address(tokenA), address(tokenB));

        tokenA.approve(address(kmanDEXPool), type(uint256).max);
        tokenB.approve(address(kmanDEXPool), type(uint256).max);
        contractAddress = address(this);
    }

    function testWithdrawFailsWhenUserDoesNotEnoughShares() public {
        vm.expectRevert(abi.encodeWithSelector(KmanDEXPoolInterface.NotEnoughShares.selector, 0, 2000));
        kmanDEXPool.withdrawLiquidity(2000);
    }

    function testWithdrawSomeLiquidity() public {
        //We invest liquidity first and gets 1000 shares, the we withdraw 500 shares which is half of the shares
        kmanDEXPool.investLiquidity(10000, 5000, 1);

        vm.expectEmit();
        emit KmanDEXPoolInterface.LiquidityRemoved(contractAddress, 500, 5000, 2500);
        kmanDEXPool.withdrawLiquidity(500);

        assertEq(kmanDEXPool.shares(contractAddress), 500, "Shares should be 500");
        assertEq(kmanDEXPool.totalShares(), 500, "Total shares should be 500");

        assertEq(kmanDEXPool.tokenAAmount(), 5000, "TokenA amount should be 5000");
        assertEq(kmanDEXPool.tokenBAmount(), 2500, "TokenB amount should be 2500");

        assertEq(kmanDEXPool.invariant(), 5000 * 2500, "Invariant should be 5000 * 2500");

        assertEq(tokenA.balanceOf(address(kmanDEXPool)), 5000, "Contract should have 5000 TokenA");
        assertEq(tokenB.balanceOf(address(kmanDEXPool)), 2500, "Contract should have 2500 TokenB");
    }

    function testWithdrawAllLiquidity() public {
        kmanDEXPool.investLiquidity(10000, 5000, 1);

        kmanDEXPool.withdrawLiquidity(1000);

        assertEq(kmanDEXPool.shares(contractAddress), 0, "Shares should now be 0");
        assertEq(kmanDEXPool.invariant(), 0, "Invariant should be 0");
    }
}
