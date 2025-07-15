use ed25519_dalek::{
    Signature, Signer, Verifier, 
    SigningKey, VerifyingKey,   
};

use rand::rngs::OsRng; 
use rand::RngCore; 
use sha2::{Sha256, Digest}; 


pub struct RngAttester {
    signing_key: SigningKey, 
    verifying_key: VerifyingKey, 
}

impl RngAttester {

    pub fn new() -> Result<Self, String> {
        let mut csprng = OsRng; 

    
        let signing_key = SigningKey::generate(&mut csprng);
        let verifying_key = (&signing_key).verifying_key(); 

        Ok(RngAttester {
            signing_key,
            verifying_key,
        })
    }

    pub fn attest(
        &self,
        random_number: &[u8],
    ) -> Result<(Vec<u8>, Vec<u8>, Signature), String> {

        let mut salt = vec![0u8; 32];
        let mut csprng = OsRng;
        csprng.fill_bytes(&mut salt); 


        let mut data_to_hash = Vec::with_capacity(random_number.len() + salt.len());
        data_to_hash.extend_from_slice(random_number);
        data_to_hash.extend_from_slice(&salt);

        let hashed_data = Sha256::digest(&data_to_hash);

        let signature = self.signing_key.sign(&hashed_data);

        Ok((random_number.to_vec(), salt, signature))
    }

    pub fn get_public_key(&self) -> &VerifyingKey {
        &self.verifying_key
    }


    pub fn verify_attestation(
        public_key: &VerifyingKey,
        random_number: &[u8],
        salt: &[u8],
        signature: &Signature,
    ) -> Result<(), String> {
    
        let mut data_to_verify_hash = Vec::with_capacity(random_number.len() + salt.len());
        data_to_verify_hash.extend_from_slice(random_number);
        data_to_verify_hash.extend_from_slice(salt);

        let hashed_data_to_verify = Sha256::digest(&data_to_verify_hash);

        public_key.verify(&hashed_data_to_verify, signature)
            .map_err(|e| format!("Signature verification failed: {}", e))
    }
}

impl Default for RngAttester {
    fn default() -> Self {
        Self::new().expect("Failed to create default RngAttester")
    }
}
