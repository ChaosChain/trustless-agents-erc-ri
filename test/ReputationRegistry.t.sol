// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/IdentityRegistry.sol";
import "../src/ReputationRegistry.sol";

/**
 * @title ReputationRegistryTest
 * @dev Comprehensive test suite for ERC-8004 Reputation Registry (Jan 2026 Update)
 * @notice Jan 2026 Update removed feedbackAuth - anyone can submit feedback directly
 * @author ChaosChain Labs
 */
contract ReputationRegistryTest is Test {
    IdentityRegistry public identityRegistry;
    ReputationRegistry public reputationRegistry;
    
    address public agentOwner = address(0xA11CE);
    address public client = address(0xB0B);
    address public client2 = address(0x3);
    address public responder = address(0x4);
    
    uint256 public agentId;
    
    string constant AGENT_URI = "ipfs://QmTest/agent.json";
    string constant FEEDBACK_URI = "ipfs://QmFeedback/feedback.json";
    string constant RESPONSE_URI = "ipfs://QmResponse/response.json";
    string constant ENDPOINT = "https://agent.example.com";
    
    string constant TAG1 = "quality";
    string constant TAG2 = "speed";
    
    event NewFeedback(
        uint256 indexed agentId,
        address indexed clientAddress,
        uint64 feedbackIndex,
        uint8 score,
        string indexed tag1,
        string tag2,
        string endpoint,
        string feedbackURI,
        bytes32 feedbackHash
    );
    
    event FeedbackRevoked(
        uint256 indexed agentId,
        address indexed clientAddress,
        uint64 indexed feedbackIndex
    );
    
    event ResponseAppended(
        uint256 indexed agentId,
        address indexed clientAddress,
        uint64 feedbackIndex,
        address indexed responder,
        string responseURI
    );

    function setUp() public {
        // Deploy contracts
        identityRegistry = new IdentityRegistry();
        reputationRegistry = new ReputationRegistry(address(identityRegistry));
        
        // Register an agent
        vm.prank(agentOwner);
        agentId = identityRegistry.register(AGENT_URI);
    }
    
    // ============ giveFeedback Tests ============
    
    function test_GiveFeedback_Success() public {
        // Setup expectations
        vm.expectEmit(true, true, true, true);
        emit NewFeedback(agentId, client, 1, 95, TAG1, TAG2, ENDPOINT, FEEDBACK_URI, keccak256("test"));
        
        // Give feedback (no authorization needed in Jan 2026 Update!)
        vm.prank(client);
        reputationRegistry.giveFeedback(
            agentId,
            95,
            TAG1,
            TAG2,
            ENDPOINT,
            FEEDBACK_URI,
            keccak256("test")
        );
        
        // Verify storage
        (uint8 score, string memory tag1, string memory tag2, bool isRevoked) = 
            reputationRegistry.readFeedback(agentId, client, 1);
        
        assertEq(score, 95);
        assertEq(tag1, TAG1);
        assertEq(tag2, TAG2);
        assertFalse(isRevoked);
    }
    
    function test_GiveFeedback_MultipleClients() public {
        // Client 1 gives feedback
        vm.prank(client);
        reputationRegistry.giveFeedback(agentId, 90, TAG1, TAG2, "", FEEDBACK_URI, bytes32(0));
        
        // Client 2 gives feedback
        vm.prank(client2);
        reputationRegistry.giveFeedback(agentId, 95, TAG1, TAG2, "", FEEDBACK_URI, bytes32(0));
        
        // Verify both stored
        (uint8 score1,,,) = reputationRegistry.readFeedback(agentId, client, 1);
        (uint8 score2,,,) = reputationRegistry.readFeedback(agentId, client2, 1);
        
        assertEq(score1, 90);
        assertEq(score2, 95);
    }
    
    function test_GiveFeedback_MultipleFeedbackSameClient() public {
        vm.startPrank(client);
        
        // Give first feedback
        reputationRegistry.giveFeedback(agentId, 90, TAG1, TAG2, "", "", bytes32(0));
        
        // Give second feedback
        reputationRegistry.giveFeedback(agentId, 85, TAG1, TAG2, "", "", bytes32(0));
        
        vm.stopPrank();
        
        // Verify both stored
        (uint8 score1,,,) = reputationRegistry.readFeedback(agentId, client, 1);
        (uint8 score2,,,) = reputationRegistry.readFeedback(agentId, client, 2);
        
        assertEq(score1, 90);
        assertEq(score2, 85);
    }
    
    function test_GiveFeedback_InvalidScore() public {
        vm.prank(client);
        vm.expectRevert("Score must be 0-100");
        reputationRegistry.giveFeedback(agentId, 101, TAG1, TAG2, "", "", bytes32(0));
    }
    
    function test_GiveFeedback_NonExistentAgent() public {
        vm.prank(client);
        vm.expectRevert("Agent does not exist");
        reputationRegistry.giveFeedback(999, 95, TAG1, TAG2, "", "", bytes32(0));
    }
    
    // ============ revokeFeedback Tests ============
    
    function test_RevokeFeedback_Success() public {
        // Give feedback
        vm.prank(client);
        reputationRegistry.giveFeedback(agentId, 95, TAG1, TAG2, "", FEEDBACK_URI, bytes32(0));
        
        // Revoke it
        vm.expectEmit(true, true, true, true);
        emit FeedbackRevoked(agentId, client, 1);
        
        vm.prank(client);
        reputationRegistry.revokeFeedback(agentId, 1);
        
        // Verify revoked
        (,,, bool isRevoked) = reputationRegistry.readFeedback(agentId, client, 1);
        assertTrue(isRevoked);
    }
    
    function test_RevokeFeedback_InvalidIndex() public {
        vm.prank(client);
        vm.expectRevert("Invalid index");
        reputationRegistry.revokeFeedback(agentId, 1);
    }
    
    // ============ appendResponse Tests ============
    
    function test_AppendResponse_Success() public {
        // Give feedback
        vm.prank(client);
        reputationRegistry.giveFeedback(agentId, 95, TAG1, TAG2, "", FEEDBACK_URI, bytes32(0));
        
        // Append response
        vm.expectEmit(true, true, true, true);
        emit ResponseAppended(agentId, client, 1, responder, RESPONSE_URI);
        
        vm.prank(responder);
        reputationRegistry.appendResponse(agentId, client, 1, RESPONSE_URI, keccak256("response"));
        
        // Verify response count
        address[] memory responders = new address[](1);
        responders[0] = responder;
        uint64 count = reputationRegistry.getResponseCount(agentId, client, 1, responders);
        assertEq(count, 1);
    }
    
    // ============ Read Function Tests ============
    
    function test_GetSummary_Success() public {
        // Give feedback from two clients
        vm.prank(client);
        reputationRegistry.giveFeedback(agentId, 90, TAG1, TAG2, "", "", bytes32(0));
        
        vm.prank(client2);
        reputationRegistry.giveFeedback(agentId, 80, TAG1, TAG2, "", "", bytes32(0));
        
        // Get summary
        address[] memory emptyFilter;
        (uint64 count, uint8 avgScore) = reputationRegistry.getSummary(
            agentId,
            emptyFilter,
            "",
            ""
        );
        
        assertEq(count, 2);
        assertEq(avgScore, 85); // (90 + 80) / 2
    }
    
    function test_GetSummary_WithTagFilter() public {
        // Give feedback with different tags
        vm.prank(client);
        reputationRegistry.giveFeedback(agentId, 90, TAG1, TAG2, "", "", bytes32(0));
        
        vm.prank(client2);
        reputationRegistry.giveFeedback(agentId, 80, "other", TAG2, "", "", bytes32(0));
        
        // Get summary filtered by TAG1
        address[] memory emptyFilter;
        (uint64 count, uint8 avgScore) = reputationRegistry.getSummary(
            agentId,
            emptyFilter,
            TAG1,
            ""
        );
        
        assertEq(count, 1);
        assertEq(avgScore, 90);
    }
    
    function test_ReadAllFeedback_Success() public {
        // Give feedback from two clients
        vm.prank(client);
        reputationRegistry.giveFeedback(agentId, 90, TAG1, TAG2, "", "", bytes32(0));
        
        vm.prank(client2);
        reputationRegistry.giveFeedback(agentId, 85, TAG1, TAG2, "", "", bytes32(0));
        
        // Read all feedback
        address[] memory emptyFilter;
        (
            address[] memory clients,
            uint64[] memory feedbackIndexes,
            uint8[] memory scores,
            string[] memory tag1s,
            string[] memory tag2s,
            bool[] memory revokedStatuses
        ) = reputationRegistry.readAllFeedback(agentId, emptyFilter, "", "", false);
        
        assertEq(clients.length, 2);
        assertEq(feedbackIndexes[0], 1);
        assertEq(feedbackIndexes[1], 1);
        assertEq(scores[0], 90);
        assertEq(scores[1], 85);
        assertEq(tag1s[0], TAG1);
        assertEq(tag2s[0], TAG2);
    }
    
    function test_GetClients_Success() public {
        // Give feedback from two clients
        vm.prank(client);
        reputationRegistry.giveFeedback(agentId, 90, TAG1, TAG2, "", "", bytes32(0));
        
        vm.prank(client2);
        reputationRegistry.giveFeedback(agentId, 85, TAG1, TAG2, "", "", bytes32(0));
        
        // Get clients
        address[] memory clients = reputationRegistry.getClients(agentId);
        
        assertEq(clients.length, 2);
        assertEq(clients[0], client);
        assertEq(clients[1], client2);
    }
    
    function test_GetLastIndex_Success() public {
        // Give feedback twice from same client
        vm.startPrank(client);
        reputationRegistry.giveFeedback(agentId, 90, TAG1, TAG2, "", "", bytes32(0));
        reputationRegistry.giveFeedback(agentId, 85, TAG1, TAG2, "", "", bytes32(0));
        vm.stopPrank();
        
        // Get last index
        uint64 lastIndex = reputationRegistry.getLastIndex(agentId, client);
        assertEq(lastIndex, 2);
    }
    
    function test_GetIdentityRegistry_Success() public {
        address registry = reputationRegistry.getIdentityRegistry();
        assertEq(registry, address(identityRegistry));
    }
}
