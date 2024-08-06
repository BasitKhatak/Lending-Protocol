// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;


interface IAtoken{
     function scaledBalanceOf(address user) external view  returns (uint256);
}