// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {KmanDEXPool} from "./KmanDEXPool.sol";

interface FactoryInterface {
    error InvalidAddress();
    error IndenticalPoolAddresses(address);
    error PoolAlreadyExists(address, address);

    event PoolCreated(address indexed tokenA, address indexed tokenB, address indexed pairAddress);

    function getPoolAddress(address tokenA, address tokenB) external view returns (address);
    function createPool(address tokenA, address tokenB) external returns (address);
}

contract KmanDEXFactory is FactoryInterface {
    address public contractOwner;
    mapping(address => mapping(address => address)) private pools;

    constructor() {
        contractOwner = msg.sender;
    }

    function getPoolAddress(address tokenA, address tokenB) external view returns (address) {
        (address minAddress, address maxAddress) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);

        return pools[minAddress][maxAddress];
    }

    function createPool(address tokenA, address tokenB) external returns (address) {
        require(tokenA != address(0) && tokenB != address(0), InvalidAddress());
        require(tokenA != tokenB, IndenticalPoolAddresses(tokenA));

        KmanDEXPool newPool = new KmanDEXPool(contractOwner, tokenA, tokenB, address(this));
        //I may need to initialize newPool here, don't now yet

        // We use less memory
        //pools[tokenA][tokenB] = address(newPool);
        //pools[tokenB][tokenA] = address(newPool);
        (address minAddress, address maxAddress) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);

        if (pools[minAddress][maxAddress] != address(0)) {
            revert PoolAlreadyExists(tokenA, tokenB);
        }

        pools[minAddress][maxAddress] = address(newPool);
        emit PoolCreated(minAddress, maxAddress, address(newPool));

        return address(newPool);
    }
}
