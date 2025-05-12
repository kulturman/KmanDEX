// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import "../lib/forge-std/src/console.sol";
import {IERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {Math} from "../lib/openzeppelin-contracts/contracts/utils/math/Math.sol";

interface KmanDEXPoolInterface {
    error InvalidAddress();
}

contract KmanDEXPool is KmanDEXPoolInterface {
    address private factory;
    address public tokenA;
    address public tokenB;

    uint256 public totalShares;
    mapping(address => uint256) public shares;
    uint256 public invariant;

    uint256 public constant TOTAL_SHARES = 1000;

    uint256 public tokenAAmount;
    uint256 public tokenBAmount;

    constructor(address factory_, address tokenA_, address tokenB_) {
        factory = factory_;
        tokenA = tokenA_;
        tokenB = tokenB_;
    }

    function investLiquidity(uint256 amountTokenA, uint256 amountTokenB) external {
        require(amountTokenA > 0 && amountTokenB > 0, "Invalid amounts");
        require(msg.sender != address(0), InvalidAddress());

        if (totalShares == 0) {
            //First investor
            totalShares = TOTAL_SHARES;
            shares[msg.sender] = TOTAL_SHARES;
        } else {
            //Subsequent investors
            uint256 sharesToMint =
                Math.min(amountTokenA * totalShares / tokenAAmount, amountTokenB * totalShares / tokenBAmount);
            shares[msg.sender] = sharesToMint;
            totalShares += sharesToMint;
        }

        tokenAAmount += amountTokenA;
        tokenBAmount += amountTokenB;

        //Use safe math library for multiplication to prevent overflow later
        invariant = tokenAAmount * tokenBAmount;
        require(IERC20(tokenA).transferFrom(msg.sender, address(this), amountTokenA));
        require(IERC20(tokenB).transferFrom(msg.sender, address(this), amountTokenB));
    }
}
