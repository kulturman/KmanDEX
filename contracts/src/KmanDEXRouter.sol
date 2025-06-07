// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "../lib/forge-std/src/console.sol";
import {IKmanDEXPool} from "./KmanDEXPool.sol";
import {IKmanDEXRouter} from "./interfaces/IKmanDEXRouter.sol";
import {IUniswapV2Router} from "./interfaces/IUniswapV2Router.sol";
import {KmanDEXFactory, IKmanDEXFactory} from "../src/KmanDEXFactory.sol";
import {SafeERC20, IERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

contract KmanDEXRouter is IKmanDEXRouter {
    using SafeERC20 for IERC20;

    address public constant UNISWAP_ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address public immutable factory;
    address public contractOwner;
    address[] public liquidityProviders;

    uint256 public constant UNISWAP_ROUTING_FEE = 1000;

    mapping(address => bool) public isLiquidityProvider;

    constructor() {
        factory = address(new KmanDEXFactory());
        contractOwner = msg.sender;
    }

    function investLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountTokenA,
        uint256 amountTokenB,
        uint256 minimumShares
    ) external {
        address pool = IKmanDEXFactory(factory).getPoolAddress(tokenA, tokenB);

        if (pool == address(0)) {
            pool = IKmanDEXFactory(factory).createPool(tokenA, tokenB);
        }

        IERC20(tokenA).transferFrom(msg.sender, pool, amountTokenA);
        IERC20(tokenB).transferFrom(msg.sender, pool, amountTokenB);

        IKmanDEXPool(pool).investLiquidity(msg.sender, amountTokenA, amountTokenB, minimumShares);

        if (!isLiquidityProvider[msg.sender]) {
            isLiquidityProvider[msg.sender] = true;
            liquidityProviders.push(msg.sender);
        }
    }

    function withdrawLiquidity(address tokenA, address tokenB, uint256 sharesToBurn) external {
        address pool = IKmanDEXFactory(factory).getPoolAddress(tokenA, tokenB);
        require(pool != address(0), PoolDoesNotExist(tokenA, tokenB));
        IKmanDEXPool(pool).withdrawLiquidity(msg.sender, sharesToBurn);
    }

    function swap(address tokenIn, address tokenOut, uint256 amountIn, uint256 minOut) external returns (uint256) {
        address pool = IKmanDEXFactory(factory).getPoolAddress(tokenIn, tokenOut);

        if (pool == address(0)) {
            return _forwardToUniswap(msg.sender, tokenIn, tokenOut, amountIn, minOut);
        }

        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);
        IERC20(tokenIn).approve(pool, amountIn);
        uint256 amountOut = IKmanDEXPool(pool).swap(msg.sender, tokenIn, amountIn, minOut);

        emit SuccessfulSwap(msg.sender, tokenIn, tokenOut, amountIn, amountOut);

        return amountOut;
    }

    function _forwardToUniswap(
        address realSender,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minTokenOut
    ) private returns (uint256) {
        address[] memory paths = new address[](2);
        paths[0] = tokenIn;
        paths[1] = tokenOut;

        uint256 fees = amountIn / UNISWAP_ROUTING_FEE;
        uint256 amountInMinusFees = amountIn - fees;

        IERC20(tokenIn).transferFrom(realSender, address(this), amountIn);
        IERC20(tokenIn).approve(UNISWAP_ROUTER, amountInMinusFees);

        if (fees > 0) {
            IERC20(tokenIn).transfer(contractOwner, fees);
        }

        uint256[] memory amounts = IUniswapV2Router(UNISWAP_ROUTER).swapExactTokensForTokens(
            amountInMinusFees, minTokenOut, paths, realSender, block.timestamp
        );

        return amounts[1];
    }

    function getLiquidityProviders() external view returns (address[] memory) {
        return liquidityProviders;
    }

    function getAllPools() external view returns (address[] memory) {
        return IKmanDEXFactory(factory).getAllPools();
    }
}
