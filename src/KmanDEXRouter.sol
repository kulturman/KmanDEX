// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "../lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "../src/KmanDEXFactory.sol";
import {IUniswapV2Router} from "./interfaces/IUniswapV2Router.sol";

contract KmanDEXRouter {
    using SafeERC20 for IERC20;

    address public immutable factory;
    address public immutable uniswapRouter;
    address public immutable feeCollector; //Contract owner

    event SwapForwarded(address indexed user, address tokenIn, address tokenOut, uint256 amountIn, uint256 feeTaken);

    error PoolDoesNotExist(address tokenA, address tokenB);

    constructor(address _uniRouter, address _collector) {
        factory = address(new KmanDEXFactory());
        uniswapRouter = _uniRouter;
        feeCollector = _collector;
    }

    function investLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountTokenA,
        uint256 amountTokenB,
        uint256 minimumShares
    ) external {
        address pool = FactoryInterface(factory).getPoolAddress(tokenA, tokenB);
        require(pool != address(0), PoolDoesNotExist(tokenA, tokenB));
        KmanDEXPoolInterface(pool).investLiquidity(msg.sender, amountTokenA, amountTokenB, minimumShares);
    }

    function withdrawLiquidity(address tokenA, address tokenB, uint256 sharesToBurn) external {
        address pool = FactoryInterface(factory).getPoolAddress(tokenA, tokenB);
        require(pool != address(0), "Pool does not exist");
        KmanDEXPoolInterface(pool).withdrawLiquidity(msg.sender, sharesToBurn);
    }

    function swap(address tokenIn, address tokenOut, uint256 amountIn, uint256 minOut) external returns (uint256) {
        address pool = FactoryInterface(factory).getPoolAddress(tokenIn, tokenOut);

        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);

        if (pool != address(0)) {
            IERC20(tokenIn).approve(pool, amountIn);
            return KmanDEXPoolInterface(pool).swap(msg.sender, tokenIn, amountIn, minOut);
        } else {
            pool = FactoryInterface(factory).createPool(tokenIn, tokenOut);
            require(pool != address(0), "Pool creation failed");

            IERC20(tokenIn).approve(pool, amountIn);
            return KmanDEXPoolInterface(pool).swap(msg.sender, tokenIn, amountIn, minOut);
        }
    }
}
