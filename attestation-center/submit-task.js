require('dotenv').config({ path: '../.env' }); 

const { ethers } = require('ethers');


const RPC_URL = process.env.RPC_URL || 'http://localhost:8545';
const PRIVATE_KEY = process.env.PRIVATE_KEY; 
const RNG_TASK_MANAGER_ADDRESS = process.env.RNG_TASK_MANAGER_ADDRESS;

const RNG_TASK_MANAGER_ABI = [
  "function createTask(uint256 minValue, uint256 maxValue, uint256 count, string callbackUrl) payable returns (uint256)",
  "event TaskCreated(uint256 indexed taskId, address indexed requester, uint256 minValue, uint256 maxValue, uint256 count)"
];


const MIN_VALUE = 1;
const MAX_VALUE = 100;
const COUNT = 5; 
const CALLBACK_URL = "https://your-callback-url.com/rng-result"; 
const TASK_FEE = ethers.parseEther("0.01"); 
async function submitRNGTask() {
  if (!PRIVATE_KEY) {
    console.error("Error: PRIVATE_KEY not set in .env. Please provide the private key of the task requester.");
    return;
  }
  if (!RNG_TASK_MANAGER_ADDRESS) {
    console.error("Error: RNG_TASK_MANAGER_ADDRESS not set in .env. Please provide the address of your deployed RNGTaskManager contract.");
    return;
  }

  try {

    const provider = new ethers.JsonRpcProvider(RPC_URL);
    console.log(`Connected to RPC: ${RPC_URL}`);

    const wallet = new ethers.Wallet(PRIVATE_KEY, provider);
    const signerAddress = await wallet.getAddress();
    console.log(`Sending task from account: ${signerAddress}`);


    const taskManager = new ethers.Contract(RNG_TASK_MANAGER_ADDRESS, RNG_TASK_MANAGER_ABI, wallet);
    console.log(`Interacting with RNGTaskManager at: ${RNG_TASK_MANAGER_ADDRESS}`);

    console.log(`Submitting RNG task with fee: ${ethers.formatEther(TASK_FEE)} ETH...`);
    const tx = await taskManager.createTask(MIN_VALUE, MAX_VALUE, COUNT, CALLBACK_URL, {
      value: TASK_FEE 
    });

    console.log(`Transaction sent: ${tx.hash}`);
    console.log("Waiting for transaction to be mined...");

    const receipt = await tx.wait(); 
    console.log("Transaction confirmed!");
    console.log("Receipt:", receipt);

    const iface = new ethers.Interface(RNG_TASK_MANAGER_ABI);
    for (const log of receipt.logs) {
      try {
        const parsedLog = iface.parseLog(log);
        if (parsedLog && parsedLog.name === "TaskCreated") {
          const taskId = parsedLog.args.taskId.toString();
          console.log(`🎉 TaskCreated Event: Task ID ${taskId}`);
          console.log(`   Requester: ${parsedLog.args.requester}`);
          console.log(`   Min Value: ${parsedLog.args.minValue}`);
          console.log(`   Max Value: ${parsedLog.args.maxValue}`);
          console.log(`   Count: ${parsedLog.args.count}`);
          break; 
        }
      } catch (e) {
  
      }
    }

  } catch (error) {
    console.error("Error submitting RNG task:", error);
    if (error.code === 'CALL_EXCEPTION' && error.data) {

      try {
        const revertReason = ethers.AbiCoder.defaultAbiCoder().decode(['string'], error.data)[0];
        console.error("Contract Revert Reason:", revertReason);
      } catch (decodeError) {
        console.error("Could not decode revert reason.");
      }
    }
  }
}

submitRNGTask();
