# Othentic - Use Case Random Number Generator AVS
A cryptographically secure random number generator built on the Othentic Stack, providing verifiable randomness for blockchain applications through decentralized task performers and attesters.

## 🎯 Overview

This AVS implements a trustless random number generation system where:
- **Task Performers** generate initial random numbers using secure entropy sources
- **Attesters** add random salts and cryptographically sign the results  
- **BLS Signature Aggregation** combines multiple signatures into verifiable randomness
- **Destruction Mechanism** ensures forward security after use

## 🏗️ Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Task Request  │───▶│ Task Performers │───▶│   Attesters     │
│   (via API)     │    │ (Generate RNG)  │    │ (Add Salt+Sign) │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                                        │
                                                        ▼
                                               ┌─────────────────┐
                                               │ BLS Aggregation │
                                               │ & On-chain Post │
                                               └─────────────────┘
```

## 📁 Repository Structure

```
othentic-rng-avs/
├── contracts/                    # Smart contracts
│   ├── src/
│   │   ├── RNGTaskManager.sol   # Main task management
│   │   ├── RNGRegistry.sol      # Operator registration
│   │   └── interfaces/
│   │       └── IRNGTaskManager.sol
│   ├── script/
│   │   └── DeployRNG.s.sol      # Deployment script
│   ├── test/
│   │   └── RNGTaskManager.t.sol # Contract tests
│   └── foundry.toml             # Foundry config
├── operator/                     # Operator implementation
│   ├── src/
│   │   ├── main.go              # Main operator logic
│   │   ├── performer/
│   │   │   └── rng_performer.go # Task performer
│   │   ├── attester/
│   │   │   └── rng_attester.go  # Attester logic
│   │   └── utils/
│   │       └── entropy.go       # Entropy generation
│   ├── config/
│   │   └── config.yaml          # Operator configuration
│   └── go.mod
├── attestation-center/           # Attestation Center integration
│   ├── submit-task.js           # Task submission script
│   ├── verify-result.js         # Result verification
│   └── package.json
├── api/                         # Public API for RNG requests
│   ├── server.js                # Express server
│   ├── routes/
│   │   └── rng.js               # RNG endpoints
│   └── package.json
├── scripts/                     # Deployment & setup scripts
│   ├── deploy.sh                # Full deployment script
│   ├── register-operator.sh     # Operator registration
│   └── setup-env.sh             # Environment setup
├── docs/                        # Documentation
│   ├── OPERATOR_GUIDE.md        # How to run an operator
│   ├── API_REFERENCE.md         # API documentation
│   └── ARCHITECTURE.md          # Technical architecture
├── .env.example                 # Environment variables template
├── docker-compose.yml           # Docker setup
└── README.md                    # This file
```

## 🚀 Quick Start

### Prerequisites
- Node.js 18+
- Go 1.21+
- Foundry
- Docker (optional)

### 1. Clone and Setup
```bash
git clone https://github.com/your-username/othentic-rng-avs.git
cd othentic-rng-avs
cp .env.example .env
# Edit .env with your configuration
./scripts/setup-env.sh
```

### 2. Deploy Contracts
```bash
cd contracts
forge build
forge script script/DeployRNG.s.sol --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast
```

### 3. Register Operator
```bash
./scripts/register-operator.sh
```

### 4. Start Operator
```bash
cd operator
go run src/main.go
```

### 5. Submit Task via Attestation Center
```bash
cd attestation-center
node submit-task.js
```

## 📋 Contract Deployment Checklist

- [ ] Deploy RNGTaskManager contract
- [ ] Deploy RNGRegistry contract  
- [ ] Verify contracts on block explorer
- [ ] Configure task parameters
- [ ] Set up operator whitelist (if needed)

## 👥 Operator Registration Checklist

- [ ] Generate operator keypair
- [ ] Stake required tokens
- [ ] Register with RNGRegistry
- [ ] Configure operator node
- [ ] Start performer and attester services
- [ ] Verify operator is active

## 🎯 Task Submission Checklist

- [ ] Connect to Attestation Center
- [ ] Submit RNG generation task
- [ ] Verify task acceptance
- [ ] Monitor task execution
- [ ] Retrieve and verify results

## 🔧 Configuration

### Environment Variables
```env
# Network Configuration
RPC_URL=https://your-rpc-endpoint
CHAIN_ID=1337
PRIVATE_KEY=0x...

# Contract Addresses (set after deployment)
RNG_TASK_MANAGER=0x...
RNG_REGISTRY=0x...

# Operator Configuration
OPERATOR_ADDRESS=0x...
OPERATOR_PRIVATE_KEY=0x...

# Attestation Center
ATTESTATION_CENTER_URL=https://attestation-center.othentic.xyz
ATTESTATION_CENTER_API_KEY=your-api-key
```

### Operator Config (config/config.yaml)
```yaml
operator:
  address: "0x..."
  private_key: "0x..."
  
network:
  rpc_url: "https://your-rpc-endpoint"
  chain_id: 1337
  
contracts:
  task_manager: "0x..."
  registry: "0x..."
  
performance:
  task_interval: "30s"
  batch_size: 10
  
entropy:
  sources:
    - "hardware"
    - "atmospheric"
    - "blockchain"
```

## 🛠️ Development

### Run Tests
```bash
# Contract tests
cd contracts && forge test

# Operator tests  
cd operator && go test ./...

# Integration tests
npm test
```

### Local Development
```bash
# Start local environment
docker-compose up -d

# Deploy to local network
./scripts/deploy.sh --network local

# Register local operator
./scripts/register-operator.sh --network local
```

## 📊 Monitoring

### Operator Health
- Monitor operator uptime and performance
- Track task completion rates
- Monitor slashing events

### System Metrics
- Random number generation rate
- Response time latency
- Network participation

## 🔐 Security Considerations

### Entropy Sources
- Hardware RNG integration
- Atmospheric noise APIs
- Blockchain-based entropy
- Multiple source aggregation

### Cryptographic Security
- BLS signature verification
- Secure key management
- Forward security mechanisms
- Signature destruction protocols

## 📝 API Reference

### Generate Random Number
```bash
POST /api/v1/rng/generate
{
  "min": 1,
  "max": 100,
  "count": 1,
  "callback_url": "https://your-app.com/callback"
}
```

### Get Random Number Status
```bash
GET /api/v1/rng/status/{request_id}
```

### Verify Random Number
```bash
POST /api/v1/rng/verify
{
  "request_id": "uuid",
  "random_number": 42,
  "proof": "0x..."
}
```

## 🚀 Deployment Guide

### Production Deployment
1. **Deploy Contracts**
   ```bash
   ./scripts/deploy.sh --network mainnet
   ```

2. **Register Operators**
   ```bash
   ./scripts/register-operator.sh --network mainnet
   ```

3. **Submit Test Task**
   ```bash
   cd attestation-center
   node submit-task.js --network mainnet
   ```

4. **Verify System**
   ```bash
   node verify-result.js --task-id $TASK_ID
   ```

## 📚 Documentation

- [Operator Guide](docs/OPERATOR_GUIDE.md) - How to run an operator
- [API Reference](docs/API_REFERENCE.md) - Complete API documentation  
- [Architecture](docs/ARCHITECTURE.md) - Technical architecture details

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

## 📜 License

MIT License - see [LICENSE](LICENSE) for details

## 🆘 Support

- [Discord](https://discord.gg/othentic)
- [Documentation](https://docs.othentic.xyz)
- [Issues](https://github.com/your-username/othentic-rng-avs/issues)

## 🎉 Acknowledgments

Built with ❤️ using the [Othentic Stack](https://othentic.xyz)

---

**Status**: ✅ Contracts Deployed | ✅ Operator Registered | ✅ Task Submitted via Attestation Center
