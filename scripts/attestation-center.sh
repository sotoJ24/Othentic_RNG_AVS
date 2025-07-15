#!/bin/bash

# attestation-center.sh
# This script simulates an attestation center submitting a task.
# In this simplified backend-only Rust example, the operator performs
# the full attestation cycle (generate, salt, sign) upon execution.
# Therefore, running the operator binary simulates a task submission.

OPERATOR_DIR="$(dirname "$0")/operator" # Assumes script is run from project root or similar

echo "--- Attestation Center: Submitting RNG Task ---"
echo "Simulating a request for a new attested random number."

# Navigate to the operator directory
if [ -d "$OPERATOR_DIR" ]; then
    echo "Navigating to operator directory: $OPERATOR_DIR"
    cd "$OPERATOR_DIR" || { echo "Failed to change directory to $OPERATOR_DIR"; exit 1; }
else
    echo "Error: Operator directory '$OPERATOR_DIR' not found."
    exit 1
fi

# Run the compiled operator binary to generate and attest a random number.
# In a real setup, this would be an RPC call to a running operator service.
echo "Executing operator to perform attestation task..."
cargo run --release

echo "Attestation task simulation completed."
echo "------------------------------------------"
