// SPDX-License-Identifier: CC0-1.0
pragma solidity 0.8.19;

/**
 * @title IValidationRegistry
 * @dev Interface for ERC-8004 Validation Registry (Jan 2026 Update)
 * @notice Generic hooks for requesting and recording independent validation
 * 
 * ⚠️ WARNING: This section is still under active updates with the TEE community.
 * Expect further changes later in 2026. Consider this EXPERIMENTAL.
 * 
 * This interface enables agents to request verification of their work and allows
 * validator smart contracts to provide responses that can be tracked on-chain.
 * Supports various validation methods including stake-secured, zkML, and TEE.
 * 
 * @author ChaosChain Labs
 */
interface IValidationRegistry {
    
    // ============ Events ============
    
    /**
     * @dev Emitted when a validation request is made
     */
    event ValidationRequest(
        address indexed validatorAddress,
        uint256 indexed agentId,
        string requestURI,
        bytes32 indexed requestHash
    );
    
    /**
     * @dev Emitted when a validation response is provided
     */
    event ValidationResponse(
        address indexed validatorAddress,
        uint256 indexed agentId,
        bytes32 indexed requestHash,
        uint8 response,
        string responseURI,
        bytes32 responseHash,
        string tag
    );

    // ============ Core Functions ============
    
    /**
     * @notice Request validation for an agent's work
     * @dev Must be called by the owner or operator of the agent
     * @param validatorAddress The address of the validator (can be EOA or contract)
     * @param agentId The agent requesting validation
     * @param requestURI URI pointing to off-chain validation data
     * @param requestHash KECCAK-256 hash of request payload (mandatory)
     */
    function validationRequest(
        address validatorAddress,
        uint256 agentId,
        string calldata requestURI,
        bytes32 requestHash
    ) external;
    
    /**
     * @notice Provide a validation response
     * @dev Must be called by the validator address specified in the request
     * @dev Can be called multiple times for progressive validation states
     * @param requestHash The hash of the validation request
     * @param response The validation result (0-100)
     * @param responseURI URI pointing to validation evidence (optional)
     * @param responseHash KECCAK-256 hash of response data (optional for IPFS)
     * @param tag Custom tag for categorization (optional)
     */
    function validationResponse(
        bytes32 requestHash,
        uint8 response,
        string calldata responseURI,
        bytes32 responseHash,
        string calldata tag
    ) external;

    // ============ Read Functions ============
    
    /**
     * @notice Get validation status for a request
     * @param requestHash The request hash
     * @return validatorAddress The validator address
     * @return agentId The agent ID
     * @return response The validation response (0-100)
     * @return responseHash The hash of the response data
     * @return tag The response tag
     * @return lastUpdate Timestamp of last update
     */
    function getValidationStatus(bytes32 requestHash) external view returns (
        address validatorAddress,
        uint256 agentId,
        uint8 response,
        bytes32 responseHash,
        string memory tag,
        uint256 lastUpdate
    );
    
    /**
     * @notice Get aggregated validation summary for an agent
     * @param agentId The agent ID (mandatory)
     * @param validatorAddresses Filter by validators (optional)
     * @param tag Filter by tag (optional, use empty string to skip)
     * @return count Number of validations
     * @return averageResponse Average response value (0-100)
     */
    function getSummary(
        uint256 agentId,
        address[] calldata validatorAddresses,
        string calldata tag
    ) external view returns (uint64 count, uint8 averageResponse);
    
    /**
     * @notice Get all validation request hashes for an agent
     * @param agentId The agent ID
     * @return requestHashes Array of request hashes
     */
    function getAgentValidations(uint256 agentId) external view returns (bytes32[] memory requestHashes);
    
    /**
     * @notice Get all validation request hashes for a validator
     * @param validatorAddress The validator address
     * @return requestHashes Array of request hashes
     */
    function getValidatorRequests(address validatorAddress) external view returns (bytes32[] memory requestHashes);
    
    /**
     * @notice Check if a validation request exists
     * @param requestHash The request hash
     * @return exists True if the request has been created
     */
    function requestExists(bytes32 requestHash) external view returns (bool exists);
    
    /**
     * @notice Get validation request details
     * @param requestHash The request hash
     * @return validatorAddress The validator address
     * @return agentId The agent ID
     * @return requestURI The request URI
     * @return timestamp The request timestamp
     */
    function getRequest(bytes32 requestHash) external view returns (
        address validatorAddress,
        uint256 agentId,
        string memory requestURI,
        uint256 timestamp
    );
    
    /**
     * @notice Get the identity registry address
     * @return registry The identity registry address
     */
    function getIdentityRegistry() external view returns (address registry);
}
