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
        
        // Check if collateral covers repayment + penalty
        require(collateralValue >= totalRepayment, "Insufficient collateral for liquidation");
        
        // Calculate liquidator reward (1% of collateral)
        uint256 liquidatorReward = (loan.collateralAmount * LIQUIDATION_REWARD) / BASIS_POINTS;
        uint256 remainingCollateral = loan.collateralAmount - liquidatorReward;
        
        // Transfer repayment from liquidator
        IERC20(loan.loanToken).transferFrom(msg.sender, address(this), repaymentRequired);
        
        // Transfer collateral to liquidator (reward)
        IERC20(loan.collateralToken).transfer(msg.sender, liquidatorReward);
        
        // Transfer remaining collateral to pool/lender
        if (loan.lender == address(0)) {
            // Loan was from pool
            IERC20(loan.collateralToken).transfer(address(this), remainingCollateral);
            totalLiquidity[loan.loanToken] += repaymentRequired;
        } else {
            // P2P loan
            IERC20(loan.collateralToken).transfer(loan.lender, remainingCollateral);
        }
        
        // Update loan state
        loan.isActive = false;
        loan.isLiquidated = true;
        loan.amountOwed = 0;
        
        // Update borrowed amount
        if (loan.lender == address(0)) {
            totalBorrowed[loan.loanToken] -= loan.amountPrincipal;
        }
        
        emit LoanLiquidated(
            loanId,
            msg.sender,
            loan.borrower,
            repaymentRequired,
            loan.collateralAmount
        );
    }
    
    // ============ INTEREST FUNCTIONS ============
    
    /**
     * @dev Accrue interest for a lender
     * @param lender Address of lender
     * @param token Address of token
     */
    function _accrueInterest(address lender, address token) internal {
        LenderPosition storage position = lenderPositions[lender];
        
        if (position.amountLent == 0) return;
        
        uint256 timeElapsed = block.timestamp - position.lastInterestUpdate;
        if (timeElapsed == 0) return;
        
        // Calculate interest based on utilization rate
        uint256 utilizationRate = totalBorrowed[token] * BASIS_POINTS / 
                                 (totalLiquidity[token] + totalBorrowed[token]);
        
        // Base rate + utilization premium
        uint256 currentRate = tokenConfigs[token].baseInterestRate + 
                            (utilizationRate * 100 / BASIS_POINTS); // 1% premium per 100% utilization
        
        // Calculate interest
        uint256 interest = (position.amountLent * currentRate * timeElapsed) / 
                         (BASIS_POINTS * SECONDS_PER_YEAR);
        
        position.accumulatedInterest += interest;
        position.lastInterestUpdate = block.timestamp;
        
        emit InterestAccrued(lender, token, interest);
    }
    
    /**
     * @dev Claim accumulated interest
     * @param token Address of token
     */
    function claimInterest(address token) external nonReentrant {
        _accrueInterest(msg.sender, token);
        
        LenderPosition storage position = lenderPositions[msg.sender];
        uint256 interest = position.accumulatedInterest;
        
        require(interest > 0, "No interest to claim");
        require(interest <= totalLiquidity[token], "Insufficient liquidity");
        
        position.accumulatedInterest = 0;
        totalLiquidity[token] -= interest;
        
        IERC20(token).transfer(msg.sender, interest);
    }
    
    // ============ VIEW FUNCTIONS ============
    
    /**
     * @dev Get current utilization rate for a token
     * @param token Address of token
     * @return Utilization rate in basis points
     */
    function getUtilizationRate(address token) public view returns (uint256) {
        uint256 totalSupply = totalLiquidity[token] + totalBorrowed[token];
        if (totalSupply == 0) return 0;
        return (totalBorrowed[token] * BASIS_POINTS) / totalSupply;
    }
    
    /**
     * @dev Check if a loan is undercollateralized
     * @param loanId ID of loan
     * @return True if undercollateralized
     */
    function _isUndercollateralized(uint256 loanId) internal view returns (bool) {
        Loan storage loan = loans[loanId];
        
        uint256 collateralValue = _getTokenValue(loan.collateralToken, loan.collateralAmount);
        uint256 loanValue = _getTokenValue(loan.loanToken, loan.amountOwed);
        
        // Apply safety margin (10%)
        uint256 requiredCollateral = (loanValue * tokenConfigs[loan.loanToken].minCollateralRatio * 11000) / 
                                    (BASIS_POINTS * 10000);
        
        return collateralValue < requiredCollateral;
    }
    
    /**
     * @dev Calculate dynamic interest rate
     * @param token Address of token
     * @param amount Amount to borrow
     * @return Interest rate in basis points
     */
    function _calculateInterestRate(address token, uint256 amount) internal view returns (uint256) {
        TokenConfig storage config = tokenConfigs[token];
        uint256 utilizationBefore = getUtilizationRate(token);
        
        // Calculate new utilization if this loan is taken
        uint256 newBorrowed = totalBorrowed[token] + amount;
        uint256 newTotal = totalLiquidity[token] + newBorrowed;
        uint256 utilizationAfter = (newBorrowed * BASIS_POINTS) / newTotal;
        
        // Base rate + utilization premium
        uint256 rate = config.baseInterestRate + 
                      (utilizationAfter * 200 / BASIS_POINTS); // 2% premium per 100% utilization
        
        return rate > MAX_INTEREST_RATE ? MAX_INTEREST_RATE : rate;
    }
    
    /**
     * @dev Get value of tokens (simplified - in production use oracle)
     * @param token Address of token
     * @param amount Amount of tokens
     * @return Value in USD (simplified as 1:1 for same token type)
     */
    function _getTokenValue(address token, uint256 amount) internal pure returns (uint256) {
        // In production, use Chainlink oracles or TWAP
        // This is a simplified version assuming 1 token = 1 USD for demo
        // Different tokens would have different prices in reality
        return amount;
    }
    
    // ============ ADMIN FUNCTIONS ============
    
    /**
     * @dev Configure a token for lending
     * @param token Address of token
     * @param enabled Whether token is enabled
     * @param minCollateralRatio Minimum collateral ratio in basis points
     * @param maxLoanTerm Maximum loan term in seconds
     * @param baseInterestRate Base interest rate in basis points
     */
    function configureToken(
        address token,
        bool enabled,
        uint256 minCollateralRatio,
        uint256 maxLoanTerm,
        uint256 baseInterestRate
    ) external onlyOwner {
        require(minCollateralRatio >= 11000, "Collateral ratio too low"); // Min 110%
        require(baseInterestRate <= MAX_INTEREST_RATE, "Interest rate too high");
        
        tokenConfigs[token] = TokenConfig({
            enabled: enabled,
            minCollateralRatio: minCollateralRatio,
            maxLoanTerm: maxLoanTerm,
            baseInterestRate: baseInterestRate
        });
        
        emit TokenConfigUpdated(token, enabled, minCollateralRatio, maxLoanTerm, baseInterestRate);
    }
    
    /**
     * @dev Approve a collateral token for a loan token
     * @param loanToken Address of loan token
     * @param collateralToken Address of collateral token
     * @param approved Whether approved
     */
    function approveCollateral(
        address loanToken,
        address collateralToken,
        bool approved
    ) external onlyOwner {
        approvedCollaterals[loanToken][collateralToken] = approved;
        emit CollateralApproved(loanToken, collateralToken, approved);
    }
    
    /**
     * @dev Emergency withdraw tokens (admin only)
     * @param token Address of token
     * @param amount Amount to withdraw
     */
    function emergencyWithdraw(address token, uint256 amount) external onlyOwner {
        IERC20(token).transfer(owner(), amount);
    }
    
    /**
     * @dev Get loan details
     * @param loanId ID of loan
     * @return Loan struct
