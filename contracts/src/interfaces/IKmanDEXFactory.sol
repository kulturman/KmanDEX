// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

interface IKmanDEXFactory {
    event PoolCreated(address indexed tokenA, address indexed tokenB, address indexed pairAddress);

    error InvalidAddress();
    error IdenticalTokenAddresses(address);
    error PoolAlreadyExists(address, address);

    function getPoolAddress(address tokenA, address tokenB) external view returns (address);
    function createPool(address tokenA, address tokenB) external returns (address);
    function getAllPools() external view returns (address[] memory);
}
