// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface IPriceFeed{
    function getETHPrice()external view returns(uint256);
    function getUSDCPrice()external view returns(uint256);
}