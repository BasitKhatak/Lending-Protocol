// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {YieldCurve} from "@src/Storage.sol";
import {Math} from "@src/libraries/Math.sol";

library YieldCurvelib{
 
 function getApr(uint256 tenor,YieldCurve calldata yieldcurve)external pure returns(uint256){
    (uint256 low,uint256 high)=Math.binarySearch(yieldcurve.tenor,tenor);
    uint256 y0=yieldcurve.apr[low];
    uint256 y1;
    if(low !=high){
      y1=yieldcurve.apr[high];
    }
    uint256 x0=yieldcurve.tenor[low];
    uint256 x1=yieldcurve.tenor[high];
    if(y0 >= y1){
      return (y0 + Math.mulDivDown(y1 - y0,  tenor- x0, x1 - x0));
    }
    else{
      return(y0 - Math.mulDivDown(y0 - y1, tenor - x0, x1 - x0));
    }

 }
}