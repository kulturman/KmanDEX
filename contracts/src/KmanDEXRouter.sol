// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "../lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "../src/KmanDEXFactory.sol";
import {IUniswapV2Router} from "./interfaces/IUniswapV2Router.sol";
import {console} from "../lib/forge-std/src/console.sol";

contract KmanDEXRouter {
    using SafeERC20 for IERC20;

    address public immutable factory;
    address public immutable uniswapRouter;
    address public immutable feeCollector; //Contract owner
    mapping(address => bool) public isLiquidityProvider;
    address[] public liquidityProviders;

    error PoolDoesNotExist(address tokenA, address tokenB);

    constructor(address _uniRouter, address _collector) {
        factory = address(new KmanDEXFactory());
        uniswapRouter = _uniRouter;
        feeCollector = _collector;

        liquidityProviders.push(address(1));
        isLiquidityProvider[address(1)] = true;
        liquidityProviders.push(address(2));
        isLiquidityProvider[address(2)] = true;
        liquidityProviders.push(address(3));
        isLiquidityProvider[address(3)] = true;
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

        IERC20(tokenA).transferFrom(msg.sender, address(this), amountTokenA);
        IERC20(tokenB).transferFrom(msg.sender, address(this), amountTokenB);
        IERC20(tokenA).approve(pool, amountTokenA);
        IERC20(tokenB).approve(pool, amountTokenB);

        KmanDEXPoolInterface(pool).investLiquidity(msg.sender, amountTokenA, amountTokenB, minimumShares);

        if (!isLiquidityProvider[msg.sender]) {
            isLiquidityProvider[msg.sender] = true;
            liquidityProviders.push(msg.sender);
        }
    }

    function withdrawLiquidity(address tokenA, address tokenB, uint256 sharesToBurn) external {
        address pool = FactoryInterface(factory).getPoolAddress(tokenA, tokenB);
        require(pool != address(0), PoolDoesNotExist(tokenA, tokenB));
        KmanDEXPoolInterface(pool).withdrawLiquidity(msg.sender, sharesToBurn);
    }

    function swap(address tokenIn, address tokenOut, uint256 amountIn, uint256 minOut) external returns (uint256) {
        address pool = FactoryInterface(factory).getPoolAddress(tokenIn, tokenOut);

        if (pool == address(0)) {
            pool = FactoryInterface(factory).createPool(tokenIn, tokenOut);
            require(pool != address(0), PoolDoesNotExist(tokenIn, tokenOut));
        }

        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);
        IERC20(tokenIn).approve(pool, amountIn);
        return KmanDEXPoolInterface(pool).swap(msg.sender, tokenIn, amountIn, minOut);
    }

    function getLiquidityProviders() external view returns (address[] memory) {
        return liquidityProviders;
    }
}
