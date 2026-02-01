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
    uint256 public constant LIQUIDATION_PENALTY = 500; // 5% penalty
    uint256 public constant LIQUIDATION_REWARD = 100; // 1% reward for liquidator
    uint256 public constant MAX_INTEREST_RATE = 5000; // 50% max interest
    
    // ============ STATE VARIABLES ============
    uint256 public loanCounter;
    
    // Mappings
    mapping(uint256 => Loan) public loans;
    mapping(address => uint256[]) public userLoans;
    mapping(address => LenderPosition) public lenderPositions;
    mapping(address => uint256) public totalLiquidity; // Total tokens available for lending
    mapping(address => uint256) public totalBorrowed; // Total tokens currently borrowed
    mapping(address => TokenConfig) public tokenConfigs;
    mapping(address => mapping(address => bool)) public approvedCollaterals; // loanToken => collateralToken => approved
    
    // ============ EVENTS ============
    event LoanCreated(
        uint256 indexed loanId,
        address indexed borrower,
        address indexed lender,
        address loanToken,
        address collateralToken,
        uint256 amount,
        uint256 collateralAmount,
        uint256 interestRate,
        uint256 dueTime
    );
    
    event LoanRepaid(
        uint256 indexed loanId,
        address indexed borrower,
        uint256 amountPaid,
        uint256 collateralReturned
    );
    
    event LoanLiquidated(
        uint256 indexed loanId,
        address indexed liquidator,
        address indexed borrower,
        uint256 amountRepaid,
        uint256 collateralSeized
    );
    
    event LiquidityAdded(
        address indexed lender,
        address indexed token,
        uint256 amount
    );
    
    event LiquidityWithdrawn(
        address indexed lender,
        address indexed token,
        uint256 amount
    );
    
    event InterestAccrued(
        address indexed lender,
        address indexed token,
        uint256 interestAmount
    );
    
    event TokenConfigUpdated(
        address indexed token,
        bool enabled,
        uint256 minCollateralRatio,
        uint256 maxLoanTerm,
        uint256 baseInterestRate
    );
    
    event CollateralApproved(
        address indexed loanToken,
        address indexed collateralToken,
        bool approved
    );
    
    // ============ MODIFIERS ============
    
    /**
     * @dev Modifier to check if token is enabled for lending
     */
    modifier tokenEnabled(address token) {
        require(tokenConfigs[token].enabled, "Token not enabled");
        _;
    }
    
    /**
     * @dev Modifier to check if loan exists and is active
     */
    modifier loanActive(uint256 loanId) {
        require(loanId < loanCounter, "Loan does not exist");
        require(loans[loanId].isActive, "Loan not active");
        require(!loans[loanId].isLiquidated, "Loan liquidated");
        _;
    }
    
    // ============ CONSTRUCTOR ============
    
