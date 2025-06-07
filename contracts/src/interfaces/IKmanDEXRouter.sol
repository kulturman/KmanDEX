// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

interface IKmanDEXRouter {
    event SuccessfulSwap(
        address indexed user, address indexed tokenIn, address indexed tokenOut, uint256 amountIn, uint256 amountOut
    );
    event LiquidityAdded(address indexed provider, uint256 amountTokenA, uint256 amountTokenB);
    event LiquidityRemoved(address indexed provider, uint256 sharesBurned, uint256 amountTokenA, uint256 amountTokenB);

    error PoolDoesNotExist(address tokenA, address tokenB);

    function investLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountTokenA,
        uint256 amountTokenB,
        uint256 minimumShares
    ) external;

    function withdrawLiquidity(address tokenA, address tokenB, uint256 sharesToBurn) external;

    function swap(address tokenIn, address tokenOut, uint256 amountIn, uint256 minOut) external returns (uint256);
}
