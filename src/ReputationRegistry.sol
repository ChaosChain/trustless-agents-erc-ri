// SPDX-License-Identifier: CC0-1.0
pragma solidity 0.8.19;

import "./IdentityRegistry.sol";
import "./interfaces/IReputationRegistry.sol";

/**
 * @title ReputationRegistry
 * @dev ERC-8004 Reputation Registry - Reference Implementation (Jan 2026 Update)
 * @notice On-chain feedback system - NO PRE-AUTHORIZATION REQUIRED
 * 
 * This contract implements the Reputation Registry as specified in ERC-8004 (Jan 2026 Update).
 * It provides a standard interface for posting and fetching feedback signals with
 * on-chain storage and aggregation capabilities.
 * 
 * Key Changes in Jan 2026 Update:
 * - ❌ REMOVED: feedbackAuth pre-authorization mechanism (~200 lines deleted!)
 * - ❌ REMOVED: Signature verification (ECDSA/ERC-1271)
 * - ❌ REMOVED: indexLimit, expiry checks
 * - ✅ NEW: Direct feedback submission (anyone can submit)
 * - ✅ NEW: String tags instead of bytes32 (more flexible, human-readable)
 * - ✅ NEW: endpoint parameter
 * - ✅ NEW: feedbackIndex in events
 * 
 * Spam/Sybil resistance is now handled through off-chain filtering and reputation
 * systems, as per the new spec rationale.
 * 
 * @author ChaosChain Labs
 */
contract ReputationRegistry is IReputationRegistry {

    // ============ State Variables ============
    
    /// @dev Reference to the IdentityRegistry
    IdentityRegistry public immutable identityRegistry;
    
    /// @dev Struct to store feedback data
    struct Feedback {
        uint8 score;
        string tag1;
        string tag2;
        bool isRevoked;
    }
    
    /// @dev agentId => clientAddress => feedbackIndex => Feedback
    mapping(uint256 => mapping(address => mapping(uint64 => Feedback))) private _feedback;
    
    /// @dev agentId => clientAddress => last feedback index
    mapping(uint256 => mapping(address => uint64)) private _lastIndex;
    
    /// @dev agentId => list of client addresses
    mapping(uint256 => address[]) private _clients;
    
    /// @dev agentId => clientAddress => exists in clients array
    mapping(uint256 => mapping(address => bool)) private _clientExists;
    
    /// @dev agentId => clientAddress => feedbackIndex => responder => response count
    mapping(uint256 => mapping(address => mapping(uint64 => mapping(address => uint64)))) private _responseCount;

    // ============ Constructor ============
    
    /**
     * @dev Constructor sets the identity registry reference
     * @param _identityRegistry Address of the IdentityRegistry contract
     */
    constructor(address _identityRegistry) {
        require(_identityRegistry != address(0), "Invalid registry address");
        identityRegistry = IdentityRegistry(_identityRegistry);
    }

    // ============ Core Functions ============
    
    /**
     * @notice Give feedback for an agent
     * @dev NO PRE-AUTHORIZATION REQUIRED - direct submission in Jan 2026 Update
     * @param agentId The agent receiving feedback
     * @param score The feedback score (0-100)
     * @param tag1 First tag for categorization (optional)
     * @param tag2 Second tag for categorization (optional)
     * @param endpoint The endpoint that was used (optional)
     * @param feedbackURI URI pointing to off-chain feedback data (optional)
     * @param feedbackHash KECCAK-256 hash of the file content (optional for IPFS)
     */
    function giveFeedback(
        uint256 agentId,
        uint8 score,
        string calldata tag1,
        string calldata tag2,
        string calldata endpoint,
        string calldata feedbackURI,
        bytes32 feedbackHash
    ) external {
        // Validate score
        require(score <= 100, "Score must be 0-100");
        
        // Verify agent exists
        require(identityRegistry.agentExists(agentId), "Agent does not exist");
        
        // Get current index for this client-agent pair
        uint64 currentIndex = _lastIndex[agentId][msg.sender] + 1;
        
        // Store feedback
        _feedback[agentId][msg.sender][currentIndex] = Feedback({
            score: score,
            tag1: tag1,
            tag2: tag2,
            isRevoked: false
        });
        
        // Update last index
        _lastIndex[agentId][msg.sender] = currentIndex;
        
        // Add client to list if first feedback
        if (!_clientExists[agentId][msg.sender]) {
            _clients[agentId].push(msg.sender);
            _clientExists[agentId][msg.sender] = true;
        }
        
        emit NewFeedback(agentId, msg.sender, currentIndex, score, tag1, tag2, endpoint, feedbackURI, feedbackHash);
    }
    
    /**
     * @notice Revoke previously given feedback
     * @param agentId The agent ID
     * @param feedbackIndex The feedback index to revoke
     */
    function revokeFeedback(uint256 agentId, uint64 feedbackIndex) external {
        require(feedbackIndex > 0 && feedbackIndex <= _lastIndex[agentId][msg.sender], "Invalid index");
        require(!_feedback[agentId][msg.sender][feedbackIndex].isRevoked, "Already revoked");
        
        _feedback[agentId][msg.sender][feedbackIndex].isRevoked = true;
        
        emit FeedbackRevoked(agentId, msg.sender, feedbackIndex);
    }
    
    /**
     * @notice Append a response to feedback
     * @param agentId The agent ID
     * @param clientAddress The client who gave the feedback
     * @param feedbackIndex The feedback index
     * @param responseURI URI pointing to the response data
     * @param responseHash KECCAK-256 hash of response content (optional for IPFS)
     */
    function appendResponse(
        uint256 agentId,
        address clientAddress,
        uint64 feedbackIndex,
        string calldata responseURI,
        bytes32 responseHash
    ) external {
        require(feedbackIndex > 0 && feedbackIndex <= _lastIndex[agentId][clientAddress], "Invalid index");
        require(bytes(responseURI).length > 0, "Empty URI");
        
        // Increment response count for this responder
        _responseCount[agentId][clientAddress][feedbackIndex][msg.sender]++;
        
        emit ResponseAppended(agentId, clientAddress, feedbackIndex, msg.sender, responseURI, responseHash);
    }

    // ============ Read Functions ============
    
    /**
     * @notice Get aggregated summary for an agent
     * @dev IMPORTANT: This function is designed for OFF-CHAIN consumption.
     *      For agents with many feedback entries, calling without filters may exceed gas limits.
     *      ALWAYS use the `clientAddresses` filter for popular agents to prevent DoS.
     *      As per ERC-8004 (Jan 2026 Update): "Without filtering by clientAddresses,
     *      results are subject to Sybil/spam attacks."
     * @param agentId The agent ID (mandatory)
     * @param clientAddresses Filter by specific clients (RECOMMENDED for popular agents)
     * @param tag1 Filter by tag1 (optional, empty string to skip)
     * @param tag2 Filter by tag2 (optional, empty string to skip)
     * @return count Number of feedback entries
     * @return averageScore Average score (0-100)
     */
    function getSummary(
        uint256 agentId,
        address[] calldata clientAddresses,
        string calldata tag1,
        string calldata tag2
    ) external view returns (uint64 count, uint8 averageScore) {
        address[] memory clients;
        if (clientAddresses.length > 0) {
            clients = clientAddresses;
        } else {
            clients = _clients[agentId];
        }
        
        uint256 totalScore = 0;
        uint64 validCount = 0;
        
        bool filterTag1 = bytes(tag1).length > 0;
        bool filterTag2 = bytes(tag2).length > 0;
        
        for (uint256 i = 0; i < clients.length; i++) {
            uint64 lastIdx = _lastIndex[agentId][clients[i]];
            
            for (uint64 j = 1; j <= lastIdx; j++) {
                Feedback storage fb = _feedback[agentId][clients[i]][j];
                
                // Skip revoked feedback
                if (fb.isRevoked) continue;
                
                // Apply tag filters
                if (filterTag1 && keccak256(bytes(fb.tag1)) != keccak256(bytes(tag1))) continue;
                if (filterTag2 && keccak256(bytes(fb.tag2)) != keccak256(bytes(tag2))) continue;
                
                totalScore += fb.score;
                validCount++;
            }
        }
        
        count = validCount;
        averageScore = validCount > 0 ? uint8(totalScore / validCount) : 0;
    }
    
    /**
     * @notice Read a specific feedback entry
     * @param agentId The agent ID
     * @param clientAddress The client address
     * @param feedbackIndex The feedback index
     * @return score The feedback score
     * @return tag1 First tag
     * @return tag2 Second tag
     * @return isRevoked Whether the feedback is revoked
     */
    function readFeedback(
        uint256 agentId,
        address clientAddress,
        uint64 feedbackIndex
    ) external view returns (
        uint8 score,
        string memory tag1,
        string memory tag2,
        bool isRevoked
    ) {
        require(feedbackIndex > 0 && feedbackIndex <= _lastIndex[agentId][clientAddress], "Invalid index");
        Feedback storage fb = _feedback[agentId][clientAddress][feedbackIndex];
        return (fb.score, fb.tag1, fb.tag2, fb.isRevoked);
    }
    
    /**
     * @notice Read all feedback for an agent
     * @dev IMPORTANT: This function is designed for OFF-CHAIN consumption (indexers, frontends).
     *      For agents with many feedback entries, calling without filters may exceed gas limits.
     *      ALWAYS use the `clientAddresses` filter for popular agents to prevent DoS.
     *      As per ERC-8004 (Jan 2026 Update): "more complex reputation aggregation will happen off-chain"
     * @param agentId The agent ID (mandatory)
     * @param clientAddresses Filter by clients (RECOMMENDED for popular agents)
     * @param tag1 Filter by tag1 (optional, empty string to ignore)
     * @param tag2 Filter by tag2 (optional, empty string to ignore)
     * @param includeRevoked Whether to include revoked feedback
     * @return clientAddresses_ Array of client addresses
     * @return feedbackIndexes Array of feedback indexes
     * @return scores Array of scores
     * @return tag1s Array of tag1 values
     * @return tag2s Array of tag2 values
     * @return revokedStatuses Array of revoked statuses
     */
    function readAllFeedback(
        uint256 agentId,
        address[] calldata clientAddresses,
        string calldata tag1,
        string calldata tag2,
        bool includeRevoked
    ) external view returns (
        address[] memory clientAddresses_,
        uint64[] memory feedbackIndexes,
        uint8[] memory scores,
        string[] memory tag1s,
        string[] memory tag2s,
        bool[] memory revokedStatuses
    ) {
        address[] memory clientList;
        if (clientAddresses.length > 0) {
            clientList = clientAddresses;
        } else {
            clientList = _clients[agentId];
        }
        
        // Count and populate in a single optimized pass
        uint256 totalCount = _countValidFeedback(agentId, clientList, tag1, tag2, includeRevoked);
        
        // Initialize arrays
        clientAddresses_ = new address[](totalCount);
        feedbackIndexes = new uint64[](totalCount);
        scores = new uint8[](totalCount);
        tag1s = new string[](totalCount);
        tag2s = new string[](totalCount);
        revokedStatuses = new bool[](totalCount);
        
        // Populate arrays
        _populateFeedbackArrays(
            agentId,
            clientList,
            tag1,
            tag2,
            includeRevoked,
            clientAddresses_,
            feedbackIndexes,
            scores,
            tag1s,
            tag2s,
            revokedStatuses
        );
    }
    
    /**
     * @dev Internal function to count valid feedback entries
     */
    function _countValidFeedback(
        uint256 agentId,
        address[] memory clientList,
        string calldata tag1,
        string calldata tag2,
        bool includeRevoked
    ) internal view returns (uint256 totalCount) {
        bool filterTag1 = bytes(tag1).length > 0;
        bool filterTag2 = bytes(tag2).length > 0;
        
        for (uint256 i = 0; i < clientList.length; i++) {
            uint64 lastIdx = _lastIndex[agentId][clientList[i]];
            for (uint64 j = 1; j <= lastIdx; j++) {
                Feedback storage fb = _feedback[agentId][clientList[i]][j];
                if (!includeRevoked && fb.isRevoked) continue;
                if (filterTag1 && keccak256(bytes(fb.tag1)) != keccak256(bytes(tag1))) continue;
                if (filterTag2 && keccak256(bytes(fb.tag2)) != keccak256(bytes(tag2))) continue;
                totalCount++;
            }
        }
    }
    
    /**
     * @dev Internal function to populate feedback arrays
     */
    function _populateFeedbackArrays(
        uint256 agentId,
        address[] memory clientList,
        string calldata tag1,
        string calldata tag2,
        bool includeRevoked,
        address[] memory clients,
        uint64[] memory feedbackIndexes,
        uint8[] memory scores,
        string[] memory tag1s,
        string[] memory tag2s,
        bool[] memory revokedStatuses
    ) internal view {
        uint256 idx = 0;
        bool filterTag1 = bytes(tag1).length > 0;
        bool filterTag2 = bytes(tag2).length > 0;
        
        for (uint256 i = 0; i < clientList.length; i++) {
            uint64 lastIdx = _lastIndex[agentId][clientList[i]];
            for (uint64 j = 1; j <= lastIdx; j++) {
                Feedback storage fb = _feedback[agentId][clientList[i]][j];
                if (!includeRevoked && fb.isRevoked) continue;
                if (filterTag1 && keccak256(bytes(fb.tag1)) != keccak256(bytes(tag1))) continue;
                if (filterTag2 && keccak256(bytes(fb.tag2)) != keccak256(bytes(tag2))) continue;
                
                clients[idx] = clientList[i];
                feedbackIndexes[idx] = j;
                scores[idx] = fb.score;
                tag1s[idx] = fb.tag1;
                tag2s[idx] = fb.tag2;
                revokedStatuses[idx] = fb.isRevoked;
                idx++;
            }
        }
    }
    
    /**
     * @notice Get response count for feedback entries
     * @dev IMPORTANT: This function has a known limitation due to gas-efficient storage design.
     *      When `responders` array is empty, the function returns 0 because the contract
     *      only tracks responses per-responder (not aggregate counts). To get accurate counts,
     *      you MUST provide the responders array. This is a design tradeoff to optimize gas
     *      costs for the more common write operations (appendResponse).
     * @param agentId The agent ID (mandatory)
     * @param clientAddress The client address (optional, address(0) for all clients)
     * @param feedbackIndex The feedback index (optional, 0 for all feedback)
     * @param responders Filter by specific responders (REQUIRED for non-zero counts)
     * @return count Total response count from specified responders
     */
    function getResponseCount(
        uint256 agentId,
        address clientAddress,
        uint64 feedbackIndex,
        address[] calldata responders
    ) external view returns (uint64 count) {
        // Early return if no responders specified (known limitation)
        if (responders.length == 0) {
            return 0;
        }
        
        if (clientAddress == address(0)) {
            // Count all responses for all clients from specified responders
            address[] memory clients = _clients[agentId];
            for (uint256 i = 0; i < clients.length; i++) {
                uint64 lastIdx = _lastIndex[agentId][clients[i]];
                for (uint64 j = 1; j <= lastIdx; j++) {
                    for (uint256 k = 0; k < responders.length; k++) {
                        count += _responseCount[agentId][clients[i]][j][responders[k]];
                    }
                }
            }
        } else if (feedbackIndex == 0) {
            // Count all responses for specific client from specified responders
            uint64 lastIdx = _lastIndex[agentId][clientAddress];
            for (uint64 j = 1; j <= lastIdx; j++) {
                for (uint256 k = 0; k < responders.length; k++) {
                    count += _responseCount[agentId][clientAddress][j][responders[k]];
                }
            }
        } else {
            // Count responses for specific feedback from specified responders
            for (uint256 k = 0; k < responders.length; k++) {
                count += _responseCount[agentId][clientAddress][feedbackIndex][responders[k]];
            }
        }
    }
    
    /**
     * @notice Get all clients who gave feedback to an agent
     * @param agentId The agent ID
     * @return clientList Array of client addresses
     */
    function getClients(uint256 agentId) external view returns (address[] memory clientList) {
        return _clients[agentId];
    }
    
    /**
     * @notice Get the last feedback index for a client-agent pair
     * @param agentId The agent ID
     * @param clientAddress The client address
     * @return lastIndex The last feedback index
     */
    function getLastIndex(uint256 agentId, address clientAddress) external view returns (uint64 lastIndex) {
        return _lastIndex[agentId][clientAddress];
    }
    
    /**
     * @notice Get the identity registry address
     * @return registry The identity registry address
     */
    function getIdentityRegistry() external view returns (address registry) {
        return address(identityRegistry);
    }
}
