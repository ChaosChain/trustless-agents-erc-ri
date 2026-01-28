# ERC-8004 Trustless Agents Reference Implementation

[![License: CC0-1.0](https://img.shields.io/badge/License-CC0_1.0-lightgrey.svg)](http://creativecommons.org/publicdomain/zero/1.0/)
[![Solidity](https://img.shields.io/badge/Solidity-0.8.19-blue)](https://soliditylang.org)
[![Tests](https://img.shields.io/badge/Tests-74%2F74%20Passing-brightgreen)](https://github.com/ChaosChain/trustless-agents-erc-ri)
[![Deployed](https://img.shields.io/badge/Deployed-Sepolia-success)](https://github.com/ChaosChain/trustless-agents-erc-ri#deployed-contracts)
[![Security](https://img.shields.io/badge/Security-8.5%2F10-green)](./SECURITY_ASSESSMENT.md)

Reference implementation for **[ERC-8004: Trustless Agents](https://eips.ethereum.org/EIPS/eip-8004)** (Jan 2026 Spec) - a protocol enabling participants to discover, choose, and interact with AI agents across organizational boundaries without pre-existing trust.

>  **Testnet Ready!** Jan 2026 Spec Update deployed to **Ethereum Sepolia**. All contracts verified and functional!

## Table of Contents

- [Overview](#overview)
- [Jan 2026 Spec Update](#jan-2026-spec-update)
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
| **Identity Registry** | Agent identity management | ERC-721 with URIStorage, `agentWallet` verification, `unsetAgentWallet` |
| **Reputation Registry** | Feedback and scoring system | `int128 value` + `uint8 valueDecimals` for signed fixed-point values |
| **Validation Registry** | Independent work verification | URI-based evidence with `responseHash` in status |

### Key Features

- **ERC-721 Native** - Agents are NFTs, compatible with existing NFT infrastructure
- **Signed Fixed-Point Values** - `int128 value` + `uint8 valueDecimals` supports ratings, yields, percentages
- **Agent Wallet** - EIP-712/ERC-1271 verified payment addresses with `unsetAgentWallet()`
- **On-Chain Composability** - Scores and tags accessible to smart contracts
- **Off-Chain Scalability** - Detailed data stored via URIs (IPFS recommended)
- **Event-Driven** - Comprehensive events for indexing and aggregation
- **Production Ready** - 74/74 tests passing, 100% spec compliant, 8.5/10 security rating
- **Gas Optimized** - IR compiler enabled, efficient storage patterns

---

## Jan 2026 Spec Update

### Status

- **Specification**: ERC-8004 Jan 2026 Spec (v1.2)
- **Implementation**: [`src/`](./src/)
- **Tests**: 74/74 passing
- **Compliance**: 100% spec compliant
- **Security**: 8.5/10 rating ([Security Assessment](./SECURITY_ASSESSMENT.md))
- **Deployment**: ✅ Live on Ethereum Sepolia

### What's New

Key changes from previous version:

1. **Signed Fixed-Point Values** - `int128 value` + `uint8 valueDecimals` replaces simple `uint8 score`
   - Supports: ratings (87/100), yields (-3.2%), uptime (99.77%), revenues ($560)
2. **`unsetAgentWallet()`** - New function to clear agent wallet address
3. **`responseHash` in Validation** - `getValidationStatus()` now returns `responseHash`
4. **Dual Tag Indexing** - `NewFeedback` event has both indexed and non-indexed `tag1`
5. **Updated Return Types** - `getSummary()` returns `(count, summaryValue, summaryValueDecimals)`

### Value Representation Examples

| tag1 | Human Value | `value` | `valueDecimals` |
|------|-------------|---------|-----------------|
| `starred` | 87/100 rating | `87` | `0` |
| `tradingYield` | -3.2% | `-32` | `1` |
| `uptime` | 99.77% | `9977` | `2` |
| `revenues` | $560 | `560` | `0` |
| `responseTime` | 560ms | `560` | `0` |

---

## Deployed Contracts

### Ethereum Sepolia (Chain ID: 11155111)

| Contract | Address | Status |
|----------|---------|--------|
| **Identity Registry** | [`0xf66e7CBdAE1Cb710fee7732E4e1f173624e137A7`](https://sepolia.etherscan.io/address/0xf66e7CBdAE1Cb710fee7732E4e1f173624e137A7) | ✅ Verified |
| **Reputation Registry** | [`0x6E2a285294B5c74CB76d76AB77C1ef15c2A9E407`](https://sepolia.etherscan.io/address/0x6E2a285294B5c74CB76d76AB77C1ef15c2A9E407) | ⚠️ Functional* |
| **Validation Registry** | [`0xC26171A3c4e1d958cEA196A5e84B7418C58DCA2C`](https://sepolia.etherscan.io/address/0xC26171A3c4e1d958cEA196A5e84B7418C58DCA2C) | ✅ Verified |

**Deployer**: `0x9B4Cef62a0ce1671ccFEFA6a6D8cBFa165c49831`

> *Reputation Registry is fully deployed and functional. Source code verification pending due to IR compilation settings.

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

Expected output: **74/74 tests passing**

### Deploy Your Own Instance

```bash
# Copy environment template
cp env.example .env

# Edit .env and add your private key and API keys
# PRIVATE_KEY=0xyour_private_key_here
# ETHERSCAN_API_KEY=your_api_key

# Deploy to Sepolia
forge script script/Deploy.s.sol:Deploy --rpc-url sepolia --broadcast --verify
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
    
    // Agent Wallet
    function setAgentWallet(uint256 agentId, address newWallet, uint256 deadline, bytes signature) external;
    function getAgentWallet(uint256 agentId) returns (address);
    function unsetAgentWallet(uint256 agentId) external;  // NEW in v1.2
    
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
- **NEW**: `unsetAgentWallet()` allows owner to clear wallet address
- Resets `agentWallet` to `address(0)` on transfer for security

### 2. Reputation Registry

**Signed fixed-point value system - supports negative values and decimals**

```solidity
contract ReputationRegistry {
    // Give feedback with signed fixed-point value
    function giveFeedback(
        uint256 agentId,
        int128 value,             // Signed! Can be negative (e.g., -32 for -3.2%)
        uint8 valueDecimals,      // 0-18 decimal places
        string tag1,              // Optional, string
        string tag2,              // Optional, string
        string endpoint,          // Optional
        string feedbackURI,       // Optional IPFS/HTTPS
        bytes32 feedbackHash      // Optional (not needed for IPFS)
    ) external;
    
    // Revoke feedback
    function revokeFeedback(uint256 agentId, uint64 feedbackIndex) external;
    
    // Append response (anyone can respond)
    function appendResponse(
        uint256 agentId,
        address clientAddress,
        uint64 feedbackIndex,
        string responseURI,
        bytes32 responseHash
    ) external;
    
    // Read functions - UPDATED return types
    function getSummary(uint256 agentId, address[] clientAddresses, string tag1, string tag2) 
        returns (uint64 count, int128 summaryValue, uint8 summaryValueDecimals);
    function readFeedback(uint256 agentId, address clientAddress, uint64 index) 
        returns (int128 value, uint8 valueDecimals, string tag1, string tag2, bool isRevoked);
    function readAllFeedback(...) returns (
        address[] clients, uint64[] indexes, int128[] values, uint8[] valueDecimals, 
        string[] tag1s, string[] tag2s, bool[] revokedStatuses
    );
}
```

**Key Features**:
- ✅ `int128 value` + `uint8 valueDecimals` for signed fixed-point numbers
- ✅ Supports negative values (yields, losses)
- ✅ Supports high precision (99.77% uptime = value=9977, decimals=2)
- ✅ Tags are `string` for flexibility
- ⚠️ Spam mitigation expected off-chain via reviewer reputation

### 3. Validation Registry

**Independent verification system with responseHash tracking**

```solidity
contract ValidationRegistry {
    // Request validation
    function validationRequest(
        address validatorAddress,
        uint256 agentId,
        string requestURI,
        bytes32 requestHash        // MANDATORY
    ) external;
    
    // Provide validation response
    function validationResponse(
        bytes32 requestHash,
        uint8 response,            // 0-100
        string responseURI,
        bytes32 responseHash,
        string tag                 // String instead of bytes32
    ) external;
    
    // Read functions - NOW includes responseHash
    function getValidationStatus(bytes32 requestHash) 
        returns (
            address validator, 
            uint256 agentId, 
            uint8 response, 
            bytes32 responseHash,  // NEW in v1.2
            string tag, 
            uint256 lastUpdate
        );
    function getSummary(uint256 agentId, address[] validators, string tag) 
        returns (uint64 count, uint8 avgResponse);
}
```

**Key Features**:
- ✅ `requestHash` is MANDATORY
- ✅ `getValidationStatus()` returns `responseHash`
- ✅ Tags are `string` for flexibility
- ✅ Self-validation prevention
- ✅ Request hash uniqueness checks

---

## Testing

### Test Coverage

- **IdentityRegistry**: 25 tests covering registration, metadata, agentWallet, unsetAgentWallet, transfers
- **ReputationRegistry**: 18 tests covering feedback (positive/negative values), revocation, responses
- **ValidationRegistry**: 31 tests covering requests, responses, aggregation

```bash
# Run all tests
forge test

# Run with detailed output
forge test -vvv

# Run specific test
forge test --match-test test_GiveFeedback_NegativeValue -vvv

# Generate gas report
forge test --gas-report
```

### Gas Benchmarks

| Operation | Gas Cost |
|-----------|----------|
| Register agent (no metadata) | ~180,000 |
| Register agent (with metadata) | ~250,000 |
| Give feedback | ~150,000 |
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
- [`IMPLEMENTERS_GUIDE.md`](./IMPLEMENTERS_GUIDE.md) - Guide for teams implementing ERC-8004

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

- ERC-8004 team for the specification
- OpenZeppelin for battle-tested contract libraries
- Foundry for excellent development tools

## Contact

- **GitHub**: [ChaosChain-Labs/trustless-agents-erc-ri](https://github.com/ChaosChain-Labs/trustless-agents-erc-ri)
- **Issues**: [Report a bug](https://github.com/ChaosChain-Labs/trustless-agents-erc-ri/issues)
- **Discussions**: [Join the conversation](https://github.com/ChaosChain-Labs/trustless-agents-erc-ri/discussions)

---

**Built with ❤️ by ChaosChain for the open AI agentic economy**
