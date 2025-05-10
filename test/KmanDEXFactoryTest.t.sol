// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import "../lib/forge-std/src/Test.sol";
import {KmanDEXFactory, FactoryInterface} from "../src/KmanDEXFactory.sol";


contract KmanDEXFactoryTest is Test {
    KmanDEXFactory public kmanDEXFactory;

    function setUp() public {
        kmanDEXFactory = new KmanDEXFactory();
    }

    function testCreatesPoolFailsWithFirstAddress0() public {
        vm.expectRevert(abi.encodeWithSelector(FactoryInterface.InvalidAddress.selector));
        kmanDEXFactory.createPool(address(0), address(1));
    }

    function testCreatesPoolFailsWithFirstSecondAddress0() public {
        vm.expectRevert(abi.encodeWithSelector(FactoryInterface.InvalidAddress.selector));
        kmanDEXFactory.createPool(address(1), address(0));
    }

    function testCreatesPoolFailsWithIdenticalAddresses() public {
        vm.expectRevert(abi.encodeWithSelector(FactoryInterface.IndenticalPoolAddresses.selector, address(1)));
        kmanDEXFactory.createPool(address(1), address(1));
    }

    function testCreatesPoolSucceeds() public {
        address tokenA = address(1);
        address tokenB = address(2);

        vm.expectEmit(true, true, true, false);
        emit FactoryInterface.PoolCreated(tokenA, tokenB, address(0));
        address pairAddress = kmanDEXFactory.createPool(tokenA, tokenB);

        assertNotEq(pairAddress, address(0));
    }
}
