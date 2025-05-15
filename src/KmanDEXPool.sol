// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import "../lib/forge-std/src/console.sol";
import "./interfaces/KmanDEXPoolInterface.sol";
import {IERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IUniswapV2Router} from "./interfaces/IUniswapV2Router.sol";
import {Math} from "../lib/openzeppelin-contracts/contracts/utils/math/Math.sol";
import {SafeMath} from "./SafeMath.sol";

contract KmanDEXPool is KmanDEXPoolInterface {
    using SafeMath for uint256;

    address public contactOwner;
    address private factory;
    address private router;
    address public tokenA;
    address public tokenB;
    address public constant UNISWAP_ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;

    uint256 public totalShares;
    mapping(address => uint256) public shares;
    uint256 public invariant;

    uint256 public constant INITIAL_SHARES = 1000;
    uint256 public constant FEE_RATE = 500;
    uint256 public constant UNISWAP_ROUTING_FEE = 1000;

    uint256 public tokenAAmount;
    uint256 public tokenBAmount;

    constructor(address contractOwner_, address factory_, address router_, address tokenA_, address tokenB_) {
        contactOwner = contractOwner_;
        factory = factory_;
        router = router_;
        tokenA = tokenA_;
        tokenB = tokenB_;
    }

    modifier onlyRouter() {
        require(msg.sender == router, CallFromAnotherAddressThanRouter(msg.sender));
        _;
    }

    function changeRouterAddress(address newRouter) external onlyRouter {
        router = newRouter;
    }

    function investLiquidity(address realSender, uint256 amountTokenA, uint256 amountTokenB, uint256 minimumShares)
        external
        onlyRouter
    {
        require(amountTokenA > 0 && amountTokenB > 0, InvalidAmount());
        require(realSender != address(0), InvalidAddress());

        if (totalShares == 0) {
            //First investor
            totalShares = INITIAL_SHARES;
            shares[realSender] = INITIAL_SHARES;

            require(minimumShares <= INITIAL_SHARES, MinimumSharesNotMet(minimumShares, INITIAL_SHARES));
        } else {
            //Subsequent investors
            uint256 sharesToMint =
                Math.min(amountTokenA * totalShares / tokenAAmount, amountTokenB * totalShares / tokenBAmount);

            require(minimumShares <= sharesToMint, MinimumSharesNotMet(minimumShares, sharesToMint));

            shares[realSender] = sharesToMint.add(shares[realSender]);
            totalShares = sharesToMint.add(totalShares);
        }

        tokenAAmount = tokenAAmount.add(amountTokenA);
        tokenBAmount = tokenBAmount.add(amountTokenB);

        //Use safe math library for multiplication to prevent overflow later
        invariant = tokenAAmount.mul(tokenBAmount);
        require(IERC20(tokenA).transferFrom(realSender, address(this), amountTokenA));
        require(IERC20(tokenB).transferFrom(realSender, address(this), amountTokenB));

        emit LiquidityAdded(realSender, amountTokenA, amountTokenB);
    }

    function withdrawLiquidity(address realSender, uint256 sharesToBurn) external onlyRouter {
        require(shares[realSender] >= sharesToBurn, NotEnoughShares(shares[realSender], sharesToBurn));
        shares[realSender] = shares[realSender].sub(sharesToBurn);

        uint256 amountTokenA = sharesToBurn.mul(tokenAAmount).div(totalShares);
        uint256 amountTokenB = sharesToBurn.mul(tokenBAmount).div(totalShares);

        totalShares = totalShares.sub(sharesToBurn);

        tokenAAmount = tokenAAmount.sub(amountTokenA);
        tokenBAmount = tokenBAmount.sub(amountTokenB);

        invariant = tokenAAmount.mul(tokenBAmount);

        require(IERC20(tokenA).transfer(realSender, amountTokenA));
        require(IERC20(tokenB).transfer(realSender, amountTokenB));

        emit LiquidityRemoved(realSender, sharesToBurn, amountTokenA, amountTokenB);
    }

    function swap(address realSender, address tokenIn, uint256 amountIn, uint256 minTokenOut)
        external
        onlyRouter
        returns (uint256)
    {
        require(tokenIn == tokenA || tokenIn == tokenB, InvalidAddress());
        require(amountIn > 0, InvalidAmount());
        require(minTokenOut > 0, InvalidAmount());

        address tokenOut = tokenIn == tokenA ? tokenB : tokenA;

        if (tokenAAmount == 0 || tokenBAmount == 0) {
            return swapWithUniswap(realSender, tokenIn, tokenOut, amountIn, minTokenOut);
        }

        //Refactor later to avoid code duplication
        if (tokenIn == tokenA) {
            return swapTokenAtoTokenB(realSender, amountIn, minTokenOut);
        } else {
            return swapTokenBtoTokenA(realSender, amountIn, minTokenOut);
        }
    }

    function swapTokenAtoTokenB(address realSender, uint256 amountIn, uint256 minTokenOut) internal returns (uint256) {
        uint256 fees = amountIn / FEE_RATE;
        uint256 amountInWithFees = amountIn - fees;

        uint256 tempAmountTokenB = tokenAAmount + amountInWithFees;
        uint256 newAmountTokenB = invariant / tempAmountTokenB;
        uint256 amountOut = tokenBAmount - newAmountTokenB;

        require(amountOut >= minTokenOut && amountOut <= tokenBAmount, MinimumAmountNotMet(minTokenOut, amountOut));

        tokenAAmount += amountIn;
        tokenBAmount = newAmountTokenB;

        invariant = tokenAAmount * tokenBAmount;

        require(IERC20(tokenA).transferFrom(realSender, address(this), amountIn));
        require(IERC20(tokenB).transfer(realSender, amountOut));

        emit Swapped(realSender, tokenA, amountIn, amountOut);
        return amountOut;
    }

    function swapTokenBtoTokenA(address realSender, uint256 amountIn, uint256 minTokenOut) internal returns (uint256) {
        uint256 fees = amountIn / FEE_RATE;
        uint256 amountInWithFees = amountIn - fees;

        uint256 tempAmountTokenA = tokenBAmount + amountInWithFees;
        uint256 newAmountTokenA = invariant / tempAmountTokenA;
        uint256 amountOut = tokenAAmount - newAmountTokenA;

        require(amountOut >= minTokenOut && amountOut <= tokenAAmount, MinimumAmountNotMet(minTokenOut, amountOut));

        tokenBAmount += amountIn;
        tokenAAmount = newAmountTokenA;

        invariant = tokenAAmount * tokenBAmount;

        require(IERC20(tokenB).transferFrom(realSender, address(this), amountIn));
        require(IERC20(tokenA).transfer(realSender, amountOut));

        emit Swapped(realSender, tokenB, amountIn, amountOut);
        return amountOut;
    }

    function swapWithUniswap(
        address realSender,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minTokenOut
    ) internal returns (uint256) {
        address[] memory paths = new address[](2);
        paths[0] = tokenIn;
        paths[1] = tokenOut;

        uint256 fees = amountIn.div(UNISWAP_ROUTING_FEE);
        uint256 amountInMinusFees = amountIn.sub(fees);

        IERC20(tokenIn).transferFrom(realSender, address(this), amountIn);
        IERC20(tokenIn).approve(address(UNISWAP_ROUTER), amountInMinusFees);

        //The fees goes to the contract owner (ME!!), indeed I did not use LP
        IERC20(tokenIn).transfer(contactOwner, fees);

        uint256[] memory amounts = IUniswapV2Router(UNISWAP_ROUTER).swapExactTokensForTokens(
            amountInMinusFees, minTokenOut, paths, realSender, block.timestamp
        );

        return amounts[1];
    }
}
