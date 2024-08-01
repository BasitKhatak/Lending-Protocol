// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import{DataParms} from "../Storage.sol";

interface IAggregator{
    function latestRoundData()
    external
    view
    returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);
}
contract Oracle{
   
   IAggregator public immutable EthPriceFeed; //ETH pricefedd instance.
   IAggregator public immutable USDCPricefeed;//USDC priceFeed instance.
   uint256 public immutable ETHstaletime;
   uint256 publlic immutable USDCstaletime;

   uint256 constant decimal=1e18; //price is returned in 18 decimal;

   constructor(address ETHaddress,address USDCaddress,ETHtime,USDCtime){
    if(ETHaddress == address(0) || USDCaddress == address(0)){
        revert("feed addresses mustt be nonzero address");
    } 
    if(ETHtime == 0 ||USDCtime == 0){
        revert("stale time must be nonzero");
    }
    EthPriceFeed=IAggregator(ETHaddress);
    USDCPricefeed=IAggregator(USDCaddress);
    ETHstaletime=ETHtime;
    USDCstaletime=USDCtime;
   }


   function getETHPrice()public view returns(uint256){
    (int256 price,uint256 updatedAt)=EthPriceFeed.latestRoundData();
    if(block.timestamp - updatedAt > ETHstaletime){
        revert("ETH Price is stale");
    }

    if(price ==0){
        revert("invalid price");
    }
    return(uint256(price));
   }

   function getUSDCPrice()public view returns(uint256){
    (int256 price,uint256 updatedAt)=USDCPricefeed.latestRoundData();
    if(block.timestamp-updatedAt > USDCstaletime){
        revert("price is stale");
    }

    if(price ==0){
        revert("invalid price");
    }

    return(uint256(price));
   }
}