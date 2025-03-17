// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";

/**
 * @title CourseNFT
 * @dev NFT contract for representing course ownership
 * Each NFT represents ownership of a specific course
 * @author GradXP Team
 */
contract CourseNFT is ERC721URIStorage, Ownable, Pausable, ERC721Burnable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    
    // Mapping from token ID to course ID
    mapping(uint256 => string) public tokenToCourse;
    
    // Mapping from course ID and owner to token ID
    mapping(string => mapping(address => uint256)) public courseOwnership;
    
    // Address of the GradXP contract that is allowed to mint NFTs
    address public gradXPContract;
    
    // Base URI for token metadata
    string private _baseTokenURI;
    
    // Royalty percentage for secondary sales (in basis points, e.g., 250 = 2.5%)
    uint256 public royaltyPercentage = 250;
    
    // Events
    event CourseNFTMinted(address to, string courseId, uint256 tokenId);
    event CourseNFTBurned(uint256 tokenId, string courseId);
    event BaseURIUpdated(string newBaseURI);
    event GradXPContractUpdated(address newGradXPContract);
    event RoyaltyPercentageUpdated(uint256 oldPercentage, uint256 newPercentage);
    
    /**
     * @dev Constructor
     */
    constructor() ERC721("GradXP Course", "GXPC") Ownable(msg.sender) {
        _baseTokenURI = "https://api.gradxp.com/metadata/";
    }
    
    /**
     * @dev Set the GradXP contract address
     * @param _gradXPContract Address of the GradXP contract
     */
    function setGradXPContract(address _gradXPContract) external onlyOwner {
        require(_gradXPContract != address(0), "Invalid address");
        gradXPContract = _gradXPContract;
        emit GradXPContractUpdated(_gradXPContract);
    }
    
    /**
     * @dev Set the base URI for token metadata
     * @param baseURI New base URI
     */
    function setBaseURI(string memory baseURI) external onlyOwner {
        _baseTokenURI = baseURI;
        emit BaseURIUpdated(baseURI);
    }
    
    /**
     * @dev Set the royalty percentage for secondary sales
     * @param _royaltyPercentage New royalty percentage in basis points
     */
    function setRoyaltyPercentage(uint256 _royaltyPercentage) external onlyOwner {
        require(_royaltyPercentage <= 1000, "Royalty cannot exceed 10%");
        uint256 oldPercentage = royaltyPercentage;
        royaltyPercentage = _royaltyPercentage;
        emit RoyaltyPercentageUpdated(oldPercentage, _royaltyPercentage);
    }
    
    /**
     * @dev Override _baseURI function to return the base URI
     */
    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }
    
    /**
     * @dev Mint a new course NFT
     * @param _to Address to mint the NFT to
     * @param _courseId Course ID
     * @return New token ID
     */
    function mintCourseNFT(address _to, string memory _courseId) external whenNotPaused returns (uint256) {
        require(msg.sender == gradXPContract, "Only GradXP contract can mint");
        require(courseOwnership[_courseId][_to] == 0, "User already owns this course");
        
        _tokenIds.increment();
        uint256 newTokenId = _tokenIds.current();
        
        _mint(_to, newTokenId);
        
        // Set token URI to courseId
        _setTokenURI(newTokenId, _courseId);
        
        // Update mappings
        tokenToCourse[newTokenId] = _courseId;
        courseOwnership[_courseId][_to] = newTokenId;
        
        emit CourseNFTMinted(_to, _courseId, newTokenId);
        
        return newTokenId;
    }
    
    /**
     * @dev Burn a course NFT
     * @param _tokenId Token ID to burn
     */
    function burnCourseNFT(uint256 _tokenId) external whenNotPaused {
        require(
            msg.sender == gradXPContract || 
            msg.sender == ownerOf(_tokenId) || 
            msg.sender == owner(),
            "Not authorized to burn"
        );
        
        string memory courseId = tokenToCourse[_tokenId];
        address tokenOwner = ownerOf(_tokenId);
        
        // Update mappings
        delete courseOwnership[courseId][tokenOwner];
        delete tokenToCourse[_tokenId];
        
        // Burn the token
        _burn(_tokenId);
        
        emit CourseNFTBurned(_tokenId, courseId);
    }
    
    /**
     * @dev Check if an address owns a specific course
     * @param _owner Address to check
     * @param _courseId Course ID
     * @return True if the address owns the course
     */
    function ownerOfCourse(address _owner, string memory _courseId) external view returns (bool) {
        return courseOwnership[_courseId][_owner] != 0;
    }
    
    /**
     * @dev Get the token ID for a course owned by an address
     * @param _owner Address to check
     * @param _courseId Course ID
     * @return Token ID
     */
    function getTokenId(address _owner, string memory _courseId) external view returns (uint256) {
        return courseOwnership[_courseId][_owner];
    }
    
    /**
     * @dev Get the course ID for a token
     * @param _tokenId Token ID
     * @return Course ID
     */
    function getCourseId(uint256 _tokenId) external view returns (string memory) {
        return tokenToCourse[_tokenId];
    }
    
    /**
     * @dev Get royalty information for a token
     * @param _tokenId Token ID
     * @param _salePrice Sale price
     * @return receiver Royalty receiver
     * @return royaltyAmount Royalty amount
     */
    function royaltyInfo(uint256 _tokenId, uint256 _salePrice) external view returns (address receiver, uint256 royaltyAmount) {
        require(_exists(_tokenId), "Token does not exist");
        
        // Calculate royalty amount
        uint256 amount = (_salePrice * royaltyPercentage) / 10000;
        
        return (owner(), amount);
    }
    
    /**
     * @dev Pause the contract
     */
    function pause() external onlyOwner {
        _pause();
    }
    
    /**
     * @dev Unpause the contract
     */
    function unpause() external onlyOwner {
        _unpause();
    }
    
    /**
     * @dev Override _beforeTokenTransfer to add pausable functionality
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId,
        uint256 batchSize
    ) internal override whenNotPaused {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }
    
    /**
     * @dev Override supportsInterface to add ERC2981 support
     */
    function supportsInterface(bytes4 interfaceId) public view override returns (bool) {
        return
            interfaceId == 0x2a55205a || // ERC2981 Interface ID for royalty standard
            super.supportsInterface(interfaceId);
    }
}

contract GradXP is Ownable, ReentrancyGuard, Pausable {
    using SafeMath for uint256;

    // ===============
    // STATE VARIABLES
    // ===============

    // Struct to store course information
    struct Course {
        string id;                  // Unique identifier for the course
        string title;               // Course title
        string description;         // Course description
        uint256 price;              // Price in wei
        uint256 totalModules;       // Total number of modules in the course
        address creator;            // Address of the course creator
        uint256 totalInvestment;    // Total amount invested in the course
        uint256 totalStudents;      // Total number of students enrolled
        uint256 totalRating;        // Sum of all ratings
        uint256 ratingCount;        // Number of ratings
        bool isActive;              // Whether the course is active
        uint256 createdAt;          // Timestamp when the course was created
        string category;            // Course category (e.g., "Development", "Design")
        string level;               // Course difficulty level (e.g., "Beginner", "Advanced")
        uint256 duration;           // Estimated duration in seconds
    }
    
    // Struct to store module information
    struct Module {
        string id;                  // Unique identifier for the module
        string title;               // Module title
        string description;         // Module description
        uint256 duration;           // Estimated duration in seconds
        uint256 rewardAmount;       // Reward amount for completing this module
        bool isActive;              // Whether the module is active
    }
    
    // Struct to store investment information
    struct Investment {
        uint256 amount;             // Amount invested
        uint256 timestamp;          // When the investment was made
        uint256 claimedRewards;     // Amount of rewards claimed
        uint256 lastClaimTime;      // Last time rewards were claimed
        bool active;                // Whether the investment is active
    }
    
    // Struct to store student progress
    struct StudentProgress {
        uint256 completedModules;   // Number of completed modules
        uint256 lastModuleCompleted; // ID of the last completed module
        uint256 earnedRewards;      // Total rewards earned
        uint256 claimedRewards;     // Total rewards claimed
        bool purchased;             // Whether the course was purchased
        uint256 purchaseTime;       // When the course was purchased
        uint256 lastActivityTime;   // Last time the student was active
        uint256 rating;             // Student's rating of the course (0-5)
        bool hasRated;              // Whether the student has rated the course
    }
    
    // Mapping of courseId to Course
    mapping(string => Course) public courses;
    
    // Mapping of courseId to array of moduleIds
    mapping(string => string[]) public courseModules;
    
    // Mapping of moduleId to Module
    mapping(string => Module) public modules;
    
    // Mapping of courseId to array of investors
    mapping(string => address[]) public courseInvestors;
    
    // Mapping of courseId to investor address to Investment
    mapping(string => mapping(address => Investment)) public investments;
    
    // Mapping of courseId to student address to StudentProgress
    mapping(string => mapping(address => StudentProgress)) public studentProgress;
    
    // Array of all course IDs
    string[] public allCourseIds;
    
    // Mapping of category to array of course IDs
    mapping(string => string[]) public coursesByCategory;
    
    // Array of all categories
    string[] public allCategories;
    
    // CourseNFT contract reference
    CourseNFT public courseNFT;
    
    // GradXPToken contract reference
    GradXPToken public token;
    
    // Platform fee percentage (in basis points, e.g., 250 = 2.5%)
    uint256 public platformFeePercentage = 250;
    
    // Default reward per module completion (in wei)
    uint256 public defaultRewardPerModule = 0.01 ether;
    
    // Minimum investment amount
    uint256 public minInvestmentAmount = 0.01 ether;
    
    // Maximum investment amount
    uint256 public maxInvestmentAmount = 100 ether;
    
    // Investor share percentage (in basis points, e.g., 5000 = 50%)
    uint256 public investorSharePercentage = 5000;
    
    // Creator share percentage (in basis points, e.g., 5000 = 50%)
    uint256 public creatorSharePercentage = 5000;
    
    // Refund window in seconds (default: 7 days)
    uint256 public refundWindow = 7 days;
    
    // Minimum rating (1)
    uint256 public constant MIN_RATING = 1;
    
    // Maximum rating (5)
    uint256 public constant MAX_RATING = 5;
    
    // ======
    // EVENTS
    // ======
    
    event CourseCreated(string courseId, address creator, uint256 price, string category, string level);
    event CourseUpdated(string courseId, address updater);
    event CourseDeactivated(string courseId, address deactivator);
    event CoursePurchased(string courseId, address student, uint256 price);
    event CourseRefunded(string courseId, address student, uint256 amount);
    event ModuleCreated(string courseId, string moduleId, string title);
    event ModuleUpdated(string courseId, string moduleId);
    event ModuleCompleted(string courseId, address student, string moduleId, uint256 rewardAmount);
    event RewardsClaimed(address student, uint256 amount, uint256 tokenAmount);
    event InvestmentMade(string courseId, address investor, uint256 amount);
    event InvestmentRewardsClaimed(address investor, string courseId, uint256 amount);
    event CourseRated(string courseId, address student, uint256 rating);
    event PlatformFeeUpdated(uint256 oldFee, uint256 newFee);
    event RewardPerModuleUpdated(uint256 oldReward, uint256 newReward);
    event InvestorShareUpdated(uint256 oldShare, uint256 newShare);
    event CreatorShareUpdated(uint256 oldShare, uint256 newShare);
    event RefundWindowUpdated(uint256 oldWindow, uint256 newWindow);
    event MinInvestmentUpdated(uint256 oldMin, uint256 newMin);
    event MaxInvestmentUpdated(uint256 oldMax, uint256 newMax);
    
    // ===========
    // CONSTRUCTOR
    // ===========
    
    /**
     * @dev Constructor
     * @param _courseNFT Address of the CourseNFT contract
     * @param _token Address of the GradXPToken contract
     */
    constructor(address _courseNFT, address _token) Ownable(msg.sender) {
        courseNFT = CourseNFT(_courseNFT);
        token = GradXPToken(_token);
    }
    
    // ==========
    // MODIFIERS
    // ==========
    
    /**
     * @dev Modifier to check if a course exists
     * @param _courseId Course ID
     */
    modifier courseExists(string memory _courseId) {
        require(courses[_courseId].creator != address(0), "Course does not exist");
        _;
    }
    
    /**
     * @dev Modifier to check if a course is active
     * @param _courseId Course ID
     */
    modifier courseActive(string memory _courseId) {
        require(courses[_courseId].isActive, "Course is not active");
        _;
    }
    
    /**
     * @dev Modifier to check if a module exists
     * @param _moduleId Module ID
     */
    modifier moduleExists(string memory _moduleId) {
        require(bytes(modules[_moduleId].id).length > 0, "Module does not exist");
        _;
    }
    
    /**
     * @dev Modifier to check if the caller is the course creator
     * @param _courseId Course ID
     */
    modifier onlyCourseCreator(string memory _courseId) {
        require(courses[_courseId].creator == msg.sender, "Only course creator can perform this action");
        _;
    }
    
    /**
     * @dev Modifier to check if the caller has purchased the course
     * @param _courseId Course ID
     */
    modifier hasPurchased(string memory _courseId) {
        require(studentProgress[_courseId][msg.sender].purchased, "Course not purchased");
        _;
    }
    
    // ================
    // COURSE FUNCTIONS
    // ================
    
    /**
     * @dev Create a new course
     * @param _id Course ID
     * @param _title Course title
     * @param _description Course description
     * @param _price Course price in wei
     * @param _totalModules Total number of modules in the course
     * @param _category Course category
     * @param _level Course difficulty level
     * @param _duration Estimated duration in seconds
     */
    function createCourse(
        string memory _id,
        string memory _title,
        string memory _description,
        uint256 _price,
        uint256 _totalModules,
        string memory _category,
        string memory _level,
        uint256 _duration
    ) external whenNotPaused {
        require(bytes(_id).length > 0, "Course ID cannot be empty");
        require(bytes(_title).length > 0, "Course title cannot be empty");
        require(_totalModules > 0, "Course must have at least one module");
        require(courses[_id].creator == address(0), "Course ID already exists");
        
        // Create new course
        Course memory newCourse = Course({
            id: _id,
            title: _title,
            description: _description,
            price: _price,
            totalModules: _totalModules,
            creator: msg.sender,
            totalInvestment: 0,
            totalStudents: 0,
            totalRating: 0,
            ratingCount: 0,
            isActive: true,
            createdAt: block.timestamp,
            category: _category,
            level: _level,
            duration: _duration
        });
        
        courses[_id] = newCourse;
        allCourseIds.push(_id);
        
        // Add to category mapping
        bool categoryExists = false;
        for (uint256 i = 0; i < allCategories.length; i++) {
            if (keccak256(bytes(allCategories[i])) == keccak256(bytes(_category))) {
                categoryExists = true;
                break;
            }
        }
        
        if (!categoryExists) {
            allCategories.push(_category);
        }
        
        coursesByCategory[_category].push(_id);
        
        emit CourseCreated(_id, msg.sender, _price, _category, _level);
    }
    
    /**
     * @dev Update an existing course
     * @param _courseId Course ID
     * @param _title New course title
     * @param _description New course description
     * @param _price New course price in wei
     * @param _level New course difficulty level
     * @param _duration New estimated duration in seconds
     */
    function updateCourse(
        string memory _courseId,
        string memory _title,
        string memory _description,
        uint256 _price,
        string memory _level,
        uint256 _duration
    ) external courseExists(_courseId) onlyCourseCreator(_courseId) whenNotPaused {
        Course storage course = courses[_courseId];
        
        if (bytes(_title).length > 0) {
            course.title = _title;
        }
        
        if (bytes(_description).length > 0) {
            course.description = _description;
        }
        
        if (_price > 0) {
            course.price = _price;
        }
        
        if (bytes(_level).length > 0) {
            course.level = _level;
        }
        
        if (_duration > 0) {
            course.duration = _duration;
        }
        
        emit CourseUpdated(_courseId, msg.sender);
    }
    
    /**
     * @dev Deactivate a course
     * @param _courseId Course ID
     */
    function deactivateCourse(string memory _courseId) 
        external 
        courseExists(_courseId) 
        onlyCourseCreator(_courseId) 
        whenNotPaused 
    {
        courses[_courseId].isActive = false;
        emit CourseDeactivated(_courseId, msg.sender);
    }
    
    /**
     * @dev Reactivate a course
     * @param _courseId Course ID
     */
    function reactivateCourse(string memory _courseId) 
        external 
        courseExists(_courseId) 
        onlyCourseCreator(_courseId) 
        whenNotPaused 
    {
        courses[_courseId].isActive = true;
        emit CourseUpdated(_courseId, msg.sender);
    }
    
    /**
     * @dev Purchase a course
     * @param _courseId Course ID
     */
    function purchaseCourse(string memory _courseId) 
        external 
        payable 
        nonReentrant 
        courseExists(_courseId) 
        courseActive(_courseId) 
        whenNotPaused 
    {
        Course storage course = courses[_courseId];
        require(msg.value >= course.price, "Insufficient payment");
        require(!studentProgress[_courseId][msg.sender].purchased, "Course already purchased");
        
        // Initialize student progress
        studentProgress[_courseId][msg.sender] = StudentProgress({
            completedModules: 0,
            lastModuleCompleted: 0,
            earnedRewards: 0,
            claimedRewards: 0,
            purchased: true,
            purchaseTime: block.timestamp,
            lastActivityTime: block.timestamp,
            rating: 0,
            hasRated: false
        });
        
        // Mint NFT to represent course ownership
        courseNFT.mintCourseNFT(msg.sender, _courseId);
        
        // Distribute funds
        uint256 platformFee = (msg.value * platformFeePercentage) / 10000;
        uint256 remainingAmount = msg.value - platformFee;
        
        // If there are investors, distribute according to shares
        if (courseInvestors[_courseId].length > 0 && course.totalInvestment > 0) {
            uint256 investorShare = (remainingAmount * investorSharePercentage) / 10000;
            uint256 creatorShare = remainingAmount - investorShare;
            
            // Send creator their share
            (bool sentCreator, ) = payable(course.creator).call{value: creatorShare}("");
            require(sentCreator, "Failed to send creator share");
            
            // Keep investor share in contract for later claiming
        } else {
            // No investors, send all to creator
            (bool sentCreator, ) = payable(course.creator).call{value: remainingAmount}("");
            require(sentCreator, "Failed to send creator share");
        }
        
        // Update course stats
        course.totalStudents += 1;
        
        emit CoursePurchased(_courseId, msg.sender, msg.value);
    }
    
    /**
     * @dev Request a refund for a course
     * @param _courseId Course ID
     */
    function requestRefund(string memory _courseId) 
        external 
        nonReentrant 
        courseExists(_courseId) 
        hasPurchased(_courseId) 
        whenNotPaused 
    {
        StudentProgress storage progress = studentProgress[_courseId][msg.sender];
        Course storage course = courses[_courseId];
        
        // Check if within refund window
        require(block.timestamp <= progress.purchaseTime + refundWindow, "Refund window expired");
        
        // Check if student has not completed any modules
        require(progress.completedModules == 0, "Cannot refund after completing modules");
        
        // Calculate refund amount (full price minus platform fee)
        uint256 platformFee = (course.price * platformFeePercentage) / 10000;
        uint256 refundAmount = course.price - platformFee;
        
        // Update student progress
        progress.purchased = false;
        
        // Burn the NFT
        uint256 tokenId = courseNFT.getTokenId(msg.sender, _courseId);
        courseNFT.burnCourseNFT(tokenId);
        
        // Update course stats
        course.totalStudents -= 1;
        
        // Send refund
        (bool sent, ) = payable(msg.sender).call{value: refundAmount}("");
        require(sent, "Failed to send refund");
        
        emit CourseRefunded(_courseId, msg.sender, refundAmount);
    }
    
    /**
     * @dev Rate a course
     * @param _courseId Course ID
     * @param _rating Rating (1-5)
     */
    function rateCourse(string memory _courseId, uint256 _rating) 
        external 
        courseExists(_courseId) 
        hasPurchased(_courseId) 
        whenNotPaused 
    {
        require(_rating >= MIN_RATING && _rating <= MAX_RATING, "Rating must be between 1 and 5");
        
        StudentProgress storage progress = studentProgress[_courseId][msg.sender];
        Course storage course = courses[_courseId];
        
        // If student has already rated, update the rating
        if (progress.hasRated) {
            course.totalRating = course.totalRating - progress.rating + _rating;
        } else {
            course.totalRating += _rating;
            course.ratingCount += 1;
            progress.hasRated = true;
        }
        
        progress.rating = _rating;
        
        emit CourseRated(_courseId, msg.sender, _rating);
    }
    
    // ================
    // MODULE FUNCTIONS
    // ================
    
    /**
     * @dev Create a new module for a course
     * @param _courseId Course ID
     * @param _moduleId Module ID
     * @param _title Module title
     * @param _description Module description
     * @param _duration Estimated duration in seconds
     * @param _rewardAmount Reward amount for completing this module
     */
    function createModule(
        string memory _courseId,
        string memory _moduleId,
        string memory _title,
        string memory _description,
        uint256 _duration,
        uint256 _rewardAmount
    ) 
        external 
        courseExists(_courseId) 
        onlyCourseCreator(_courseId) 
        whenNotPaused 
    {
        require(bytes(_moduleId).length > 0, "Module ID cannot be empty");
        require(bytes(_title).length > 0, "Module title cannot be empty");
        require(bytes(modules[_moduleId].id).length == 0, "Module ID already exists");
        
        // Create new module
        Module memory newModule = Module({
            id: _moduleId,
            title: _title,
            description: _description,
            duration: _duration,
            rewardAmount: _rewardAmount > 0 ? _rewardAmount : defaultRewardPerModule,
            isActive: true
        });
        
        modules[_moduleId] = newModule;
        courseModules[_courseId].push(_moduleId);
        
        emit ModuleCreated(_courseId, _moduleId, _title);
    }
    
    /**
     * @dev Update an existing module
     * @param _moduleId Module ID
     * @param _title New module title
     * @param _description New module description
     * @param _duration New estimated duration in seconds
     * @param _rewardAmount New reward amount
     * @param _isActive New active status
     */
    function updateModule(
        string memory _courseId,
        string memory _moduleId,
        string memory _title,
        string memory _description,
        uint256 _duration,
        uint256 _rewardAmount,
        bool _isActive
    ) 
        external 
        courseExists(_courseId) 
        moduleExists(_moduleId) 
        onlyCourseCreator(_courseId) 
        whenNotPaused 
    {
        Module storage module = modules[_moduleId];
        
        if (bytes(_title).length > 0) {
            module.title = _title;
        }
        
        if (bytes(_description).length > 0) {
            module.description = _description;
        }
        
        if (_duration > 0) {
            module.duration = _duration;
        }
        
        if (_rewardAmount > 0) {
            module.rewardAmount = _rewardAmount;
        }
        
        module.isActive = _isActive;
        
        emit ModuleUpdated(_courseId, _moduleId);
    }
    
    /**
     * @dev Complete a module and earn rewards
     * @param _courseId Course ID
     * @param _moduleId Module ID
     */
    function completeModule(string memory _courseId, string memory _moduleId) 
        external 
        nonReentrant 
        courseExists(_courseId) 
        moduleExists(_moduleId) 
        courseActive(_courseId) 
        hasPurchased(_courseId) 
        whenNotPaused 
    {
        Course storage course = courses[_courseId];
        StudentProgress storage progress = studentProgress[_courseId][msg.sender];
        Module storage module = modules[_moduleId];
        
        require(module.isActive, "Module is not active");
        
        // Check if module belongs to the course
        bool moduleFound = false;
        for (uint256 i = 0; i < courseModules[_courseId].length; i++) {
            if (keccak256(bytes(courseModules[_courseId][i])) == keccak256(bytes(_moduleId))) {
                moduleFound = true;
                break;
            }
        }
        require(moduleFound, "Module does not belong to this course");
        
        // Check if module has already been completed
        bool alreadyCompleted = false;
        if (progress.completedModules > 0) {
            for (uint256 i = 0; i < progress.completedModules; i++) {
                if (progress.lastModuleCompleted == i) {
                    alreadyCompleted = true;
                    break;
                }
            }
        }
        require(!alreadyCompleted, "Module already completed");
        
        // Update progress
        progress.completedModules += 1;
        progress.lastModuleCompleted = progress.completedModules;
        progress.lastActivityTime = block.timestamp;
        
        // Calculate and add rewards
        uint256 moduleReward = module.rewardAmount;
        progress.earnedRewards += moduleReward;
        
        // Mint some tokens as additional reward
        uint256 tokenReward = moduleReward * 100; // 100 tokens per ETH of rewards
        token.mint(msg.sender, tokenReward);
        
        emit ModuleCompleted(_courseId, msg.sender, _moduleId, moduleReward);
    }
    
    // ================
    // REWARD FUNCTIONS
    // ================
    
    /**
     * @dev Claim earned rewards
     */
    function claimRewards() external nonReentrant whenNotPaused {
        uint256 totalRewards = 0;
        uint256 totalTokenRewards = 0;
        
        // Calculate total rewards across all courses
        for (uint256 i = 0; i < allCourseIds.length; i++) {
            string memory courseId = allCourseIds[i];
            StudentProgress storage progress = studentProgress[courseId][msg.sender];
            
            if (progress.purchased) {
                uint256 unclaimedRewards = progress.earnedRewards - progress.claimedRewards;
                if (unclaimedRewards > 0) {
                    totalRewards += unclaimedRewards;
                    progress.claimedRewards += unclaimedRewards;
                    
                    // Calculate token rewards
                    uint256 tokenRewards = unclaimedRewards * 100; // 100 tokens per ETH of rewards
                    totalTokenRewards += tokenRewards;
                }
            }
        }
        
        require(totalRewards > 0, "No rewards to claim");
        
        // Transfer rewards to student
        (bool sent, ) = payable(msg.sender).call{value: totalRewards}("");
        require(sent, "Failed to send rewards");
        
        // Mint tokens as additional rewards
        token.mint(msg.sender, totalTokenRewards);
        
        emit RewardsClaimed(msg.sender, totalRewards, totalTokenRewards);
    }
    
    // ====================
    // INVESTMENT FUNCTIONS
    // ====================
    
    /**
     * @dev Invest in a course
     * @param _courseId Course ID
     */
    function investInCourse(string memory _courseId) 
        external 
        payable 
        nonReentrant 
        courseExists(_courseId) 
        courseActive(_courseId) 
        whenNotPaused 
    {
        require(msg.value >= minInvestmentAmount, "Investment amount below minimum");
        require(msg.value <= maxInvestmentAmount, "Investment amount above maximum");
        
        // Check if this is a new investor
        bool isNewInvestor = investments[_courseId][msg.sender].amount == 0;
        
        // Update investment
        if (isNewInvestor) {
            courseInvestors[_courseId].push(msg.sender);
            investments[_courseId][msg.sender] = Investment({
                amount: msg.value,
                timestamp: block.timestamp,
                claimedRewards: 0,
                lastClaimTime: block.timestamp,
                active: true
            });
        } else {
            investments[_courseId][msg.sender].amount += msg.value;
            investments[_courseId][msg.sender].timestamp = block.timestamp;
            investments[_courseId][msg.sender].active = true;
        }
        
        // Update course total investment
        courses[_courseId].totalInvestment += msg.value;
        
        emit InvestmentMade(_courseId, msg.sender, msg.value);
    }
    
    /**
     * @dev Claim investment rewards for a specific course
     * @param _courseId Course ID
     */
    function claimInvestmentRewards(string memory _courseId) 
        external 
        nonReentrant 
        courseExists(_courseId) 
        whenNotPaused 
    {
        Course storage course = courses[_courseId];
        Investment storage investment = investments[_courseId][msg.sender];
        
        require(investment.amount > 0, "No investment found");
        require(investment.active, "Investment is not active");
        
        // Calculate investor's share of the course revenue
        uint256 investorSharePercentage = (investment.amount * 10000) / course.totalInvestment;
        
        // Calculate total revenue from course purchases since last claim
        uint256 totalRevenue = course.totalStudents * course.price;
        uint256 investorRevenueShare = (totalRevenue * investorSharePercentage * this.getInvestorSharePercentage()) / (10000 * 10000);
        
        // Calculate unclaimed rewards
        uint256 unclaimedRewards = investorRevenueShare - investment.claimedRewards;
        require(unclaimedRewards > 0, "No rewards to claim");
        
        // Update claimed rewards
        investment.claimedRewards += unclaimedRewards;
        investment.lastClaimTime = block.timestamp;
        
        // Transfer rewards to investor
        (bool sent, ) = payable(msg.sender).call{value: unclaimedRewards}("");
        require(sent, "Failed to send rewards");
        
        emit InvestmentRewardsClaimed(msg.sender, _courseId, unclaimedRewards);
    }
    
    /**
     * @dev Claim investment rewards for all courses
     */
    function claimAllInvestmentRewards() external nonReentrant whenNotPaused {
        uint256 totalRewards = 0;
        
        for (uint256 i = 0; i < allCourseIds.length; i++) {
            string memory courseId = allCourseIds[i];
            Investment storage investment = investments[courseId][msg.sender];
            
            if (investment.amount > 0 && investment.active) {
                Course storage course = courses[courseId];
                
                // Calculate investor's share of the course revenue
                uint256 investorSharePercentage = (investment.amount * 10000) / course.totalInvestment;
                
                // Calculate total revenue from course purchases
                uint256 totalRevenue = course.totalStudents * course.price;
                uint256 investorRevenueShare = (totalRevenue * investorSharePercentage * this.getInvestorSharePercentage()) / (10000 * 10000);
                
                // Calculate unclaimed rewards
                uint256 unclaimedRewards = investorRevenueShare - investment.claimedRewards;
                
                if (unclaimedRewards > 0) {
                    // Update claimed rewards
                    investment.claimedRewards += unclaimedRewards;
                    investment.lastClaimTime = block.timestamp;
                    
                    totalRewards += unclaimedRewards;
                    
                    emit InvestmentRewardsClaimed(msg.sender, courseId, unclaimedRewards);
                }
            }
        }
        
        require(totalRewards > 0, "No rewards to claim");
        
        // Transfer rewards to investor
        (bool sent, ) = payable(msg.sender).call{value: totalRewards}("");
        require(sent, "Failed to send rewards");
    }
    
    /**
     * @dev Withdraw investment from a course
     * @param _courseId Course ID
     */
    function withdrawInvestment(string memory _courseId) 
        external 
        nonReentrant 
        courseExists(_courseId) 
        whenNotPaused 
    {
        Investment storage investment = investments[_courseId][msg.sender];
        Course storage course = courses[_courseId];
        
        require(investment.amount > 0, "No investment found");
        require(investment.active, "Investment already withdrawn");
        
        // Calculate withdrawal amount (original investment minus a fee)
        uint256 withdrawalFee = (investment.amount * 500) / 10000; // 5% fee
        uint256 withdrawalAmount = investment.amount - withdrawalFee;
        
        // Update investment
        investment.active = false;
        
        // Update course total investment
        course.totalInvestment -= investment.amount;
        
        // Transfer withdrawal amount to investor
        (bool sent, ) = payable(msg.sender).call{value: withdrawalAmount}("");
        require(sent, "Failed to send withdrawal");
        
        emit InvestmentWithdrawn(msg.sender, _courseId, withdrawalAmount);
    }
    
    // =================
    // GETTER FUNCTIONS
    // =================
    
    /**
     * @dev Get course details
     * @param _courseId Course ID
     * @return Course details
     */
    function getCourse(string memory _courseId) external view returns (Course memory) {
        return courses[_courseId];
    }
    
    /**
     * @dev Get module details
     * @param _moduleId Module ID
     * @return Module details
     */
    function getModule(string memory _moduleId) external view returns (Module memory) {
        return modules[_moduleId];
    }
    
    /**
     * @dev Get all modules for a course
     * @param _courseId Course ID
     * @return Array of module IDs
     */
    function getCourseModules(string memory _courseId) external view returns (string[] memory) {
        return courseModules[_courseId];
    }
    
    /**
     * @dev Get student progress for a course
     * @param _courseId Course ID
     * @param _student Student address
     * @return StudentProgress details
     */
    function getStudentProgress(string memory _courseId, address _student) external view returns (StudentProgress memory) {
        return studentProgress[_courseId][_student];
    }
    
    /**
     * @dev Get investment details
     * @param _courseId Course ID
     * @param _investor Investor address
     * @return Investment details
     */
    function getInvestment(string memory _courseId, address _investor) external view returns (Investment memory) {
        return investments[_courseId][_investor];
    }
    
    /**
     * @dev Get all course IDs
     * @return Array of course IDs
     */
    function getAllCourseIds() external view returns (string[] memory) {
        return allCourseIds;
    }
    
    /**
     * @dev Get all categories
     * @return Array of categories
     */
    function getAllCategories() external view returns (string[] memory) {
        return allCategories;
    }
    
    /**
     * @dev Get courses by category
     * @param _category Category
     * @return Array of course IDs
     */
    function getCoursesByCategory(string memory _category) external view returns (string[] memory) {
        return coursesByCategory[_category];
    }
    
    /**
     * @dev Get total number of courses
     * @return Total number of courses
     */
    function getTotalCourses() external view returns (uint256) {
        return allCourseIds.length;
    }
    
    /**
     * @dev Get course rating
     * @param _courseId Course ID
     * @return Average rating (0-5)
     */
    function getCourseRating(string memory _courseId) external view returns (uint256) {
        Course memory course = courses[_courseId];
        if (course.ratingCount == 0) {
            return 0;
        }
        return course.totalRating / course.ratingCount;
    }
    
    /**
     * @dev Get investor share percentage
     * @return Investor share percentage in basis points
     */
    function getInvestorSharePercentage() external view returns (uint256) {
        return investorSharePercentage;
    }
    
    /**
     * @dev Get creator share percentage
     * @return Creator share percentage in basis points
     */
    function getCreatorSharePercentage() external view returns (uint256) {
        return creatorSharePercentage;
    }
    
    // =================
    // ADMIN FUNCTIONS
    // =================
    
    /**
     * @dev Update platform fee percentage
     * @param _newFeePercentage New fee percentage in basis points
     */
    function updatePlatformFee(uint256 _newFeePercentage) external onlyOwner {
        require(_newFeePercentage <= 1000, "Fee cannot exceed 10%");
        uint256 oldFee = platformFeePercentage;
        platformFeePercentage = _newFeePercentage;
        emit PlatformFeeUpdated(oldFee, _newFeePercentage);
    }
    
    /**
     * @dev Update default reward per module
     * @param _newRewardPerModule New reward amount per module in wei
     */
    function updateDefaultRewardPerModule(uint256 _newRewardPerModule) external onlyOwner {
        uint256 oldReward = defaultRewardPerModule;
        defaultRewardPerModule = _newRewardPerModule;
        emit RewardPerModuleUpdated(oldReward, _newRewardPerModule);
    }
    
    /**
     * @dev Update investor share percentage
     * @param _newSharePercentage New share percentage in basis points
     */
    function updateInvestorSharePercentage(uint256 _newSharePercentage) external onlyOwner {
        require(_newSharePercentage <= 10000, "Share cannot exceed 100%");
        uint256 oldShare = investorSharePercentage;
        investorSharePercentage = _newSharePercentage;
        creatorSharePercentage = 10000 - _newSharePercentage;
        emit InvestorShareUpdated(oldShare, _newSharePercentage);
        emit CreatorShareUpdated(oldShare, creatorSharePercentage);
    }
    
    /**
     * @dev Update refund window
     * @param _newRefundWindow New refund window in seconds
     */
    function updateRefundWindow(uint256 _newRefundWindow) external onlyOwner {
        uint256 oldWindow = refundWindow;
        refundWindow = _newRefundWindow;
        emit RefundWindowUpdated(oldWindow, _newRefundWindow);
    }
    
    /**
     * @dev Update minimum investment amount
     * @param _newMinInvestment New minimum investment amount in wei
     */
    function updateMinInvestment(uint256 _newMinInvestment) external onlyOwner {
        require(_newMinInvestment <= maxInvestmentAmount, "Min cannot exceed max");
        uint256 oldMin = minInvestmentAmount;
        minInvestmentAmount = _newMinInvestment;
        emit MinInvestmentUpdated(oldMin, _newMinInvestment);
    }
    
    /**
     * @dev Update maximum investment amount
     * @param _newMaxInvestment New maximum investment amount in wei
     */
    function updateMaxInvestment(uint256 _newMaxInvestment) external onlyOwner {
        require(_newMaxInvestment >= minInvestmentAmount, "Max cannot be less than min");
        uint256 oldMax = maxInvestmentAmount;
        maxInvestmentAmount = _newMaxInvestment;
        emit MaxInvestmentUpdated(oldMax, _newMaxInvestment);
    }
    
    /**
     * @dev Pause the contract
     */
    function pause() external onlyOwner {
        _pause();
    }
    
    /**
     * @dev Unpause the contract
     */
    function unpause() external onlyOwner {
        _unpause();
    }
    
    /**
     * @dev Withdraw platform fees
     * @param _amount Amount to withdraw
     */
    function withdrawPlatformFees(uint256 _amount) external onlyOwner {
        require(_amount > 0, "Amount must be greater than 0");
        require(address(this).balance >= _amount, "Insufficient balance");
        
        (bool sent, ) = payable(owner()).call{value: _amount}("");
        require(sent, "Failed to send funds");
    }
    
    // Fallback function to receive ETH
    receive() external payable {}
    
    // Event for investment withdrawal
    event InvestmentWithdrawn(address investor, string courseId, uint256 amount);
}

contract GradXPToken is ERC20Burnable, ERC20Permit, ERC20Votes, Ownable, Pausable {
    // Address of the GradXP contract that is allowed to mint tokens
    address public gradXPContract;
    
    // Maximum supply of tokens
    uint256 public constant MAX_SUPPLY = 1_000_000_000 * 10**18; // 1 billion tokens
    
    // Events
    event GradXPContractUpdated(address newGradXPContract);
    
    /**
     * @dev Constructor
     */
    constructor() 
        ERC20("GradXP Token", "GXP") 
        ERC20Permit("GradXP Token")
        Ownable(msg.sender) 
    {
        // Mint initial supply to owner (10% of max supply)
        _mint(msg.sender, MAX_SUPPLY / 10);
    }
    
    /**
     * @dev Set the GradXP contract address
     * @param _gradXPContract Address of the GradXP contract
     */
    function setGradXPContract(address _gradXPContract) external onlyOwner {
        require(_gradXPContract != address(0), "Invalid address");
        gradXPContract = _gradXPContract;
        emit GradXPContractUpdated(_gradXPContract);
    }
    
    /**
     * @dev Mint new tokens
     * @param _to Address to mint tokens to
     * @param _amount Amount of tokens to mint
     */
    function mint(address _to, uint256 _amount) external whenNotPaused {
        require(msg.sender == gradXPContract || msg.sender == owner(), "Only GradXP contract or owner can mint");
        require(totalSupply() + _amount <= MAX_SUPPLY, "Exceeds maximum supply");
        _mint(_to, _amount);
    }
    
    /**
     * @dev Pause the contract
     */
    function pause() external onlyOwner {
        _pause();
    }
    
    /**
     * @dev Unpause the contract
     */
    function unpause() external onlyOwner {
        _unpause();
    }
    
    /**
     * @dev Override _beforeTokenTransfer to add pausable functionality
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override whenNotPaused {
        super._beforeTokenTransfer(from, to, amount);
    }
    
    /**
     * @dev Override _afterTokenTransfer for ERC20Votes
     */
    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override(ERC20, ERC20Votes) {
        super._afterTokenTransfer(from, to, amount);
    }
    
    /**
     * @dev Override _mint for ERC20Votes
     */
    function _mint(address to, uint256 amount) internal override(ERC20, ERC20Votes) {
        super._mint(to, amount);
    }
    
    /**
     * @dev Override _burn for ERC20Votes
     */
    function _burn(address account, uint256 amount) internal override(ERC20, ERC20Votes) {
        super._burn(account, amount);
    }
}

