// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {IKmanDEXRouter, KmanDEXRouter} from "../src/KmanDEXRouter.sol";
import {IKmanDEXFactory, KmanDEXFactory} from "../src/KmanDEXFactory.sol";
import {KmanDEXPool, IKmanDEXPool} from "../src/KmanDEXPool.sol";
import {Test} from "../lib/forge-std/src/Test.sol";
import {ERC20Mock} from "./ERC20Mock.sol";
import {IERC20} from "../lib/forge-std/src/interfaces/IERC20.sol";

contract KmanDEXRouterTest is Test {
    KmanDEXFactory public factory;
    address public feeCollector;
    address public USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; // USDC
    address public WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; // WETH
    KmanDEXRouter public router;

    function setUp() public {
        vm.createSelectFork(vm.rpcUrl("main_net"), 22476889);
        router = new KmanDEXRouter();
        factory = KmanDEXFactory(router.factory());
        deal(USDC, address(router), 20_000);
        deal(WETH, address(router), 10_000);
        feeCollector = address(0x300);
    }

    function testSwapWithExistingPool() public {
        //We need to prank as the router as we create the contract from it
        vm.startPrank(address(router));
        address pool = factory.createPool(USDC, WETH);
        //Authorize investment in pool
        IERC20(USDC).approve(pool, type(uint256).max);
        IERC20(WETH).approve(pool, type(uint256).max);

        IKmanDEXPool(pool).investLiquidity(address(router), 10_000, 5_000, 1);
        IERC20(USDC).approve(address(router), 1_000);

        vm.expectCall(pool, abi.encodeWithSelector(IKmanDEXPool.swap.selector, address(router), USDC, 1_000, 1));
        vm.expectEmit();
        emit IKmanDEXRouter.SuccessfulSwap(address(router), USDC, WETH, 1_000, 454);

        /*
            Just like when we called the pool directly, testing just one case is enough, we don't really need because we checked
            that the router delegated correctly to the pool, but we keep it for clarity
        */
        uint256 amountOut = router.swap(address(USDC), address(WETH), 1_000, 1);
        assertEq(amountOut, 454, "Amount out should be 454");
    }

    function testInvestLiquidityCreatesLiquidityPoolIfNotAlreadyExists() public {
        vm.startPrank(address(router));
        //Authorize investment in pool, we approve the router
        IERC20(USDC).approve(address(router), type(uint256).max);
        IERC20(WETH).approve(address(router), type(uint256).max);

        assertEq(factory.getPoolAddress(USDC, WETH), address(0), "Pool should not exist yet");

        router.investLiquidity(USDC, WETH, 10000, 5000, 1);

        assertNotEq(factory.getPoolAddress(USDC, WETH), address(0), "Pool should exist now");
    }

    function testInvestLiquidity() public {
        vm.startPrank(address(router));
        address pool = factory.createPool(USDC, WETH);
        //Authorize investment in pool, we approve the router
        IERC20(USDC).approve(address(router), type(uint256).max);
        IERC20(WETH).approve(address(router), type(uint256).max);

        vm.expectCall(
            address(pool),
            abi.encodeWithSelector(IKmanDEXPool.investLiquidity.selector, address(router), 10000, 5000, 1)
        );

        router.investLiquidity(USDC, WETH, 10000, 5000, 1);
    }

    function testWithdrawLiquidity() public {
        vm.startPrank(address(router));
        address pool = factory.createPool(USDC, WETH);
        //Authorize investment in pool
        IERC20(USDC).approve(address(router), type(uint256).max);
        IERC20(WETH).approve(address(router), type(uint256).max);

        router.investLiquidity(USDC, WETH, 10000, 5000, 1);

        vm.expectCall(
            address(pool), abi.encodeWithSelector(IKmanDEXPool.withdrawLiquidity.selector, address(router), 1)
        );

        router.withdrawLiquidity(USDC, WETH, 1);
    }
}
