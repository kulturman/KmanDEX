// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Test, Vm} from "../lib/forge-std/src/Test.sol";
import {KmanDEXFactory, IKmanDEXFactory} from "../src/KmanDEXFactory.sol";

contract KmanDEXFactoryTest is Test {
    KmanDEXFactory public kmanDEXFactory;

    function setUp() public {
        kmanDEXFactory = new KmanDEXFactory();
    }

    function testCreatesPoolFailsWithFirstAddress0() public {
        vm.expectRevert(abi.encodeWithSelector(IKmanDEXFactory.InvalidAddress.selector));
        kmanDEXFactory.createPool(address(0), address(1));
    }

    function testCreatesPoolFailsWithFirstSecondAddress0() public {
        vm.expectRevert(abi.encodeWithSelector(IKmanDEXFactory.InvalidAddress.selector));
        kmanDEXFactory.createPool(address(1), address(0));
    }

    function testCreatesPoolFailsWithIdenticalAddresses() public {
        vm.expectRevert(abi.encodeWithSelector(IKmanDEXFactory.IdenticalPoolAddresses.selector, address(1)));
        kmanDEXFactory.createPool(address(1), address(1));
    }

    function testCreatePoolFailsWithPoolAlreadyExists() public {
        address tokenA = address(1);
        address tokenB = address(2);

        kmanDEXFactory.createPool(tokenA, tokenB);

        vm.expectRevert(abi.encodeWithSelector(IKmanDEXFactory.PoolAlreadyExists.selector, tokenA, tokenB));
        kmanDEXFactory.createPool(tokenA, tokenB);
    }

    function testCreatesPoolSucceeds() public {
        address tokenA = address(1);
        address tokenB = address(2);

        address poolAddress = kmanDEXFactory.createPool(tokenA, tokenB);

        // Check that the pool address is stored correctly, (A, B) and (B, A) should point to the same pool
        assertEq(kmanDEXFactory.getPoolAddress(tokenA, tokenB), poolAddress);
        assertEq(kmanDEXFactory.getPoolAddress(tokenB, tokenA), poolAddress);
    }

    function testCreatesPoolEmitsCorrectEvent() public {
        address tokenA = address(1);
        address tokenB = address(2);

        vm.recordLogs();
        address createdPool = kmanDEXFactory.createPool(tokenA, tokenB);

        Vm.Log[] memory entries = vm.getRecordedLogs();
        assertEq(entries.length, 1);

        Vm.Log memory log = entries[0];
        bytes32 expectedSig = keccak256("PoolCreated(address,address,address)");
        assertEq(log.topics[0], expectedSig);

        (address t0, address t1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);

        assertEq(kmanDEXFactory.getPoolAddress(tokenA, tokenB), createdPool);
        assertEq(kmanDEXFactory.getPoolAddress(tokenB, tokenA), createdPool);
        assertEq(address(uint160(uint256(log.topics[1]))), t0);
        assertEq(address(uint160(uint256(log.topics[2]))), t1);
        assertEq(address(uint160(uint256(log.topics[3]))), createdPool);
    }
}
