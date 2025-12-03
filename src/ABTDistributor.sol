// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// Interface for the ABT token with the mint function
interface IABTToken is IERC20 {
    function mint(address to, uint256 amount) external;
}

contract ABTDistributor is Ownable {
    using SafeERC20 for IERC20;

    // --- Core Configuration ---
    IABTToken public abtToken;
    IERC20 public requiredToken; // The token users must hold and receive as reward

    // --- ABT Claim Limits ---
    // Max number of separate 'claim' transactions a user can make per day
    uint256 public constant MAX_ABT_CLAIMS_PER_DAY = 20;

    // --- Campaign Configuration (Stored in smallest units, e.g., Wei) ---
    bool public isCampaignActive;            // Master switch for the campaign
    uint256 public rewardAmountPerUser;      // Amount of requiredToken to give per user (in smallest units)
    uint256 public maxGlobalRewardsPerDay;   // Total limit of requiredToken rewards for ALL users daily (in smallest units)
    
    // --- State Tracking ---
    struct UserState {
        uint256 dailyAbtClaims;    // How many ABT claims made today
        uint256 lastAbtDayId;      // Day ID for ABT claims reset
        uint256 lastRewardDayId;   // Day ID for the last Bonus Reward received reset
    }

    // Tracks daily global usage for the campaign
    struct GlobalCampaignState {
        uint256 totalRewardsToday; // Total rewards distributed today (in smallest units)
        uint256 lastResetDayId;
    }

    mapping(address => UserState) public userStates;
    GlobalCampaignState public campaignState;

    // --- Events ---
    event AbtClaimed(address indexed user, uint256 amount, uint256 time);
    event CampaignRewardSent(address indexed user, uint256 amount);
    event CampaignConfigUpdated(bool isActive, uint256 rewardAmount, uint256 dailyCap);

    // --- Constants for Token Conversion ---
    // Used to convert whole token amounts to their smallest unit (10^18 for standard ERC20)
    uint256 private constant TOKEN_DECIMALS_MULTIPLIER = 10**18;

    constructor(
        address _abtTokenAddress, 
        address _requiredTokenAddress, 
        address _initialOwner
    ) Ownable(_initialOwner) {
        require(_abtTokenAddress != address(0), "Invalid ABT Token");
        require(_requiredTokenAddress != address(0), "Invalid Required Token");
        
        abtToken = IABTToken(_abtTokenAddress);
        requiredToken = IERC20(_requiredTokenAddress);
    }

    /**
     * @dev Main function to claim ABT + optional Campaign Reward
     */
    function claim(uint256 _claimAmount) external {
        // 1. Validate Input (1 to 10 ABT *whole tokens*)
        require(_claimAmount >= 1 && _claimAmount <= 10, "Claim amount must be between 1 and 10");
        
        // 2. Validate Holding (Must hold a non-zero balance of the Required Token)
        require(requiredToken.balanceOf(msg.sender) > 0, "Must hold required token to claim");

        // 3. Calculate Time (Day ID changes at 12 AM UTC)
        uint256 currentDayId = block.timestamp / 1 days;
        UserState storage state = userStates[msg.sender];

        // --- Logic A: ABT Daily Limit (20x per day) ---
        
        // Reset if new day
        if (state.lastAbtDayId < currentDayId) {
            state.dailyAbtClaims = 0;
            state.lastAbtDayId = currentDayId;
        }

        require(state.dailyAbtClaims < MAX_ABT_CLAIMS_PER_DAY, "ABT Daily limit reached (20/20)");

        // Increment count
        state.dailyAbtClaims += 1;

        // --- Logic B: Campaign Reward (1x per day, conditional) ---
        _tryProcessCampaignReward(msg.sender, currentDayId);

        // --- Logic C: Mint ABT ---
        // Convert whole token amount to smallest unit for minting
        uint256 abtMintAmount = _claimAmount * TOKEN_DECIMALS_MULTIPLIER;
        abtToken.mint(msg.sender, abtMintAmount);

        emit AbtClaimed(msg.sender, abtMintAmount, block.timestamp);
    }

    /**
     * @dev Internal function to handle the bonus reward logic safely
     */
    function _tryProcessCampaignReward(address user, uint256 dayId) internal {
        // 1. Check if Campaign is ON
        if (!isCampaignActive) return;

        // 2. Check if User already got reward today
        if (userStates[user].lastRewardDayId == dayId) return;

        // 3. Check Global Daily Reset
        if (campaignState.lastResetDayId < dayId) {
            campaignState.totalRewardsToday = 0;
            campaignState.lastResetDayId = dayId;
        }

        // 4. Check Global Daily Cap
        if (campaignState.totalRewardsToday + rewardAmountPerUser > maxGlobalRewardsPerDay) return;

        // 5. Check Contract Balance
        uint256 contractBalance = requiredToken.balanceOf(address(this));
        if (contractBalance < rewardAmountPerUser) return;

        // --- EXECUTE REWARD ---
        
        // Update User State (Critical: Done before external call)
        userStates[user].lastRewardDayId = dayId;
        
        // Update Global State (Critical: Done before external call)
        campaignState.totalRewardsToday += rewardAmountPerUser;

        // Transfer Reward (Uses SafeERC20)
        requiredToken.safeTransfer(user, rewardAmountPerUser);
        
        emit CampaignRewardSent(user, rewardAmountPerUser);
    }

    // --- Admin Functions ---

    /**
     * @dev Configure the campaign. The inputs are expected to be in WHOLE tokens
     * and are internally converted to the smallest unit (10^18).
     * @param _isActive Turn campaign on/off
     * @param _rewardAmountWhole Amount of *whole* tokens per user (e.g., 10)
     * @param _dailyCapWhole Max total *whole* tokens to distribute per day (e.g., 1000)
     */
    function setCampaignConfig(
        bool _isActive, 
        uint256 _rewardAmountWhole, 
        uint256 _dailyCapWhole
    ) external onlyOwner {
        // Security Enhancement: If the campaign is active, prevent setting the reward to 0
        if (_isActive) {
            require(_rewardAmountWhole > 0, "Reward amount must be > 0 when active");
        }
        
        // Convert whole token amounts to the smallest unit (Wei-equivalent)
        rewardAmountPerUser = _rewardAmountWhole * TOKEN_DECIMALS_MULTIPLIER;
        maxGlobalRewardsPerDay = _dailyCapWhole * TOKEN_DECIMALS_MULTIPLIER;
        
        isCampaignActive = _isActive;

        emit CampaignConfigUpdated(_isActive, rewardAmountPerUser, maxGlobalRewardsPerDay);
    }

    /**
     * @dev Withdraw remaining reward tokens from the contract
     */
    function withdrawRequiredToken(uint256 amount) external onlyOwner {
        requiredToken.safeTransfer(msg.sender, amount);
    }
    
    /**
     * @dev Update required token address if needed
     */
    function setRequiredToken(address _newRequiredToken) external onlyOwner {
        // Security Enhancement: Validate against zero address
        require(_newRequiredToken != address(0), "New token cannot be zero address");
        requiredToken = IERC20(_newRequiredToken);
    }
}