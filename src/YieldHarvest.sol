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
