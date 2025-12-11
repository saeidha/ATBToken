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
        require(votingToken.balanceOf(msg.sender) > 0, "No tokens to vote");
        _;
    }

    // --- Admin Functions ---

    function setAllowedCreator(address _user, bool _status) external onlyOwner {
        allowedCreators[_user] = _status;
        emit CreatorStatusChanged(_user, _status);
    }

    // --- Core Functions ---

    function createProposal(string memory _title, string memory _description, uint256 _durationSeconds) external {
        uint256 balance = votingToken.balanceOf(msg.sender);
        
        // 1. Check eligibility (10k tokens OR allowed list)
        require(balance >= CREATION_THRESHOLD || allowedCreators[msg.sender], "Not eligible to create proposal");

        // 2. Check Daily Limit (Resets at midnight UTC)
        uint256 currentDay = block.timestamp / 1 days;
        require(lastProposalDay[msg.sender] < currentDay, "You can only create one proposal per day");

        // Create Proposal
        proposalCount++;
        proposals[proposalCount] = Proposal({
            id: proposalCount,
            creator: msg.sender,
            title: _title,
            description: _description,
            endTime: block.timestamp + _durationSeconds,
            yesVotes: 0,
            noVotes: 0,
            likeCount: 0,
            isOpen: true
        });

        lastProposalDay[msg.sender] = currentDay;
        emit ProposalCreated(proposalCount, msg.sender, _title, block.timestamp + _durationSeconds);
    }

    function vote(uint256 _proposalId, bool _support) external {
        Proposal storage p = proposals[_proposalId];
        
        // New eligibility check: token holder OR proposal creator OR allowed creator
        require(
            votingToken.balanceOf(msg.sender) > 0 || msg.sender == p.creator || allowedCreators[msg.sender],
            "Not eligible to vote: Must be a token holder, proposal creator, or an allowed creator."
        );

        require(p.isOpen, "Proposal does not exist or invalid");
        require(block.timestamp < p.endTime, "Voting has ended");

        uint256 weight = votingToken.balanceOf(msg.sender);

        if (_support) {
            p.yesVotes += weight;
        } else {
            p.noVotes += weight;
        }

        userVotes[_proposalId][msg.sender] = UserVoteInfo({
            hasVoted: true,
            support: _support,
            voteWeight: weight
        });

        emit Voted(_proposalId, msg.sender, _support, weight);
    }

    // Anyone can like (Social feature)
    function likeProposal(uint256 _proposalId) external {
        require(proposals[_proposalId].id != 0, "Invalid proposal");

        proposals[_proposalId].likeCount++;

        emit Liked(_proposalId, msg.sender);
    }

    // --- View Functions ---

    function getAllProposals() external view returns (Proposal[] memory) {
        Proposal[] memory allProps = new Proposal[](proposalCount);
        for (uint256 i = 1; i <= proposalCount; i++) {
            allProps[i - 1] = proposals[i];
        }
        return allProps;
    }

    // Helper to get user status for UI (Vote status and Like status)
    function getUserProposalStatus(uint256 _proposalId, address _user) external view returns (bool voted, bool support, uint256 weight) {
        UserVoteInfo memory info = userVotes[_proposalId][_user];
        return (info.hasVoted, info.support, info.voteWeight);
    }
}
