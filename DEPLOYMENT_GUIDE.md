# ERC-8004 Jan 2026 Update - Deployment Guide

This guide explains how to deploy the ERC-8004 contracts with deterministic addresses across multiple chains.

## Prerequisites

1. **Foundry** installed and up to date
   ```bash
   foundryup
   ```

2. **Private Key** with sufficient funds on target networks
   - Ethereum Sepolia: Get testnet ETH from [Sepolia Faucet](https://sepoliafaucet.com/)
   - Base Sepolia: Get testnet ETH from [Base Sepolia Faucet](https://bridge.base.org/deposit)

3. **API Keys** for contract verification
   - Etherscan: Get from [etherscan.io/myapikey](https://etherscan.io/myapikey)
   - Basescan: Get from [basescan.org/myapikey](https://basescan.org/myapikey)

## Setup

1. Copy the environment template:
   ```bash
   cp env.example .env
   ```

2. Edit `.env` and add your credentials:
   ```bash
   PRIVATE_KEY=your_private_key_without_0x_prefix
   ETHERSCAN_API_KEY=your_etherscan_api_key
   BASESCAN_API_KEY=your_basescan_api_key
   ```

   **Important**: Never commit the `.env` file to git!

## Deployment

### Option 1: Automated Deployment (Recommended)

Deploy to both Ethereum Sepolia and Base Sepolia with one command:

```bash
./scripts/deploy-deterministic.sh
```

This script will:
- Deploy to Ethereum Sepolia
- Verify contracts on Etherscan
- Deploy to Base Sepolia
- Verify contracts on Basescan

### Option 2: Manual Deployment

Deploy to specific networks manually:

#### Ethereum Sepolia

```bash
forge script script/DeployDeterministic.s.sol:DeployDeterministic \
    --rpc-url https://rpc.sepolia.org \
    --broadcast \
    --verify \
    --etherscan-api-key $ETHERSCAN_API_KEY \
    -vvv
```

#### Base Sepolia

```bash
forge script script/DeployDeterministic.s.sol:DeployDeterministic \
    --rpc-url https://sepolia.base.org \
    --broadcast \
    --verify \
    --etherscan-api-key $BASESCAN_API_KEY \
    --verifier-url "https://api-sepolia.basescan.org/api" \
    -vvv
```

## Deterministic Addresses

The deployment uses CREATE2 with a fixed salt, ensuring the same addresses across all chains when deployed from the same deployer address.

### Current Deployment (Jan 2026 Update)

**Deployer Address**: TBD after deployment
**Salt**: `keccak256("ERC8004_JAN2026_UPDATE_V1")`

Expected addresses (will be confirmed after deployment):
- **IdentityRegistry**: TBD
- **ReputationRegistry**: TBD
- **ValidationRegistry**: TBD

These addresses will be the same on:
- ✅ Ethereum Sepolia
- ✅ Base Sepolia

## Post-Deployment

After successful deployment:

1. **Update `deployments.json`** with new addresses
2. **Update `README.md`** with deployment information
3. **Test the contracts** using the test suite:
   ```bash
   forge test -vvv
   ```
4. **Verify contracts** are live on block explorers

## Verification

Contracts should be automatically verified during deployment. If manual verification is needed:

```bash
# Ethereum Sepolia
forge verify-contract <ADDRESS> \
    src/IdentityRegistry.sol:IdentityRegistry \
    --chain sepolia \
    --etherscan-api-key $ETHERSCAN_API_KEY

# Base Sepolia
forge verify-contract <ADDRESS> \
    src/IdentityRegistry.sol:IdentityRegistry \
    --chain base-sepolia \
    --etherscan-api-key $BASESCAN_API_KEY \
    --verifier-url "https://api-sepolia.basescan.org/api"
```

For ReputationRegistry and ValidationRegistry, add constructor arguments:

```bash
forge verify-contract <ADDRESS> \
    src/ReputationRegistry.sol:ReputationRegistry \
    --constructor-args $(cast abi-encode "constructor(address)" <IDENTITY_REGISTRY_ADDRESS>) \
    --chain sepolia \
    --etherscan-api-key $ETHERSCAN_API_KEY
```

## Troubleshooting

### "Insufficient funds" error
- Ensure your deployer address has enough testnet ETH
- Check balance: `cast balance <YOUR_ADDRESS> --rpc-url <RPC_URL>`

### "Verification failed" error
- Wait a few minutes and try manual verification
- Ensure you're using the correct API key for the network
- Check that the contract bytecode matches

### "Nonce too high" error
- Someone else may have deployed from your address
- Check the nonce: `cast nonce <YOUR_ADDRESS> --rpc-url <RPC_URL>`
- Consider using a fresh deployer address

## Security Notes

1. **Private Key Security**: Never share or commit your private key
2. **Test First**: Always test on testnets before mainnet deployment
3. **Verify Source Code**: Always verify contracts on block explorers
4. **Gas Estimation**: Check gas prices before deploying to mainnet

## Support

For issues or questions:
- Open an issue on [GitHub](https://github.com/ChaosChain-Labs/trustless-agents-erc-ri)
- Review the [Security Assessment](SECURITY_ASSESSMENT.md)
- Check the [Spec Compliance](SPEC_COMPLIANCE_VERIFICATION.md)

## License

CC0-1.0 License - See [LICENSE](LICENSE) for details
