// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Import OpenZeppelin's ERC20 interface and SafeMath (though not needed in ^0.8.0)
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title ERC20TokenLoan
 * @dev A decentralized lending protocol for ERC20 tokens
 * Features:
 * - Lenders can deposit tokens to earn interest
 * - Borrowers can take loans with collateral
 * - Dynamic interest rates based on utilization
 * - Collateral ratio requirements
 * - Liquidations for undercollateralized loans
 * - Loan term limits
 */
contract ERC20TokenLoan is Ownable, ReentrancyGuard {
    
    // ============ STRUCTS ============
    
    /**
     * @dev Struct representing a loan
     * @param borrower Address of the borrower
     * @param lender Address of the lender (0 if from pool)
     * @param amountPrincipal Original loan amount
     * @param amountOwed Current amount owed (principal + interest)
     * @param collateralAmount Amount of collateral tokens deposited
     * @param collateralToken Address of collateral token
     * @param loanToken Address of loan token
     * @param interestRate Annual interest rate (in basis points, 100 = 1%)
     * @param startTime Timestamp when loan was taken
     * @param dueTime Timestamp when loan is due
     * @param isActive Whether the loan is active
     * @param isLiquidated Whether the loan has been liquidated
     */
    struct Loan {
        address borrower;
        address lender;
        uint256 amountPrincipal;
        uint256 amountOwed;
        uint256 collateralAmount;
        address collateralToken;
        address loanToken;
        uint256 interestRate; // in basis points (1% = 100)
        uint256 startTime;
        uint256 dueTime;
        bool isActive;
        bool isLiquidated;
    }
    
    /**
     * @dev Struct representing a lender's position
     * @param amountDeposited Total amount deposited
     * @param amountLent Amount currently lent out
     * @param lastInterestUpdate Last time interest was calculated
     * @param accumulatedInterest Interest earned so far
     */
    struct LenderPosition {
        uint256 amountDeposited;
        uint256 amountLent;
        uint256 lastInterestUpdate;
        uint256 accumulatedInterest;
    }
    
    /**
     * @dev Struct for token configuration
     * @param enabled Whether this token is enabled for lending/borrowing
     * @param minCollateralRatio Minimum collateral ratio (in basis points)
     * @param maxLoanTerm Maximum loan term in seconds
     * @param baseInterestRate Base interest rate (in basis points)
     */
    struct TokenConfig {
        bool enabled;
        uint256 minCollateralRatio; // 15000 = 150%
        uint256 maxLoanTerm; // in seconds
        uint256 baseInterestRate; // in basis points
    }
    
    // ============ CONSTANTS ============
    uint256 public constant BASIS_POINTS = 10000; // 100% = 10000 basis points
    uint256 public constant SECONDS_PER_YEAR = 365 days;
