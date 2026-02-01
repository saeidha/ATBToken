// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract TokenVoting is Ownable {
    
    struct Proposal {
        uint256 id;
        address creator;
        string title;
        string description;
        uint256 endTime;
        uint256 yesVotes; // Total weight of YES votes
        uint256 noVotes;  // Total weight of NO votes
        uint256 likeCount;
        bool isOpen;
    }

    struct UserVoteInfo {
        bool hasVoted;
        bool support; // true for Yes, false for No
        uint256 voteWeight;
    }

    IERC20 public votingToken;
