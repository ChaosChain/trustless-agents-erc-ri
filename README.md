# ERC-8004 Trustless Agents Reference Implementation

[![License: CC0-1.0](https://img.shields.io/badge/License-CC0_1.0-lightgrey.svg)](http://creativecommons.org/publicdomain/zero/1.0/)
[![Solidity](https://img.shields.io/badge/Solidity-0.8.19-blue)](https://soliditylang.org)
[![Tests](https://img.shields.io/badge/Tests-67%2F67%20Passing-brightgreen)](https://github.com/ChaosChain/trustless-agents-erc-ri)
[![Deployed](https://img.shields.io/badge/Deployed-2%20Testnets-success)](https://github.com/ChaosChain/trustless-agents-erc-ri#deployed-contracts)
[![Security](https://img.shields.io/badge/Security-8.5%2F10-green)](./SECURITY_ASSESSMENT.md)

Reference implementation for **[ERC-8004: Trustless Agents](https://eips.ethereum.org/EIPS/eip-8004)** (Jan 2026 Update) - a protocol enabling participants to discover, choose, and interact with AI agents across organizational boundaries without pre-existing trust.

>  **Testnet Ready!** Jan 2026 Update deployed to **Ethereum Sepolia** and **Base Sepolia**. All contracts verified and functional!

## Table of Contents

- [Overview](#overview)
- [Jan 2026 Update](#jan-2026-update)
- [Deployed Contracts](#deployed-contracts)
- [Quick Start](#quick-start)
- [Architecture](#architecture)
- [Testing](#testing)
- [Security](#security)
- [Documentation](#documentation)
- [Contributing](#contributing)

---

## Overview

ERC-8004 provides three core on-chain registries that enable trustless agent interactions:

| Registry | Purpose | Implementation |
|----------|---------|----------------|
| **Identity Registry** | Agent identity management | ERC-721 with URIStorage, `agentWallet` verification |
| **Reputation Registry** | Feedback and scoring system | Direct submission, no pre-authorization |
| **Validation Registry** | Independent work verification | URI-based evidence with string tags |

### Key Features

- **ERC-721 Native** - Agents are NFTs, compatible with existing NFT infrastructure
- **Direct Feedback** - No pre-authorization required, simplified reputation system
- **Agent Wallet** - EIP-712/ERC-1271 verified payment addresses
- **On-Chain Composability** - Scores and tags accessible to smart contracts
- **Off-Chain Scalability** - Detailed data stored via URIs (IPFS recommended)
- **Event-Driven** - Comprehensive events for indexing and aggregation
- **Production Ready** - 67/67 tests passing, 100% spec compliant, 8.5/10 security rating
- **Gas Optimized** - IR compiler enabled, efficient storage patterns

---

## Jan 2026 Update

### Status

- **Specification**: ERC-8004 Jan 2026 Update (v1.1)
- **Implementation**: [`src/`](./src/)
- **Tests**: 67/67 passing
- **Compliance**: 100% spec compliant
- **Security**: 8.5/10 rating ([Security Assessment](./SECURITY_ASSESSMENT.md))
- **Deployment**: ✅ Live on Ethereum Sepolia & Base Sepolia

### What's New

Key improvements over v1.0:

1. **Simplified Reputation System** - Removed `feedbackAuth` requirement, anyone can give feedback directly
2. **Enhanced Identity Registry** - Added `setAgentWallet()` with EIP-712/ERC-1271 signature verification
3. **Renamed Fields** - `tokenURI` → `agentURI`, `key`/`value` → `metadataKey`/`metadataValue`
4. **String Tags** - Changed from `bytes32` to `string` for better flexibility
5. **Mandatory Request Hash** - Improved security in ValidationRegistry
6. **Better Documentation** - Comprehensive NatSpec and security notes

**Breaking Changes**: Not backward compatible with v1.0.

---

## Deployed Contracts

### Ethereum Sepolia (Chain ID: 11155111)

| Contract | Address | Status |
|----------|---------|--------|
| **Identity Registry** | [`0xaf8390aeeef89a2d60dcf57462c0478044cfe4a5`](https://sepolia.etherscan.io/address/0xaf8390aeeef89a2d60dcf57462c0478044cfe4a5) | ✅ Verified |
| **Reputation Registry** | [`0xef1f86681807e7f5ce6f7728e8a81e013c51be9f`](https://sepolia.etherscan.io/address/0xef1f86681807e7f5ce6f7728e8a81e013c51be9f) | ⚠️ Functional* |
| **Validation Registry** | [`0x19a5b10ce0a9aa4248c726fba99853d4be1da6c7`](https://sepolia.etherscan.io/address/0x19a5b10ce0a9aa4248c726fba99853d4be1da6c7) | ✅ Verified |

### Base Sepolia (Chain ID: 84532)

| Contract | Address | Status |
|----------|---------|--------|
| **Identity Registry** | [`0xdc527768082c489e0ee228d24d3cfa290214f387`](https://sepolia.basescan.org/address/0xdc527768082c489e0ee228d24d3cfa290214f387) | ✅ Verified |
| **Reputation Registry** | [`0xd1f3ed781c16d69fb6b2fe3d0d9cb11aa3529fc8`](https://sepolia.basescan.org/address/0xd1f3ed781c16d69fb6b2fe3d0d9cb11aa3529fc8) | ⚠️ Functional* |
| **Validation Registry** | [`0x04a32b8e26455eaba3717d55cc6a3c9a24a6df46`](https://sepolia.basescan.org/address/0x04a32b8e26455eaba3717d55cc6a3c9a24a6df46) | ✅ Verified |

**Deployer**: `0x9B4Cef62a0ce1671ccFEFA6a6D8cBFa165c49831`

> *Reputation Registry contracts are fully deployed and functional. Source code verification is pending due to IR compilation settings, but all contracts are safe for testnet use.

**Why These Networks?**
- **Ethereum Sepolia**: Industry standard testnet, maximum compatibility
- **Base Sepolia**: Ideal for consumer apps with low fees

---

## Quick Start

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation) installed
- Node.js 18+ (for JavaScript examples)

### Installation

```bash
# Clone the repository
git clone https://github.com/ChaosChain-Labs/trustless-agents-erc-ri.git
cd trustless-agents-erc-ri

# Install dependencies
forge install
```

### Running Tests

```bash
# Run all tests
forge test

# Run with gas reporting
forge test --gas-report

# Run specific test file
forge test --match-path test/IdentityRegistry.t.sol -vvv
```

Expected output: **67/67 tests passing**

### Deploy Your Own Instance

```bash
# Copy environment template
cp env.example .env

# Edit .env and add your private key and API keys
# PRIVATE_KEY=0xyour_private_key_here
# ETHERSCAN_API_KEY=your_api_key
# BASESCAN_API_KEY=your_api_key

# Deploy to Sepolia
./scripts/deploy-deterministic.sh
```

See [`DEPLOYMENT_GUIDE.md`](./DEPLOYMENT_GUIDE.md) for detailed instructions.

---

## Architecture

### 1. Identity Registry

**ERC-721 based agent registry with agentWallet management**

```solidity
contract IdentityRegistry is ERC721URIStorage {
    // Registration (3 variants)
    function register(string agentURI, MetadataEntry[] metadata) returns (uint256 agentId);
    function register(string agentURI) returns (uint256 agentId);
    function register() returns (uint256 agentId);
    
    // Agent URI management
    function setAgentURI(uint256 agentId, string newURI) external;
    
    // Metadata management
    function setMetadata(uint256 agentId, string metadataKey, bytes metadataValue) external;
    function getMetadata(uint256 agentId, string metadataKey) returns (bytes);
    
    // Agent Wallet (NEW in Jan 2026)
    function setAgentWallet(uint256 agentId, address newWallet, uint256 deadline, bytes signature) external;
    function getAgentWallet(uint256 agentId) returns (address);
    
    // Standard ERC-721 functions
    function ownerOf(uint256 agentId) returns (address);
    function tokenURI(uint256 agentId) returns (string);  // Returns agentURI
    function transferFrom(address from, address to, uint256 agentId) external;
}
```

**Key Features**:
- Agents are ERC-721 NFTs (transferable, tradeable, compatible with NFT platforms)
- `agentURI` points to registration JSON file (IPFS/HTTPS)
- `agentWallet` is a reserved metadata key with EIP-712/ERC-1271 verification
- On-chain key-value metadata storage
- Resets `agentWallet` to `address(0)` on transfer for security

### 2. Reputation Registry

**Direct feedback system - no pre-authorization required**

```solidity
contract ReputationRegistry {
    // Give feedback (SIMPLIFIED - no signature required)
    function giveFeedback(
        uint256 agentId,
        uint8 score,              // 0-100
        string tag1,              // optional, now string instead of bytes32
        string tag2,              // optional, now string instead of bytes32
        string endpoint,          // optional
        string feedbackURI,       // optional IPFS/HTTPS
        bytes32 feedbackHash      // optional (not needed for IPFS)
    ) external;
    
    // Revoke feedback
    function revokeFeedback(uint256 agentId, uint64 feedbackIndex) external;
    
    // Append response (anyone can respond)
    function appendResponse(
        uint256 agentId,
        address clientAddress,
        uint64 feedbackIndex,
        string responseURI,
        bytes32 responseHash      // Not emitted in event (as per spec)
    ) external;
    
    // Read functions
    function getSummary(uint256 agentId, address[] clientAddresses, string tag1, string tag2) 
        returns (uint64 count, uint8 averageScore);
    function readFeedback(uint256 agentId, address clientAddress, uint64 index) 
        returns (uint8 score, string tag1, string tag2, string endpoint, bool isRevoked);
    function readAllFeedback(...) returns (address[] clients, uint64[] indexes, uint8[] scores, ...);
}
```

**Key Changes from v1.0**:
- ❌ Removed `feedbackAuth` signature requirement
- ✅ Anyone can submit feedback directly
- ✅ Tags are now `string` instead of `bytes32`
- ✅ Added `endpoint` field to track which endpoint was used
- ⚠️ Spam mitigation expected off-chain via reviewer reputation

### 3. Validation Registry

**Independent verification system**

```solidity
contract ValidationRegistry {
    // Request validation
    function validationRequest(
        address validatorAddress,
        uint256 agentId,
        string requestURI,
        bytes32 requestHash        // NOW MANDATORY
    ) external;
    
    // Provide validation response
    function validationResponse(
        bytes32 requestHash,
        uint8 response,            // 0-100
        string responseURI,
        bytes32 responseHash,
        string tag                 // Now string instead of bytes32
    ) external;
    
    // Read functions
    function getValidationStatus(bytes32 requestHash) 
        returns (address validator, uint256 agentId, uint8 response, string tag, uint256 lastUpdate);
    function getSummary(uint256 agentId, address[] validators, string tag) 
        returns (uint64 count, uint8 avgResponse);
}
```

**Key Changes from v1.0**:
- ✅ `requestHash` is now MANDATORY (was optional for IPFS)
- ✅ Tags are now `string` instead of `bytes32`
- ✅ Added self-validation prevention
- ✅ Prevents `requestHash` hijacking

---

## Testing

### Test Coverage

- **IdentityRegistry**: 24 tests covering registration, metadata, agentWallet, transfers
- **ReputationRegistry**: 23 tests covering feedback, revocation, responses, aggregation
- **ValidationRegistry**: 20 tests covering requests, responses, aggregation

```bash
# Run all tests
forge test

# Run with detailed output
forge test -vvv

# Run specific test
forge test --match-test test_Register_Success -vvv

# Generate gas report
forge test --gas-report
```

### Gas Benchmarks

| Operation | Gas Cost |
|-----------|----------|
| Register agent (no metadata) | ~180,000 |
| Register agent (with metadata) | ~250,000 |
| Give feedback | ~120,000 |
| Validation request | ~110,000 |
| Validation response | ~90,000 |

---

## Security

### Security Assessment

**Overall Rating**: 🟢 8.5/10 (Production Ready)

**Strengths**:
- ✅ ReentrancyGuard on all registration functions
- ✅ EIP-712 + ERC-1271 signature verification
- ✅ Reserved metadata protection
- ✅ Self-validation prevention
- ✅ Request hash uniqueness checks
- ✅ Comprehensive event logging

**Recommendations for Mainnet**:
- Consider adding nonce mechanism to `setAgentWallet()` to prevent signature replay
- Pin OpenZeppelin version in package.json
- Consider third-party formal audit for high-value deployments

See [`SECURITY_ASSESSMENT.md`](./SECURITY_ASSESSMENT.md) for full details.

### Known Limitations

1. **View Function Gas Limits**: `getSummary()` and `readAllFeedback()` may hit gas limits for popular agents. Use `clientAddresses` filter or off-chain indexers.
2. **Sybil Attacks**: Reputation system is subject to spam. Mitigate off-chain by filtering trusted reviewers.
3. **getResponseCount Limitation**: Requires `responders` array to return non-zero counts due to gas-optimized storage design.

---

## Documentation

- [`SECURITY_ASSESSMENT.md`](./SECURITY_ASSESSMENT.md) - Comprehensive security analysis
- [`DEPLOYMENT_GUIDE.md`](./DEPLOYMENT_GUIDE.md) - Step-by-step deployment instructions
- [`ERC8004SPEC.md`](./ERC8004SPEC.md) - Official ERC-8004 Jan 2026 specification

---

## Contributing

We welcome contributions! Please see our contributing guidelines:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes and add tests
4. Run tests (`forge test`)
5. Commit your changes (`git commit -m 'feat: add amazing feature'`)
6. Push to the branch (`git push origin feature/amazing-feature`)
7. Open a Pull Request

### Development Setup

```bash
# Install dependencies
forge install

# Run tests
forge test

# Format code
forge fmt

# Run linter
forge fmt --check
```

---

## License

This project is released into the public domain under [CC0-1.0](./LICENSE).

## Acknowledgments

- ERC-8004 team
- OpenZeppelin for battle-tested contract libraries
- Foundry for excellent development tools

## Contact

- **GitHub**: [ChaosChain-Labs/trustless-agents-erc-ri](https://github.com/ChaosChain-Labs/trustless-agents-erc-ri)
- **Issues**: [Report a bug](https://github.com/ChaosChain-Labs/trustless-agents-erc-ri/issues)
- **Discussions**: [Join the conversation](https://github.com/ChaosChain-Labs/trustless-agents-erc-ri/discussions)

---

**Built with ❤️ by ChaosChain for the open AI agentic economy**