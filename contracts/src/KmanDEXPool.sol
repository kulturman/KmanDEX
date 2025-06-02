// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import "./interfaces/KmanDEXPoolInterface.sol";
import {IERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IUniswapV2Router} from "./interfaces/IUniswapV2Router.sol";
import {Math} from "../lib/openzeppelin-contracts/contracts/utils/math/Math.sol";

contract KmanDEXPool is KmanDEXPoolInterface {
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

    function initialize(address contractOwner_, address factory_, address router_, address tokenA_, address tokenB_)
        external
    {
        require(msg.sender == factory_, CallFromAnotherAddressThanFactory(msg.sender));
        require(factory == address(0), AlreadyInitialized());
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

    function investLiquidity(address realSender, uint256 amountTokenA, uint256 amountTokenB, uint256 minimumShares)
        external
        onlyRouter
    {
        require(amountTokenA > 0 && amountTokenB > 0, InvalidAmount());
        require(realSender != address(0), InvalidAddress());
        //Use a local variable to avoid reading from storage multiple times
        uint256 localTotalShares = totalShares;

        if (localTotalShares == 0) {
            localTotalShares = INITIAL_SHARES;
            shares[realSender] = INITIAL_SHARES;
            require(minimumShares <= INITIAL_SHARES, MinimumSharesNotMet(minimumShares, INITIAL_SHARES));
        } else {
            uint256 sharesToMint = Math.min(
                (amountTokenA * localTotalShares) / tokenAAmount, (amountTokenB * localTotalShares) / tokenBAmount
            );
            require(minimumShares <= sharesToMint, MinimumSharesNotMet(minimumShares, sharesToMint));
            shares[realSender] += sharesToMint;
            localTotalShares += sharesToMint;
        }

        totalShares = localTotalShares;
        tokenAAmount += amountTokenA;
        tokenBAmount += amountTokenB;
        invariant = tokenAAmount * tokenBAmount;

        require(IERC20(tokenA).transferFrom(router, address(this), amountTokenA));
        require(IERC20(tokenB).transferFrom(router, address(this), amountTokenB));

        emit LiquidityAdded(realSender, amountTokenA, amountTokenB);
    }

    function withdrawLiquidity(address realSender, uint256 sharesToBurn) external onlyRouter {
        uint256 realSenderShares = shares[realSender];

        require(
            realSenderShares >= sharesToBurn && sharesToBurn > 0, NotEnoughShares(realSenderShares, sharesToBurn)
        );
        shares[realSender] -= sharesToBurn;

        uint256 localTotalShares = totalShares;
        uint256 amountTokenA = (sharesToBurn * tokenAAmount);
        uint256 amountTokenB = (sharesToBurn * tokenBAmount);

        // We can safely divide by localTotalShares here because we already checked that sharesToBurn <= totalShares and sharesToBurn > 0
        assembly {
            amountTokenA := div(amountTokenA, localTotalShares)
            amountTokenB := div(amountTokenB, localTotalShares)
        }

        localTotalShares -= sharesToBurn;
        tokenAAmount -= amountTokenA;
        tokenBAmount -= amountTokenB;
        invariant = tokenAAmount * tokenBAmount;

        totalShares = localTotalShares;

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

        return _swap(realSender, tokenIn, tokenOut, amountIn, minTokenOut);
    }

    // I avoided using cache variables here because it triggered a stack too deep error and the logic is simple enough to not require it.

    function _swap(address realSender, address tokenIn, address tokenOut, uint256 amountIn, uint256 minTokenOut)
        internal
        returns (uint256)
    {
        uint256 fee = amountIn;

        assembly {
            fee := div(fee, FEE_RATE)
        }

        uint256 amountInAfterFee = amountIn - fee;

        uint256 tokenInAmount = tokenIn == tokenA ? tokenAAmount : tokenBAmount;
        uint256 tokenOutAmount = tokenOut == tokenA ? tokenAAmount : tokenBAmount;

        uint256 newTokenInAmount = tokenInAmount + amountInAfterFee;
        uint256 newTokenOutAmount = invariant;

        assembly {
            newTokenOutAmount := div(newTokenOutAmount, newTokenInAmount)
        }

        uint256 amountOut = tokenOutAmount - newTokenOutAmount;

        require(amountOut >= minTokenOut && amountOut <= tokenOutAmount, MinimumAmountNotMet(minTokenOut, amountOut));

        if (tokenIn == tokenA) {
            tokenAAmount += amountIn;
            tokenBAmount = newTokenOutAmount;
        } else {
            tokenBAmount += amountIn;
            tokenAAmount = newTokenOutAmount;
        }

        invariant = tokenAAmount * tokenBAmount;

        require(IERC20(tokenIn).transferFrom(router, address(this), amountIn));
        require(IERC20(tokenOut).transfer(realSender, amountOut));

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

        uint256 fees = amountIn / UNISWAP_ROUTING_FEE;
        uint256 amountInMinusFees = amountIn - fees;

        IERC20(tokenIn).transferFrom(realSender, address(this), amountIn);
        IERC20(tokenIn).approve(UNISWAP_ROUTER, amountInMinusFees);

        if (fees > 0) {
            IERC20(tokenIn).transfer(contactOwner, fees);
        }

        uint256[] memory amounts = IUniswapV2Router(UNISWAP_ROUTER).swapExactTokensForTokens(
            amountInMinusFees, minTokenOut, paths, realSender, block.timestamp
        );

        return amounts[1];
    }
}
