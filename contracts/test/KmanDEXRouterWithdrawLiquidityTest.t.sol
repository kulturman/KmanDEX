// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import {IKmanDEXPool, KmanDEXPool} from "../src/KmanDEXPool.sol";
import {Test} from "../lib/forge-std/src/Test.sol";
import {ERC20Mock} from "./ERC20Mock.sol";
import {KmanDEXRouter} from "../src/KmanDEXRouter.sol";
import {IKmanDEXFactory} from "../src/KmanDEXFactory.sol";

contract KmanDEXPoolWithdrawLiquidityTest is Test {
    KmanDEXPool public kmanDEXPool;
    ERC20Mock public tokenA;
    ERC20Mock public tokenB;
    address contractAddress;
    KmanDEXRouter public router;

    function setUp() public {
        tokenA = new ERC20Mock("TokenA", "TKA");
        tokenB = new ERC20Mock("TokenB", "TKB");
        router = new KmanDEXRouter();
        //kmanDEXPool = new KmanDEXPool(address(2), address(this), address(this), address(tokenA), address(tokenB));
        kmanDEXPool = KmanDEXPool(IKmanDEXFactory(router.factory()).createPool(address(tokenA), address(tokenB)));

        tokenA.approve(address(router), type(uint256).max);
        tokenB.approve(address(router), type(uint256).max);
        contractAddress = address(this);
    }

    function testWithdrawFailsWhenUserDoesNotEnoughShares() public {
        vm.expectRevert(abi.encodeWithSelector(IKmanDEXPool.NotEnoughShares.selector, 0, 2000));
        router.withdrawLiquidity(address(tokenA), address(tokenB), 2000);
    }

    function testWithdrawSomeLiquidity() public {
        //LP1 receives INITIAL_SHARES - MINIMUM_LIQUIDITY at first deposit; we burn half of INITIAL_SHARES,
        // which corresponds to half of the reserves.
        router.investLiquidity(address(tokenA), address(tokenB), 10000, 5000, 1);

        uint256 initialShares = kmanDEXPool.INITIAL_SHARES();
        uint256 minimumLiquidity = kmanDEXPool.MINIMUM_LIQUIDITY();
        uint256 sharesToBurn = initialShares / 2;
        uint256 expectedRemainingLPShares = (initialShares - minimumLiquidity) - sharesToBurn;

        vm.expectEmit();
        emit IKmanDEXPool.LiquidityRemoved(contractAddress, sharesToBurn, 5000, 2500);
        router.withdrawLiquidity(address(tokenA), address(tokenB), sharesToBurn);

        assertEq(kmanDEXPool.shares(contractAddress), expectedRemainingLPShares, "LP shares mismatch");
        assertEq(kmanDEXPool.totalShares(), expectedRemainingLPShares + minimumLiquidity, "Total shares mismatch");

        assertEq(kmanDEXPool.tokenAAmount(), 5000, "TokenA amount should be 5000");
        assertEq(kmanDEXPool.tokenBAmount(), 2500, "TokenB amount should be 2500");

        assertEq(kmanDEXPool.invariant(), 5000 * 2500, "Invariant should be 5000 * 2500");

        assertEq(tokenA.balanceOf(address(kmanDEXPool)), 5000, "Contract should have 5000 TokenA");
        assertEq(tokenB.balanceOf(address(kmanDEXPool)), 2500, "Contract should have 2500 TokenB");
    }

    function testWithdrawAllLiquidity() public {
        router.investLiquidity(address(tokenA), address(tokenB), 10000, 5000, 1);

        uint256 sharesToBurn = kmanDEXPool.shares(contractAddress);
        router.withdrawLiquidity(address(tokenA), address(tokenB), sharesToBurn);

        assertEq(kmanDEXPool.shares(contractAddress), 0, "LP shares should now be 0");
        // MINIMUM_LIQUIDITY remains permanently locked, so totalShares does NOT go to zero.
        assertEq(kmanDEXPool.totalShares(), kmanDEXPool.MINIMUM_LIQUIDITY(), "Locked MINIMUM_LIQUIDITY remains");
    }
}
