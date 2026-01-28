// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/IdentityRegistry.sol";
import "../src/ReputationRegistry.sol";
import "../src/ValidationRegistry.sol";

/**
 * @title Deploy
 * @dev Deployment script for ERC-8004 Jan 2026 Spec contracts (v1.2)
 * @notice Deploys all three core registries in the correct order
 * 
 * Usage:
 * forge script script/Deploy.s.sol:Deploy --rpc-url <RPC_URL> --broadcast --verify
 * 
 * v1.2 Spec Changes:
 * - IdentityRegistry: Added unsetAgentWallet()
 * - ReputationRegistry: int128 value + uint8 valueDecimals
 * - ValidationRegistry: responseHash in getValidationStatus()
 * 
 * @author ChaosChain Labs
 */
contract Deploy is Script {
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // 1. Deploy IdentityRegistry (no dependencies)
        console.log("Deploying IdentityRegistry...");
        IdentityRegistry identityRegistry = new IdentityRegistry();
        console.log("IdentityRegistry deployed at:", address(identityRegistry));
        
        // 2. Deploy ReputationRegistry (depends on IdentityRegistry)
        console.log("Deploying ReputationRegistry...");
        ReputationRegistry reputationRegistry = new ReputationRegistry(address(identityRegistry));
        console.log("ReputationRegistry deployed at:", address(reputationRegistry));
        
        // 3. Deploy ValidationRegistry (depends on IdentityRegistry)
        console.log("Deploying ValidationRegistry...");
        ValidationRegistry validationRegistry = new ValidationRegistry(address(identityRegistry));
        console.log("ValidationRegistry deployed at:", address(validationRegistry));
        
        vm.stopBroadcast();
        
        // Output deployment summary
        console.log("\n=== ERC-8004 v1.2 (Jan 2026 Spec) Deployment Complete ===");
        console.log("Network Chain ID:", block.chainid);
        console.log("Deployer:", vm.addr(deployerPrivateKey));
        console.log("\nContract Addresses:");
        console.log("  IdentityRegistry:   ", address(identityRegistry));
        console.log("  ReputationRegistry: ", address(reputationRegistry));
        console.log("  ValidationRegistry: ", address(validationRegistry));
        console.log("\nVerification Commands:");
        console.log("forge verify-contract <address> src/IdentityRegistry.sol:IdentityRegistry");
        console.log("forge verify-contract <address> src/ReputationRegistry.sol:ReputationRegistry --constructor-args <encoded>");
        console.log("forge verify-contract <address> src/ValidationRegistry.sol:ValidationRegistry --constructor-args <encoded>");
    }
}

/**
 * @title DeployIdentityOnly
 * @dev Deploy only the IdentityRegistry
 */
contract DeployIdentityOnly is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        vm.startBroadcast(deployerPrivateKey);
        
        IdentityRegistry identityRegistry = new IdentityRegistry();
        console.log("IdentityRegistry deployed at:", address(identityRegistry));
        
        vm.stopBroadcast();
    }
}

/**
 * @title DeployReputationOnly
 * @dev Deploy only the ReputationRegistry (requires existing IdentityRegistry)
 */
contract DeployReputationOnly is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address identityRegistryAddress = vm.envAddress("IDENTITY_REGISTRY");
        
        vm.startBroadcast(deployerPrivateKey);
        
        ReputationRegistry reputationRegistry = new ReputationRegistry(identityRegistryAddress);
        console.log("ReputationRegistry deployed at:", address(reputationRegistry));
        
        vm.stopBroadcast();
    }
}

/**
 * @title DeployValidationOnly
 * @dev Deploy only the ValidationRegistry (requires existing IdentityRegistry)
 */
contract DeployValidationOnly is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address identityRegistryAddress = vm.envAddress("IDENTITY_REGISTRY");
        
        vm.startBroadcast(deployerPrivateKey);
        
        ValidationRegistry validationRegistry = new ValidationRegistry(identityRegistryAddress);
        console.log("ValidationRegistry deployed at:", address(validationRegistry));
        
        vm.stopBroadcast();
    }
}
