// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import "../lib/forge-std/src/console.sol";
import {IERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {Math} from "../lib/openzeppelin-contracts/contracts/utils/math/Math.sol";

interface KmanDEXPoolInterface {
    error InvalidAddress();
    error InvalidAmount();
    error NotEnoughShares(uint256 actualShares, uint256 sharesToBurn);
    error MinimumSharesNotMet(uint256 minimumShares, uint256 sharesToMint);
    error MinimumAmountNotMet(uint256 minTokenOut, uint256 amountOut);

    event LiquidityAdded(address indexed provider, uint256 amountTokenA, uint256 amountTokenB);
    event LiquidityRemoved(address indexed provider, uint256 sharesBurned, uint256 amountTokenA, uint256 amountTokenB);

    function investLiquidity(uint256 amountTokenA, uint256 amountTokenB, uint256 minimumShares) external;
    function withdrawLiquidity(uint256 sharesToBurn) external;
    function swap(address tokenIn, uint256 amountIn, uint256 minTokenOut) external returns (uint256 amountOut);
}

contract KmanDEXPool is KmanDEXPoolInterface {
    address private factory;
    address public tokenA;
    address public tokenB;

    uint256 public totalShares;
    mapping(address => uint256) public shares;
    uint256 public invariant;

    uint256 public constant INITIAL_SHARES = 1000;
    uint256 public constant FEE_RATE = 500;

    uint256 public tokenAAmount;
    uint256 public tokenBAmount;

    constructor(address factory_, address tokenA_, address tokenB_) {
        factory = factory_;
        tokenA = tokenA_;
        tokenB = tokenB_;
    }

    function investLiquidity(uint256 amountTokenA, uint256 amountTokenB, uint256 minimumShares) external {
        require(amountTokenA > 0 && amountTokenB > 0, InvalidAmount());
        require(msg.sender != address(0), InvalidAddress());

        if (totalShares == 0) {
            //First investor
            totalShares = INITIAL_SHARES;
            shares[msg.sender] = INITIAL_SHARES;

            require(minimumShares <= INITIAL_SHARES, MinimumSharesNotMet(minimumShares, INITIAL_SHARES));
        } else {
            //Subsequent investors
            uint256 sharesToMint =
                Math.min(amountTokenA * totalShares / tokenAAmount, amountTokenB * totalShares / tokenBAmount);

            require(minimumShares <= sharesToMint, MinimumSharesNotMet(minimumShares, sharesToMint));

            shares[msg.sender] += sharesToMint;
            totalShares += sharesToMint;
        }

        tokenAAmount += amountTokenA;
        tokenBAmount += amountTokenB;

        //Use safe math library for multiplication to prevent overflow later
        invariant = tokenAAmount * tokenBAmount;
        require(IERC20(tokenA).transferFrom(msg.sender, address(this), amountTokenA));
        require(IERC20(tokenB).transferFrom(msg.sender, address(this), amountTokenB));

        emit LiquidityAdded(msg.sender, amountTokenA, amountTokenB);
    }

    function withdrawLiquidity(uint256 sharesToBurn) external {
        require(shares[msg.sender] >= sharesToBurn, NotEnoughShares(shares[msg.sender], sharesToBurn));
        shares[msg.sender] -= sharesToBurn;

        uint256 amountTokenA = (sharesToBurn * tokenAAmount) / totalShares;
        uint256 amountTokenB = (sharesToBurn * tokenBAmount) / totalShares;

        totalShares -= sharesToBurn;

        tokenAAmount -= amountTokenA;
        tokenBAmount -= amountTokenB;

        invariant = tokenAAmount * tokenBAmount;

        require(IERC20(tokenA).transfer(msg.sender, amountTokenA));
        require(IERC20(tokenB).transfer(msg.sender, amountTokenB));

        emit LiquidityRemoved(msg.sender, sharesToBurn, amountTokenA, amountTokenB);
    }

    function swap(address tokenIn, uint256 amountIn, uint256 minTokenOut) external returns (uint256) {
        require(tokenIn == tokenA || tokenIn == tokenB, InvalidAddress());
        require(amountIn > 0, InvalidAmount());
        require(minTokenOut > 0, InvalidAmount());

        if (tokenIn == tokenA) {
            return swapTokenAtoTokenB(amountIn, minTokenOut);
        } else {
            return swapTokenBtoTokenA(amountIn, minTokenOut);
        }
    }

    function swapTokenAtoTokenB(uint256 amountIn, uint256 minTokenOut) internal returns (uint256) {
        uint256 fees = amountIn / FEE_RATE;
        uint256 amountInWithFees = amountIn - fees;

        uint256 tempAmountTokenB = tokenAAmount + amountInWithFees;
        uint256 newAmountTokenB = invariant / tempAmountTokenB;
        uint256 amountOut = tokenBAmount - newAmountTokenB;

        require(amountOut >= minTokenOut && amountOut <= tokenBAmount, MinimumAmountNotMet(minTokenOut, amountOut));

        tokenAAmount += amountIn;
        tokenBAmount = newAmountTokenB;

        invariant = tokenAAmount * tokenBAmount;

        require(IERC20(tokenA).transferFrom(msg.sender, address(this), amountIn));
        require(IERC20(tokenB).transfer(msg.sender, amountOut));

        return amountOut;
    }

    function swapTokenBtoTokenA(uint256 amountIn, uint256 minTokenOut) internal returns (uint256) {
        require(tokenB == msg.sender, InvalidAddress());

        uint256 fees = amountIn / FEE_RATE;
        uint256 amountInWithFees = amountIn - fees;

        uint256 amountOut = 0;

        return amountOut;
    }
}
