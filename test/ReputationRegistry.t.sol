// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/IdentityRegistry.sol";
import "../src/ReputationRegistry.sol";

/**
 * @title ReputationRegistryTest
 * @dev Comprehensive test suite for ERC-8004 Reputation Registry (Jan 2026 Update)
 * @notice Jan 2026 Update: int128 value + uint8 valueDecimals, no feedbackAuth
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
    
    // Updated event with int128 value, uint8 valueDecimals, and indexed + non-indexed tag1
    event NewFeedback(
        uint256 indexed agentId,
        address indexed clientAddress,
        uint64 feedbackIndex,
        int128 value,
        uint8 valueDecimals,
        string indexed indexedTag1,
        string tag1,
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
        string responseURI,
        bytes32 responseHash
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
        // Setup expectations - value=95, valueDecimals=0 (87/100 rating style)
        vm.expectEmit(true, true, true, true);
        emit NewFeedback(agentId, client, 1, 95, 0, TAG1, TAG1, TAG2, ENDPOINT, FEEDBACK_URI, keccak256("test"));
        
        // Give feedback (no authorization needed in Jan 2026 Update!)
        vm.prank(client);
        reputationRegistry.giveFeedback(
            agentId,
            95,      // value
            0,       // valueDecimals
            TAG1,
            TAG2,
            ENDPOINT,
            FEEDBACK_URI,
            keccak256("test")
        );
        
        // Verify storage
        (int128 value, uint8 valueDecimals, string memory tag1, string memory tag2, bool isRevoked) = 
            reputationRegistry.readFeedback(agentId, client, 1);
        
        assertEq(value, 95);
        assertEq(valueDecimals, 0);
        assertEq(tag1, TAG1);
        assertEq(tag2, TAG2);
        assertFalse(isRevoked);
    }
    
    function test_GiveFeedback_NegativeValue() public {
        // Test negative value like -3.2% yield: value=-32, valueDecimals=1
        vm.prank(client);
        reputationRegistry.giveFeedback(
            agentId,
            -32,     // value (negative!)
            1,       // valueDecimals (means divide by 10)
            "tradingYield",
            "month",
            "",
            "",
            bytes32(0)
        );
        
        // Verify storage
        (int128 value, uint8 valueDecimals,,,) = 
            reputationRegistry.readFeedback(agentId, client, 1);
        
        assertEq(value, -32);
        assertEq(valueDecimals, 1);
    }
    
    function test_GiveFeedback_HighPrecision() public {
        // Test 99.77% uptime: value=9977, valueDecimals=2
        vm.prank(client);
        reputationRegistry.giveFeedback(
            agentId,
            9977,    // value
            2,       // valueDecimals (means divide by 100)
            "uptime",
            "",
            "",
            "",
            bytes32(0)
        );
        
        (int128 value, uint8 valueDecimals,,,) = 
            reputationRegistry.readFeedback(agentId, client, 1);
        
        assertEq(value, 9977);
        assertEq(valueDecimals, 2);
    }
    
    function test_GiveFeedback_MultipleClients() public {
        // Client 1 gives feedback
        vm.prank(client);
        reputationRegistry.giveFeedback(agentId, 90, 0, TAG1, TAG2, "", FEEDBACK_URI, bytes32(0));
        
        // Client 2 gives feedback
        vm.prank(client2);
        reputationRegistry.giveFeedback(agentId, 95, 0, TAG1, TAG2, "", FEEDBACK_URI, bytes32(0));
        
        // Verify both stored
        (int128 val1,,,,) = reputationRegistry.readFeedback(agentId, client, 1);
        (int128 val2,,,,) = reputationRegistry.readFeedback(agentId, client2, 1);
        
        assertEq(val1, 90);
        assertEq(val2, 95);
    }
    
    function test_GiveFeedback_MultipleFeedbackSameClient() public {
        vm.startPrank(client);
        
        // Give first feedback
        reputationRegistry.giveFeedback(agentId, 90, 0, TAG1, TAG2, "", "", bytes32(0));
        
        // Give second feedback
        reputationRegistry.giveFeedback(agentId, 85, 0, TAG1, TAG2, "", "", bytes32(0));
        
        vm.stopPrank();
        
        // Verify both stored
        (int128 val1,,,,) = reputationRegistry.readFeedback(agentId, client, 1);
        (int128 val2,,,,) = reputationRegistry.readFeedback(agentId, client, 2);
        
        assertEq(val1, 90);
        assertEq(val2, 85);
    }
    
    function test_GiveFeedback_InvalidValueDecimals() public {
        vm.prank(client);
        vm.expectRevert("valueDecimals must be 0-18");
        reputationRegistry.giveFeedback(agentId, 100, 19, TAG1, TAG2, "", "", bytes32(0));
    }
    
    function test_GiveFeedback_NonExistentAgent() public {
        vm.prank(client);
        vm.expectRevert("Agent does not exist");
        reputationRegistry.giveFeedback(999, 95, 0, TAG1, TAG2, "", "", bytes32(0));
    }
    
    // ============ revokeFeedback Tests ============
    
    function test_RevokeFeedback_Success() public {
        // Give feedback
        vm.prank(client);
        reputationRegistry.giveFeedback(agentId, 95, 0, TAG1, TAG2, "", FEEDBACK_URI, bytes32(0));
        
        // Revoke it
        vm.expectEmit(true, true, true, true);
        emit FeedbackRevoked(agentId, client, 1);
        
        vm.prank(client);
        reputationRegistry.revokeFeedback(agentId, 1);
        
        // Verify revoked
        (,,,, bool isRevoked) = reputationRegistry.readFeedback(agentId, client, 1);
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
        reputationRegistry.giveFeedback(agentId, 95, 0, TAG1, TAG2, "", FEEDBACK_URI, bytes32(0));
        
        // Append response
        bytes32 responseHash = keccak256("response");
        vm.expectEmit(true, true, true, true);
        emit ResponseAppended(agentId, client, 1, responder, RESPONSE_URI, responseHash);
        
        vm.prank(responder);
        reputationRegistry.appendResponse(agentId, client, 1, RESPONSE_URI, responseHash);
        
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
        reputationRegistry.giveFeedback(agentId, 90, 0, TAG1, TAG2, "", "", bytes32(0));
        
        vm.prank(client2);
        reputationRegistry.giveFeedback(agentId, 80, 0, TAG1, TAG2, "", "", bytes32(0));
        
        // Get summary
        address[] memory emptyFilter;
        (uint64 count, int128 summaryValue, uint8 summaryDecimals) = reputationRegistry.getSummary(
            agentId,
            emptyFilter,
            "",
            ""
        );
        
        assertEq(count, 2);
        assertEq(summaryValue, 170); // 90 + 80 (sum, not average)
        assertEq(summaryDecimals, 0);
    }
    
    function test_GetSummary_MixedDecimals() public {
        // Give feedback with different decimals
        // 90 (value=90, decimals=0) and 9.5 (value=95, decimals=1)
        vm.prank(client);
        reputationRegistry.giveFeedback(agentId, 90, 0, TAG1, TAG2, "", "", bytes32(0));
        
        vm.prank(client2);
        reputationRegistry.giveFeedback(agentId, 95, 1, TAG1, TAG2, "", "", bytes32(0));
        
        // Get summary - should normalize to max decimals (1)
        address[] memory emptyFilter;
        (uint64 count, int128 summaryValue, uint8 summaryDecimals) = reputationRegistry.getSummary(
            agentId,
            emptyFilter,
            "",
            ""
        );
        
        assertEq(count, 2);
        // 90 * 10 + 95 = 900 + 95 = 995
        assertEq(summaryValue, 995);
        assertEq(summaryDecimals, 1);
    }
    
    function test_GetSummary_WithTagFilter() public {
        // Give feedback with different tags
        vm.prank(client);
        reputationRegistry.giveFeedback(agentId, 90, 0, TAG1, TAG2, "", "", bytes32(0));
        
        vm.prank(client2);
        reputationRegistry.giveFeedback(agentId, 80, 0, "other", TAG2, "", "", bytes32(0));
        
        // Get summary filtered by TAG1
        address[] memory emptyFilter;
        (uint64 count, int128 summaryValue,) = reputationRegistry.getSummary(
            agentId,
            emptyFilter,
            TAG1,
            ""
        );
        
        assertEq(count, 1);
        assertEq(summaryValue, 90);
    }
    
    function test_ReadAllFeedback_Success() public {
        // Give feedback from two clients
        vm.prank(client);
        reputationRegistry.giveFeedback(agentId, 90, 0, TAG1, TAG2, "", "", bytes32(0));
        
        vm.prank(client2);
        reputationRegistry.giveFeedback(agentId, 85, 1, TAG1, TAG2, "", "", bytes32(0));
        
        // Read all feedback
        address[] memory emptyFilter;
        (
            address[] memory clients,
            uint64[] memory feedbackIndexes,
            int128[] memory values,
            uint8[] memory valueDecimalsArr,
            string[] memory tag1s,
            string[] memory tag2s,
            bool[] memory revokedStatuses
        ) = reputationRegistry.readAllFeedback(agentId, emptyFilter, "", "", false);
        
        assertEq(clients.length, 2);
        assertEq(feedbackIndexes[0], 1);
        assertEq(feedbackIndexes[1], 1);
        assertEq(values[0], 90);
        assertEq(values[1], 85);
        assertEq(valueDecimalsArr[0], 0);
        assertEq(valueDecimalsArr[1], 1);
        assertEq(tag1s[0], TAG1);
        assertEq(tag2s[0], TAG2);
        assertFalse(revokedStatuses[0]);
        assertFalse(revokedStatuses[1]);
    }
    
    function test_GetClients_Success() public {
        // Give feedback from two clients
        vm.prank(client);
        reputationRegistry.giveFeedback(agentId, 90, 0, TAG1, TAG2, "", "", bytes32(0));
        
        vm.prank(client2);
        reputationRegistry.giveFeedback(agentId, 85, 0, TAG1, TAG2, "", "", bytes32(0));
        
        // Get clients
        address[] memory clients = reputationRegistry.getClients(agentId);
        
        assertEq(clients.length, 2);
        assertEq(clients[0], client);
        assertEq(clients[1], client2);
    }
    
    function test_GetLastIndex_Success() public {
        // Give feedback twice from same client
        vm.startPrank(client);
        reputationRegistry.giveFeedback(agentId, 90, 0, TAG1, TAG2, "", "", bytes32(0));
        reputationRegistry.giveFeedback(agentId, 85, 0, TAG1, TAG2, "", "", bytes32(0));
        vm.stopPrank();
        
        // Get last index
        uint64 lastIndex = reputationRegistry.getLastIndex(agentId, client);
        assertEq(lastIndex, 2);
    }
    
    function test_GetIdentityRegistry_Success() public {
        address registry = reputationRegistry.getIdentityRegistry();
        assertEq(registry, address(identityRegistry));
    }
    
    // ============ Edge Cases ============
    
    function testFuzz_GiveFeedback_AnyValue(int128 value, uint8 decimals) public {
        vm.assume(decimals <= 18);
        
        vm.prank(client);
        reputationRegistry.giveFeedback(agentId, value, decimals, "", "", "", "", bytes32(0));
        
        (int128 storedValue, uint8 storedDecimals,,,) = 
            reputationRegistry.readFeedback(agentId, client, 1);
        
        assertEq(storedValue, value);
        assertEq(storedDecimals, decimals);
    }
}
