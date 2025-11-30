// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title ATBToken
 * @dev An ERC20 token with a claim function, restricted to holders of a specific token,
 * with a variable claim amount and a daily claim count limit.
 */
contract ATBToken is ERC20, Ownable {
    // The address of the token users must hold to be eligible for claiming.
    IERC20 public requiredToken;

    // Max supply: 100 Billion tokens with 18 decimal places.
    uint256 public constant MAX_SUPPLY = 100_000_000_000 * (10**18);

    // Maximum number of claims allowed in a 24-hour period.
    uint256 public constant MAX_CLAIMS_PER_PERIOD = 20;

    // Cooldown period: 24 hours in seconds.
    uint256 public constant COOLDOWN_PERIOD = 24 * 60 * 60; // 1 day

    // Struct to track a user's claim history for the daily limit.
    struct ClaimInfo {
        uint256 claimCount;
        uint256 periodStartTimestamp;
    }

    // Mapping to store the claim information for each address.
    mapping(address => ClaimInfo) public userClaimInfo;

    /**
     * @dev Contract constructor.
     * @param _requiredTokenAddress The address of the token required for claiming (e.g., 0xabc).
     * @param _initialOwner The address of the deployer/owner.
     */
    constructor(address _requiredTokenAddress, address _initialOwner)
        ERC20("ABT", "ABT")
        Ownable(_initialOwner)
    {
        require(_requiredTokenAddress != address(0), "Address cannot be zero");
        requiredToken = IERC20(_requiredTokenAddress);
    }

    /**
     * @dev The main claim function.
     * @param _claimAmount The amount of tokens to claim, must be between 1 and 10 (inclusive).
     */
    function claim(uint256 _claimAmount) external {
        // --- Input Validation ---
        // 1. Check if the claim amount is within the allowed range (1 to 10).
        require(_claimAmount >= 1 && _claimAmount <= 10, "ATB: Claim amount must be between 1 and 10");

        // Calculate the actual mint amount in the smallest unit (with 18 decimals).
        uint256 actualMintAmount = _claimAmount * (10**18);

        // --- Eligibility Check (Required Token Holder) ---
        // 2. Check if the user holds the required token.
        require(
            requiredToken.balanceOf(msg.sender) > 0,
            "ATB: You must hold the required token to claim"
        );

        // --- Daily Claim Limit Check ---
        ClaimInfo storage info = userClaimInfo[msg.sender];

        // Check if the current claim period has ended (24 hours passed).
        if (block.timestamp >= info.periodStartTimestamp + COOLDOWN_PERIOD) {
            // Start a new period. Reset count and update timestamp.
            info.claimCount = 1;
            info.periodStartTimestamp = block.timestamp;
        } else {
            // Period is active. Check if the limit has been reached.
            require(
                info.claimCount < MAX_CLAIMS_PER_PERIOD,
                "ATB: Daily claim limit reached. Wait for 24 hours from the start of the period."
            );
            // Increment the claim count for the current period.
            info.claimCount += 1;
        }

        // --- Supply Cap Check ---
        // 4. Check if max supply would be exceeded.
        require(
            totalSupply() + actualMintAmount <= MAX_SUPPLY,
            "ATB: Max supply would be exceeded"
        );

        // --- Minting ---
        // Mint the tokens for the user.
        _mint(msg.sender, actualMintAmount);
    }

    /**
     * @dev (Optional) A function for the owner to change the required token address.
     */
    function setRequiredToken(address _newRequiredTokenAddress) external onlyOwner {
        require(_newRequiredTokenAddress != address(0), "Address cannot be zero");
        requiredToken = IERC20(_newRequiredTokenAddress);
    }
}