// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import{IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {NonTransferable} from "@src/tokens/NonTransferable.sol"; 
import{IWETH} from "@src/Interfaces/IWETH.sol";


   uint256 constant PERCENT=1e18;

   enum AmountType{
    credit,
    cashamount
   }

    struct FeeConfigurartions{
        uint256 swapfee_percent;
        uint256 protocol_liquidationFee;
        uint256 overdueloan_protocol_liquidationFee;
        uint256 liquidatorreward_percent;
        address feeReciever;
    }

    struct RiskParms{
        uint256 crliquidation;
        uint256 cropenining;
        uint256 minBorrowtoken;
        uint256 minBuyCredit;
        uint256 maxtenor;
        uint256 mintenor;
    }

    struct DataParms{
        address underlyingborrowtoken;
        address underlyingcollatoraltoken;
        address pricefeed;
        address variablePool;
    }
    struct Tokens{
        NonTransferable collatoraltoken;
        NonTransferable borrowtoken;
        NonTransferable debttoken;
        
    }

    struct DepositParms{
        address token;
        uint256 amount; 
    }

    struct WithdrawParms{
        address token;
        uint256 amount;
        address to;
    }

    struct YieldCurve{
        uint256[] apr;
        uint256[] tenor; 
    }

    struct LoanOffer{
        YieldCurve yieldCurve;  
        uint256 maxdue;
    }

    struct BorrowOffer{
        YieldCurve yieldCurve;
        bool Fullsale;    
    }
    struct CreditPosition{
        address lender;
        uint256 debpositionId;
        uint256 creditamount;
    }

    struct DebtPosition{
        address borrower;
        uint256 futurevalue;
        uint256 duedate;
    }

    struct BuyCreditParms{
        AmountType anounttype;
        uint256 amount;
        uint256 duration;
        uint256 creditPositionId;
        address borrower;
        uint256 minCredit;
        address lender;
        bool newPosition;
        uint256 deadline;
        uint256 tenor;
        uint256 minAPR;
        
    }

    struct SellCreditparms{
        uint256 creditPositionId;
        uint256 amount;
        uint256 minCash;
        AmountType amounttype;
        address lender;
    }

    struct RepayParms{
        uint256 amount;
        uint256 creditpositionId;
        AmountType amounttype;  
    }

    struct LiquidationParms{
        uint256 debtpositionId;
        uint256 minCollatoral;
    }
