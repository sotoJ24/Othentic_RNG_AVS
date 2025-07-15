
    mod performer;
    mod attester;

    use performer::RngPerformer;
    use attester::RngAttester;

    use hex;

    fn main() -> Result<(), String> {
        println!("Starting RNG Operator (Rust Backend)...");

     
        let rng_performer = RngPerformer::new();
        println!("RNG Performer initialized.");

 
        let rng_attester = RngAttester::new()
            .map_err(|e| format!("Failed to initialize RNG Attester: {}", e))?;
        println!("RNG Attester initialized and key pair generated.");

        let public_key = rng_attester.get_public_key();
        println!("Attester's Public Key (hex): {}", hex::encode(public_key.to_bytes()));

   
        let random_number_length = 32; // Bytes
        let raw_random_number = rng_performer.generate_random_number(random_number_length)
            .map_err(|e| format!("Failed to generate random number: {}", e))?;
        println!("\nGenerated Raw Random Number (hex): {}", hex::encode(&raw_random_number));

      
        let (_original_random_number, salt, signature) = rng_attester.attest(&raw_random_number)
            .map_err(|e| format!("Failed to attest to random number: {}", e))?;

        println!("Generated Salt (hex): {}", hex::encode(&salt));
        println!("Generated Signature (hex): {}", hex::encode(signature.to_bytes()));


        println!("\nAttempting to verify attestation...");
        match RngAttester::verify_attestation(public_key, &raw_random_number, &salt, &signature) {
            Ok(()) => {
                println!("Verification Result: SUCCESS!");
                println!("Attestation successfully verified! The random number and salt are authentic.");
            }
            Err(e) => {
                println!("Verification Result: FAILED!");
                println!("Attestation verification FAILED! {}", e);
                return Err(e); 
            }
        }

        println!("\nRNG Operator finished successfully.");
        Ok(()) 
    }
    