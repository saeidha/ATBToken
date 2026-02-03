// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

/**
 * @title YieldHarvest - Advanced ERC20 Staking & Yield Farming Protocol
 * @dev Features:
 * - Multiple stake types (Flexible, Locked, Boosted)
 * - Dynamic APR based on pool utilization
 * - Referral system with rewards
 * - Auto-compounding interest
 * - NFT-based boost cards
 * - Vesting schedules
 * - Penalty-free early withdrawals with conditions
 * - Governance voting rights for stakers
 */
contract YieldHarvest is ReentrancyGuard, Ownable {
    using SafeMath for uint256;
    
    // ============ ENUMS ============
    enum StakeType {
        FLEXIBLE,    // 0: Withdraw anytime, lower APR
        LOCKED,      // 1: Fixed lock period, medium APR
        BOOSTED      // 2: Locked + NFT boost, highest APR
    }
    
    enum BoostCardTier {
        NONE,        // 0: No boost
        BRONZE,      // 1: 10% APR boost
        SILVER,      // 2: 25% APR boost
        GOLD,        // 3: 50% APR boost
        PLATINUM     // 4: 100% APR boost
    }
    
    // ============ STRUCTS ============
    
    /**
     * @dev User's stake position
     */
    struct StakePosition {
        uint256 stakeId;
        address user;
        address token;
        StakeType stakeType;
        uint256 amount;
        uint256 rewardDebt;
        uint256 startTime;
        uint256 lockEndTime;
        uint256 lastHarvestTime;
        uint256 totalHarvested;
        BoostCardTier boostTier;
        bool isActive;
        uint256 penaltyPaid; // Track penalties for stats
    }
    
    /**
     * @dev Pool configuration
     */
    struct PoolConfig {
        address token;
        bool isActive;
        uint256 baseAPR;           // Base APR in basis points (100 = 1%)
        uint256 lockPeriod;        // For LOCKED stakes (seconds)
        uint256 minStakeAmount;
        uint256 maxStakeAmount;
        uint256 totalStaked;
        uint256 totalRewardsPaid;
        uint256 performanceFee;    // Fee on rewards (basis points)
        uint256 earlyWithdrawFee;  // Fee for early withdrawal (basis points)
        uint256 poolCap;           // Maximum total staked in pool
    }
    
    /**
     * @dev Referral data
     */
    struct ReferralData {
        address referrer;
        uint256 totalReferred;
        uint256 referralRewards;
        uint256 lastCommissionTime;
        uint256[] referredStakes;
    }
    
    /**
     * @dev Vesting schedule
     */
    struct VestingSchedule {
        uint256 totalAmount;
        uint256 claimedAmount;
        uint256 startTime;
        uint256 cliff;          // Cliff period (seconds)
        uint256 duration;       // Total vesting duration (seconds)
        uint256 slicePeriod;    // Time between vesting slices (seconds)
    }
    
    // ============ CONSTANTS ============
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant SECONDS_PER_YEAR = 365 days;
    uint256 public constant MAX_PERFORMANCE_FEE = 2000; // 20%
    uint256 public constant MAX_EARLY_WITHDRAW_FEE = 1000; // 10%
    uint256 public constant MIN_LOCK_PERIOD = 7 days;
    uint256 public constant MAX_LOCK_PERIOD = 365 days;
    
    // Boost card multipliers (basis points)
    uint256 public constant BRONZE_BOOST = 11000;   // 10%
    uint256 public constant SILVER_BOOST = 12500;   // 25%
    uint256 public constant GOLD_BOOST = 15000;     // 50%
    uint256 public constant PLATINUM_BOOST = 20000; // 100%
    
    // ============ STATE VARIABLES ============
    uint256 public totalStakes;
    uint256 public totalValueLocked;
    uint256 public totalRewardsDistributed;
    uint256 public governanceProposalCount;
    
    // Mappings
    mapping(uint256 => StakePosition) public stakes;
    mapping(address => uint256[]) public userStakes;
    mapping(address => PoolConfig) public pools;
    mapping(address => ReferralData) public referrals;
    mapping(address => VestingSchedule) public vestingSchedules;
    mapping(address => mapping(address => uint256)) public userPoolStakes; // user => token => amount
    mapping(address => uint256) public userTotalRewards;
    mapping(address => bool) public whitelistedTokens;
    mapping(address => BoostCardTier) public boostCards; // NFT holders boost tiers
    mapping(uint256 => GovernanceProposal) public governanceProposals;
    mapping(address => uint256) public userVotingPower; // Based on staked amount
    
    // ============ EVENTS ============
    event StakeCreated(
        uint256 indexed stakeId,
        address indexed user,
        address indexed token,
        StakeType stakeType,
        uint256 amount,
        uint256 lockEndTime,
        BoostCardTier boostTier,
        address referrer
    );
    
    event Harvested(
        uint256 indexed stakeId,
        address indexed user,
        uint256 amount,
        uint256 performanceFee
    );
    
    event Unstaked(
        uint256 indexed stakeId,
        address indexed user,
        uint256 amount,
        uint256 reward,
        uint256 earlyWithdrawFee,
        bool isEarly
    );
    
    event PoolConfigured(
        address indexed token,
        uint256 baseAPR,
        uint256 lockPeriod,
        uint256 minStakeAmount,
        uint256 maxStakeAmount,
        uint256 poolCap
    );
    
    event ReferralReward(
        address indexed referrer,
        address indexed referredUser,
        uint256 stakeId,
        uint256 rewardAmount
    );
    
    event BoostCardAssigned(
        address indexed user,
        BoostCardTier tier
    );
    
    event RewardsCompounded(
        uint256 indexed stakeId,
        address indexed user,
        uint256 compoundedAmount
    );
    
    event GovernanceProposalCreated(
        uint256 indexed proposalId,
        address indexed creator,
        string description,
        uint256 votingEndTime
    );
    
    event Voted(
        uint256 indexed proposalId,
        address indexed voter,
        bool support,
        uint256 votingPower
    );
    
    event VestingCreated(
        address indexed beneficiary,
        uint256 totalAmount,
        uint256 cliff,
        uint256 duration
    );
    
    event VestingClaimed(
        address indexed beneficiary,
        uint256 amount,
        uint256 remaining
    );
    
    // Governance Proposal Structure
    struct GovernanceProposal {
        uint256 proposalId;
        address creator;
        string description;
        uint256 createTime;
        uint256 votingEndTime;
        uint256 forVotes;
        uint256 againstVotes;
