// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

interface KmanDEXPoolInterface {
    error InvalidAddress();
    error InvalidAmount();
    error NotEnoughShares(uint256 actualShares, uint256 sharesToBurn);
    error MinimumSharesNotMet(uint256 minimumShares, uint256 sharesToMint);
    error MinimumAmountNotMet(uint256 minTokenOut, uint256 amountOut);
    error CallFromAnotherAddressThanRouter(address sender);
    error CallFromAnotherAddressThanFactory(address sender);
    error AlreadyInitialized();

    event LiquidityAdded(address indexed provider, uint256 amountTokenA, uint256 amountTokenB);
    event LiquidityRemoved(address indexed provider, uint256 sharesBurned, uint256 amountTokenA, uint256 amountTokenB);

    function investLiquidity(address realSender, uint256 amountTokenA, uint256 amountTokenB, uint256 minimumShares)
        external;
    function withdrawLiquidity(address realSender, uint256 sharesToBurn) external;
    function swap(address realSender, address tokenIn, uint256 amountIn, uint256 minTokenOut)
        external
        returns (uint256 amountOut);

    function initialize(address contractOwner_, address factory_, address router_, address tokenA_, address tokenB_)
        external;
}
