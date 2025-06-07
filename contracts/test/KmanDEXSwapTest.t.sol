// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import {Test} from "../lib/forge-std/src/Test.sol";
import {KmanDEXPool, IKmanDEXPool} from "../src/KmanDEXPool.sol";
import {ERC20Mock} from "./ERC20Mock.sol";
import {KmanDEXRouter} from "../src/KmanDEXRouter.sol";
import {IKmanDEXFactory} from "../src/KmanDEXFactory.sol";

contract KmanDEXSwapTest is Test {
    KmanDEXPool public kmanDEXPool;
    KmanDEXRouter router;
    ERC20Mock public tokenA;
    ERC20Mock public tokenB;
    address public contractAddress;
    address public contractOwner = address(2);

    function setUp() public {
        tokenA = new ERC20Mock("TokenA", "TKA");
        tokenB = new ERC20Mock("TokenB", "TKB");
        router = new KmanDEXRouter();
        kmanDEXPool = KmanDEXPool(IKmanDEXFactory(router.factory()).createPool(address(tokenA), address(tokenB)));
        tokenA.approve(address(router), type(uint256).max);
        tokenB.approve(address(router), type(uint256).max);
        contractAddress = address(this);
    }

    function testRevertsSwapWhenMinimumAmountNotMet() public {
        // Swap 1000 TokenA for TokenB
        router.investLiquidity(address(tokenA), address(tokenB), 10_000, 5_000, 1);
        uint256 amountIn = 1_000;

        vm.expectRevert(abi.encodeWithSelector(IKmanDEXPool.MinimumAmountNotMet.selector, 1000, 454));
        router.swap(address(tokenA), address(tokenB), amountIn, 1000);
    }

    function testSwapTokenAToTokenB() public {
        // Swap 1000 TokenA for TokenB
        router.investLiquidity(address(tokenA), address(tokenB), 10_000, 5_000, 1);
        uint256 amountIn = 1_000;
        uint256 senderTokenABalanceBeforeSwap = tokenA.balanceOf(contractAddress);
        uint256 senderTokenBBalanceBeforeSwap = tokenB.balanceOf(contractAddress);

        uint256 amountOut = router.swap(address(tokenA), address(tokenB), amountIn, 100);

        //We apply .2% fee, so we should get 1000 - 2 = 998, but we have 10_000 TokenA and 5_000 TokenB,
        assertEq(amountOut, 454, "Amount out should be 454");

        assertEq(kmanDEXPool.tokenAAmount(), 10_000 + amountIn, "TokenA amount should be 11_000");
        assertEq(kmanDEXPool.tokenBAmount(), 5_000 - amountOut, "TokenB amount should be 4_546");
        assertEq(kmanDEXPool.invariant(), 11_000 * 4_546, "Invariant should be 4_546 * 11_000");

        assertEq(tokenA.balanceOf(address(kmanDEXPool)), 11_000, "Contract should have 11_000 TokenA");
        assertEq(tokenB.balanceOf(address(kmanDEXPool)), 4_546, "Contract should have 4_546 TokenB");

        //Check that the sender has the right amount of TokenA and TokenB
        assertEq(
            tokenA.balanceOf(contractAddress),
            senderTokenABalanceBeforeSwap - amountIn,
            "Sender should have senderTokenBBalanceBeforeSwap - amountIn TokenA"
        );
        assertEq(
            tokenB.balanceOf(contractAddress),
            senderTokenBBalanceBeforeSwap + amountOut,
            "Sender should have senderTokenBBalanceBeforeSwap + amountOut TokenB"
        );
    }

    function testSwapTokenBToTokenA() public {
        // Swap 1000 TokenB for TokenA, we should get 454 TokenA just like in the previous test
        router.investLiquidity(address(tokenA), address(tokenB), 5_000, 10_000, 1);
        uint256 amountIn = 1_000;
        uint256 senderTokenABalanceBeforeSwap = tokenA.balanceOf(contractAddress);
        uint256 senderTokenBBalanceBeforeSwap = tokenB.balanceOf(contractAddress);

        uint256 amountOut = router.swap(address(tokenB), address(tokenA), amountIn, 100);

        assertEq(amountOut, 454, "Amount out should be 454");

        assertEq(kmanDEXPool.tokenBAmount(), 10_000 + amountIn, "TokenB amount should be 11_000");
        assertEq(kmanDEXPool.tokenAAmount(), 5_000 - amountOut, "TokenA amount should be 4_546");
        assertEq(kmanDEXPool.invariant(), 11_000 * 4_546, "Invariant should be 4_546 * 11_000");

        assertEq(tokenB.balanceOf(address(kmanDEXPool)), 11_000, "Pool should have 11_000 TokenB");
        assertEq(tokenA.balanceOf(address(kmanDEXPool)), 4_546, "Pool should have 4_546 TokenA");

        //Check that the sender has the right amount of TokenA and TokenB
        assertEq(
            tokenB.balanceOf(contractAddress),
            senderTokenBBalanceBeforeSwap - amountIn,
            "Sender should have senderTokenBBalanceBeforeSwap - amountIn TokenB"
        );

        assertEq(
            tokenA.balanceOf(contractAddress),
            senderTokenABalanceBeforeSwap + amountOut,
            "Sender should have senderTokenBBalanceBeforeSwap + amountOut TokenA"
        );
    }
}
