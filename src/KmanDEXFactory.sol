// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {KmanDEXPool} from "./KmanDEXPool.sol";

interface FactoryInterface {
    error InvalidAddress();
    error IndenticalPoolAddresses(address);
    error PoolAlreadyExists();

    event PoolCreated(address indexed tokenA, address indexed tokenB, address pairAddress);

    function getPoolAddress(address tokenA, address tokenB) external view returns (address);
    function createPool(address tokenA, address tokenB) external returns (address);
}

contract KmanDEXFactory is FactoryInterface {
    mapping(address => mapping(address => address)) public pairsMapping;

    function getPoolAddress(address tokenA, address tokenB) external view returns (address) {
        return pairsMapping[tokenA][tokenB];
    }

    function createPool(address tokenA, address tokenB) external returns (address) {
        require(tokenA != address(0) && tokenB != address(0), InvalidAddress());
        require(tokenA != tokenB, IndenticalPoolAddresses(tokenA));

        KmanDEXPool newPool = new KmanDEXPool(tokenA, tokenB);
        //I may need to initialize newPool here, don't now yet

        emit PoolCreated(tokenA, tokenB, address(newPool));

        return address(newPool);
    }
}
