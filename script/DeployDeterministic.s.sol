// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/IdentityRegistry.sol";
import "../src/ReputationRegistry.sol";
import "../src/ValidationRegistry.sol";

/**
 * @title DeployDeterministic
 * @dev Deterministic deployment script for ERC-8004 Jan 2026 Update contracts
 * @notice Deploys all three core registries with CREATE2 for deterministic addresses across chains
 * 
 * Usage:
 * forge script script/DeployDeterministic.s.sol:DeployDeterministic --rpc-url <RPC_URL> --broadcast --verify
 * 
 * @author ChaosChain Labs
 */
contract DeployDeterministic is Script {
    
    // Salt for CREATE2 - change this to get different addresses
    bytes32 constant SALT = keccak256("ERC8004_JAN2026_UPDATE_V1");
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("Deployer:", deployer);
        console.log("Chain ID:", block.chainid);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // 1. Deploy IdentityRegistry (no dependencies)
        console.log("\nDeploying IdentityRegistry with CREATE2...");
        IdentityRegistry identityRegistry = new IdentityRegistry{salt: SALT}();
        console.log("IdentityRegistry deployed at:", address(identityRegistry));
        
        // 2. Deploy ReputationRegistry (depends on IdentityRegistry)
        console.log("\nDeploying ReputationRegistry with CREATE2...");
        ReputationRegistry reputationRegistry = new ReputationRegistry{salt: SALT}(address(identityRegistry));
        console.log("ReputationRegistry deployed at:", address(reputationRegistry));
        
        // 3. Deploy ValidationRegistry (depends on IdentityRegistry)
        console.log("\nDeploying ValidationRegistry with CREATE2...");
        ValidationRegistry validationRegistry = new ValidationRegistry{salt: SALT}(address(identityRegistry));
        console.log("ValidationRegistry deployed at:", address(validationRegistry));
        
        vm.stopBroadcast();
        
        // Output deployment summary
        console.log("\n========================================");
        console.log("ERC-8004 Jan 2026 Update - Deployment Complete");
        console.log("========================================");
        console.log("Network Chain ID:", block.chainid);
        console.log("Deployer:", deployer);
        console.log("\nContract Addresses:");
        console.log("  IdentityRegistry:   ", address(identityRegistry));
        console.log("  ReputationRegistry: ", address(reputationRegistry));
        console.log("  ValidationRegistry: ", address(validationRegistry));
        console.log("\nThese addresses are deterministic and will be the same");
        console.log("on all chains when deployed with the same deployer address.");
        console.log("========================================\n");
    }
}

