// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title ATBToken
 * @dev An ERC20 token with a daily claim function, restricted to holders of a specific token.
 */
contract ATBToken is ERC20, Ownable {
    // The address of the token users must hold to be eligible for claiming.
    IERC20 public requiredToken;

    // Max supply: 100 Billion tokens with 18 decimal places.
    uint256 public constant MAX_SUPPLY = 100_000_000_000 * (10**18);

    // Claim amount: 10 tokens with 18 decimal places.
    uint256 public constant CLAIM_AMOUNT = 10 * (10**18);

    // Cooldown period: 24 hours in seconds.
    uint256 public constant COOLDOWN_PERIOD = 24 * 60 * 60; // 1 day

    // Mapping to store the timestamp of the last claim for each address.
    mapping(address => uint256) public lastClaimedTimestamp;

    /**
     * @dev Contract constructor.
     * @param _requiredTokenAddress The address of the token required for claiming (e.g., 0xabc).
     * @param _initialOwner The address of the deployer/owner.
     */
    constructor(address _requiredTokenAddress, address _initialOwner)
        ERC20("ATB", "ATB")
        Ownable(_initialOwner)
    {
        require(_requiredTokenAddress != address(0), "Address cannot be zero");
        requiredToken = IERC20(_requiredTokenAddress);
    }

    /**
     * @dev The main claim function.
     */
    function claim() external {
        // First check: Does the user hold the required token?
        require(
            requiredToken.balanceOf(msg.sender) > 0,
            "ATB: You must hold the required token to claim"
        );

        // Second check: Has 24 hours passed since the last claim?
        uint256 lastClaim = lastClaimedTimestamp[msg.sender];
        require(
            block.timestamp >= lastClaim + COOLDOWN_PERIOD,
            "ATB: Cooldown period is active, please wait"
        );

        // Check supply cap
        require(
            totalSupply() + CLAIM_AMOUNT <= MAX_SUPPLY,
            "ATB: Max supply would be exceeded"
        );

        // Update the claim timestamp
        lastClaimedTimestamp[msg.sender] = block.timestamp;

        // Mint 10 new tokens for the user
        _mint(msg.sender, CLAIM_AMOUNT);
    }

    /**
     * @dev (Optional) A function for the owner to change the required token address.
     */
    function setRequiredToken(address _newRequiredTokenAddress) external onlyOwner {
        require(_newRequiredTokenAddress != address(0), "Address cannot be zero");
        requiredToken = IERC20(_newRequiredTokenAddress);
    }
}
