// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {YieldCurvelib} from "@src/libraries/YieldCurvelib.sol";
import {Math} from "@src/libraries/Math.sol";
import {Oracle} from "@src/Oracle.sol";
import {NonTransferable} from "@src/tokens/NonTransferable.sol";
import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IWETH} from "@src/Interfaces/IWETH.sol";
import {IAtoken} from "@src/Interfaces/IAtoken.sol";
import {IPool} from "@src/Interfaces/IPool.sol";
import {IPriceFeed} from "@src/Interfaces/IPriceFeed.sol"; 
import{
  FeeConfigurartions,
  DataParms,
  RiskParms,
  Tokens,
  DepositParms,
  WithdrawParms,
  YieldCurve,
  LoanOffer,
  BorrowOffer,
  DebtPosition,
  CreditPosition,
  BuyCreditParms,
  RepayParms,
  SellCreditparms,
  LiquidationParms,
  PERCENT
} from "@src/Storage.sol";

///@notice Main contract for user interaction which is used by user

contract Root{

 address public owner;
 
 IWETH public CollatoralToken;
 IERC20 public BorrowToken;
 IPriceFeed public PriceFeed;
 
 FeeConfigurartions public  feeconfig;
 RiskParms public riskparms;
 DataParms public dataparms;
 Tokens public tokens;

 uint256 internal creditId=1; //credit id for creditposition increment everytime new creditposition is created
 uint256 internal debtId=1;  //debt id for debtposition increment everytime new debtposition is created

 mapping(address => LoanOffer)public loanoffers;  //lender address to loanoffer mapping
 mapping(address => BorrowOffer)public borrowoffers;  //Borrower address to Borrowoffer mapping
 mapping(uint256=>CreditPosition)public creditpositions;//creditpositionId to creditposition
 mapping(uint256=>DebtPosition)public debtpositions;//debtpositionId to debtposition
 mapping(uint256=>DebtPosition)public CredittoDebtposition;//creditpositionId to debtposition

 
 constructor(FeeConfigurartions memory _feeconfig,RiskParms memory _riskparms,DataParms memory _dataparms,address _owner){
    require(_feeconfig.swapfee_percent<PERCENT,"swap fee must be less than 100Percent");

    require(_feeconfig.liquidatorreward_percent<PERCENT,"liquidatorreward_percent must be less than 100Percent");
    require(_feeconfig.protocol_liquidationFee<PERCENT,"liquidationfee  must be less than 100Percent");
    require(_feeconfig.overdueloan_protocol_liquidationFee<PERCENT," must be less than 100Percent");
    require(_feeconfig.feeReciever !=address(0));
    require(_owner !=address(0));

    //Validating Riskparmeters//
    require(_riskparms.crliquidation>PERCENT);
    require(_riskparms.cropenining>PERCENT && riskparms.cropenining>riskparms.crliquidation);
    require(_riskparms.minBorrowtoken>0);
    require(_riskparms.maxtenor>0 && riskparms.maxtenor>riskparms.mintenor);
    require(_riskparms.mintenor>0);

    //Validating Dataparms//
    require(_dataparms.underlyingborrowtoken != address(0));
    require(_dataparms.underlyingcollatoraltoken !=address(0));
    require(_dataparms.pricefeed != address(0));
    require (_dataparms.variablePool != address(0));
  
    

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
    dataparms.underlyingcollatoraltoken=_dataparms.underlyingcollatoraltoken;
    dataparms.variablePool=_dataparms.variablePool;

    PriceFeed=IPriceFeed(_dataparms.pricefeed);
    CollatoralToken=IWETH(_dataparms.underlyingcollatoraltoken);
    BorrowToken=IERC20(_dataparms.underlyingborrowtoken);
    tokens.collatoraltoken=new NonTransferable(address(this),ERC20(_dataparms.underlyingcollatoraltoken).name(),ERC20(_dataparms.underlyingcollatoraltoken).symbol(),ERC20(_dataparms.underlyingcollatoraltoken).decimals());
    tokens.borrowtoken=new NonTransferable(address(this),ERC20(_dataparms.underlyingborrowtoken).name(),ERC20(_dataparms.underlyingborrowtoken).symbol(),ERC20(_dataparms.underlyingborrowtoken).decimals());
    tokens.debttoken=new NonTransferable(address(this),ERC20(_dataparms.underlyingborrowtoken).name(),ERC20(_dataparms.underlyingborrowtoken).symbol(),ERC20(_dataparms.underlyingborrowtoken).decimals());
    
    }

    ///@notice deposit function for lender and borrower to deposit collatoral and borrow token.

    function deposit(DepositParms calldata depositparms)public payable{
        //deposit token address must be either USDC or WETH//
        require(depositparms.token==dataparms.underlyingborrowtoken || depositparms.token==dataparms.underlyingcollatoraltoken);
        if(depositparms.amount <=0){
            revert("deposit amount should be greater than zero");
        }
        if((msg.value > 0 && depositparms.amount != msg.value) || (depositparms.token == dataparms.underlyingborrowtoken && msg.value != 0)){
            revert(" USDC or ETH tokens are  not allowed to be deposit at same time");
        }
        
        if(depositparms.token == dataparms.underlyingcollatoraltoken && msg.value == 0 ){
            if(CollatoralToken.balanceOf(msg.sender) < depositparms.amount){
                revert("you do not have enough balance to deposit");
            }
        
        }
        uint256 balanceBefore=CollatoralToken.balanceOf(address(this));
        uint256 netBalance;
        // deposit msg.value to Weth to recieve the Weth which is used in this contract
        if(msg.value > 0){
            CollatoralToken.deposit{value:msg.value}();
            uint256 balanceAfter=CollatoralToken.balanceOf(address(this));
            netBalance=balanceAfter-balanceBefore;
        }
        if(depositparms.token == dataparms.underlyingcollatoraltoken){
            msg.value > 0 ? depositCollatoralToken(netBalance) : depositCollatoralToken(depositparms.amount);   
        }
        if(depositparms.token == dataparms.underlyingborrowtoken){
            depositBorrowToken(depositparms.amount);
        }    
    }

    ///@notice deposit borrowtoken to Aave variable pool
    function depositBorrowToken(uint256 amount)internal{
        IPool pool=IPool(dataparms.variablePool);
        IAtoken atoken=IAtoken(pool.getReserveData(dataparms.underlyingborrowtoken).aTokenAddress);
        uint256 sacledBalance=atoken.scaledBalanceOf(address(this));

        BorrowToken.approve(dataparms.variablePool,amount);
        //deposit USDC in Aave variable Pool
        pool.supply(dataparms.underlyingborrowtoken,amount,address(this),0);

        uint256 NetBalance=atoken.scaledBalanceOf(address(this))-sacledBalance;
        tokens.borrowtoken.mint(msg.sender,NetBalance);
    }
    //mint collatoral tokens for user which represent his/her collatoral in this protocol
    function depositCollatoralToken(uint256 amount)internal{
        tokens.collatoraltoken.mint(msg.sender,amount);
    }

    //Withdraw Borrow or Collatoral token from Protocol//
    function Withdraw(uint256 amount,address to,address token)external{
        if(amount == 0){
            revert("amount should be non zero");
        }
        if(token != dataparms.underlyingborrowtoken && token != dataparms.underlyingcollatoraltoken){
            revert("inavlid token it is not supported");
        }
        if(token == dataparms.underlyingcollatoraltoken){
            if(tokens.collatoraltoken.balanceOf(msg.sender) < amount){
                revert("amount should be within or equal to balance");
            }
            tokens.collatoraltoken.burn(msg.sender,amount);
            if(tokens.debttoken.balanceOf(msg.sender) > 0){
                if(isLiquadatible(msg.sender)){
                    revert("you cannot withfraw collatoral as your laon is liquidatible");
                }
               CollatoralToken.transfer(to,amount);
            }
        }
    }

    ///@notice function to check if borrower position is liquidatible or not
    function isLiquadatible(address user)public view returns(bool){
        uint256 debt=tokens.debttoken.balanceOf(user);
        uint256 collatoral=tokens.collatoraltoken.balanceOf(user);

        uint256 debtInWad=Math.amountToWad(debt,tokens.debttoken._decimals());

        //get the collatoral Price from oracle which is in 18 decimal
        uint256 collatoralPrice=PriceFeed.getETHPrice();
        uint256 collatoralRatio=Math.mulDivDown(collatoral,collatoralPrice,debtInWad);

        if(collatoralRatio == 0){
            return(false);
        }
        else if(collatoralRatio <= riskparms.crliquidation){
            return(true);
        }
        else{
            return(false);
        }
        

    }
    function setloanoffer(LoanOffer calldata loanoffer)external{
        ValidateLoanoffer(loanoffer);
        executeloanoffer(loanoffer);
    }

    //validate laonoffer given by lender
    function ValidateLoanoffer(LoanOffer calldata loanoffer)internal view {
        if(loanoffer.maxdue == 0){
            revert("loan duration must be greater than zero");
        }
        if(loanoffer.maxdue< block.timestamp + riskparms.mintenor){
            revert("loan duration must be greater than mintenor");
        }

        if(loanoffer.yieldCurve.tenor[0] < riskparms.mintenor){
            revert("min tenor must be equal to or greater than protocol min tenor");
        }
        uint256 length=loanoffer.yieldCurve.tenor.length;
        if(loanoffer.yieldCurve.tenor[length-1] > riskparms.maxtenor){
            revert("lender offer maxtenor should be less tha protocol maxtenor");
        }

        if(loanoffer.yieldCurve.tenor.length ==0 || loanoffer.yieldCurve.apr.length == 0){
            revert("Both array length should be greater than zero");
        }
        if(loanoffer.yieldCurve.tenor.length != loanoffer.yieldCurve.apr.length){
            revert("Both array length should be equal");
        }

        for(uint i=length-1; i>0; i--){
            if(loanoffer.yieldCurve.tenor[i-1] >= loanoffer.yieldCurve.tenor[i]){
                revert("tenors must be in ascending order");
            }
        }}

        function executeloanoffer(LoanOffer calldata loanoffer)internal{
            loanoffers[msg.sender]=LoanOffer({yieldCurve:loanoffer.yieldCurve,maxdue:loanoffer.maxdue});
        }
        
        function SetBorrowoffer(BorrowOffer calldata parms)external{
            validateBorrowOffer(parms);
            ExecuteBorrowoffer(parms);
        }


        function ExecuteBorrowoffer(BorrowOffer calldata parms)internal{
             borrowoffers[msg.sender]=BorrowOffer({yieldCurve:parms.yieldCurve,Fullsale:parms.Fullsale});
        }

        ///@notice it validate the Borrow offer to ensure offer do not voilate protocol assign security parameters
        function validateBorrowOffer(BorrowOffer calldata parms)public view{
            if(parms.yieldCurve.tenor.length != parms.yieldCurve.apr.length){
                revert("api and tenor array length should be equal");
            }
            if(parms.yieldCurve.tenor.length==0 || parms.yieldCurve.apr.length==0){
                revert("Both of tenor and api length should be greater than zero");
            }
            uint256 length=parms.yieldCurve.tenor.length;
            if(parms.yieldCurve.tenor[0] < riskparms.mintenor || parms.yieldCurve.tenor[length-1]>riskparms.maxtenor){
                revert("max and min tenor shoild be within protocol specified range");
            }
            for(uint i=(length-1);i>0;i--){
                if(
                    parms.yieldCurve.tenor[i-1] >= parms.yieldCurve.tenor[i]
                ){
                    revert("tenors should be in ascending order");
                }       
            }
        }
        //It validates buyoffer from lender to ensure that it do not voilate the risk Parameters of protocol
        function validateBuyCredit(BuyCreditParms calldata parms)public view {
          CreditPosition memory creditposition=creditpositions[parms.creditPositionId];
          DebtPosition memory deptposition=CredittoDebtposition[creditposition.debpositionId];  
          if(parms.amount < riskparms.minBuyCredit){
              revert("credit must be graeter than minbuyCredit tokens");
            }  
          //First case in which lender give laon to buyer by opening credit and deposit position
          if(parms.newPosition){
            if(parms.creditPositionId !=0){
                revert("invalid credit positionId");
            }
            if(parms.borrower == address(0)){
                revert("borrower address should be valid address");
            }
            if(borrowoffers[parms.borrower].yieldCurve.tenor.length ==0){
                revert("borrow offer do not exist for borrower");
            }
            if(parms.tenor < riskparms.mintenor || parms.tenor >riskparms.maxtenor){
                revert("tenor sould be within max and min tenor range");
            }

          //Second Case in which lender Buy creditPosition from borrower and give a loan to borrower in return
          }
          else{
             if(creditposition.creditamount < riskparms.minBuyCredit){
                revert("invalid creditposition id");
             }
             if(block.timestamp >= deptposition.duedate){
                revert("debt position is expired");
             }
             address borrower=creditpositions[parms.creditPositionId].lender;
             uint256 tenor=deptposition.duedate-block.timestamp;
              
             if(borrowoffers[borrower].yieldCurve.tenor.length ==0){
                revert("Borrow offer do not exist for borrwerer");
             }

             if(parms.amount > CredittoDebtposition[parms.creditPositionId].futurevalue){  
               revert("buy creditamount should be less than total availible credit amount");
             }
             
             //check if minimum creditamount is left after partial sale of credit
             if(!(borrowoffers[borrower].Fullsale)){
                if(riskparms.minBuyCredit > creditposition.creditamount-parms.amount){
                    revert("minBuy creditamount should be left for borrower");
                }
             }
             //check if borrower position is transferable or not
             if(!(isCreditTransferable(deptposition))){
                revert("credit position iss non transferable as depositposition is in under liquidation ratio");
             }
             uint256 APR=YieldCurvelib.getApr(tenor,borrowoffers[borrower].yieldCurve);
             if(parms.minAPR > APR){
                revert("Borrower provided Apr is below minApr");
             }
             }
        }

        //check if debtposition is transferable by borrower or not by comparing its risk parameters to protocol risk parameters
        function isCreditTransferable(DebtPosition memory debtpos)public view returns(bool result){
            uint256 collatoral = tokens.collatoraltoken.balanceOf(debtpos.borrower);
            uint256 debt=tokens.debttoken.balanceOf(debtpos.borrower);
            uint256 debtinWad=Math.amountToWad(debt,tokens.debttoken._decimals());
            uint256 collatoraprice= PriceFeed.getETHPrice();
            uint256 collatoralratio=Math.mulDivDown(collatoral,collatoraprice,debtinWad);

            if(collatoralratio < riskparms.crliquidation){
                return(false);
            }
        }
        //READ FUNTIONS//
        function getdebtposition(uint256 id)public view returns(DebtPosition memory){
            require(id>=0 && id<=debtId,"id should be valid debtpositioId");
            return(debtpositions[id]);
        }
        function getdebtPositionFromCreditId(uint256 creditPositionId)public view returns(DebtPosition memory){
            require(creditPositionId>=0 && creditPositionId<=creditId,"id should be valid creditpositionId");
            return(CredittoDebtposition[creditPositionId]);
        }

}