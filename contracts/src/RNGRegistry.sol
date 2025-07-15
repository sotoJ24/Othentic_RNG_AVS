// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title RNGRegistry
 * @dev Registry contract for managing RNG AVS operators, staking, and slashing
 */
contract RNGRegistry is Ownable, ReentrancyGuard {
    using ECDSA for bytes32;

    // Structs
    struct Operator {
        address operatorAddress;
        string metadataURI;
        address delegationApprover;
        uint256 stakedAmount;
        uint256 totalStake;
        uint256 registrationBlock;
        uint256 lastActivityBlock;
        uint256 taskCount;
        uint256 successfulTasks;
        uint256 slashCount;
        uint256 totalSlashed;
        bool isActive;
        bool isWhitelisted;
        OperatorStatus status;
    }

    struct Delegator {
        address delegatorAddress;
        uint256 stakedAmount;
        uint256 shares;
        uint256 lastRewardBlock;
        uint256 pendingRewards;
        bool isActive;
    }

    struct SlashingEvent {
        address operator;
        uint256 amount;
        uint256 timestamp;
        string reason;
        address slasher;
        bool executed;
    }

    struct RewardDistribution {
        uint256 totalRewards;
        uint256 operatorRewards;
        uint256 delegatorRewards;
        uint256 distributionBlock;
        mapping(address => uint256) operatorShares;
        mapping(address => uint256) delegatorShares;
    }

    // Enums
    enum OperatorStatus {
        Registered,
        Active,
        Inactive,
        Slashed,
        Ejected
    }

    // State variables
    mapping(address => Operator) public operators;
    mapping(address => address[]) public operatorToDelegators;
    mapping(address => mapping(address => Delegator)) public delegations;
    mapping(uint256 => SlashingEvent) public slashingEvents;
    mapping(uint256 => RewardDistribution) public rewardDistributions;
    mapping(address => bool) public authorizedSlashers;
    mapping(address => uint256) public operatorIndex;
    
    address[] public operatorList;
    uint256 public nextSlashingId;
    uint256 public nextRewardId;
    uint256 public totalStaked;
    uint256 public minOperatorStake;
    uint256 public minDelegatorStake;
    uint256 public maxOperators;
    uint256 public slashingDelay;
    uint256 public withdrawalDelay;
    uint256 public operatorCommission; // Basis points (100 = 1%)
    
    IERC20 public stakingToken;
    address public taskManager;
    
    // Events
    event OperatorRegistered(
        address indexed operator,
        string metadataURI,
        uint256 stakedAmount
    );
    
    event OperatorDeregistered(address indexed operator);
    
    event StakeDeposited(
        address indexed operator,
        address indexed delegator,
        uint256 amount
    );
    
    event StakeWithdrawn(
        address indexed operator,
        address indexed delegator,
        uint256 amount
    );
    
    event OperatorSlashed(
        address indexed operator,
        uint256 amount,
        string reason
    );
    
    event RewardsDistributed(
        uint256 indexed rewardId,
        uint256 totalAmount,
        uint256 operatorCount
    );
    
    event OperatorStatusChanged(
        address indexed operator,
        OperatorStatus oldStatus,
        OperatorStatus newStatus
    );

    // Modifiers
    modifier onlyTaskManager() {
        require(msg.sender == taskManager, "Only task manager can call");
        _;
    }
    
    modifier onlyRegisteredOperator() {
        require(operators[msg.sender].isActive, "Not a registered operator");
        _;
    }
    
    modifier onlyAuthorizedSlasher() {
        require(
            authorizedSlashers[msg.sender] || msg.sender == owner(),
            "Not authorized to slash"
        );
        _;
    }

    modifier validOperator(address operator) {
        require(operators[operator].operatorAddress != address(0), "Operator not found");
        _;
    }

    constructor(
        address _stakingToken,
        uint256 _minOperatorStake,
        uint256 _minDelegatorStake,
        uint256 _maxOperators,
        uint256 _slashingDelay,
        uint256 _withdrawalDelay,
        uint256 _operatorCommission
    ) {
        stakingToken = IERC20(_stakingToken);
        minOperatorStake = _minOperatorStake;
        minDelegatorStake = _minDelegatorStake;
        maxOperators = _maxOperators;
        slashingDelay = _slashingDelay;
        withdrawalDelay = _withdrawalDelay;
        operatorCommission = _operatorCommission;
    }

    /**
     * @dev Register as an operator
     */
    function registerOperator(
        string calldata metadataURI,
        address delegationApprover,
        uint256 stakeAmount
    ) external nonReentrant {
        require(operators[msg.sender].operatorAddress == address(0), "Already registered");
        require(operatorList.length < maxOperators, "Max operators reached");
        require(stakeAmount >= minOperatorStake, "Insufficient stake");
        
        // Transfer stake
        require(
            stakingToken.transferFrom(msg.sender, address(this), stakeAmount),
            "Stake transfer failed"
        );

        // Create operator record
        operators[msg.sender] = Operator({
            operatorAddress: msg.sender,
            metadataURI: metadataURI,
            delegationApprover: delegationApprover,
            stakedAmount: stakeAmount,
            totalStake: stakeAmount,
            registrationBlock: block.number,
            lastActivityBlock: block.number,
            taskCount: 0,
            successfulTasks: 0,
            slashCount: 0,
            totalSlashed: 0,
            isActive: true,
            isWhitelisted: false,
            status: OperatorStatus.Registered
        });

        operatorIndex[msg.sender] = operatorList.length;
        operatorList.push(msg.sender);
        totalStaked += stakeAmount;

        emit OperatorRegistered(msg.sender, metadataURI, stakeAmount);
    }

    /**
     * @dev Deregister as an operator
     */
    function deregisterOperator() external nonReentrant onlyRegisteredOperator {
        Operator storage operator = operators[msg.sender];
        require(operator.status != OperatorStatus.Slashed, "Cannot deregister while slashed");
        
        // Return stake to operator
        uint256 stakeToReturn = operator.stakedAmount;
        operator.isActive = false;
        operator.status = OperatorStatus.Inactive;
        totalStaked -= stakeToReturn;

        // Remove from operator list
        uint256 index = operatorIndex[msg.sender];
        uint256 lastIndex = operatorList.length - 1;
        
        if (index != lastIndex) {
            address lastOperator = operatorList[lastIndex];
            operatorList[index] = lastOperator;
            operatorIndex[lastOperator] = index;
        }
        
        operatorList.pop();
        delete operatorIndex[msg.sender];

        // Transfer stake back
        require(
            stakingToken.transfer(msg.sender, stakeToReturn),
            "Stake return failed"
        );

        emit OperatorDeregistered(msg.sender);
    }

    /**
     * @dev Delegate stake to an operator
     */
    function delegateStake(
        address operator,
        uint256 amount
    ) external nonReentrant validOperator(operator) {
        require(amount >= minDelegatorStake, "Insufficient delegation amount");
        require(operators[operator].isActive, "Operator not active");
        
        // Transfer tokens
        require(
            stakingToken.transferFrom(msg.sender, address(this), amount),
            "Delegation transfer failed"
        );

        // Update operator total stake
        operators[operator].totalStake += amount;
        totalStaked += amount;

        // Update or create delegator record
        Delegator storage delegator = delegations[operator][msg.sender];
        if (delegator.delegatorAddress == address(0)) {
            delegator.delegatorAddress = msg.sender;
            delegator.isActive = true;
            operatorToDelegators[operator].push(msg.sender);
        }
        
        delegator.stakedAmount += amount;
        delegator.shares += amount; // Simple 1:1 share ratio for now
        delegator.lastRewardBlock = block.number;

        emit StakeDeposited(operator, msg.sender, amount);
    }

    /**
     * @dev Undelegate stake from an operator
     */
    function undelegateStake(
        address operator,
        uint256 amount
    ) external nonReentrant validOperator(operator) {
        Delegator storage delegator = delegations[operator][msg.sender];
        require(delegator.isActive, "No active delegation");
        require(delegator.stakedAmount >= amount, "Insufficient staked amount");
        
        // Update records
        delegator.stakedAmount -= amount;
        delegator.shares -= amount;
        operators[operator].totalStake -= amount;
        totalStaked -= amount;

        // If no stake left, deactivate delegation
        if (delegator.stakedAmount == 0) {
            delegator.isActive = false;
        }

        // Transfer tokens back
        require(
            stakingToken.transfer(msg.sender, amount),
            "Undelegation transfer failed"
        );

        emit StakeWithdrawn(operator, msg.sender, amount);
    }

    /**
     * @dev Slash an operator for malicious behavior
     */
    function slashOperator(
        address operator,
        uint256 amount,
        string calldata reason
    ) external onlyAuthorizedSlasher validOperator(operator) {
        Operator storage op = operators[operator];
        require(op.isActive, "Operator not active");
        require(amount <= op.totalStake, "Slash amount exceeds stake");

        uint256 slashingId = nextSlashingId++;
        
        // Create slashing event
        slashingEvents[slashingId] = SlashingEvent({
            operator: operator,
            amount: amount,
            timestamp: block.timestamp,
            reason: reason,
            slasher: msg.sender,
            executed: false
        });

        // Execute slashing after delay (for now, immediate)
        _executeSlashing(slashingId);
    }

    /**
     * @dev Internal function to execute slashing
     */
    function _executeSlashing(uint256 slashingId) internal {
        SlashingEvent storage slashing = slashingEvents[slashingId];
        require(!slashing.executed, "Slashing already executed");
        
        Operator storage operator = operators[slashing.operator];
        uint256 slashAmount = slashing.amount;
        
        // Calculate how much to slash from operator vs delegators
        uint256 operatorSlash = slashAmount > operator.stakedAmount 
            ? operator.stakedAmount 
            : slashAmount;
        uint256 delegatorSlash = slashAmount - operatorSlash;
        
        // Slash operator stake
        operator.stakedAmount -= operatorSlash;
        operator.totalStake -= operatorSlash;
        operator.slashCount++;
        operator.totalSlashed += operatorSlash;
        totalStaked -= operatorSlash;
        
        // Slash delegator stakes proportionally
        if (delegatorSlash > 0) {
            address[] memory delegatorAddresses = operatorToDelegators[slashing.operator];
            uint256 totalDelegatorStake = operator.totalStake - operator.stakedAmount;
            
            for (uint256 i = 0; i < delegatorAddresses.length; i++) {
                address delegatorAddr = delegatorAddresses[i];
                Delegator storage delegator = delegations[slashing.operator][delegatorAddr];
                
                if (delegator.isActive && delegator.stakedAmount > 0) {
                    uint256 delegatorSlashAmount = (delegatorSlash * delegator.stakedAmount) / totalDelegatorStake;
                    delegator.stakedAmount -= delegatorSlashAmount;
                    delegator.shares -= delegatorSlashAmount;
                    operator.totalStake -= delegatorSlashAmount;
                    totalStaked -= delegatorSlashAmount;
                }
            }
        }
        
        // Update operator status
        if (operator.stakedAmount < minOperatorStake) {
            operator.isActive = false;
            operator.status = OperatorStatus.Slashed;
        }
        
        slashing.executed = true;
        
        emit OperatorSlashed(slashing.operator, slashAmount, slashing.reason);
    }

    /**
     * @dev Distribute rewards to operators and delegators
     */
    function distributeRewards(uint256 totalRewardAmount) external onlyTaskManager {
        require(totalRewardAmount > 0, "No rewards to distribute");
        require(operatorList.length > 0, "No operators to reward");
        
        // Transfer rewards to contract
        require(
            stakingToken.transferFrom(msg.sender, address(this), totalRewardAmount),
            "Reward transfer failed"
        );
        
        uint256 rewardId = nextRewardId++;
        RewardDistribution storage distribution = rewardDistributions[rewardId];
        distribution.totalRewards = totalRewardAmount;
        distribution.distributionBlock = block.number;
        
        // Calculate rewards per operator based on performance
        uint256 activeOperators = 0;
        for (uint256 i = 0; i < operatorList.length; i++) {
            if (operators[operatorList[i]].isActive) {
                activeOperators++;
            }
        }
        
        uint256 baseRewardPerOperator = totalRewardAmount / activeOperators;
        
        // Distribute rewards
        for (uint256 i = 0; i < operatorList.length; i++) {
            address operatorAddr = operatorList[i];
            Operator storage operator = operators[operatorAddr];
            
            if (operator.isActive) {
                // Calculate operator commission
                uint256 operatorReward = (baseRewardPerOperator * operatorCommission) / 10000;
                uint256 delegatorReward = baseRewardPerOperator - operatorReward;
                
                // Add to operator stake
                operator.stakedAmount += operatorReward;
                operator.totalStake += operatorReward;
                totalStaked += operatorReward;
                
                // Distribute to delegators proportionally
                if (delegatorReward > 0) {
                    address[] memory delegatorAddresses = operatorToDelegators[operatorAddr];
                    uint256 totalDelegatorStake = operator.totalStake - operator.stakedAmount;
                    
                    for (uint256 j = 0; j < delegatorAddresses.length; j++) {
                        address delegatorAddr = delegatorAddresses[j];
                        Delegator storage delegator = delegations[operatorAddr][delegatorAddr];
                        
                        if (delegator.isActive && delegator.stakedAmount > 0) {
                            uint256 delegatorRewardAmount = (delegatorReward * delegator.stakedAmount) / totalDelegatorStake;
                            delegator.stakedAmount += delegatorRewardAmount;
                            delegator.shares += delegatorRewardAmount;
                            operator.totalStake += delegatorRewardAmount;
                            totalStaked += delegatorRewardAmount;
                        }
                    }
                }
            }
        }
        
        emit RewardsDistributed(rewardId, totalRewardAmount, activeOperators);
    }

    /**
     * @dev Update operator activity (called by task manager)
     */
    function updateOperatorActivity(
        address operator,
        bool successful
    ) external onlyTaskManager validOperator(operator) {
        Operator storage op = operators[operator];
        op.lastActivityBlock = block.number;
        op.taskCount++;
        
        if (successful) {
            op.successfulTasks++;
        }
        
        // Activate operator if they were just registered
        if (op.status == OperatorStatus.Registered) {
            op.status = OperatorStatus.Active;
            emit OperatorStatusChanged(operator, OperatorStatus.Registered, OperatorStatus.Active);
        }
    }

    /**
     * @dev Get operator information
     */
    function getOperator(address operator) external view returns (Operator memory) {
        return operators[operator];
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
     * @dev Get operator delegators
     */
    function getOperatorDelegators(address operator) external view returns (address[] memory) {
        return operatorToDelegators[operator];
    }

    /**
     * @dev Get delegation info
     */
    function getDelegation(
        address operator,
        address delegator
    ) external view returns (Delegator memory) {
        return delegations[operator][delegator];
    }

    /**
     * @dev Set task manager address
     */
    function setTaskManager(address _taskManager) external onlyOwner {
        taskManager = _taskManager;
    }

    /**
     * @dev Authorize slasher
     */
    function authorizeSlasher(address slasher) external onlyOwner {
        authorizedSlashers[slasher] = true;
    }

    /**
     * @dev Revoke slasher authorization
     */
    function revokeSlasher(address slasher) external onlyOwner {
        authorizedSlashers[slasher] = false;
    }

    /**
     * @dev Update system parameters
     */
    function updateParameters(
        uint256 _minOperatorStake,
        uint256 _minDelegatorStake,
        uint256 _maxOperators,
        uint256 _slashingDelay,
        uint256 _withdrawalDelay,
        uint256 _operatorCommission
    ) external onlyOwner {
        minOperatorStake = _minOperatorStake;
        minDelegatorStake = _minDelegatorStake;
        maxOperators = _maxOperators;
        slashingDelay = _slashingDelay;
        withdrawalDelay = _withdrawalDelay;
        operatorCommission = _operatorCommission;
    }

    /**
     * @dev Emergency functions
     */
    function pauseOperator(address operator) external onlyOwner {
        operators[operator].isActive = false;
        operators[operator].status = OperatorStatus.Inactive;
    }

    function unpauseOperator(address operator) external onlyOwner {
        require(operators[operator].stakedAmount >= minOperatorStake, "Insufficient stake");
        operators[operator].isActive = true;
        operators[operator].status = OperatorStatus.Active;
    }

    /**
     * @dev Get total number of operators
     */
    function getTotalOperators() external view returns (uint256) {
        return operatorList.length;
    }

    /**
     * @dev Get registry statistics
     */
    function getRegistryStats() external view returns (
        uint256 totalOperators,
        uint256 activeOperators,
        uint256 totalStakeAmount,
        uint256 totalSlashingEvents
    ) {
        totalOperators = operatorList.length;
        totalStakeAmount = totalStaked;
        totalSlashingEvents = nextSlashingId;
        
        for (uint256 i = 0; i < operatorList.length; i++) {
            if (operators[operatorList[i]].isActive) {
                activeOperators++;
            }
        }
    }
}