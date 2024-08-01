// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import{ERC20}from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import{Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";


contract NonTransferable is ERC20,Ownable{

    uint256  immutable decimal;
    constructor(address memory owner,string memory name,string memory symbol,uint256 _decimal)ERC20(name,symbol)Ownable(owner){
        decimal=_decimal;     
    }

    function mint(address reciever, uint256 amount)public onlyOwner{
        super._mint(reciever,amount);
    }

    function burn(address reciever,uint256 amount)public onlyOwner{
        super._burn(reciever,amount);
    }

    function transfer(address to,uint256 _amount)public onlyOwner{
        super.transfer(to,_amount);
    }

    function approve(address, uint256) public virtual override returns (bool) {
        revert Errors.NOT_SUPPORTED();
    }
     function decimals() public view virtual override returns (uint8) {
        return decimal;
    }
    
}