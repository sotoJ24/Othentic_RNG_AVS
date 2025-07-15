#!/bin/bash

# Load environment variables from .env.example (or a proper .env file)
# Make sure to fill these in your .env or set them directly in your shell
# Example: export RPC_URL="http://localhost:8545"
# Example: export PRIVATE_KEY="0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
# Example: export RNG_REGISTRY_ADDRESS="0x5FbDB2315678afecb367f032d93F642f64180aa3" # From your DeployRNG.s.sol output
# Example: export STAKING_TOKEN_ADDRESS="0x0000000000000000000000000000000000000001" # From your DeployRNG.s.sol

# Check if required environment variables are set
if [ -z "$RPC_URL" ] || [ -z "$PRIVATE_KEY" ] || [ -z "$RNG_REGISTRY_ADDRESS" ] || [ -z "$STAKING_TOKEN_ADDRESS" ]; then
  echo "Error: Missing required environment variables (RPC_URL, PRIVATE_KEY, RNG_REGISTRY_ADDRESS, STAKING_TOKEN_ADDRESS)."
  echo "Please set them in your shell or in a .env file."
  exit 1
fi

echo "--- Registering Operator ---"
echo "RPC URL: $RPC_URL"
echo "RNG Registry Address: $RNG_REGISTRY_ADDRESS"
echo "Staking Token Address: $STAKING_TOKEN_ADDRESS"

# --- Operator Parameters ---
# These should match the requirements of your RNGRegistry contract's registerOperator function
METADATA_URI="ipfs://QmVyGvF3GvF3GvF3GvF3GvF3GvF3GvF3GvF3GvF3GvF3Gv" # Example IPFS URI
DELEGATION_APPROVER="0x0000000000000000000000000000000000000000" # Example: address(0) if not used, or a specific address
STAKE_AMOUNT="1000000000000000000" # 1 token (1 ether in wei) - must be >= minOperatorStake in RNGRegistry

# --- Step 1: Approve the RNGRegistry to spend staking tokens ---
# The operator needs to approve the RNGRegistry contract to pull the stakeAmount from their wallet.
echo "Approving RNGRegistry to spend $STAKE_AMOUNT wei of staking token..."
cast send \
  --rpc-url "$RPC_URL" \
  --private-key "$PRIVATE_KEY" \
  "$STAKING_TOKEN_ADDRESS" \
  "approve(address,uint256)" \
  "$RNG_REGISTRY_ADDRESS" \
  "$STAKE_AMOUNT" \
  --json # Output as JSON for easier parsing if needed, or remove for simpler output

echo "Approval transaction sent. Waiting for confirmation..."
# You might want to add a sleep or a check for transaction confirmation here in a real script.

# --- Step 2: Call registerOperator on RNGRegistry ---
echo "Calling registerOperator on RNGRegistry..."
cast send \
  --rpc-url "$RPC_URL" \
  --private-key "$PRIVATE_KEY" \
  "$RNG_REGISTRY_ADDRESS" \
  "registerOperator(string,address,uint256)" \
  "$METADATA_URI" \
  "$DELEGATION_APPROVER" \
  "$STAKE_AMOUNT" \
  --json # Output as JSON for easier parsing if needed, or remove for simpler output

echo "Register operator transaction sent. Check blockchain explorer for status."
echo "--- Operator Registration Complete ---"
