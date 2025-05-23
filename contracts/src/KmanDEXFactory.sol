// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import "./interfaces/FactoryInterface.sol";
import {KmanDEXPool, KmanDEXPoolInterface} from "./KmanDEXPool.sol";

contract KmanDEXFactory is FactoryInterface {
    address public contractOwner;
    address public router;
    mapping(address => mapping(address => address)) private pools;
    address[] public allPools;

    constructor() {
        contractOwner = msg.sender;
        router = msg.sender;
        allPools.push(
            address(
                new KmanDEXPool(
                    contractOwner,
                    address(this),
                    router,
                    0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48,
                    0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2
                )
            )
        );
    }

    function getPoolAddress(address tokenA, address tokenB) external view returns (address) {
        (address minAddress, address maxAddress) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);

        return pools[minAddress][maxAddress];
    }

    function createPool(address tokenA, address tokenB) external returns (address) {
        require(tokenA != address(0) && tokenB != address(0), InvalidAddress());
        require(tokenA != tokenB, IdenticalPoolAddresses(tokenA));

        KmanDEXPool newPool = new KmanDEXPool(contractOwner, address(this), router, tokenA, tokenB);
        //I may need to initialize newPool here, don't now yet

        // We use less memory
        //pools[tokenA][tokenB] = address(newPool);
        //pools[tokenB][tokenA] = address(newPool);
        (address minAddress, address maxAddress) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);

        if (pools[minAddress][maxAddress] != address(0)) {
            revert PoolAlreadyExists(tokenA, tokenB);
        }

        pools[minAddress][maxAddress] = address(newPool);
        allPools.push(address(newPool));

        emit PoolCreated(minAddress, maxAddress, address(newPool));

        return address(newPool);
    }

    function getAllPools() external view returns (address[] memory) {
        return allPools;
    }
}
