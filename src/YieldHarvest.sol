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
        bool executed;
        mapping(address => bool) hasVoted;
    }
    
    // ============ MODIFIERS ============
    modifier poolExists(address token) {
        require(pools[token].isActive, "Pool does not exist");
        _;
    }
    
    modifier stakeExists(uint256 stakeId) {
        require(stakeId < totalStakes, "Stake does not exist");
        _;
    }
    
    modifier stakeActive(uint256 stakeId) {
        require(stakes[stakeId].isActive, "Stake not active");
        _;
    }
    
    modifier onlyStakeOwner(uint256 stakeId) {
        require(stakes[stakeId].user == msg.sender, "Not stake owner");
        _;
    }
    
    modifier notLocked(uint256 stakeId) {
        require(
            stakes[stakeId].stakeType != StakeType.LOCKED || 
            block.timestamp >= stakes[stakeId].lockEndTime,
            "Stake is locked"
        );
        _;
    }
    
    // ============ CONSTRUCTOR ============
    constructor() {
        totalStakes = 0;
        totalValueLocked = 0;
        totalRewardsDistributed = 0;
    }
    
    // ============ STAKE FUNCTIONS ============
    
    /**
     * @dev Create a new stake with optional referral
     * @param token Token to stake
     * @param amount Amount to stake
     * @param stakeType Type of stake (0: Flexible, 1: Locked, 2: Boosted)
     * @param referrer Optional referrer address
     */
    function createStake(
        address token,
        uint256 amount,
        StakeType stakeType,
        address referrer
    ) external nonReentrant poolExists(token) returns (uint256) {
        PoolConfig storage pool = pools[token];
        
        // Validate inputs
        require(amount >= pool.minStakeAmount, "Below minimum stake");
        require(amount <= pool.maxStakeAmount, "Above maximum stake");
        require(pool.totalStaked + amount <= pool.poolCap, "Pool capacity reached");
        
        // Transfer tokens from user
        IERC20(token).transferFrom(msg.sender, address(this), amount);
        
        // Calculate lock end time
        uint256 lockEndTime = 0;
        if (stakeType == StakeType.LOCKED || stakeType == StakeType.BOOSTED) {
            lockEndTime = block.timestamp + pool.lockPeriod;
        }
        
        // Check boost card if applicable
        BoostCardTier boostTier = BoostCardTier.NONE;
        if (stakeType == StakeType.BOOSTED) {
            boostTier = boostCards[msg.sender];
            require(boostTier != BoostCardTier.NONE, "No boost card");
        }
        
        // Create stake position
        uint256 stakeId = totalStakes++;
        stakes[stakeId] = StakePosition({
            stakeId: stakeId,
            user: msg.sender,
            token: token,
            stakeType: stakeType,
            amount: amount,
            rewardDebt: 0,
            startTime: block.timestamp,
            lockEndTime: lockEndTime,
            lastHarvestTime: block.timestamp,
            totalHarvested: 0,
            boostTier: boostTier,
            isActive: true,
            penaltyPaid: 0
        });
        
        // Update user stakes
        userStakes[msg.sender].push(stakeId);
        userPoolStakes[msg.sender][token] += amount;
        
        // Update pool totals
        pool.totalStaked += amount;
        totalValueLocked += amount;
        
        // Handle referral
        if (referrer != address(0) && referrer != msg.sender) {
            _processReferral(referrer, msg.sender, stakeId, amount);
        }
        
        // Update voting power
        _updateVotingPower(msg.sender);
        
        emit StakeCreated(
            stakeId,
            msg.sender,
            token,
            stakeType,
            amount,
            lockEndTime,
            boostTier,
            referrer
        );
        
        return stakeId;
    }
    
    /**
     * @dev Harvest rewards from a stake
     * @param stakeId ID of the stake
     * @param compound Whether to compound rewards
     */
    function harvest(uint256 stakeId, bool compound) 
        external 
        nonReentrant 
        stakeExists(stakeId) 
        stakeActive(stakeId) 
        onlyStakeOwner(stakeId) 
    {
        StakePosition storage stake = stakes[stakeId];
        PoolConfig storage pool = pools[stake.token];
        
        // Calculate pending rewards
        uint256 pending = _calculateRewards(stakeId);
        require(pending > 0, "No rewards to harvest");
        
        // Calculate performance fee
        uint256 feeAmount = (pending * pool.performanceFee) / BASIS_POINTS;
        uint256 netReward = pending - feeAmount;
        
        // Update stake
        stake.lastHarvestTime = block.timestamp;
        stake.totalHarvested += pending;
        stake.rewardDebt += pending;
        
        // Update totals
        pool.totalRewardsPaid += pending;
        totalRewardsDistributed += pending;
        userTotalRewards[msg.sender] += pending;
        
        if (compound) {
            // Compound rewards back into stake
            stake.amount += netReward;
            pool.totalStaked += netReward;
            totalValueLocked += netReward;
            
            emit RewardsCompounded(stakeId, msg.sender, netReward);
        } else {
            // Transfer net reward to user
            IERC20(stake.token).transfer(msg.sender, netReward);
            
            // Transfer fee to fee collector
            if (feeAmount > 0) {
                IERC20(stake.token).transfer(owner(), feeAmount);
            }
        }
        
        // Update voting power if compounding
        if (compound) {
            _updateVotingPower(msg.sender);
        }
        
        emit Harvested(stakeId, msg.sender, pending, feeAmount);
    }
    
    /**
     * @dev Unstake tokens with rewards
     * @param stakeId ID of the stake
     */
    function unstake(uint256 stakeId) 
        external 
        nonReentrant 
        stakeExists(stakeId) 
        stakeActive(stakeId) 
        onlyStakeOwner(stakeId) 
    {
        StakePosition storage stake = stakes[stakeId];
        PoolConfig storage pool = pools[stake.token];
        
        bool isEarly = false;
        uint256 earlyWithdrawFee = 0;
        uint256 penaltyAmount = 0;
        
        // Check if early withdrawal
        if (stake.stakeType != StakeType.FLEXIBLE && block.timestamp < stake.lockEndTime) {
            isEarly = true;
            earlyWithdrawFee = (stake.amount * pool.earlyWithdrawFee) / BASIS_POINTS;
            penaltyAmount = earlyWithdrawFee;
        }
        
        // Calculate pending rewards (no rewards for early withdrawal)
        uint256 pendingRewards = 0;
        if (!isEarly) {
            pendingRewards = _calculateRewards(stakeId);
        }
        
        // Total amount to transfer
        uint256 totalTransfer = stake.amount - penaltyAmount + pendingRewards;
        
        // Update stake as inactive
        stake.isActive = false;
        stake.penaltyPaid = penaltyAmount;
        
        // Update pool totals
        pool.totalStaked -= stake.amount;
        totalValueLocked -= stake.amount;
        if (pendingRewards > 0) {
            pool.totalRewardsPaid += pendingRewards;
            totalRewardsDistributed += pendingRewards;
            userTotalRewards[msg.sender] += pendingRewards;
        }
        
        // Update user pool stake
        userPoolStakes[msg.sender][stake.token] -= stake.amount;
        
        // Transfer tokens
        require(
            IERC20(stake.token).transfer(msg.sender, totalTransfer),
            "Transfer failed"
        );
        
        // Transfer penalty to fee collector
        if (penaltyAmount > 0) {
            IERC20(stake.token).transfer(owner(), penaltyAmount);
        }
        
        // Update voting power
        _updateVotingPower(msg.sender);
        
        emit Unstaked(
            stakeId,
            msg.sender,
            stake.amount,
            pendingRewards,
            earlyWithdrawFee,
            isEarly
        );
    }
    
    // ============ REWARD CALCULATION ============
    
    /**
     * @dev Calculate pending rewards for a stake
     * @param stakeId ID of the stake
     * @return Pending reward amount
     */
    function calculatePendingRewards(uint256 stakeId) 
        public 
        view 
        stakeExists(stakeId) 
        returns (uint256) 
    {
        return _calculateRewards(stakeId);
    }
    
    function _calculateRewards(uint256 stakeId) internal view returns (uint256) {
        StakePosition storage stake = stakes[stakeId];
        if (!stake.isActive) return 0;
        
        PoolConfig storage pool = pools[stake.token];
        
        uint256 timeStaked = block.timestamp - stake.lastHarvestTime;
        if (timeStaked == 0) return 0;
        
        // Calculate base APR with dynamic adjustments
        uint256 effectiveAPR = _getEffectiveAPR(pool, stake);
        
        // Calculate rewards
        uint256 rewards = (stake.amount * effectiveAPR * timeStaked) / 
                         (BASIS_POINTS * SECONDS_PER_YEAR);
        
        return rewards;
    }
    
    /**
     * @dev Get effective APR for a stake
     * @param pool Pool configuration
     * @param stake Stake position
     * @return Effective APR in basis points
     */
    function _getEffectiveAPR(PoolConfig storage pool, StakePosition storage stake) 
        internal 
        view 
        returns (uint256) 
    {
        uint256 baseAPR = pool.baseAPR;
        
        // Apply stake type multiplier
        if (stake.stakeType == StakeType.LOCKED) {
            baseAPR = (baseAPR * 15000) / BASIS_POINTS; // 50% boost
        } else if (stake.stakeType == StakeType.BOOSTED) {
            // Apply NFT boost
            uint256 boostMultiplier = _getBoostMultiplier(stake.boostTier);
            baseAPR = (baseAPR * boostMultiplier) / BASIS_POINTS;
        }
        
        // Apply pool utilization multiplier (higher utilization = higher APR)
        uint256 utilization = (pool.totalStaked * BASIS_POINTS) / pool.poolCap;
        if (utilization > 8000) { // >80% utilization
            baseAPR = (baseAPR * (10000 + (utilization - 8000) / 2)) / BASIS_POINTS;
        }
        
        return baseAPR;
    }
    
    function _getBoostMultiplier(BoostCardTier tier) internal pure returns (uint256) {
        if (tier == BoostCardTier.BRONZE) return BRONZE_BOOST;
        if (tier == BoostCardTier.SILVER) return SILVER_BOOST;
        if (tier == BoostCardTier.GOLD) return GOLD_BOOST;
        if (tier == BoostCardTier.PLATINUM) return PLATINUM_BOOST;
        return BASIS_POINTS; // 100%
    }
    
    // ============ REFERRAL SYSTEM ============
    
    function _processReferral(address referrer, address referredUser, uint256 stakeId, uint256 amount) internal {
        ReferralData storage refData = referrals[referrer];
        
        if (refData.referrer == address(0)) {
            refData.referrer = referrer;
        }
        
        refData.totalReferred += 1;
        refData.referredStakes.push(stakeId);
        
        // Calculate referral reward (1% of stake amount)
        uint256 rewardAmount = (amount * 100) / BASIS_POINTS;
        
        // Transfer reward if contract has balance
        StakePosition storage stake = stakes[stakeId];
        if (IERC20(stake.token).balanceOf(address(this)) >= rewardAmount) {
            IERC20(stake.token).transfer(referrer, rewardAmount);
            refData.referralRewards += rewardAmount;
            
            emit ReferralReward(referrer, referredUser, stakeId, rewardAmount);
        }
    }
    
    /**
     * @dev Get referral stats for a user
     */
    function getReferralStats(address user) 
        external 
        view 
        returns (
            uint256 totalReferred,
            uint256 totalRewards,
            uint256[] memory referredStakes
        ) 
    {
        ReferralData storage refData = referrals[user];
        return (
            refData.totalReferred,
            refData.referralRewards,
            refData.referredStakes
        );
    }
    
    // ============ VESTING SYSTEM ============
    
    /**
     * @dev Create vesting schedule for team/advisors
     * @param beneficiary Address to vest tokens to
     * @param amount Total amount to vest
     * @param cliffDuration Cliff period in seconds
     * @param vestingDuration Total vesting duration in seconds
     * @param slicePeriod Seconds between vesting slices
     */
    function createVestingSchedule(
        address beneficiary,
        address token,
        uint256 amount,
        uint256 cliffDuration,
        uint256 vestingDuration,
        uint256 slicePeriod
    ) external onlyOwner {
        require(beneficiary != address(0), "Invalid beneficiary");
        require(amount > 0, "Amount must be > 0");
        require(cliffDuration <= vestingDuration, "Cliff > duration");
        require(slicePeriod > 0, "Slice period must be > 0");
        
        // Transfer tokens to contract
        IERC20(token).transferFrom(msg.sender, address(this), amount);
        
        vestingSchedules[beneficiary] = VestingSchedule({
            totalAmount: amount,
            claimedAmount: 0,
            startTime: block.timestamp,
            cliff: cliffDuration,
            duration: vestingDuration,
            slicePeriod: slicePeriod
        });
        
        emit VestingCreated(beneficiary, amount, cliffDuration, vestingDuration);
    }
    
    /**
     * @dev Claim vested tokens
     */
    function claimVestedTokens() external nonReentrant {
        VestingSchedule storage schedule = vestingSchedules[msg.sender];
        require(schedule.totalAmount > 0, "No vesting schedule");
        
        uint256 claimable = _calculateVestedAmount(msg.sender);
        require(claimable > 0, "No tokens to claim");
        
        // Update claimed amount
        schedule.claimedAmount += claimable;
        
        // Transfer tokens
        // Note: Token address should be stored in a mapping for production
        // For simplicity, using a known token address
        IERC20(address(this)).transfer(msg.sender, claimable);
        
        emit VestingClaimed(
            msg.sender,
            claimable,
            schedule.totalAmount - schedule.claimedAmount
        );
    }
    
    function _calculateVestedAmount(address beneficiary) internal view returns (uint256) {
        VestingSchedule storage schedule = vestingSchedules[beneficiary];
        
        if (block.timestamp < schedule.startTime + schedule.cliff) {
            return 0;
        }
        
        if (block.timestamp >= schedule.startTime + schedule.duration) {
            return schedule.totalAmount - schedule.claimedAmount;
        }
        
        uint256 timeSinceStart = block.timestamp - schedule.startTime;
        uint256 totalSlices = schedule.duration / schedule.slicePeriod;
        uint256 slicesVested = timeSinceStart / schedule.slicePeriod;
        
        uint256 vestedAmount = (schedule.totalAmount * slicesVested) / totalSlices;
        return vestedAmount - schedule.claimedAmount;
    }
    
    // ============ GOVERNANCE FUNCTIONS ============
    
    /**
     * @dev Create governance proposal
     * @param description Proposal description
     * @param votingPeriod Voting period in seconds
     */
    function createProposal(string memory description, uint256 votingPeriod) 
        external 
        returns (uint256) 
    {
        require(userVotingPower[msg.sender] > 0, "No voting power");
        require(votingPeriod >= 3 days && votingPeriod <= 30 days, "Invalid voting period");
        
        uint256 proposalId = governanceProposalCount++;
        
        GovernanceProposal storage proposal = governanceProposals[proposalId];
        proposal.proposalId = proposalId;
        proposal.creator = msg.sender;
        proposal.description = description;
        proposal.createTime = block.timestamp;
        proposal.votingEndTime = block.timestamp + votingPeriod;
        proposal.executed = false;
        
        emit GovernanceProposalCreated(
            proposalId,
            msg.sender,
            description,
            proposal.votingEndTime
        );
        
        return proposalId;
    }
    
    /**
     * @dev Vote on a proposal
     * @param proposalId Proposal ID
     * @param support True for yes, false for no
     */
    function vote(uint256 proposalId, bool support) external {
        GovernanceProposal storage proposal = governanceProposals[proposalId];
        
        require(block.timestamp <= proposal.votingEndTime, "Voting ended");
        require(!proposal.hasVoted[msg.sender], "Already voted");
        require(userVotingPower[msg.sender] > 0, "No voting power");
        
        proposal.hasVoted[msg.sender] = true;
        
        if (support) {
            proposal.forVotes += userVotingPower[msg.sender];
        } else {
            proposal.againstVotes += userVotingPower[msg.sender];
        }
        
        emit Voted(proposalId, msg.sender, support, userVotingPower[msg.sender]);
    }
    
    function _updateVotingPower(address user) internal {
        uint256 totalStakeValue = 0;
        
        // Calculate total staked value across all pools
        for (uint256 i = 0; i < userStakes[user].length; i++) {
            uint256 stakeId = userStakes[user][i];
            if (stakes[stakeId].isActive) {
                totalStakeValue += stakes[stakeId].amount;
            }
        }
        
        userVotingPower[user] = totalStakeValue / 1e18; // 1 voting power per token
    }
    
    // ============ ADMIN FUNCTIONS ============
    
    /**
     * @dev Configure a new staking pool
     */
    function configurePool(
        address token,
        uint256 baseAPR,
        uint256 lockPeriod,
        uint256 minStakeAmount,
        uint256 maxStakeAmount,
        uint256 poolCap,
        uint256 performanceFee,
        uint256 earlyWithdrawFee
    ) external onlyOwner {
        require(baseAPR <= 50000, "APR too high"); // Max 500%
        require(lockPeriod >= MIN_LOCK_PERIOD && lockPeriod <= MAX_LOCK_PERIOD, "Invalid lock period");
        require(performanceFee <= MAX_PERFORMANCE_FEE, "Fee too high");
        require(earlyWithdrawFee <= MAX_EARLY_WITHDRAW_FEE, "Fee too high");
        
        pools[token] = PoolConfig({
            token: token,
            isActive: true,
            baseAPR: baseAPR,
            lockPeriod: lockPeriod,
            minStakeAmount: minStakeAmount,
            maxStakeAmount: maxStakeAmount,
            totalStaked: 0,
            totalRewardsPaid: 0,
            performanceFee: performanceFee,
            earlyWithdrawFee: earlyWithdrawFee,
            poolCap: poolCap
        });
        
        whitelistedTokens[token] = true;
        
        emit PoolConfigured(
            token,
            baseAPR,
            lockPeriod,
            minStakeAmount,
            maxStakeAmount,
            poolCap
        );
    }
    
    /**
     * @dev Assign boost card to user (simulated NFT)
     */
    function assignBoostCard(address user, BoostCardTier tier) external onlyOwner {
        boostCards[user] = tier;
        emit BoostCardAssigned(user, tier);
    }
    
    /**
     * @dev Emergency withdraw stuck tokens (owner only)
     */
    function emergencyWithdraw(address token, uint256 amount) external onlyOwner {
        require(IERC20(token).balanceOf(address(this)) >= amount, "Insufficient balance");
        IERC20(token).transfer(owner(), amount);
    }
    
    /**
     * @dev Update pool parameters
     */
    function updatePoolAPR(address token, uint256 newAPR) external onlyOwner {
        require(pools[token].isActive, "Pool not active");
        require(newAPR <= 50000, "APR too high");
        pools[token].baseAPR = newAPR;
    }
    
    // ============ VIEW FUNCTIONS ============
    
    /**
     * @dev Get user's active stakes
     */
    function getUserActiveStakes(address user) 
        external 
        view 
        returns (uint256[] memory activeStakes) 
    {
        uint256[] storage allStakes = userStakes[user];
        uint256 activeCount = 0;
        
        // Count active stakes
        for (uint256 i = 0; i < allStakes.length; i++) {
            if (stakes[allStakes[i]].isActive) {
                activeCount++;
            }
        }
        
        // Create array of active stakes
        activeStakes = new uint256[](activeCount);
        uint256 index = 0;
        
        for (uint256 i = 0; i < allStakes.length; i++) {
            if (stakes[allStakes[i]].isActive) {
                activeStakes[index] = allStakes[i];
                index++;
            }
        }
        
        return activeStakes;
    }
    
    /**
     * @dev Get pool statistics
     */
    function getPoolStats(address token) 
        external 
        view 
        returns (
            uint256 totalStaked,
            uint256 totalRewardsPaid,
            uint256 utilizationRate,
            uint256 currentAPR
        ) 
    {
        PoolConfig storage pool = pools[token];
        totalStaked = pool.totalStaked;
        totalRewardsPaid = pool.totalRewardsPaid;
        utilizationRate = (pool.totalStaked * BASIS_POINTS) / pool.poolCap;
        currentAPR = pool.baseAPR;
        
        return (totalStaked, totalRewardsPaid, utilizationRate, currentAPR);
    }
    
    /**
     * @dev Calculate APR for a specific stake type
     */
    function calculateProjectedAPR(
        address token,
        StakeType stakeType,
        BoostCardTier boostTier
    ) external view returns (uint256) {
        PoolConfig storage pool = pools[token];
        require(pool.isActive, "Pool not active");
        
        uint256 baseAPR = pool.baseAPR;
        
        // Apply stake type multiplier
        if (stakeType == StakeType.LOCKED) {
            baseAPR = (baseAPR * 15000) / BASIS_POINTS;
        } else if (stakeType == StakeType.BOOSTED) {
            uint256 boostMultiplier = _getBoostMultiplier(boostTier);
            baseAPR = (baseAPR * boostMultiplier) / BASIS_POINTS;
        }
        
        return baseAPR;
    }
    
    /**
     * @dev Get total rewards earned by user
     */
    function getUserTotalRewards(address user) external view returns (uint256) {
        return userTotalRewards[user];
    }
    
    /**
     * @dev Get stake details
     */
    function getStakeDetails(uint256 stakeId) 
        external 
        view 
        returns (
            address user,
            address token,
            StakeType stakeType,
            uint256 amount,
            uint256 startTime,
            uint256 lockEndTime,
            uint256 totalHarvested,
            uint256 pendingRewards,
            bool isActive
        ) 
    {
        StakePosition storage stake = stakes[stakeId];
        return (
            stake.user,
            stake.token,
            stake.stakeType,
            stake.amount,
            stake.startTime,
            stake.lockEndTime,
            stake.totalHarvested,
            _calculateRewards(stakeId),
            stake.isActive
        );
    }
}