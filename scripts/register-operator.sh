#!/bin/bash

# register-operator.sh
# This script "deploys" (runs) the Rust RNG operator backend.
# In a real AVS, this might also involve an on-chain registration
# transaction to an Operator Registry smart contract.

OPERATOR_DIR="$(dirname "$0")/operator" # Assumes script is run from project root or similar

echo "--- Registering/Deploying RNG Operator Backend ---"

# Navigate to the operator directory
if [ -d "$OPERATOR_DIR" ]; then
    echo "Navigating to operator directory: $OPERATOR_DIR"
    cd "$OPERATOR_DIR" || { echo "Failed to change directory to $OPERATOR_DIR"; exit 1; }
else
    echo "Error: Operator directory '$OPERATOR_DIR' not found."
    exit 1
fi

# Build the Rust operator in release mode for performance
echo "Building Rust operator..."
cargo build --release || { echo "Rust operator build failed!"; exit 1; }
echo "Rust operator built successfully."

# Run the compiled operator binary
# In a production environment, you would typically use a process manager (e.g., systemd, supervisor)
# to keep this running reliably in the background.
echo "Running RNG operator..."
# Using `exec` replaces the current shell process with the Rust program,
# which is suitable for a long-running service.
# For a simple run-and-exit, just `cargo run --release` is fine.
# We'll use `cargo run --release` for simplicity in this example,
# as the current Rust app runs and exits after one attestation cycle.
cargo run --release

echo "RNG Operator execution finished."
echo "------------------------------------------"
