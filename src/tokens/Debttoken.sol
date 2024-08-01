// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import{ERC20}from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import{Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";


contract Debttoken is ERC20,Ownable{

    address public rootaddress;
    constructor(string memory name,string memory symbol,address root)ERC20(name,symbol)Ownable(msg.sender){
        if(root == address(0)){
            revert("root ontract must be non zero");
        } 
        rootaddress=root;   
    }

    function mint(address reciever, uint256 amount)public{
        require(msg.sender == rootaddress);
        super._mint(reciever,amount);
    }

    function burn(address reciever,uint256 amount)public{
        require(msg.sender == rootaddress);
        super._burn(reciever,amount);
    }

    function approve
    
}
