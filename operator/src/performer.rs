// src/performer.rs

//! This module provides the `RngPerformer` responsible for generating
//! cryptographically secure random numbers.

use rand::RngCore; // Only RngCore is needed here
use rand::rngs::OsRng; // Operating system's cryptographically secure random number generator

/// `RngPerformer` is a struct that encapsulates the random number generation logic.
/// It currently holds no state, but could be extended for configuration (e.g., specific RNG source).
pub struct RngPerformer {
    // In a more complex scenario, this could hold configurations
    // like a specific RNG instance or default random number size.
}

impl RngPerformer {
    /// Creates a new instance of `RngPerformer`.
    ///
    /// # Returns
    /// A new `RngPerformer` instance.
    pub fn new() -> Self {
        RngPerformer {}
    }

    /// Generates a cryptographically secure random byte vector of the specified length.
    ///
    /// It uses `OsRng`, which is the operating system's cryptographically secure
    /// random number generator, suitable for security-sensitive applications.
    ///
    /// # Arguments
    /// * `length` - The desired length of the random byte vector.
    ///
    /// # Returns
    /// A `Result` containing:
    /// - `Ok(Vec<u8>)` if the random number was generated successfully.
    /// - `Err(String)` if an error occurred during generation (e.g., `OsRng` failure).
    pub fn generate_random_number(&self, length: usize) -> Result<Vec<u8>, String> {
        if length == 0 {
            return Err("Length must be a positive integer.".to_string());
        }

        let mut random_bytes = vec![0u8; length]; // Create a vector of zeros of the desired length
        let mut rng = OsRng; // Initialize the OS random number generator

        // Fill the vector with cryptographically secure random bytes.
        // `fill_bytes` returns a Result indicating success or failure.
        rng.fill_bytes(&mut random_bytes);

        // In real-world scenarios, `fill_bytes` can return an error,
        // but for `OsRng`, it typically panics on unrecoverable errors.
        // For robustness, we'll return Ok, assuming fill_bytes succeeded.
        // If there was an underlying OS error, it would likely panic before this point.

        Ok(random_bytes)
    }
}

// Default implementation for `RngPerformer` to allow `RngPerformer::default()`
impl Default for RngPerformer {
    fn default() -> Self {
        Self::new()
    }
}
