// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./OwnableUpgradeable.sol";

contract Oracle is Initializable, OwnableUpgradeable {
    uint256 public MIN_STAKE;
    uint256 public MAX_MEMBERS;
    uint256 public PROPOSAL_FEE;
    uint256 public REQUEST_FEE;
    uint256 public PRICE_RETRIEVAL_FEE;

    mapping(address => uint256) public stakes;
    address[] public daoMembers;

    uint256 public totalProposalFeesCollected;
    uint256 public totalRequestFeesCollected;

    mapping(string => bytes32) public symbolToPriceId;
    mapping(bytes32 => uint256) public prices;
    mapping(bytes32 => bool) public priceUpdated;

    mapping(bytes32 => Proposal) public proposals;

    event PriceUpdated(bytes32 indexed priceId, uint256 price);
    event StakeDeposited(address indexed member, uint256 amount);
    event StakeWithdrawn(address indexed member, uint256 amount);
    event FeesDistributed(uint256 totalAmount);
    event RandomNumberRequest(bytes32 indexed requestId);
    event RandomNumberAvailable(bytes32 indexed requestId, uint256 randomNumber);
    event ProposalCreated(bytes32 indexed proposalId, address proposer, string description);
    event PriceRequested(bytes32 indexed requestId, string symbol);
    event FeeUpdated(string feeType, uint256 newValue);
    event FundsWithdrawn(address indexed by, uint256 amount);
    event Voted(bytes32 indexed proposalId, address voter, bool vote);
    event ProposalOpened(bytes32 indexed proposalId);

    struct Proposal {
        string description;
        address opener;
        uint256 voteCount;
        mapping(address => bool) votes;
    }

    function initialize(address owner) public initializer {
        __Ownable_init(owner);
        MIN_STAKE = 2500 ether;
        MAX_MEMBERS = 100;
        PROPOSAL_FEE = 10 ether;
        REQUEST_FEE = 1 ether;
        PRICE_RETRIEVAL_FEE = 1 ether;
        totalProposalFeesCollected = 0;
        totalRequestFeesCollected = 0;
    }

    modifier costs(uint256 fee) {
        require(msg.value == fee, "Incorrect fee amount");
        _;
    }

    function setProposalFee(uint256 newProposalFee) public onlyOwner {
        PROPOSAL_FEE = newProposalFee;
        emit FeeUpdated("PROPOSAL_FEE", newProposalFee);
    }


    function setPriceRetrievalFee(uint256 newPriceRetrievalFee) public onlyOwner {
        PRICE_RETRIEVAL_FEE = newPriceRetrievalFee;
        emit FeeUpdated("PRICE_RETRIEVAL_FEE", newPriceRetrievalFee);
    }

    function setMinStake(uint256 newMinStake) public onlyOwner {
        MIN_STAKE = newMinStake;
        emit FeeUpdated("MIN_STAKE", newMinStake);
    }

    function setRequestFee(uint256 newRequestFee) public onlyOwner {
        REQUEST_FEE = newRequestFee;
        emit FeeUpdated("REQUEST_FEE", newRequestFee);
    }

    function setMaxMembers(uint256 newMaxMembers) public onlyOwner {
        MAX_MEMBERS = newMaxMembers;
        emit FeeUpdated("MAX_MEMBERS", newMaxMembers);
    }

    function joinDAO() public payable {
        require(msg.value >= MIN_STAKE, "Minimum stake not met");
        require(daoMembers.length < MAX_MEMBERS, "DAO membership full");
        require(stakes[msg.sender] == 0, "Already a DAO member");

        uint256 ownerFee = msg.value / 100;  // 1% fee to the owner
        uint256 stakeAmount = msg.value - ownerFee;
        stakes[msg.sender] += stakeAmount;
        daoMembers.push(msg.sender);
        payable(owner()).transfer(ownerFee);

        emit StakeDeposited(msg.sender, stakeAmount);
    }

    function leaveDAO(uint256 withdrawAmount) public {
        uint256 currentStake = stakes[msg.sender];
        require(currentStake > 0, "Not a DAO member");
        require(withdrawAmount <= currentStake, "Cannot withdraw more than the staked amount");

        stakes[msg.sender] -= withdrawAmount;
        payable(msg.sender).transfer(withdrawAmount);
        emit StakeWithdrawn(msg.sender, withdrawAmount);

        if (stakes[msg.sender] < MIN_STAKE) {
            removeDAOMember(msg.sender);
        }
    }

    function getPriceId(string memory symbol) public returns (bytes32) {
        bytes32 priceId = symbolToPriceId[symbol];
        if (priceId == bytes32(0)) {
            priceId = keccak256(abi.encodePacked(symbol, block.timestamp));
            symbolToPriceId[symbol] = priceId;
        }
        return priceId;
    }

    function updatePrice(string memory symbol, uint256 price) public onlyOwner {
        bytes32 priceId = getPriceId(symbol);
        prices[priceId] = price;
        priceUpdated[priceId] = true;
        emit PriceUpdated(priceId, price);
    }

    function getPrice(bytes32 priceId) public payable costs(PRICE_RETRIEVAL_FEE) returns (uint256) {
        require(priceUpdated[priceId], "Price not updated yet");
        totalRequestFeesCollected += msg.value;
        return prices[priceId];
    }

    function openProposal(string memory description) public payable {
        require(msg.value == PROPOSAL_FEE, "Incorrect fee amount");
        totalProposalFeesCollected += msg.value;

        bytes32 proposalId = keccak256(abi.encodePacked(msg.sender, description, block.timestamp));
        Proposal storage newProposal = proposals[proposalId];
        newProposal.description = description;
        newProposal.opener = msg.sender;

        emit ProposalCreated(proposalId, msg.sender, description);
    }

    function distributeFees() public onlyOwner {
        uint256 totalFees = totalProposalFeesCollected + totalRequestFeesCollected;
        uint256 ownerShare = (totalFees * 7) / 100; // 7% to the owner
        uint256 distributedAmount = totalFees - ownerShare;

        uint256 totalStakes = getTotalStakes();
        for (uint256 i = 0; i < daoMembers.length; i++) {
            address member = daoMembers[i];
            uint256 memberShare = (stakes[member] * distributedAmount) / totalStakes;
            payable(member).transfer(memberShare);
        }

        payable(owner()).transfer(ownerShare);
        totalProposalFeesCollected = 0;
        totalRequestFeesCollected = 0;
        emit FeesDistributed(distributedAmount);
    }

    function addStake() public payable {
        require(msg.value > 0, "Stake increase must be greater than zero");
        require(stakes[msg.sender] > 0, "Not a DAO member");

        uint256 ownerFee = msg.value / 100;  // 1% fee to the owner
        uint256 additionalStake = msg.value - ownerFee;
        stakes[msg.sender] += additionalStake;
        payable(owner()).transfer(ownerFee);

        emit StakeDeposited(msg.sender, additionalStake);
    }

    function getTotalStakes() private view returns (uint256 total) {
        for (uint256 i = 0; i < daoMembers.length; i++) {
            total += stakes[daoMembers[i]];
        }
        return total;
    }

    function removeDAOMember(address member) private {
        for (uint256 i = 0; i < daoMembers.length; i++) {
            if (daoMembers[i] == member) {
                daoMembers[i] = daoMembers[daoMembers.length - 1];
                daoMembers.pop();
                break;
            }
        }
    }

    function voteOnProposal(bytes32 proposalId, bool vote) public {
        require(stakes[msg.sender] > 0, "Only DAO members can vote");
        Proposal storage proposal = proposals[proposalId];
        require(!proposal.votes[msg.sender], "Already voted");

        proposal.votes[msg.sender] = true;
        if (vote) {
            proposal.voteCount++;
        }

        emit Voted(proposalId, msg.sender, vote);
    }

    function withdraw(uint256 amount) public {
        uint256 stakedAmount = stakes[msg.sender];
        require(stakedAmount >= amount, "Withdrawal amount exceeds staked amount");
        require(amount > 0, "Amount must be greater than zero");

        stakes[msg.sender] -= amount;
        payable(msg.sender).transfer(amount);
        emit FundsWithdrawn(msg.sender, amount);

        if (stakes[msg.sender] < MIN_STAKE) {
            removeDAOMember(msg.sender);
        }
    }

}
