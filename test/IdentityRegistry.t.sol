// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/IdentityRegistry.sol";

/**
 * @title IdentityRegistryTest
 * @dev Comprehensive test suite for ERC-8004 v1.0 Identity Registry
 * @author ChaosChain Labs
 */
contract IdentityRegistryTest is Test {
    IdentityRegistry public registry;
    
    address public alice = address(0x1);
    address public bob = address(0x2);
    address public charlie = address(0x3);
    
    string constant TOKEN_URI = "ipfs://QmTest123/registration.json";
    string constant TOKEN_URI_2 = "https://example.com/agent.json";
    
    event Registered(uint256 indexed agentId, string tokenURI, address indexed owner);
    event MetadataSet(uint256 indexed agentId, string indexed indexedKey, string key, bytes value);

    function setUp() public {
        registry = new IdentityRegistry();
    }

    // ============ Registration Tests ============

    function test_Register_WithTokenURIAndMetadata() public {
        vm.startPrank(alice);
        
        // Prepare metadata
        IIdentityRegistry.MetadataEntry[] memory metadata = new IIdentityRegistry.MetadataEntry[](2);
        metadata[0] = IIdentityRegistry.MetadataEntry({
            metadataKey: "agentName",
            metadataValue: abi.encodePacked("Alice Agent")
        });
        metadata[1] = IIdentityRegistry.MetadataEntry({
            metadataKey: "agentType",
            metadataValue: abi.encodePacked("AI Assistant")
        });
        
        // Expect events
        vm.expectEmit(true, true, false, true);
        emit Registered(1, TOKEN_URI, alice);
        
        vm.expectEmit(true, true, false, true);
        emit MetadataSet(1, "agentName", "agentName", abi.encodePacked("Alice Agent"));
        
        vm.expectEmit(true, true, false, true);
        emit MetadataSet(1, "agentType", "agentType", abi.encodePacked("AI Assistant"));
        
        // Register
        uint256 agentId = registry.register(TOKEN_URI, metadata);
        
        // Assertions
        assertEq(agentId, 1, "First agent should have ID 1");
        assertEq(registry.ownerOf(agentId), alice, "Alice should own the agent");
        assertEq(registry.tokenURI(agentId), TOKEN_URI, "Token URI should match");
        assertEq(registry.totalAgents(), 1, "Should have 1 agent");
        assertTrue(registry.agentExists(agentId), "Agent should exist");
        
        // Check metadata
        assertEq(
            registry.getMetadata(agentId, "agentName"),
            abi.encodePacked("Alice Agent"),
            "Agent name should match"
        );
        assertEq(
            registry.getMetadata(agentId, "agentType"),
            abi.encodePacked("AI Assistant"),
            "Agent type should match"
        );
        
        vm.stopPrank();
    }
    
    function test_Register_WithTokenURIOnly() public {
        vm.startPrank(bob);
        
        vm.expectEmit(true, true, false, true);
        emit Registered(1, TOKEN_URI_2, bob);
        
        uint256 agentId = registry.register(TOKEN_URI_2);
        
        assertEq(agentId, 1, "Should be agent ID 1");
        assertEq(registry.ownerOf(agentId), bob, "Bob should own the agent");
        assertEq(registry.tokenURI(agentId), TOKEN_URI_2, "Token URI should match");
        
        vm.stopPrank();
    }
    
    function test_Register_WithoutTokenURI() public {
        vm.startPrank(charlie);
        
        vm.expectEmit(true, true, false, true);
        emit Registered(1, "", charlie);
        
        uint256 agentId = registry.register();
        
        assertEq(agentId, 1, "Should be agent ID 1");
        assertEq(registry.ownerOf(agentId), charlie, "Charlie should own the agent");
        assertEq(registry.tokenURI(agentId), "", "Token URI should be empty");
        
        vm.stopPrank();
    }
    
    function test_Register_MultipleAgents() public {
        vm.prank(alice);
        uint256 agentId1 = registry.register(TOKEN_URI);
        
        vm.prank(bob);
        uint256 agentId2 = registry.register(TOKEN_URI_2);
        
        vm.prank(charlie);
        uint256 agentId3 = registry.register();
        
        assertEq(agentId1, 1, "First agent ID should be 1");
        assertEq(agentId2, 2, "Second agent ID should be 2");
        assertEq(agentId3, 3, "Third agent ID should be 3");
        assertEq(registry.totalAgents(), 3, "Should have 3 agents");
    }
    
    function test_Register_EmptyMetadataKey_Reverts() public {
        vm.startPrank(alice);
        
        IIdentityRegistry.MetadataEntry[] memory metadata = new IIdentityRegistry.MetadataEntry[](1);
        metadata[0] = IIdentityRegistry.MetadataEntry({
            metadataKey: "",
            metadataValue: abi.encodePacked("test")
        });
        
        vm.expectRevert("Empty key");
        registry.register(TOKEN_URI, metadata);
        
        vm.stopPrank();
    }
    
    // ============ Metadata Tests ============
    
    function test_SetMetadata_Success() public {
        vm.startPrank(alice);
        
        uint256 agentId = registry.register(TOKEN_URI);
        
        vm.expectEmit(true, true, false, true);
        emit MetadataSet(agentId, "version", "version", abi.encodePacked("1.0.0"));
        
        registry.setMetadata(agentId, "version", abi.encodePacked("1.0.0"));
        
        assertEq(
            registry.getMetadata(agentId, "version"),
            abi.encodePacked("1.0.0"),
            "Version should match"
        );
        
        vm.stopPrank();
    }
    
    function test_SetMetadata_UpdateExisting() public {
        vm.startPrank(alice);
        
        uint256 agentId = registry.register(TOKEN_URI);
        
        registry.setMetadata(agentId, "status", abi.encodePacked("active"));
        assertEq(registry.getMetadata(agentId, "status"), abi.encodePacked("active"));
        
        registry.setMetadata(agentId, "status", abi.encodePacked("inactive"));
        assertEq(registry.getMetadata(agentId, "status"), abi.encodePacked("inactive"));
        
        vm.stopPrank();
    }
    
    function test_SetMetadata_NotOwner_Reverts() public {
        vm.prank(alice);
        uint256 agentId = registry.register(TOKEN_URI);
        
        vm.prank(bob);
        vm.expectRevert("Not authorized");
        registry.setMetadata(agentId, "test", abi.encodePacked("value"));
    }
    
    function test_SetMetadata_EmptyKey_Reverts() public {
        vm.startPrank(alice);
        
        uint256 agentId = registry.register(TOKEN_URI);
        
        vm.expectRevert("Empty key");
        registry.setMetadata(agentId, "", abi.encodePacked("value"));
        
        vm.stopPrank();
    }
    
    function test_GetMetadata_NonExistentAgent_Reverts() public {
        vm.expectRevert("Agent does not exist");
        registry.getMetadata(999, "test");
    }
    
    function test_GetMetadata_NonExistentKey_ReturnsEmpty() public {
        vm.prank(alice);
        uint256 agentId = registry.register(TOKEN_URI);
        
        bytes memory value = registry.getMetadata(agentId, "nonexistent");
        assertEq(value.length, 0, "Should return empty bytes");
    }
    
    // ============ ERC-721 Functionality Tests ============
    
    function test_Transfer_Success() public {
        vm.prank(alice);
        uint256 agentId = registry.register(TOKEN_URI);
        
        vm.prank(alice);
        registry.transferFrom(alice, bob, agentId);
        
        assertEq(registry.ownerOf(agentId), bob, "Bob should now own the agent");
    }

    function test_Approve_Success() public {
        vm.prank(alice);
        uint256 agentId = registry.register(TOKEN_URI);

        vm.prank(alice);
        registry.approve(bob, agentId);
        
        assertEq(registry.getApproved(agentId), bob, "Bob should be approved");
        
        vm.prank(bob);
        registry.transferFrom(alice, charlie, agentId);
        
        assertEq(registry.ownerOf(agentId), charlie, "Charlie should now own the agent");
    }
    
    function test_SetApprovalForAll_Success() public {
        vm.prank(alice);
        uint256 agentId = registry.register(TOKEN_URI);
        
        vm.prank(alice);
        registry.setApprovalForAll(bob, true);
        
        assertTrue(registry.isApprovedForAll(alice, bob), "Bob should be approved for all");
        
        vm.prank(bob);
        registry.setMetadata(agentId, "test", abi.encodePacked("value"));
        
        assertEq(registry.getMetadata(agentId, "test"), abi.encodePacked("value"));
    }
    
    // ============ View Function Tests ============
    
    function test_TotalAgents_Increments() public {
        assertEq(registry.totalAgents(), 0, "Should start at 0");
        
        vm.prank(alice);
        registry.register(TOKEN_URI);
        assertEq(registry.totalAgents(), 1);
        
        vm.prank(bob);
        registry.register(TOKEN_URI_2);
        assertEq(registry.totalAgents(), 2);
    }
    
    function test_AgentExists_Correct() public {
        assertFalse(registry.agentExists(1), "Agent 1 should not exist yet");
        
        vm.prank(alice);
        uint256 agentId = registry.register(TOKEN_URI);
        
        assertTrue(registry.agentExists(agentId), "Agent should exist");
        assertFalse(registry.agentExists(999), "Agent 999 should not exist");
    }
    
    function test_SupportsInterface_ERC721() public {
        // ERC721
        assertTrue(registry.supportsInterface(0x80ac58cd));
        // ERC721Metadata
        assertTrue(registry.supportsInterface(0x5b5e139f));
        // ERC165
        assertTrue(registry.supportsInterface(0x01ffc9a7));
    }
    
    function test_Name_AndSymbol() public {
        assertEq(registry.name(), "ERC-8004 Trustless Agent");
        assertEq(registry.symbol(), "AGENT");
    }
    
    // ============ Edge Cases ============
    
    function test_Register_LargeMetadata() public {
        vm.startPrank(alice);
        
        // Create large metadata
        bytes memory largeValue = new bytes(1000);
        for (uint i = 0; i < 1000; i++) {
            largeValue[i] = bytes1(uint8(i % 256));
        }
        
        IIdentityRegistry.MetadataEntry[] memory metadata = new IIdentityRegistry.MetadataEntry[](1);
        metadata[0] = IIdentityRegistry.MetadataEntry({
            metadataKey: "largeData",
            metadataValue: largeValue
        });
        
        uint256 agentId = registry.register(TOKEN_URI, metadata);
        
        assertEq(registry.getMetadata(agentId, "largeData"), largeValue);
        
        vm.stopPrank();
    }
    
    function test_Register_ManyMetadataEntries() public {
        vm.startPrank(alice);
        
        IIdentityRegistry.MetadataEntry[] memory metadata = new IIdentityRegistry.MetadataEntry[](10);
        for (uint i = 0; i < 10; i++) {
            metadata[i] = IIdentityRegistry.MetadataEntry({
                metadataKey: string(abi.encodePacked("key", vm.toString(i))),
                metadataValue: abi.encodePacked("value", i)
            });
        }
        
        uint256 agentId = registry.register(TOKEN_URI, metadata);
        
        for (uint i = 0; i < 10; i++) {
            bytes memory expected = abi.encodePacked("value", i);
            bytes memory actual = registry.getMetadata(agentId, string(abi.encodePacked("key", vm.toString(i))));
            assertEq(actual, expected);
        }
        
        vm.stopPrank();
    }
    
    // ============ Fuzz Tests ============
    
    function testFuzz_Register_RandomAddresses(address user) public {
        vm.assume(user != address(0));
        vm.assume(user.code.length == 0); // Only EOAs to avoid ERC721Receiver issues
        
        vm.prank(user);
        uint256 agentId = registry.register(TOKEN_URI);
        
        assertEq(registry.ownerOf(agentId), user);
        assertTrue(registry.agentExists(agentId));
    }
    
    function testFuzz_SetMetadata_RandomValues(bytes memory value) public {
        vm.assume(value.length < 10000); // Reasonable size limit
        
        vm.startPrank(alice);
        uint256 agentId = registry.register(TOKEN_URI);
        
        registry.setMetadata(agentId, "test", value);
        assertEq(registry.getMetadata(agentId, "test"), value);
        
        vm.stopPrank();
    }
    
    // ============ unsetAgentWallet Tests ============
    
    function test_UnsetAgentWallet_Success() public {
        vm.startPrank(alice);
        
        uint256 agentId = registry.register(TOKEN_URI);
        
        // Verify initial wallet is set to owner
        assertEq(registry.getAgentWallet(agentId), alice);
        
        // Unset the wallet
        registry.unsetAgentWallet(agentId);
        
        // Verify wallet is now address(0)
        assertEq(registry.getAgentWallet(agentId), address(0));
        
        vm.stopPrank();
    }
    
    function test_UnsetAgentWallet_NotOwner_Reverts() public {
        vm.prank(alice);
        uint256 agentId = registry.register(TOKEN_URI);
        
        vm.prank(bob);
        vm.expectRevert("Not authorized");
        registry.unsetAgentWallet(agentId);
    }
    
    function test_UnsetAgentWallet_ApprovedOperator_Success() public {
        vm.prank(alice);
        uint256 agentId = registry.register(TOKEN_URI);
        
        vm.prank(alice);
        registry.setApprovalForAll(bob, true);
        
        vm.prank(bob);
        registry.unsetAgentWallet(agentId);
        
        assertEq(registry.getAgentWallet(agentId), address(0));
    }
}
