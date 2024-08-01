// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {YieldCurvelib} from "src/libraries/YieldCurvelib.sol";
import {Math} from "src/libraries/Math.sol";
import {Oracle} from "src/Oracle.sol";
import {NonTransferable} from "./tokens/NonTransferable.sol";
import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IWETH} from "./Interfaces/IWETH.sol";
import {IAtoken} from "./Interface/IAtoken.sol";
import {IDataProvider} from "./Interface/IDataProvider.sol";
import {IPool} from "../Interface/IPool.sol";
import{
 DataParms,
 Tokens,
 FeeConfigurartion,
 RiskParms,
 PERCENT,
 DataParms,
 DepositParms,
 LoanOffer,
 BorrowOffer,
 CreditPosition,
 DebtPosition,
 BuyCreditParms
} from ".Storage.sol";



contract Root{

 address public owner;
 FeeConfigurartion public feeconfig;
 RiskParms public riskparms;
 DataParms public dataparms;
 Tokens public tokens;

 IWETH public weth;
 IERC20 public USDC;
 
 uint256 internal creditId=1; //credit id for creditposition increment everytime new creditposition is created//
 uint256 internal debtId=1;  //debt id for debtposition increment everytime new debtposition is created//

 mapping(address => LoanOffer)public loanoffers;  //lender address to loanoffer mapping//
 mapping(address => BorrowOffer)public borrowoffers;  //Borrower address to Borrowoffer mapping//
 mapping(uint256=>CreditPosition)public creditpositions;
 mapping(uint256=>DebtPosition)public debtpositions;
 mapping(uint256=>DebtPosition)public CredittoDebtposition;

 
 constructor(FeeConfigurartion calldata _feeconfig,RiskParms calldata _riskparms,DataParms calldata _dataparms,address _owner){
    require(_feeconfig.swapfee_percent<PERCENT,"swap fee must be less than 100Percent");
    require(dataparms.ETHfeedaddresscv!==address(0) && dataparms.USDCfeedaddress !==address(0),"price fedd address must be zon zero");
    require(_feeconfig.liquidatorreward_percent<PERCENT,"liquidatorreward_percent must be less than 100Percent");
    require(_feeconfig.protocol_liquidationFee<PERCENT,"liquidationfee  must be less than 100Percent");
    require(_feeconfig.overdueloan_protocol_liquidationFee<PERCENT," must be less than 100Percent");
    require(_feeconfig.FeeReciever !=address(0));
    require(_owner !=address(0));

    //Validating Riskparmeters//
    require(_riskparms.crliquidation>PERCENT);
    require(_riskparms.cropenining>PERCENT && riskparms.cropenining>riskparms.crliquidation);
    require(_riskparms.minBorrowtoken>0);
    require(_riskparms.maxtenor>0 && riskparms.maxtenor>riskparms.mintenor);
    require(_riskparms.mintenor>0);

    //Validating Dataparms//
    require(_dataparms.underlyingborrowtoken !== address(0));
    require(_dataparms.underlyingcollatoraltoken !==address(0));
    rquire (_dataparms.variablePool !== address(0));
    require(_dataparms.weth != address(0));
    

    //Initialize data//
    owner=_owner;
    feeconfig.swapfee_percent=_feeconfig.swapfee_percent;
    feeconfig.protocol_liquidationFee=_feeconfig.protocol_liquidationFee;
    feeconfig.overdueloan_protocol_liquidationFee=_feeconfig.overdueloan_protocol_liquidationFee;
    feeconfig.liquidatorreward_percent=_feeconfig.liquidatorreward_percent;
    feeconfig.feeReciever=_feeconfig.feeReciever;

    riskparms.cropenining=_riskparms.cropenining;
    riskparms.crliquidation=_riskparms.crliquidation;
    riskparms.minBorrowtoken=_riskparms.minBorrowtoken;
    riskparms.maxtenor=_riskparms.maxtenor;
    riskparms.mintenor=_riskparms.mintenor;

    dataparms.underlyingborrowtoken=_dataparms.underlyingborrowtoken;
    dataparms.collatoraltoken=_dataparms.underlyingcollatoraltoken;
    dataparms.variablePool=_dataparms.variablePool;
    weth=WETH(_dataparms.underlyingcollatoraltoken);
    USDC=IERC20(_dataparms.underlyingborrowtoken);
    tokens.collatoraltoken=new NonTransferable(address(this),ERC20(_dataparms.underlyingcollatoraltoken).name(),ERC20(_dataparms.underlyingcollatoraltoken).symbol(),ERC20(_dataparms.underlyingcollatoraltoken).decimal());
    tokens.borrowtoken=new NonTransferable(address(this),ERC20(_dataparms.underlyingborrowtoken).name(),ERC20(_dataparms.underlyingborrowtoken).symbol(),ERC20(_dataparms.underlyingborrowtoken).decimal());
    tokens.debttoken=new NonTransferable(address(this),ERC20(_dataparms.underlyingborrowtoken).name(),ERC20(_dataparms.underlyingborrowtoken).symbol(),ERC20(_dataparms.underlyingborrowtoken).decimal());
    tokens.weth=IWETH(_dataparms.weth);
    }

    //deposit function for lender and borrower to deposit collatoral and borrow token.

    function deposit(DepositParms calldata depositparms)public payble{
        //deposit token address must be either USDC or WETH//
        require(depositparms.token==dataparms.borrowtoken || depositparms.token==dataparms.collatoraltoken);
        if(depositparms.amount <=0){
            revert("deposit amount should be greater than zero");
        }
        if((msg.value > 0 && depositparms.amount !== msg.value) || (DepositParms.token == dataparms.underlyingborrowtoken && msg.value !== 0)){
            revert(" USDC or ETH tokens are  not allowed to be deposit at same time");
        }
        
        if(depositparms.token == dataparms.underlyingcollatoraltoken && msg.value == 0 ){
            if(weth.balanceOf(msg.sender) < depositparms.amount){
                revert("you do not have enough balance to deposit");
            }
        
        }
        uint256 balanceBefore=weth.balanceOf(address(this));
        if(msg.value > 0){
            tokens.weth.deposit({value:msg.value});
            uint256 balanceAfter=tokens.weth.balanceOf(address(this));
            uint256 netBalance=balanceAfter-balanceBefore;
        }
        if(depositparms.token == dataparms.underlyingcollatoraltoken){
            msg.value > 0 ? depositCollatoralToken(netBalance) : depositCollatoralToken(depositparms.amount);   
        }
        if(depositparms.token == dataparms.underlyingborrowtoken){
            depositBorrowToken(depositparms.amount);
        }    
    }

    //deposit borrowtoken to Aave variable pool//
    function depositBorrowToken(uint256 amount)internal{
        IPool pool=IPool(dataparms.variablePool);
        IAtoken atoken=IAtoken(pool.getReserveData().aTokenAddress);
        uint256 sacledBalance=atoken.sacledBalance(address(this));

        USDC.approve(dataparms.variablePool,amount);
        //deposit USDC in Aave variable Pool//
        pool.supply(dataparms.underlyingborrowtoken,amount,address(this),0);

        uint256 NetBalance=atoken.sacledBalance(address(this))-sacledBalance;
        tokens.borrowtoken.mint(msg.sender,NetBalance);
    }
    function depositCollatoralToken(uint256 amount)internal{
        tokens.collatoraltoken.mint(msg.sender,amount);
    }

    //Withdraw Borrow or Collatoral token from Protocol//
    function Withdraw(uint256 amount,address to,address token)external{
        if(amount == 0){
            revert("amount should be non zero");
        }
        if(token != tokens.collatoraltoken && token != tokens.borrowtoken){
            revert("inavlid token it is not supported");
        }
        if(token == tokens.collatoraltoken){
            if(tokens.collatoraltoken.balanceOf(msg.sender) < amount){
                revert("amount should be within or equal to balance");
            }
            tokens.collatoraltoken.burn(msg.sender,amount);
            if(tokens.debttoken.balanceOf(msg.sender) > 0){
                if(isLiquadatible(msg.sender)){
                    revert("you cannot withfraw collatoral as your laon is liquidatible");
                }
               weth.transfer(msg.sender,amount);
            }
        }
    }

    function isLiquadatible(address user)public returns(bool){
        uint256 debt=tokens.debttoken.balanceOf(user);
        uint256 collatoral=tokens.collatoraltoken.balanceOf(user);

        uint256 debtInWad=Math.amountToWad(debt,tokens.debttoken.decimal());
        uint256 collatoralPrice=Oracle.getETHprice();
        uint256 collatoralRatio=Math.mulDivDown(collatoral,collatoralPrice,debtInWad);

        if(collatoralRatio == 0){
            return(false);
        }
        elseif(collatoralRatio <= riskparms.crliquidation){
            return(true);
        }
        else{
            return(false);
        }
        

    }
    function setloanoffer(LoanOffer calldata loanoffer)external{
        ValidateLoanoffer(loanoffer);
        Executeloanoffer(loanoffer);
    }

    //validate laonoffer given by lender//
    function ValidateLoanoffer(loanoffer)internal {
        if(loanoffer.maxdue == 0){
            revert("loan duration must be greater than zero");
        }
        if(loanoffer.maxdue< block.timestamp + riskparms.mintenor){
            revert("loan duration must be greater than mintenor");
        }

        if(loanoffer.relativeCurve.tenor[0] < riskparms.mintenor){
            revert("min tenor must be equal to or greater than protocol min tenor");
        }
        uint256 length=relativeCurve.tenor.length;
        if(laonoffer.relativeCurve.tenor[length-1] > riskparms.maxtenor){
            revert("lender offer maxtenor should be less tha protocol maxtenor");
        }

        if(laonoffer.relativeCurve.tenor.length ==0 || loanoffer.relativeCurve.api.length == 0){
            revert("Both array length should be greater than zero");
        }
        if(loanoffer.relativeCurve.tenor.length != loanoffer.relativeCurve.api.length){
            revert("Both array length should be equal")
        }

        for(uint i=length-1; i>0; i--){
            if(loanoffer.relativeCurve.tenor[i-1] >= laonoffer.relativeCurve.tenor[i]){
                revert("tenors must be in ascending order");
            }
        }

        function executeloanoffer(LoanOffer calldata laonoffer)internal{
            loanoffers[msg.sender]=LoanOffer({relativeCurve:laonoffer.relativeCurve,maxdue:loanoffer.maxdue});
        }
        
        function SetBorrowoffer(BorrowOffer calldata parms)external{
            validateBorrowOffer(oarms);


        function executeBorrowoffer(BorrowOffer calldata parms)internal{
             borrowoffers[msg.sender]=BorrowOffer({relativeCurve:parms.relativeCurve});
        }

        function validateBorrowOffer(BorrowOffer calldata parms)public {
            if(parms.relativeCurve.tenor.length != parms.relativeCurve.api.length){
                revert("api and tenor array length should be equal");
            }
            if(parms.relativeCurve.tenor.length==0 || parms.relativeCurve.api.length==0){
                revert("Both of tenor and api length should be greater than zero");
            }
            uint length=parms.relativeCurve.tenor.length;
            if(parms.relativeCurve.tenor[0] < riskparms.mintenor || parms.relativeCurve.tenor[length-1]>riskparms.maxtenor){
                revert("max and min tenor shoild be within protocol specified range");
            }

            
            for(uint i=(length-1),i>0;i--){
                if(
                    parms.relativeCurve.tenor[i-1] >= parms.relativeCurve.tenor[i]
                ){
                    revert("tenors should be in ascending order");
                }
                
            }
        }

        function BuyCredit(BuyCreditParms calldata parms)external {
            
        }

        //It validates buyoffer from lender//
        function validateBuyCredit(BuyCreditParms calldata parms)public{

          if(parms.amount < riskparms.minBuyCredit){
              revert("credit must be graeter than minbuyCredit tokens");
            }  
          //First case in which lender give laon to buyer by opening credit and deposit position//  
          if(parms.newPosition){
            if(parms.creditPositionId !=0){
                revert("invalid credit positionId");
            }
            if(parms.borrower == address(0)){
                revert("borrower address should be valid address")
            }
            if(borrowoffers[parms.borrower].relativeCurve.tenor.length ==0){
                revert("borrow offer do not exist for borrower");
            }
            if(parms.tenor < riskparms.mintenor || parms.tenor >riskparms.maxtenor){
                revert("tenor sould be within max and min tenor range");
            }
            if()

          //Second Case in which lender Buy creditPosition from borrower and give a loan to borrower in return//
          }
          else{

             CreditPosition memory creditposition=creditpositions[parms.creditPositionId];
             DebtPosition memory depositposition=CredittoDebtposition[creditposition.debpositionId];
             if(creditposition.creditamount < riskparms.minBuyCredit){
                revert("invalid creditposition id")
             }
             if(block.timestamp >= depositposition.duedate){
                revert("debt position is expired");
             }
             address borrower=creditpositions[creditPositionId].lender;
             uint256 tenor=depositposition.duedate-block.timestamp;
              
             if(borrowoffers[borrower].relativeCurve.tenor.length ==0){
                revert("Borrow offer do not exist for borrwerer");
             }
             
             
             if(parms.amount > CredittoDebtposition[parms.creditPositionId].futurevalue){
               
               revert("buy creditamount should be less than total availible credit amount");
             }
             
             //check if minimum creditamount is left afetr partial sale of credit//
             if(!(borrowoffers[borrower].Fullsale)){
                if(riskparms.minBuyCredit > creditposition.creditamount-parms.amount){
                    revert("minBuy creditamount should be left for borrower");
                }
             }

             //check if borrower position is transferable or not//
             if(!(isCreditTransferable())){
                revert("credit position iss non transferable as depositposition is in under liquidation ratio");
             }

             uint256 Apr=YieldCurvelib.getApr(tenor,borrowoffers[borrower].relativeCurve);
             if(parms.minAPR > APR){
                revert("Borrower provided Apr is below minApr");
             }
             }
         
        }

        function CreditAmountOut(uint256 cashamount,BorrowOffer memory borrowoffer,uint256 tenor)public returns(uint256){
             uint256 apr=
        }

        function CashamountOut(uint256 creditamount,BorrowOffer memory borrowoffer,uint256 tenor)public returns(uint256){

        }

        function isCreditTransferable(DebtPosition memory debtpos)public returns(bool){
            uint256 collatoral = tokens.collatoraltoken.balanceOf(debtpos.borrower);
            uint256 debt=tokens.debttoken.balanceOf(borrower);
            uint256 debtinWad=Math.amountToWad(debt,dataparms.debttoken.decimal);
            uint256 collatoraprice=Oracle.getETHprice();
            uint256 collatoralratio=Math.mulDivDown(collatoralvalue,collatoraprice,debtinWad);

            if(collatoralratio < riskparms.crliquidation){
                return(false);
            }

        }

        //READ FUNTIONS//
        function getdebtposition(uint256 id)public returns(DebtPosition){
            require(id>=0 && id<=debtId,"id should be valid debtpositioId");
            return(debtpositions[id]);
        }

        function getdebtPositionFromCreditId(uint256 creditPositionId)public returns(DebtPosition){
            require(creditPositionId>=0 && creditpositionId<=creditId,"id should be valid creditpositionId");
            return(CredittoDebtposition[creditPositionId]);
        }

}