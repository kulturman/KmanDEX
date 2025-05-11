// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../src/KmanDEXPool.sol";
import {Test} from "../lib/forge-std/src/Test.sol";

contract KmanDEXPoolTest is Test {
    KmanDEXPool public kmanDEXPool;

    function setUp() public {
        kmanDEXPool = new KmanDEXPool(address(this), address(1), address(2));
    }

    function testInvestLiquidityWithEmptyPool() public {
        address sender = address(this);

        kmanDEXPool.investLiquidity(10000, 10000);

        assertEq(kmanDEXPool.totalShares(), kmanDEXPool.TOTAL_SHARES());
        assertEq(kmanDEXPool.shares(sender), kmanDEXPool.TOTAL_SHARES());

        assertEq(kmanDEXPool.tokenAAmount(), 10000);
        assertEq(kmanDEXPool.tokenBAmount(), 10000);

        assertEq(kmanDEXPool.invariant(), 10000 * 10000);
    }
}
