// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;


interface IWETH{
    function deposit() external payable;
    function balanceOf(address)external returns(uint);
    function withdraw(uint256) external;
    function transfer(address to, uint256 value) external;
}