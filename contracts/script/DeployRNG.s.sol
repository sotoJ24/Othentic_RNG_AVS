// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "../lib/forge-std/src/Script.sol";
import {RNGRegistry} from "../src/RNGRegistry.sol";
import {RNGTaskManager} from "../src/RNGTaskManager.sol";
import {console} from "../lib/forge-std/src/console.sol";

/**
 * @title DeployRNG
 * @dev Foundry script for deploying RNGRegistry and RNGTaskManager
 */
contract DeployRNG is Script {
    function run() external returns (RNGRegistry registry, RNGTaskManager taskManager) {
        // Start broadcasting transactions from the deployer's address
        // This will use the private key provided via --private-key or $PRIVATE_KEY env var
        vm.startBroadcast();

        // --- 1. Deploy RNGRegistry ---
        // Arguments for RNGRegistry constructor:
        // address _stakingToken,
        // uint256 _minOperatorStake,
        // uint256 _minDelegatorStake,
        // uint256 _maxOperators,
        // uint256 _slashingDelay,
        // uint256 _withdrawalDelay,
        // uint256 _operatorCommission


        address STAKING_TOKEN_ADDRESS = 0x0000000000000000000000000000000000000001; 
        uint256 MIN_OPERATOR_STAKE = 1 ether;
        uint256 MIN_DELEGATOR_STAKE = 0.1 ether;
        uint256 MAX_OPERATORS = 100;
        uint256 SLASHING_DELAY = 100; 
        uint256 WITHDRAWAL_DELAY = 200; 
        uint256 OPERATOR_COMMISSION = 1000; 

        registry = new RNGRegistry(
            STAKING_TOKEN_ADDRESS,
            MIN_OPERATOR_STAKE,
            MIN_DELEGATOR_STAKE,
            MAX_OPERATORS,
            SLASHING_DELAY,
            WITHDRAWAL_DELAY,
            OPERATOR_COMMISSION
        );

        console.log("RNGRegistry deployed at:", address(registry));

        // --- 2. Deploy RNGTaskManager ---
        // Arguments for RNGTaskManager constructor:
        // uint256 _minStake,
        // uint256 _taskFee,
        // uint256 _slashAmount,
        // uint256 _maxTasksPerBlock,
        // uint256 _taskTimeout

        uint256 TASK_MANAGER_MIN_STAKE = 1 ether;
        uint256 TASK_MANAGER_TASK_FEE = 0.01 ether;
        uint256 TASK_MANAGER_SLASH_AMOUNT = 0.5 ether;
        uint256 TASK_MANAGER_MAX_TASKS_PER_BLOCK = 10;
        uint256 TASK_MANAGER_TASK_TIMEOUT = 300; // in seconds

        taskManager = new RNGTaskManager(
            TASK_MANAGER_MIN_STAKE,
            TASK_MANAGER_TASK_FEE,
            TASK_MANAGER_SLASH_AMOUNT,
            TASK_MANAGER_MAX_TASKS_PER_BLOCK,
            TASK_MANAGER_TASK_TIMEOUT
        );

        console.log("RNGTaskManager deployed at:", address(taskManager));

        // Stop broadcasting transactions
        vm.stopBroadcast();
    }
}
