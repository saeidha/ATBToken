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
