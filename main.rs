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
    uint256 public constant CREATION_THRESHOLD = 1000 * 10**18; // Assuming 18 decimals

    uint256 public proposalCount;
    mapping(uint256 => Proposal) public proposals;
    mapping(address => bool) public allowedCreators;
    
    // Tracking user interactions
    mapping(uint256 => mapping(address => UserVoteInfo)) public userVotes;
    
    // Daily restriction tracking: User Address => Last Creation Day (Unix Day)
    mapping(address => uint256) public lastProposalDay;

    event ProposalCreated(uint256 indexed id, address indexed creator, string title, uint256 endTime);
    event Voted(uint256 indexed proposalId, address indexed voter, bool support, uint256 weight);
    event Liked(uint256 indexed proposalId, address indexed user);
    event CreatorStatusChanged(address indexed user, bool isAllowed);

    constructor(address _tokenAddress) Ownable(msg.sender) {
        votingToken = IERC20(_tokenAddress);
        allowedCreators[msg.sender] = true; // Default owner is allowed
    }

    // --- Modifiers ---

    modifier onlyTokenHolder() {
        _checkTokenHolder();
        _;
    }

    function _checkTokenHolder() internal view {
        require(votingToken.balanceOf(msg.sender) > 0, "No tokens to vote");
    }

    // --- Admin Functions ---

    function setAllowedCreator(address _user, bool _status) external onlyOwner {
        allowedCreators[_user] = _status;
        emit CreatorStatusChanged(_user, _status);
    }

    // --- Core Functions ---

    function createProposal(string memory _title, string memory _description, uint256 _durationSeconds) external {
        uint256 balance = votingToken.balanceOf(msg.sender);
