
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "./utils/Counters.sol";

/**
 * @title GradXP Combined Smart Contracts
 * @dev Unified smart contract for the GradXP platform
 */

contract GradXPCombined {
    // Token Contract Variables & Events
    ERC20Token public token;
    
    // Funding Contract Variables & Events
    address public owner;
    uint256 public totalFunds;
    uint256 public lockPeriodEnd;
    bool public fundsLocked = false;
    
    event FundsReceived(address indexed investor, uint256 amount);
    event FundsLocked(uint256 amount, uint256 unlockTime);
    event FundsWithdrawn(uint256 amount, address destination);
    
    // Yield Farming Variables & Events
    uint256 public totalStaked;
    uint256 public yieldRate = 10; // 10% APY
    uint256 public lastYieldTime;
    bool public yieldActive = false;
    
    event FundsStaked(uint256 amount);
    event YieldGenerated(uint256 amount);
    
    // Learning Contract Variables & Events
    struct UserScore {
        uint256 score;
        uint256 timestamp;
        bool completed;
    }
    
    struct Course {
        string title;
        string description;
        uint256 maxScore;
        uint256 passingScore;
        uint256 questionCount;
    }
    
    mapping(uint256 => Course) public courses;
    mapping(uint256 => mapping(address => UserScore)) public userScores;
    mapping(uint256 => address[]) public courseParticipants;
    
    uint256 public courseCount = 0;
    
    event CourseAdded(uint256 courseId, string title);
    event ScoreRecorded(address indexed user, uint256 courseId, uint256 score);
    
    // NFT Contract Variables & Events
    NFTCertificate public certificate;
    
    // Reward Contract Variables & Events
    struct Reward {
        uint256 ethAmount;
        uint256 tokenAmount;
    }
    
    mapping(uint256 => Reward[]) public courseRewards;
    mapping(uint256 => mapping(address => bool)) public rewardsClaimed;
    
    event RewardsDistributed(uint256 courseId, address[] recipients, uint256[] ethAmounts, uint256[] tokenAmounts);
    event RewardClaimed(address indexed user, uint256 courseId, uint256 ethAmount, uint256 tokenAmount);
    
    constructor() {
        owner = msg.sender;
        token = new ERC20Token();
        certificate = new NFTCertificate(address(this));
        lastYieldTime = block.timestamp;
        
        // Set up default courses
        addCourse("Introduction to Web3", "Learn the fundamentals of Web3 technology and blockchain", 100, 70, 3);
        addCourse("DeFi Fundamentals", "Explore decentralized finance protocols and applications", 100, 70, 5);
        addCourse("NFT Creation", "Learn to create, mint and trade NFTs on various marketplaces", 100, 70, 4);
        
        // Set up default rewards for courses
        uint256[] memory ethAmounts0 = new uint256[](3);
        uint256[] memory tokenAmounts0 = new uint256[](3);
        ethAmounts0[0] = 0.03 ether;
        ethAmounts0[1] = 0.02 ether;
        ethAmounts0[2] = 0.01 ether;
        tokenAmounts0[0] = 10 * 10**18;
        tokenAmounts0[1] = 10 * 10**18;
        tokenAmounts0[2] = 10 * 10**18;
        configureRewards(0, ethAmounts0, tokenAmounts0);

        uint256[] memory ethAmounts1 = new uint256[](3);
        uint256[] memory tokenAmounts1 = new uint256[](3);
        ethAmounts1[0] = 0.04 ether;
        ethAmounts1[1] = 0.025 ether;
        ethAmounts1[2] = 0.015 ether;
        tokenAmounts1[0] = 15 * 10**18;
        tokenAmounts1[1] = 12 * 10**18;
        tokenAmounts1[2] = 10 * 10**18;
        configureRewards(1, ethAmounts1, tokenAmounts1);

        uint256[] memory ethAmounts2 = new uint256[](3);
        uint256[] memory tokenAmounts2 = new uint256[](3);
        ethAmounts2[0] = 0.035 ether;
        ethAmounts2[1] = 0.022 ether;
        ethAmounts2[2] = 0.012 ether;
        tokenAmounts2[0] = 12 * 10**18;
        tokenAmounts2[1] = 10 * 10**18;
        tokenAmounts2[2] = 8 * 10**18;
        configureRewards(2, ethAmounts2, tokenAmounts2);
    }
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    
    //===============================================================
    // Funding Contract Functions
    //===============================================================
    
    /**
     * @dev Receive funds from investors
     */
    receive() external payable {
        if (fundsLocked) {
            revert("Funds are currently locked");
        }
        totalFunds += msg.value;
        emit FundsReceived(msg.sender, msg.value);
    }
    
    /**
     * @dev Lock funds for a specified period
     * @param lockPeriod Time in seconds to lock the funds
     */
    function lockFunds(uint256 lockPeriod) external onlyOwner {
        require(!fundsLocked, "Funds are already locked");
        require(totalFunds > 0, "No funds to lock");
        
        fundsLocked = true;
        lockPeriodEnd = block.timestamp + lockPeriod;
        
        emit FundsLocked(totalFunds, lockPeriodEnd);
    }
    
    /**
     * @dev Check if lock period has ended
     */
    function isLockPeriodEnded() public view returns (bool) {
        if (!fundsLocked) return false;
        return block.timestamp >= lockPeriodEnd;
    }
    
    //===============================================================
    // Yield Farming Contract Functions
    //===============================================================
    
    /**
     * @dev Simulate yield generation (for demo purposes)
     */
    function generateYield() external onlyOwner {
        require(yieldActive, "No active staking");
        require(totalStaked > 0, "No funds staked");
        
        // For demonstration, add 1% yield (simulating 10% APY over time)
        uint256 yieldAmount = (totalStaked * 1) / 100;
        totalStaked += yieldAmount;
        lastYieldTime = block.timestamp;
        
        emit YieldGenerated(yieldAmount);
    }
    
    /**
     * @dev Manual function to add yield (for demo purposes only)
     */
    function addSimulatedYield(uint256 amount) external onlyOwner {
        require(amount > 0, "Amount must be greater than 0");
        totalStaked += amount;
        lastYieldTime = block.timestamp;
        
        emit YieldGenerated(amount);
    }
    
    /**
     * @dev Get current yield info
     */
    function getYieldInfo() external view returns (uint256 stakedAmount, uint256 yieldPercentage, uint256 lastYieldTimestamp) {
        return (totalStaked, yieldRate, lastYieldTime);
    }
    
    //===============================================================
    // Learning Contract Functions
    //===============================================================
    
    /**
     * @dev Add a new course
     */
    function addCourse(
        string memory title, 
        string memory description, 
        uint256 maxScore, 
        uint256 passingScore, 
        uint256 questionCount
    ) public onlyOwner {
        require(passingScore <= maxScore, "Passing score cannot exceed max score");
        
        courses[courseCount] = Course(title, description, maxScore, passingScore, questionCount);
        emit CourseAdded(courseCount, title);
        courseCount++;
    }
    
    /**
     * @dev Record a user's score for a specific course
     */
    function recordScore(uint256 courseId, uint256 score) external {
        require(courseId < courseCount, "Course does not exist");
        require(score <= courses[courseId].maxScore, "Score exceeds maximum");
        require(!userScores[courseId][msg.sender].completed, "User already completed this course");
        
        userScores[courseId][msg.sender] = UserScore(score, block.timestamp, true);
        courseParticipants[courseId].push(msg.sender);
        
        emit ScoreRecorded(msg.sender, courseId, score);
    }
    
    /**
     * @dev Get top performers for a specific course
     * @param courseId The course ID
     * @param count Number of top performers to retrieve
     */
    function getTopPerformers(uint256 courseId, uint256 count) external view returns (address[] memory, uint256[] memory) {
        require(courseId < courseCount, "Course does not exist");
        
        uint256 participantCount = courseParticipants[courseId].length;
        uint256 resultCount = count < participantCount ? count : participantCount;
        
        address[] memory performers = new address[](resultCount);
        uint256[] memory scores = new uint256[](resultCount);
        
        // Create a copy of participants and scores for sorting
        address[] memory participants = new address[](participantCount);
        uint256[] memory participantScores = new uint256[](participantCount);
        
        for (uint256 i = 0; i < participantCount; i++) {
            address participant = courseParticipants[courseId][i];
            participants[i] = participant;
            participantScores[i] = userScores[courseId][participant].score;
        }
        
        // Simple bubble sort (inefficient but works for small datasets)
        for (uint256 i = 0; i < participantCount; i++) {
            for (uint256 j = i + 1; j < participantCount; j++) {
                if (participantScores[i] < participantScores[j]) {
                    // Swap scores
                    uint256 tempScore = participantScores[i];
                    participantScores[i] = participantScores[j];
                    participantScores[j] = tempScore;
                    
                    // Swap addresses
                    address tempAddr = participants[i];
                    participants[i] = participants[j];
                    participants[j] = tempAddr;
                }
            }
        }
        
        // Fill result arrays with top performers
        for (uint256 i = 0; i < resultCount; i++) {
            performers[i] = participants[i];
            scores[i] = participantScores[i];
        }
        
        return (performers, scores);
    }
    
    /**
     * @dev Get course details
     */
    function getCourseDetails(uint256 courseId) external view returns (
        string memory title,
        string memory description,
        uint256 maxScore,
        uint256 passingScore,
        uint256 questionCount
    ) {
        require(courseId < courseCount, "Course does not exist");
        Course memory course = courses[courseId];
        return (
            course.title,
            course.description,
            course.maxScore,
            course.passingScore,
            course.questionCount
        );
    }
    
    /**
     * @dev Check if a user has passed a course
     */
    function hasPassed(uint256 courseId, address user) public view returns (bool) {
        require(courseId < courseCount, "Course does not exist");
        
        UserScore memory score = userScores[courseId][user];
        return score.completed && score.score >= courses[courseId].passingScore;
    }
    
    //===============================================================
    // Reward Contract Functions
    //===============================================================
    
    /**
     * @dev Configure rewards for a course
     */
    function configureRewards(uint256 courseId, uint256[] memory ethAmounts, uint256[] memory tokenAmounts) public onlyOwner {
        require(ethAmounts.length == tokenAmounts.length, "Arrays must have same length");
        
        delete courseRewards[courseId];
        
        for (uint256 i = 0; i < ethAmounts.length; i++) {
            courseRewards[courseId].push(Reward(ethAmounts[i], tokenAmounts[i]));
        }
    }
    
    /**
     * @dev Distribute rewards to top performers
     * @param courseId The course ID
     */
    function distributeRewards(uint256 courseId) external onlyOwner {
        (address[] memory topPerformers, ) = this.getTopPerformers(courseId, courseRewards[courseId].length);
        
        uint256[] memory ethAmounts = new uint256[](topPerformers.length);
        uint256[] memory tokenAmounts = new uint256[](topPerformers.length);
        
        for (uint256 i = 0; i < topPerformers.length; i++) {
            if (i < courseRewards[courseId].length) {
                Reward memory reward = courseRewards[courseId][i];
                
                // Transfer ETH reward
                payable(topPerformers[i]).transfer(reward.ethAmount);
                
                // Transfer token reward
                token.transfer(topPerformers[i], reward.tokenAmount);
                
                // Mark as claimed
                rewardsClaimed[courseId][topPerformers[i]] = true;
                
                ethAmounts[i] = reward.ethAmount;
                tokenAmounts[i] = reward.tokenAmount;
                
                emit RewardClaimed(topPerformers[i], courseId, reward.ethAmount, reward.tokenAmount);
            }
        }
        
        emit RewardsDistributed(courseId, topPerformers, ethAmounts, tokenAmounts);
    }
    
    /**
     * @dev Check if address has claimed rewards for a course
     */
    function hasClaimedReward(uint256 courseId, address user) external view returns (bool) {
        return rewardsClaimed[courseId][user];
    }
    
    //===============================================================
    // NFT Certificate Functions
    //===============================================================
    
    /**
     * @dev Mint a certificate for a user who completed a course
     */
    function mintCertificate(address user, uint256 courseId) external {
        require(msg.sender == owner || hasPassed(courseId, user), "User has not passed the course");
        certificate.mintCertificate(user, courseId);
    }
    
    /**
     * @dev Check if a user has received a certificate for a course
     */
    function hasCertificate(address user, uint256 courseId) external view returns (bool) {
        return certificate.hasCertificate(user, courseId);
    }
}

//===============================================================
// ERC20 Token Contract
//===============================================================
contract ERC20Token is ERC20 {
    address public owner;
    
    constructor() ERC20("GradXP Token", "GXP") {
        owner = msg.sender;
        _mint(msg.sender, 1000 * 10**18); // 1000 tokens initial supply
    }
    
    /**
     * @dev Mint additional tokens (only owner)
     */
    function mint(address to, uint256 amount) external {
        require(msg.sender == owner, "Only owner can mint tokens");
        _mint(to, amount);
    }
}

//===============================================================
// NFT Certificate Contract
//===============================================================
contract NFTCertificate is ERC721URIStorage {
    using Counters for Counters.Counter;
    
    address public owner;
    address public learningContract;
    
    Counters.Counter private _tokenIds;
    
    mapping(uint256 => string) public courseBaseURI;
    mapping(address => mapping(uint256 => uint256)) public userCertificates;
    
    event CertificateMinted(address indexed user, uint256 courseId, uint256 tokenId);
    
    constructor(address _learningContract) ERC721("GradXP Certificate", "GXPC") {
        owner = msg.sender;
        learningContract = _learningContract;
        
        // Set default URIs for courses
        courseBaseURI[0] = "ipfs://QmTBCgGCXJsW7YzZQuZztqLptEQMWURKGx7ZYZTpzv5erY/web3";
        courseBaseURI[1] = "ipfs://QmTBCgGCXJsW7YzZQuZztqLptEQMWURKGx7ZYZTpzv5erY/defi";
        courseBaseURI[2] = "ipfs://QmTBCgGCXJsW7YzZQuZztqLptEQMWURKGx7ZYZTpzv5erY/nft";
    }
    
    /**
     * @dev Set base URI for a course
     */
    function setCourseBaseURI(uint256 courseId, string memory baseURI) external {
        require(msg.sender == owner, "Only owner can call this function");
        courseBaseURI[courseId] = baseURI;
    }
    
    /**
     * @dev Mint a certificate for a user who completed a course
     */
    function mintCertificate(address user, uint256 courseId) external {
        require(msg.sender == owner || msg.sender == learningContract, "Unauthorized");
        require(userCertificates[user][courseId] == 0, "Certificate already minted");
        
        _tokenIds.increment();
        uint256 newItemId = _tokenIds.current();
        
        _mint(user, newItemId);
        
        // Concatenate the base URI with the token ID to create a unique token URI
        string memory tokenURI = string(abi.encodePacked(courseBaseURI[courseId], "/", uint2str(newItemId)));
        _setTokenURI(newItemId, tokenURI);
        
        userCertificates[user][courseId] = newItemId;
        
        emit CertificateMinted(user, courseId, newItemId);
    }
    
    /**
     * @dev Check if a user has received a certificate for a course
     */
    function hasCertificate(address user, uint256 courseId) external view returns (bool) {
        return userCertificates[user][courseId] > 0;
    }
    
    /**
     * @dev Get the token ID of a user's certificate for a course
     */
    function getCertificateTokenId(address user, uint256 courseId) external view returns (uint256) {
        return userCertificates[user][courseId];
    }
    
    /**
     * @dev Convert uint to string
     */
    function uint2str(uint256 _i) internal pure returns (string memory) {
        if (_i == 0) {
            return "0";
        }
        
        uint256 j = _i;
        uint256 length;
        
        while (j != 0) {
            length++;
            j /= 10;
        }
        
        bytes memory bstr = new bytes(length);
        uint256 k = length;
        
        while (_i != 0) {
            k = k - 1;
            uint8 temp = (48 + uint8(_i - _i / 10 * 10));
            bytes1 b1 = bytes1(temp);
            bstr[k] = b1;
            _i /= 10;
        }
        
        return string(bstr);
    }
}