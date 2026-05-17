// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import {IKmanDEXPool, KmanDEXPool} from "../src/KmanDEXPool.sol";
import {ERC20Mock} from "./ERC20Mock.sol";
import {Test} from "../lib/forge-std/src/Test.sol";
import {KmanDEXRouter, IKmanDEXRouter} from "../src/KmanDEXRouter.sol";
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
        uint256 initialShares = kmanDEXPool.INITIAL_SHARES();
        uint256 minimumLiquidity = kmanDEXPool.MINIMUM_LIQUIDITY();
        uint256 expectedSenderShares = initialShares - minimumLiquidity;

        vm.expectEmit();
        emit IKmanDEXRouter.LiquidityAdded(contractAddress, 10000, 5000);
        router.investLiquidity(address(tokenA), address(tokenB), 10000, 5000, 0);

        assertEq(kmanDEXPool.totalShares(), initialShares, "Total shares should equal INITIAL_SHARES");
        assertEq(
            kmanDEXPool.shares(contractAddress),
            expectedSenderShares,
            "Sender should get INITIAL_SHARES - MINIMUM_LIQUIDITY"
        );
        assertEq(kmanDEXPool.shares(address(0)), minimumLiquidity, "MINIMUM_LIQUIDITY should be locked at address(0)");

        assertEq(kmanDEXPool.tokenAAmount(), 10000);
        assertEq(kmanDEXPool.tokenBAmount(), 5000);

        assertEq(kmanDEXPool.invariant(), 10000 * 5000);

        assertEq(tokenA.balanceOf(address(kmanDEXPool)), 10000, "Contract should have 10000 TokenA");
        assertEq(tokenB.balanceOf(address(kmanDEXPool)), 5000, "Contract should have 5000 TokenB");
    }

    function testRevertsWhenMinimumSharesNotMetOnEmptyPool() public {
        uint256 expectedSenderShares = kmanDEXPool.INITIAL_SHARES() - kmanDEXPool.MINIMUM_LIQUIDITY();
        uint256 askedShares = expectedSenderShares + 1;
        vm.expectRevert(
            abi.encodeWithSelector(IKmanDEXPool.MinimumSharesNotMet.selector, askedShares, expectedSenderShares)
        );
        router.investLiquidity(address(tokenA), address(tokenB), 10000, 5000, askedShares);
    }

    function testRevertsWhenMinimumSharesNotMetOnNonEmptyPool() public {
        router.investLiquidity(address(tokenA), address(tokenB), 10000, 5000, 1);
        //Second deposit at the same ratio mints (amount * totalShares) / reserve shares.
        // 10_000 * 1e18 / 10_000 = 1e18 shares
        uint256 expectedShares = 1e18;
        uint256 askedShares = expectedShares + 1;
        vm.expectRevert(abi.encodeWithSelector(IKmanDEXPool.MinimumSharesNotMet.selector, askedShares, expectedShares));
        router.investLiquidity(address(tokenA), address(tokenB), 10000, 5000, askedShares);
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

        uint256 initialShares = kmanDEXPool.INITIAL_SHARES();
        uint256 minimumLiquidity = kmanDEXPool.MINIMUM_LIQUIDITY();
        // LP1 gets INITIAL_SHARES - MINIMUM_LIQUIDITY at first deposit.
        // LP2 deposits at half the existing reserves, so receives initialShares / 2.
        uint256 expectedFirstShares = initialShares - minimumLiquidity;
        uint256 expectedSecondShares = initialShares / 2;

        assertEq(kmanDEXPool.shares(firstInvestor), expectedFirstShares, "First investor shares mismatch");
        assertEq(kmanDEXPool.shares(secondInvestor), expectedSecondShares, "Second investor shares mismatch");
        assertEq(kmanDEXPool.shares(address(0)), minimumLiquidity, "MINIMUM_LIQUIDITY should remain locked");

        assertEq(
            kmanDEXPool.totalShares(),
            initialShares + expectedSecondShares,
            "Total shares should be INITIAL_SHARES + LP2 shares"
        );

        assertEq(tokenA.balanceOf(address(kmanDEXPool)), 30_000, "Contract should have 30000 TokenA");
        assertEq(tokenB.balanceOf(address(kmanDEXPool)), 15_000, "Contract should have 15000 TokenB");

        assertEq(kmanDEXPool.tokenAAmount(), 30_000, "TokenA amount should be 30000");
        assertEq(kmanDEXPool.tokenBAmount(), 15_000, "TokenB amount should be 15000");
    }

    function testInvestLiquidityCumulatesForSameInvestor() public {
        router.investLiquidity(address(tokenA), address(tokenB), 20_000, 10_000, 1);
        router.investLiquidity(address(tokenA), address(tokenB), 30_000, 15_000, 1);

        uint256 initialShares = kmanDEXPool.INITIAL_SHARES();
        uint256 minimumLiquidity = kmanDEXPool.MINIMUM_LIQUIDITY();
        // First deposit: INITIAL_SHARES - MINIMUM_LIQUIDITY.
        // Second deposit (30_000 on top of 20_000): 30_000 * INITIAL_SHARES / 20_000 = 1.5e18.
        uint256 expectedShares = (initialShares - minimumLiquidity) + (initialShares * 3) / 2;

        assertEq(kmanDEXPool.shares(contractAddress), expectedShares, "First investor should accumulate both deposits");
        assertEq(kmanDEXPool.totalShares(), expectedShares + minimumLiquidity, "Total shares mismatch");

        assertEq(tokenA.balanceOf(address(kmanDEXPool)), 50_000, "Contract should have 50000 TokenA");
        assertEq(tokenB.balanceOf(address(kmanDEXPool)), 25_000, "Contract should have 25000 TokenB");

        assertEq(kmanDEXPool.tokenAAmount(), 50_000, "TokenA amount should be 50000");
        assertEq(kmanDEXPool.tokenBAmount(), 25_000, "TokenB amount should be 25000");
    }
}
