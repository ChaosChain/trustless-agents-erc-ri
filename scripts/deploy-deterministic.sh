#!/bin/bash

# ERC-8004 Jan 2026 Update - Deterministic Deployment Script
# Deploys to Ethereum Sepolia and Base Sepolia

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}ERC-8004 Jan 2026 Update${NC}"
echo -e "${BLUE}Deterministic Deployment${NC}"
echo -e "${BLUE}========================================${NC}\n"

# Check if .env exists
if [ ! -f .env ]; then
    echo -e "${RED}Error: .env file not found${NC}"
    echo -e "${YELLOW}Please create a .env file with:${NC}"
    echo "PRIVATE_KEY=your_private_key"
    echo "ETHERSCAN_API_KEY=your_etherscan_api_key"
    echo "BASESCAN_API_KEY=your_basescan_api_key"
    exit 1
fi

# Load environment variables
source .env

# Check required variables
if [ -z "$PRIVATE_KEY" ]; then
    echo -e "${RED}Error: PRIVATE_KEY not set in .env${NC}"
    exit 1
fi

if [ -z "$ETHERSCAN_API_KEY" ]; then
    echo -e "${RED}Error: ETHERSCAN_API_KEY not set in .env${NC}"
    exit 1
fi

if [ -z "$BASESCAN_API_KEY" ]; then
    echo -e "${RED}Error: BASESCAN_API_KEY not set in .env${NC}"
    exit 1
fi

# RPC URLs - use from .env if available, otherwise use defaults
if [ -z "$SEPOLIA_RPC_URL" ]; then
    SEPOLIA_RPC="https://ethereum-sepolia-rpc.publicnode.com"
    echo -e "${YELLOW}Note: Using default Sepolia RPC (publicnode.com)${NC}"
else
    SEPOLIA_RPC="$SEPOLIA_RPC_URL"
fi

if [ -z "$BASE_SEPOLIA_RPC_URL" ]; then
    BASE_SEPOLIA_RPC="https://sepolia.base.org"
else
    BASE_SEPOLIA_RPC="$BASE_SEPOLIA_RPC_URL"
fi

echo -e "${GREEN}✓ Environment variables loaded${NC}\n"

# Deploy to Ethereum Sepolia
echo -e "${BLUE}[1/2] Deploying to Ethereum Sepolia...${NC}"
forge script script/DeployDeterministic.s.sol:DeployDeterministic \
    --rpc-url "$SEPOLIA_RPC" \
    --broadcast \
    --verify \
    --etherscan-api-key "$ETHERSCAN_API_KEY" \
    -vvv

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Ethereum Sepolia deployment complete${NC}\n"
else
    echo -e "${RED}✗ Ethereum Sepolia deployment failed${NC}\n"
    exit 1
fi

# Wait a bit before next deployment
sleep 5

# Deploy to Base Sepolia
echo -e "${BLUE}[2/2] Deploying to Base Sepolia...${NC}"
forge script script/DeployDeterministic.s.sol:DeployDeterministic \
    --rpc-url "$BASE_SEPOLIA_RPC" \
    --broadcast \
    --verify \
    --etherscan-api-key "$BASESCAN_API_KEY" \
    --verifier-url "https://api-sepolia.basescan.org/api" \
    -vvv

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Base Sepolia deployment complete${NC}\n"
else
    echo -e "${RED}✗ Base Sepolia deployment failed${NC}\n"
    exit 1
fi

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}🎉 All deployments complete!${NC}"
echo -e "${GREEN}========================================${NC}\n"

echo -e "${YELLOW}Next steps:${NC}"
echo "1. Update deployments.json with new addresses"
echo "2. Update README.md with deployment info"
echo "3. Commit and push to GitHub"

