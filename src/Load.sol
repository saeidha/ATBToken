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
    
    constructor() {
        loanCounter = 0;
    }
    
    // ============ LENDING FUNCTIONS ============
    
    /**
     * @dev Deposit tokens to lend
     * @param token Address of token to deposit
     * @param amount Amount to deposit
     */
    function depositLiquidity(address token, uint256 amount) 
        external 
        nonReentrant 
        tokenEnabled(token) 
    {
        require(amount > 0, "Amount must be > 0");
        
        // Transfer tokens from lender
        IERC20(token).transferFrom(msg.sender, address(this), amount);
        
        // Update lender position
        LenderPosition storage position = lenderPositions[msg.sender];
        position.amountDeposited += amount;
        position.lastInterestUpdate = block.timestamp;
        
        // Update total liquidity
        totalLiquidity[token] += amount;
        
        emit LiquidityAdded(msg.sender, token, amount);
    }
    
    /**
     * @dev Withdraw deposited tokens (if not lent out)
     * @param token Address of token to withdraw
     * @param amount Amount to withdraw
     */
    function withdrawLiquidity(address token, uint256 amount) 
        external 
        nonReentrant 
    {
        LenderPosition storage position = lenderPositions[msg.sender];
        
        // Calculate available balance (deposited - lent out)
        uint256 availableBalance = position.amountDeposited - position.amountLent;
        require(amount <= availableBalance, "Insufficient available balance");
        
        // Accrue interest before withdrawal
        _accrueInterest(msg.sender, token);
        
        // Update positions
        position.amountDeposited -= amount;
        totalLiquidity[token] -= amount;
        
        // Transfer tokens to lender
        IERC20(token).transfer(msg.sender, amount);
        
        emit LiquidityWithdrawn(msg.sender, token, amount);
    }
    
    // ============ BORROWING FUNCTIONS ============
    
    /**
     * @dev Request a loan from the liquidity pool
     * @param loanToken Address of token to borrow
     * @param collateralToken Address of collateral token
     * @param loanAmount Amount to borrow
     * @param collateralAmount Amount of collateral to deposit
     * @param loanDuration Duration of loan in seconds
     */
    function requestLoan(
        address loanToken,
        address collateralToken,
        uint256 loanAmount,
        uint256 collateralAmount,
        uint256 loanDuration
    ) 
        external 
        nonReentrant 
        tokenEnabled(loanToken)
        returns (uint256) 
    {
        // Validate inputs
        require(loanAmount > 0, "Loan amount must be > 0");
        require(collateralAmount > 0, "Collateral amount must be > 0");
        require(approvedCollaterals[loanToken][collateralToken], "Collateral not approved");
        
        TokenConfig storage config = tokenConfigs[loanToken];
        
        // Check loan duration
        require(loanDuration <= config.maxLoanTerm, "Loan duration too long");
        
        // Calculate collateral ratio
        uint256 collateralValue = _getTokenValue(collateralToken, collateralAmount);
        uint256 loanValue = _getTokenValue(loanToken, loanAmount);
        uint256 collateralRatio = (collateralValue * BASIS_POINTS) / loanValue;
        
        require(collateralRatio >= config.minCollateralRatio, "Insufficient collateral");
        
        // Check available liquidity
        require(loanAmount <= totalLiquidity[loanToken], "Insufficient liquidity");
        
        // Calculate dynamic interest rate
        uint256 interestRate = _calculateInterestRate(loanToken, loanAmount);
        
        // Calculate total owed
        uint256 interestAmount = (loanAmount * interestRate * loanDuration) / 
                                (BASIS_POINTS * SECONDS_PER_YEAR);
        uint256 totalOwed = loanAmount + interestAmount;
        
        // Transfer collateral from borrower
        IERC20(collateralToken).transferFrom(msg.sender, address(this), collateralAmount);
        
        // Transfer loan tokens to borrower
        IERC20(loanToken).transfer(msg.sender, loanAmount);
        
        // Create loan
        uint256 loanId = loanCounter++;
        loans[loanId] = Loan({
            borrower: msg.sender,
            lender: address(0), // From pool
            amountPrincipal: loanAmount,
            amountOwed: totalOwed,
            collateralAmount: collateralAmount,
            collateralToken: collateralToken,
            loanToken: loanToken,
            interestRate: interestRate,
            startTime: block.timestamp,
            dueTime: block.timestamp + loanDuration,
            isActive: true,
            isLiquidated: false
        });
        
        // Update state
        userLoans[msg.sender].push(loanId);
        totalLiquidity[loanToken] -= loanAmount;
        totalBorrowed[loanToken] += loanAmount;
        
        emit LoanCreated(
            loanId,
            msg.sender,
            address(0),
            loanToken,
            collateralToken,
            loanAmount,
            collateralAmount,
            interestRate,
            block.timestamp + loanDuration
        );
        
        return loanId;
    }
    
    /**
     * @dev Repay a loan
     * @param loanId ID of loan to repay
     */
    function repayLoan(uint256 loanId) 
        external 
        nonReentrant 
        loanActive(loanId) 
    {
        Loan storage loan = loans[loanId];
        require(msg.sender == loan.borrower, "Only borrower can repay");
        require(block.timestamp <= loan.dueTime, "Loan overdue");
        
        uint256 amountToRepay = loan.amountOwed;
        
        // Transfer repayment from borrower
        IERC20(loan.loanToken).transferFrom(msg.sender, address(this), amountToRepay);
        
        // Return collateral to borrower
        IERC20(loan.collateralToken).transfer(loan.borrower, loan.collateralAmount);
        
        // Update loan state
        loan.isActive = false;
        loan.amountOwed = 0;
        
        // Update pool state
        if (loan.lender == address(0)) {
            // Loan was from pool
            totalLiquidity[loan.loanToken] += amountToRepay;
            totalBorrowed[loan.loanToken] -= loan.amountPrincipal;
        }
        
        emit LoanRepaid(loanId, msg.sender, amountToRepay, loan.collateralAmount);
    }
    
    // ============ LIQUIDATION FUNCTIONS ============
    
    /**
     * @dev Liquidate an undercollateralized loan
     * @param loanId ID of loan to liquidate
     */
    function liquidateLoan(uint256 loanId) 
        external 
        nonReentrant 
        loanActive(loanId) 
    {
        Loan storage loan = loans[loanId];
        
        // Check if loan is overdue or undercollateralized
        bool isOverdue = block.timestamp > loan.dueTime;
        bool isUndercollateralized = _isUndercollateralized(loanId);
        
        require(isOverdue || isUndercollateralized, "Loan not liquidatable");
        
        // Calculate amounts
        uint256 repaymentRequired = loan.amountOwed;
        uint256 collateralValue = _getTokenValue(loan.collateralToken, loan.collateralAmount);
        
        // Calculate liquidation penalty (5% of loan value)
        uint256 penalty = (repaymentRequired * LIQUIDATION_PENALTY) / BASIS_POINTS;
        uint256 totalRepayment = repaymentRequired + penalty;
