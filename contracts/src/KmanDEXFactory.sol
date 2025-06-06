// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IKmanDEXFactory} from "./interfaces/IKmanDEXFactory.sol";
import {KmanDEXPool, IKmanDEXPool} from "./KmanDEXPool.sol";
import {Clones} from "../lib/openzeppelin-contracts/contracts/proxy/Clones.sol";

contract KmanDEXFactory is IKmanDEXFactory {
    using Clones for address;

    address public contractOwner;
    address public router;
    mapping(address => mapping(address => address)) private pools;
    address[] public allPools;

    address public mainPool;

    constructor() {
        contractOwner = msg.sender;
        router = msg.sender;

        mainPool = address(new KmanDEXPool(contractOwner, address(this), router, address(0), address(0)));
    }

    function getPoolAddress(address tokenA, address tokenB) external view returns (address) {
        (address minAddress, address maxAddress) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);

        return pools[minAddress][maxAddress];
    }

    function createPool(address tokenA, address tokenB) external returns (address) {
        require(tokenA != address(0) && tokenB != address(0), InvalidAddress());
        require(tokenA != tokenB, IdenticalPoolAddresses(tokenA));

        (address minAddress, address maxAddress) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);

        if (pools[minAddress][maxAddress] != address(0)) {
            revert PoolAlreadyExists(tokenA, tokenB);
        }

        //Using this approach to save gas on pool creation, createPool function average cost went from 1M+ to 252K
        address newPool = mainPool.clone();

        pools[minAddress][maxAddress] = newPool;
        allPools.push(newPool);

        IKmanDEXPool(newPool).initialize(contractOwner, address(this), router, tokenA, tokenB);

        emit PoolCreated(minAddress, maxAddress, newPool);

        return newPool;
    }

    function getAllPools() external view returns (address[] memory) {
        return allPools;
    }
}
