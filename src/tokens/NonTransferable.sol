// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import{ERC20}from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import{Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";


contract NonTransferable is ERC20,Ownable{

    uint8  immutable decimal;
    constructor(address  owner,string memory name,string memory symbol,uint8 _decimal)ERC20(name,symbol)Ownable(owner){
        decimal=_decimal;     
    }

    function mint(address reciever, uint256 amount)public onlyOwner{
        super._mint(reciever,amount);
    }

    function burn(address reciever,uint256 amount)public onlyOwner{
        super._burn(reciever,amount);
    }

    function transfer(address to,uint256 _amount) public virtual override returns (bool result){
        result=super.transfer(to,_amount);
        return(result);
    }

    function approve(address, uint256) public virtual override returns (bool) {
        revert("Not supported");
    }
     function _decimals() public view  returns (uint8) {
        return decimal;
    }
    
}