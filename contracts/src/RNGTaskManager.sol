// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;


import "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import "../lib/openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";


/**
 * @title RNGTaskManager
 * @dev Manages random number generation tasks for the Othentic AVS
 */
contract RNGTaskManager is Ownable, ReentrancyGuard {
    using ECDSA for bytes32;

    // Structs
    struct RNGTask {
        uint256 taskId;
        address requester;
        uint256 minValue;
        uint256 maxValue;
        uint256 count;
        uint256 timestamp;
        uint256 blockNumber;
        TaskStatus status;
        bytes32 seed;
        string callbackUrl;
    }

    struct RNGResult {
        uint256 taskId;
        uint256[] randomNumbers;
        bytes aggregatedSignature;
        address[] attesters;
        uint256 timestamp;
        bool verified;
    }

    struct Operator {
        address operatorAddress;
        bool isActive;
        uint256 stake;
        uint256 taskCount;
        uint256 slashCount;
        uint256 lastActivityBlock;
    }

    // Enums
    enum TaskStatus {
        Pending,
        InProgress,
        Completed,
        Failed,
        Cancelled
    }

    // State variables
    mapping(uint256 => RNGTask) public tasks;
    mapping(uint256 => RNGResult) public results;
    mapping(address => Operator) public operators;
    mapping(address => bool) public authorizedRequesters;
    
    address[] public operatorList;
    uint256 public nextTaskId;
    uint256 public minStake;
    uint256 public taskFee;
    uint256 public slashAmount;
    uint256 public maxTasksPerBlock;
    uint256 public taskTimeout;
    
    // Events
    event TaskCreated(
        uint256 indexed taskId,
        address indexed requester,
        uint256 minValue,
        uint256 maxValue,
        uint256 count
    );
    
    event TaskCompleted(
        uint256 indexed taskId,
        uint256[] randomNumbers,
        address[] attesters
    );
    
    event OperatorRegistered(address indexed operator, uint256 stake);
    event OperatorSlashed(address indexed operator, uint256 amount);

    // Modifiers
    modifier onlyActiveOperator() {
        require(operators[msg.sender].isActive, "Not an active operator");
        _;
    }

    modifier onlyAuthorizedRequester() {
        require(
            authorizedRequesters[msg.sender] || msg.sender == owner(),
            "Not authorized to request tasks"
        );
        _;
    }

    modifier validTask(uint256 taskId) {
        require(taskId < nextTaskId, "Task does not exist");
        _;
    }

    // Corrected Constructor:
    // Explicitly call Ownable() with msg.sender as the initial owner
    // and ReentrancyGuard() constructors
    constructor(
        uint256 _minStake,
        uint256 _taskFee,
        uint256 _slashAmount,
        uint256 _maxTasksPerBlock,
        uint256 _taskTimeout
    ) Ownable(msg.sender) ReentrancyGuard() { 
        minStake = _minStake;
        taskFee = _taskFee;
        slashAmount = _slashAmount;
        maxTasksPerBlock = _maxTasksPerBlock;
        taskTimeout = _taskTimeout;
        nextTaskId = 0; 
    }

    /**
     * @dev Register a new operator
     */
    function registerOperator() external payable {
        require(msg.value >= minStake, "Insufficient stake");
        require(!operators[msg.sender].isActive, "Operator already registered");

        operators[msg.sender] = Operator({
            operatorAddress: msg.sender,
            isActive: true,
            stake: msg.value,
            taskCount: 0,
            slashCount: 0,
            lastActivityBlock: block.number
        });

        operatorList.push(msg.sender);
        emit OperatorRegistered(msg.sender, msg.value);
    }

    /**
     * @dev Create a new RNG task
     */
    function createTask(
        uint256 minValue,
        uint256 maxValue,
        uint256 count,
        string calldata callbackUrl
    ) external payable onlyAuthorizedRequester returns (uint256) {
        require(msg.value >= taskFee, "Insufficient task fee");
        require(minValue < maxValue, "Invalid range");
        require(count > 0 && count <= 100, "Invalid count");

        uint256 taskId = nextTaskId++;
        bytes32 seed = keccak256(
            abi.encodePacked(
                block.timestamp,
                msg.sender,
                taskId
            )
        );

        tasks[taskId] = RNGTask({
            taskId: taskId,
            requester: msg.sender,
            minValue: minValue,
            maxValue: maxValue,
            count: count,
            timestamp: block.timestamp,
            blockNumber: block.number,
            status: TaskStatus.Pending,
            seed: seed,
            callbackUrl: callbackUrl
        });

        emit TaskCreated(taskId, msg.sender, minValue, maxValue, count);
        return taskId;
    }

    /**
     * @dev Submit RNG result (called by operators)
     */
    function submitResult(
        uint256 taskId,
        uint256[] calldata randomNumbers,
        bytes calldata aggregatedSignature,
        address[] calldata attesters
    ) external onlyActiveOperator validTask(taskId) {
        RNGTask storage task = tasks[taskId];
        require(task.status == TaskStatus.Pending, "Task not pending");
        require(
            block.timestamp <= task.timestamp + taskTimeout,
            "Task expired"
        );
        require(randomNumbers.length == task.count, "Invalid result count");

        // Verify all random numbers are in range
        for (uint256 i = 0; i < randomNumbers.length; i++) {
            require(
                randomNumbers[i] >= task.minValue &&
                randomNumbers[i] <= task.maxValue,
                "Random number out of range"
            );
        }

        // Verify attesters are active operators
        for (uint256 i = 0; i < attesters.length; i++) {
            require(operators[attesters[i]].isActive, "Invalid attester");
        }

        // Store result
        results[taskId] = RNGResult({
            taskId: taskId,
            randomNumbers: randomNumbers,
            aggregatedSignature: aggregatedSignature,
            attesters: attesters,
            timestamp: block.timestamp,
            verified: true
        });

        // Update task status
        task.status = TaskStatus.Completed;

        // Update operator stats
        operators[msg.sender].taskCount++;
        operators[msg.sender].lastActivityBlock = block.number;

        emit TaskCompleted(taskId, randomNumbers, attesters);
    }

    /**
     * @dev Verify a random number result
     */
    function verifyResult(
        uint256 taskId,
        uint256[] calldata randomNumbers,
        bytes calldata signature
    ) external view validTask(taskId) returns (bool) {
        RNGResult storage result = results[taskId];
        if (!result.verified) return false;

        // Verify random numbers match
        if (result.randomNumbers.length != randomNumbers.length) return false;
        
        for (uint256 i = 0; i < randomNumbers.length; i++) {
            if (result.randomNumbers[i] != randomNumbers[i]) return false;
        }

        // Additional signature verification would go here
        // For now, we trust the stored aggregated signature
        return keccak256(signature) == keccak256(result.aggregatedSignature);
    }

    /**
     * @dev Slash an operator for malicious behavior
     */
    function slashOperator(
        address operator
    ) external onlyOwner {
        require(operators[operator].isActive, "Operator not active");
        require(operators[operator].stake >= slashAmount, "Insufficient stake");

        operators[operator].stake -= slashAmount;
        operators[operator].slashCount++;

        if (operators[operator].stake < minStake) {
            operators[operator].isActive = false;
        }

        emit OperatorSlashed(operator, slashAmount);
    }

    /**
     * @dev Get task details
     */
    function getTask(uint256 taskId) 
        external 
        view 
        validTask(taskId) 
        returns (RNGTask memory) 
    {
        return tasks[taskId];
    }

    /**
     * @dev Get result details
     */
    function getResult(uint256 taskId)
        external
        view
        validTask(taskId)
        returns (RNGResult memory)
    {
        return results[taskId];
    }

    /**
     * @dev Get active operators
     */
    function getActiveOperators() external view returns (address[] memory) {
        uint256 activeCount = 0;
        for (uint256 i = 0; i < operatorList.length; i++) {
            if (operators[operatorList[i]].isActive) {
                activeCount++;
            }
        }

        address[] memory activeOperators = new address[](activeCount);
        uint256 index = 0;
        for (uint256 i = 0; i < operatorList.length; i++) {
            if (operators[operatorList[i]].isActive) {
                activeOperators[index] = operatorList[i];
                index++;
            }
        }

        return activeOperators;
    }

    /**
     * @dev Authorize a requester
     */
    function authorizeRequester(address requester) external onlyOwner {
        authorizedRequesters[requester] = true;
    }

    /**
     * @dev Revoke requester authorization
     */
    function revokeRequester(address requester) external onlyOwner {
        authorizedRequesters[requester] = false;
    }

    /**
     * @dev Update system parameters
     */
    function updateParameters(
        uint256 _minStake,
        uint256 _taskFee,
        uint256 _slashAmount,
        uint256 _maxTasksPerBlock,
        uint256 _taskTimeout
    ) external onlyOwner {
        minStake = _minStake;
        taskFee = _taskFee;
        slashAmount = _slashAmount;
        maxTasksPerBlock = _maxTasksPerBlock;
        taskTimeout = _taskTimeout;
    }

    /**
     * @dev Withdraw contract balance
     */
    function withdraw() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

    /**
     * @dev Emergency pause/unpause operators
     */
    function pauseOperator(address operator) external onlyOwner {
        operators[operator].isActive = false;
    }

    function unpauseOperator(address operator) external onlyOwner {
        require(operators[operator].stake >= minStake, "Insufficient stake");
        operators[operator].isActive = true;
    }
}
