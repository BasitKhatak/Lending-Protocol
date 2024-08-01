// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;


Interface IWETH{
    function deposit() external payable;
    function balanceOf(address)external returns(uint);
}