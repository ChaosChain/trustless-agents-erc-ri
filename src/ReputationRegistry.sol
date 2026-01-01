// SPDX-License-Identifier: CC0-1.0
pragma solidity 0.8.19;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import "./IdentityRegistry.sol";
import "./interfaces/IReputationRegistry.sol";

/**
 * @title ReputationRegistry
 * @dev ERC-8004 v1.0 Reputation Registry - Reference Implementation
 * @notice On-chain feedback system with cryptographic authorization
 * 
 * This contract implements the Reputation Registry as specified in ERC-8004 v1.0.
 * It provides a standard interface for posting and fetching feedback signals with
 * on-chain storage and aggregation capabilities.
 * 
 * Key Features:
 * - Cryptographic feedback authorization (EIP-191/ERC-1271)
 * - On-chain feedback storage with scores (0-100)
 * - Tag-based categorization system
 * - IPFS/URI support with integrity hashes
 * - Feedback revocation
 * - Response appending by any party
 * - On-chain aggregation for composability
 * 
 * @author ChaosChain Labs
 */
contract ReputationRegistry is IReputationRegistry {
    using ECDSA for bytes32;

    // ============ State Variables ============
    
    /// @dev Reference to the IdentityRegistry
    IdentityRegistry public immutable identityRegistry;
    
    /// @dev Struct to store feedback data
    struct Feedback {
        uint8 score;
        bytes32 tag1;
        bytes32 tag2;
        bool isRevoked;
    }
    
    /// @dev Struct for feedback authorization
    struct FeedbackAuth {
        uint256 agentId;
        address clientAddress;
        uint64 indexLimit;
        uint256 expiry;
        uint256 chainId;
        address identityRegistry;
        address signerAddress;
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

    /// @dev Size of FeedbackAuth struct in bytes (7 fields × 32 bytes each)
    uint256 private constant FEEDBACK_AUTH_STRUCT_SIZE = 224;

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
     * @param agentId The agent receiving feedback
     * @param score The feedback score (0-100)
     * @param tag1 First tag for categorization (optional)
     * @param tag2 Second tag for categorization (optional)
     * @param fileuri URI pointing to off-chain feedback data (optional)
     * @param filehash KECCAK-256 hash of the file content (optional for IPFS)
     * @param feedbackAuth Signed authorization from the agent
     */
    function giveFeedback(
        uint256 agentId,
        uint8 score,
        bytes32 tag1,
        bytes32 tag2,
        string calldata fileuri,
        bytes32 filehash,
        bytes memory feedbackAuth
    ) external {
        // Validate score
        require(score <= 100, "Score must be 0-100");
        
        // Verify agent exists
        require(identityRegistry.agentExists(agentId), "Agent does not exist");
        
        // Decode and verify feedback authorization
        FeedbackAuth memory auth = _decodeFeedbackAuth(feedbackAuth);
        
        // Verify authorization parameters
        require(auth.agentId == agentId, "AgentId mismatch");
        require(auth.clientAddress == msg.sender, "ClientAddress mismatch");
        require(auth.chainId == block.chainid, "ChainId mismatch");
        require(auth.identityRegistry == address(identityRegistry), "Registry mismatch");
        require(block.timestamp < auth.expiry, "Authorization expired");
        
        // Get current index for this client-agent pair
        uint64 currentIndex = _lastIndex[agentId][msg.sender] + 1;
        require(currentIndex <= auth.indexLimit, "Index limit exceeded");
        
        // Verify signer is owner or approved operator
        address agentOwner = identityRegistry.ownerOf(agentId);
        
        // SECURITY: Prevent self-feedback to maintain integrity
        require(msg.sender != agentOwner, "Self-feedback not allowed");
        require(
            auth.signerAddress == agentOwner || 
            identityRegistry.isApprovedForAll(agentOwner, auth.signerAddress) ||
            identityRegistry.getApproved(agentId) == auth.signerAddress,
            "Invalid signer"
        );
        
        // Extract signature (last 65 bytes: r=32, s=32, v=1)
        require(feedbackAuth.length >= 289, "Invalid auth data length"); // 224 + 65
        
        bytes32 r;
        bytes32 s;
        uint8 v;
        
        assembly {
            // feedbackAuth layout: [length][FEEDBACK_AUTH_STRUCT_SIZE bytes struct][32 bytes r][32 bytes s][1 byte v]
            let dataPtr := add(feedbackAuth, 32)                 // Skip length prefix
            let sigStart := add(dataPtr, FEEDBACK_AUTH_STRUCT_SIZE) // Start of signature
            r := mload(sigStart)                                 // Load r (32 bytes)
            s := mload(add(sigStart, 32))                        // Load s (32 bytes)
            v := byte(0, mload(add(sigStart, 64)))               // Load v (1 byte)
        }
        
        // Verify signature using EIP-191 (personal sign) or ERC-1271 (smart contract)
        // As per spec: "signed using EIP-191 or ERC-1271"
        bytes32 messageHash = _hashFeedbackAuth(auth);
        
        // Prepare signature bytes for verification
        bytes memory signature = new bytes(65);
        assembly {
            mstore(add(signature, 32), r)
            mstore(add(signature, 64), s)
            mstore8(add(signature, 96), v)
        }
        
        // Try EIP-191 personal sign first (for EOAs) using tryRecover to avoid revert
        (address recoveredSigner, ECDSA.RecoverError error) = ECDSA.tryRecover(messageHash, signature);
        
        // If ECDSA recovery succeeds and matches, accept it
        bool validSignature = (error == ECDSA.RecoverError.NoError && recoveredSigner == auth.signerAddress);
        
        // If EOA recovery fails or doesn't match, try ERC-1271 for smart contract wallets
        if (!validSignature) {
            validSignature = SignatureChecker.isValidSignatureNow(auth.signerAddress, messageHash, signature);
        }
        
        require(validSignature, "Invalid signature");
        
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
        
        emit NewFeedback(agentId, msg.sender, score, tag1, tag2, fileuri, filehash);
    }
    
    /**
     * @notice Revoke previously given feedback
     * @param agentId The agent ID
     * @param feedbackIndex The feedback index to revoke
     */
    function revokeFeedback(uint256 agentId, uint64 feedbackIndex) external {
        require(identityRegistry.agentExists(agentId), "Agent does not exist");

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
     * @param responseUri URI pointing to the response data
     * @param responseHash KECCAK-256 hash of response content (optional for IPFS)
     */
    function appendResponse(
        uint256 agentId,
        address clientAddress,
        uint64 feedbackIndex,
        string calldata responseUri,
        bytes32 responseHash
    ) external {
        require(identityRegistry.agentExists(agentId), "Agent does not exist");

        require(feedbackIndex > 0 && feedbackIndex <= _lastIndex[agentId][clientAddress], "Invalid index");
        require(bytes(responseUri).length > 0, "Empty URI");
        
        // Increment response count for this responder
        _responseCount[agentId][clientAddress][feedbackIndex][msg.sender]++;
        
        emit ResponseAppended(agentId, clientAddress, feedbackIndex, msg.sender, responseUri, responseHash);
    }

    // ============ Read Functions ============
    
    /**
     * @notice Get aggregated summary for an agent
     * @dev IMPORTANT: This function is designed for OFF-CHAIN consumption.
     *      For agents with many feedback entries, calling without filters may exceed gas limits.
     *      ALWAYS use the `clientAddresses` filter for popular agents to prevent DoS.
     *      As per ERC-8004 v1.0 spec (line 209): "Without filtering by clientAddresses,
     *      results are subject to Sybil/spam attacks."
     * @param agentId The agent ID (mandatory)
     * @param clientAddresses Filter by specific clients (RECOMMENDED for popular agents)
     * @param tag1 Filter by tag1 (optional, bytes32(0) to skip)
     * @param tag2 Filter by tag2 (optional, bytes32(0) to skip)
     * @return count Number of feedback entries
     * @return averageScore Average score (0-100)
     */
    function getSummary(
        uint256 agentId,
        address[] calldata clientAddresses,
        bytes32 tag1,
        bytes32 tag2
    ) external view returns (uint64 count, uint8 averageScore) {
        require(identityRegistry.agentExists(agentId), "Agent does not exist");

        address[] memory clients;
        if (clientAddresses.length > 0) {
            clients = clientAddresses;
        } else {
            clients = _clients[agentId];
        }
        
        uint256 totalScore = 0;
        uint64 validCount = 0;
        
        for (uint256 i = 0; i < clients.length; i++) {
            uint64 lastIdx = _lastIndex[agentId][clients[i]];
            
            for (uint64 j = 1; j <= lastIdx; j++) {
                Feedback storage fb = _feedback[agentId][clients[i]][j];
                
                // Skip revoked feedback
                if (fb.isRevoked) continue;
                
                // Apply tag filters
                if (tag1 != bytes32(0) && fb.tag1 != tag1) continue;
                if (tag2 != bytes32(0) && fb.tag2 != tag2) continue;
                
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
     * @param index The feedback index
     * @return score The feedback score
     * @return tag1 First tag
     * @return tag2 Second tag
     * @return isRevoked Whether the feedback is revoked
     */
    function readFeedback(
        uint256 agentId,
        address clientAddress,
        uint64 index
    ) external view returns (
        uint8 score,
        bytes32 tag1,
        bytes32 tag2,
        bool isRevoked
    ) {
        require(identityRegistry.agentExists(agentId), "Agent does not exist");

        require(index > 0 && index <= _lastIndex[agentId][clientAddress], "Invalid index");
        Feedback storage fb = _feedback[agentId][clientAddress][index];
        return (fb.score, fb.tag1, fb.tag2, fb.isRevoked);
    }
    
    /**
     * @notice Read all feedback for an agent
     * @dev IMPORTANT: This function is designed for OFF-CHAIN consumption (indexers, frontends).
     *      For agents with many feedback entries, calling without filters may exceed gas limits.
     *      ALWAYS use the `clientAddresses` filter for popular agents to prevent DoS.
     *      As per ERC-8004 v1.0 spec: "more complex reputation aggregation will happen off-chain"
     * @param agentId The agent ID (mandatory)
     * @param clientAddresses Filter by clients (RECOMMENDED for popular agents)
     * @param tag1 Filter by tag1 (optional, bytes32(0) to ignore)
     * @param tag2 Filter by tag2 (optional, bytes32(0) to ignore)
     * @param includeRevoked Whether to include revoked feedback
     * @return clients Array of client addresses
     * @return scores Array of scores
     * @return tag1s Array of tag1 values
     * @return tag2s Array of tag2 values
     * @return revokedStatuses Array of revoked statuses
     */
    function readAllFeedback(
        uint256 agentId,
        address[] calldata clientAddresses,
        bytes32 tag1,
        bytes32 tag2,
        bool includeRevoked
    ) external view returns (
        address[] memory clients,
        uint8[] memory scores,
        bytes32[] memory tag1s,
        bytes32[] memory tag2s,
        bool[] memory revokedStatuses
    ) {
        require(identityRegistry.agentExists(agentId), "Agent does not exist");

        address[] memory clientList;
        if (clientAddresses.length > 0) {
            clientList = clientAddresses;
        } else {
            clientList = _clients[agentId];
        }
        
        // Count and populate in a single optimized pass
        uint256 totalCount = _countValidFeedback(agentId, clientList, tag1, tag2, includeRevoked);
        
        // Initialize arrays
        clients = new address[](totalCount);
        scores = new uint8[](totalCount);
        tag1s = new bytes32[](totalCount);
        tag2s = new bytes32[](totalCount);
        revokedStatuses = new bool[](totalCount);
        
        // Populate arrays
        _populateFeedbackArrays(
            agentId,
            clientList,
            tag1,
            tag2,
            includeRevoked,
            clients,
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
        bytes32 tag1,
        bytes32 tag2,
        bool includeRevoked
    ) internal view returns (uint256 totalCount) {
        for (uint256 i = 0; i < clientList.length; i++) {
            uint64 lastIdx = _lastIndex[agentId][clientList[i]];
            for (uint64 j = 1; j <= lastIdx; j++) {
                Feedback storage fb = _feedback[agentId][clientList[i]][j];
                if (!includeRevoked && fb.isRevoked) continue;
                if (tag1 != bytes32(0) && fb.tag1 != tag1) continue;
                if (tag2 != bytes32(0) && fb.tag2 != tag2) continue;
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
        bytes32 tag1,
        bytes32 tag2,
        bool includeRevoked,
        address[] memory clients,
        uint8[] memory scores,
        bytes32[] memory tag1s,
        bytes32[] memory tag2s,
        bool[] memory revokedStatuses
    ) internal view {
        uint256 idx = 0;
        for (uint256 i = 0; i < clientList.length; i++) {
            uint64 lastIdx = _lastIndex[agentId][clientList[i]];
            for (uint64 j = 1; j <= lastIdx; j++) {
                Feedback storage fb = _feedback[agentId][clientList[i]][j];
                if (!includeRevoked && fb.isRevoked) continue;
                if (tag1 != bytes32(0) && fb.tag1 != tag1) continue;
                if (tag2 != bytes32(0) && fb.tag2 != tag2) continue;
                
                clients[idx] = clientList[i];
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
        require(identityRegistry.agentExists(agentId), "Agent does not exist");
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
        require(identityRegistry.agentExists(agentId), "Agent does not exist");
        return _clients[agentId];
    }
    
    /**
     * @notice Get the last feedback index for a client-agent pair
     * @param agentId The agent ID
     * @param clientAddress The client address
     * @return lastIndex The last feedback index
     */
    function getLastIndex(uint256 agentId, address clientAddress) external view returns (uint64 lastIndex) {
        require(identityRegistry.agentExists(agentId), "Agent does not exist");

        return _lastIndex[agentId][clientAddress];
    }
    
    /**
     * @notice Get the identity registry address
     * @return registry The identity registry address
     */
    function getIdentityRegistry() external view returns (address registry) {
        return address(identityRegistry);
    }

    // ============ Internal Functions ============
    
    /**
     * @dev Decode feedback authorization from bytes
     * @param data The encoded authorization data
     * @return auth The decoded FeedbackAuth struct
     */
    function _decodeFeedbackAuth(bytes memory data) internal pure returns (FeedbackAuth memory auth) {
        // Data format: abi.encode(struct fields) + signature (65 bytes)
        require(data.length >= 65 + FEEDBACK_AUTH_STRUCT_SIZE, "Invalid auth data");
        
        // Decode struct fields (first FEEDBACK_AUTH_STRUCT_SIZE bytes)
        bytes memory structData = new bytes(FEEDBACK_AUTH_STRUCT_SIZE);
        for (uint256 i = 0; i < FEEDBACK_AUTH_STRUCT_SIZE; i++) {
            structData[i] = data[i];
        }
        
        (
            auth.agentId,
            auth.clientAddress,
            auth.indexLimit,
            auth.expiry,
            auth.chainId,
            auth.identityRegistry,
            auth.signerAddress
        ) = abi.decode(structData, (uint256, address, uint64, uint256, uint256, address, address));
    }
    
    /**
     * @dev Hash feedback authorization for EIP-191 personal sign
     * @param auth The FeedbackAuth struct
     * @return hash The EIP-191 message hash
     */
    function _hashFeedbackAuth(FeedbackAuth memory auth) internal pure returns (bytes32 hash) {
        // Encode the struct as specified in ERC-8004 v1.0
        bytes32 structHash = keccak256(abi.encode(
            auth.agentId,
            auth.clientAddress,
            auth.indexLimit,
            auth.expiry,
            auth.chainId,
            auth.identityRegistry,
            auth.signerAddress
        ));
        
        // EIP-191 personal sign format: "\x19Ethereum Signed Message:\n32" + hash
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", structHash));
    }
}
