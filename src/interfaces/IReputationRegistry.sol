// SPDX-License-Identifier: CC0-1.0
pragma solidity 0.8.19;

/**
 * @title IReputationRegistry
 * @dev Interface for ERC-8004 Reputation Registry (Jan 2026 Update)
 * @notice On-chain feedback system - NO PRE-AUTHORIZATION REQUIRED
 * 
 * This interface provides a standard for posting and fetching feedback signals
 * with on-chain storage and aggregation capabilities. In the Jan 2026 update,
 * the feedbackAuth mechanism has been removed - any client can directly submit
 * feedback. Spam and Sybil resistance is handled through off-chain filtering
 * and reputation systems.
 * 
 * Value Representation:
 * - value (int128): Signed fixed-point value (e.g., -32 for -3.2%)
 * - valueDecimals (uint8): Decimal places (0-18, e.g., 1 means divide by 10)
 * 
 * Examples:
 * - 87/100 rating: value=87, valueDecimals=0
 * - -3.2% yield: value=-32, valueDecimals=1
 * - $560 revenue: value=560, valueDecimals=0
 * - 99.77% uptime: value=9977, valueDecimals=2
 * 
 * @author ChaosChain Labs
 */
interface IReputationRegistry {
    
    // ============ Events ============
    
    /**
     * @dev Emitted when new feedback is given
     * @notice indexedTag1 is for filtering, tag1 is the actual readable value
     */
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
    
    /**
     * @dev Emitted when feedback is revoked
     */
    event FeedbackRevoked(
        uint256 indexed agentId,
        address indexed clientAddress,
        uint64 indexed feedbackIndex
    );
    
    /**
     * @dev Emitted when a response is appended to feedback
     */
    event ResponseAppended(
        uint256 indexed agentId,
        address indexed clientAddress,
        uint64 feedbackIndex,
        address indexed responder,
        string responseURI,
        bytes32 responseHash
    );

    // ============ Core Functions ============
    
    /**
     * @notice Give feedback for an agent
     * @dev No pre-authorization required in Jan 2026 Update - direct submission
     * @param agentId The agent receiving feedback
     * @param value The feedback value as signed fixed-point (int128)
     * @param valueDecimals The number of decimal places (0-18)
     * @param tag1 First tag for categorization (optional)
     * @param tag2 Second tag for categorization (optional)
     * @param endpoint The endpoint that was used (optional)
     * @param feedbackURI URI pointing to off-chain feedback data (optional)
     * @param feedbackHash KECCAK-256 hash of the file content (optional for IPFS)
     */
    function giveFeedback(
        uint256 agentId,
        int128 value,
        uint8 valueDecimals,
        string calldata tag1,
        string calldata tag2,
        string calldata endpoint,
        string calldata feedbackURI,
        bytes32 feedbackHash
    ) external;
    
    /**
     * @notice Revoke previously given feedback
     * @param agentId The agent ID
     * @param feedbackIndex The feedback index to revoke
     */
    function revokeFeedback(uint256 agentId, uint64 feedbackIndex) external;
    
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
    ) external;

    // ============ Read Functions ============
    
    /**
     * @notice Get aggregated summary for an agent
     * @param agentId The agent ID (mandatory)
     * @param clientAddresses Filter by specific clients (MUST be provided per spec)
     * @param tag1 Filter by tag1 (optional, use empty string to skip)
     * @param tag2 Filter by tag2 (optional, use empty string to skip)
     * @return count Number of feedback entries
     * @return summaryValue Aggregated value (sum)
     * @return summaryValueDecimals Decimal places for summaryValue
     */
    function getSummary(
        uint256 agentId,
        address[] calldata clientAddresses,
        string calldata tag1,
        string calldata tag2
    ) external view returns (uint64 count, int128 summaryValue, uint8 summaryValueDecimals);
    
    /**
     * @notice Read a specific feedback entry
     * @param agentId The agent ID
     * @param clientAddress The client address
     * @param feedbackIndex The feedback index
     * @return value The feedback value (signed fixed-point)
     * @return valueDecimals The decimal places
     * @return tag1 First tag
     * @return tag2 Second tag
     * @return isRevoked Whether the feedback is revoked
     */
    function readFeedback(
        uint256 agentId,
        address clientAddress,
        uint64 feedbackIndex
    ) external view returns (
        int128 value,
        uint8 valueDecimals,
        string memory tag1,
        string memory tag2,
        bool isRevoked
    );
    
    /**
     * @notice Read all feedback for an agent
     * @param agentId The agent ID (mandatory)
     * @param clientAddresses Filter by clients (optional)
     * @param tag1 Filter by tag1 (optional)
     * @param tag2 Filter by tag2 (optional)
     * @param includeRevoked Whether to include revoked feedback
     * @return clients Array of client addresses
     * @return feedbackIndexes Array of feedback indexes
     * @return values Array of values (int128)
     * @return valueDecimals Array of value decimals
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
        address[] memory clients,
        uint64[] memory feedbackIndexes,
        int128[] memory values,
        uint8[] memory valueDecimals,
        string[] memory tag1s,
        string[] memory tag2s,
        bool[] memory revokedStatuses
    );
    
    /**
     * @notice Get response count for a feedback entry
     * @param agentId The agent ID (mandatory)
     * @param clientAddress The client address (optional)
     * @param feedbackIndex The feedback index (optional)
     * @param responders Filter by responders (optional)
     * @return count Total response count
     */
    function getResponseCount(
        uint256 agentId,
        address clientAddress,
        uint64 feedbackIndex,
        address[] calldata responders
    ) external view returns (uint64 count);
    
    /**
     * @notice Get all clients who gave feedback to an agent
     * @param agentId The agent ID
     * @return clientList Array of client addresses
     */
    function getClients(uint256 agentId) external view returns (address[] memory clientList);
    
    /**
     * @notice Get the last feedback index for a client-agent pair
     * @param agentId The agent ID
     * @param clientAddress The client address
     * @return lastIndex The last feedback index
     */
    function getLastIndex(uint256 agentId, address clientAddress) external view returns (uint64 lastIndex);
    
    /**
     * @notice Get the identity registry address
     * @return registry The identity registry address
     */
    function getIdentityRegistry() external view returns (address registry);
}
