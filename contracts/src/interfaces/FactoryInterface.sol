// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

interface FactoryInterface {
    error InvalidAddress();
    error IdenticalPoolAddresses(address);
    error PoolAlreadyExists(address, address);

    event PoolCreated(address indexed tokenA, address indexed tokenB, address indexed pairAddress);

    function getPoolAddress(address tokenA, address tokenB) external view returns (address);
    function createPool(address tokenA, address tokenB) external returns (address);
    function getAllPools() external view returns (address[] memory);
}
