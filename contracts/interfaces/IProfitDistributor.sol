// SPDX-License-Identifier: MIT

pragma solidity >= 0.8.0;

interface IProfitDistributor{
    function distributeProfit(uint256 amountTokens) external;
}
