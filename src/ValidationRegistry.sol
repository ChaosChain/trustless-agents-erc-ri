// SPDX-License-Identifier: CC0-1.0
pragma solidity 0.8.19;

import "./IdentityRegistry.sol";
import "./interfaces/IValidationRegistry.sol";

/**
 * @title ValidationRegistry
 * @dev ERC-8004 Validation Registry - Reference Implementation (Jan 2026 Update)
 * @notice Generic hooks for requesting and recording independent validation
 * 
 * ⚠️ WARNING: This section is still under active updates with the TEE community.
 * Expect further changes later in 2026. Consider this EXPERIMENTAL.
 * 
 * This contract implements the Validation Registry as specified in ERC-8004 (Jan 2026 Update).
 * It enables agents to request verification of their work and allows validator
 * smart contracts to provide responses that can be tracked on-chain.
 * 
 * Key Changes in Jan 2026 Update:
 * - ✅ NEW: String tags instead of bytes32 (more flexible, human-readable)
 * - ✅ NEW: Consistent URI naming (requestURI, responseURI)
 * - ✅ NEW: requestHash is now mandatory (commitment to request payload)
 * - Support for various validation methods (stake-secured, zkML, TEE)
 * 
 * @author ChaosChain Labs
 */
contract ValidationRegistry is IValidationRegistry {

    // ============ State Variables ============
    
    /// @dev Reference to the IdentityRegistry
    IdentityRegistry public immutable identityRegistry;
    
    /// @dev Struct to store validation request data
    struct Request {
        address validatorAddress;
        uint256 agentId;
        string requestURI;
        bytes32 requestHash;
        uint256 timestamp;
    }
    
    /// @dev Struct to store validation response data
    struct Response {
        address validatorAddress;
        uint256 agentId;
        uint8 response;
        bytes32 responseHash;
        string tag;
        uint256 lastUpdate;
    }
    
    /// @dev requestHash => Request
    mapping(bytes32 => Request) private _requests;
    
    /// @dev requestHash => Response
    mapping(bytes32 => Response) private _responses;
    
    /// @dev agentId => array of requestHashes
    mapping(uint256 => bytes32[]) private _agentValidations;
    
    /// @dev validatorAddress => array of requestHashes
    mapping(address => bytes32[]) private _validatorRequests;
    
    /// @dev requestHash => exists in arrays
    mapping(bytes32 => bool) private _requestExists;

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
    ) external {
        // Validate inputs
        require(validatorAddress != address(0), "Invalid validator address");
        require(bytes(requestURI).length > 0, "Empty request URI");
        require(requestHash != bytes32(0), "Request hash required");
        require(identityRegistry.agentExists(agentId), "Agent does not exist");
        
        // Verify caller is owner or approved operator
        address agentOwner = identityRegistry.ownerOf(agentId);
        require(
            msg.sender == agentOwner ||
            identityRegistry.isApprovedForAll(agentOwner, msg.sender) ||
            identityRegistry.getApproved(agentId) == msg.sender,
            "Not authorized"
        );
        
        // SECURITY: Prevent self-validation (defeats purpose of independent validation)
        // As per ERC-8004 (Jan 2026 Update) intent: "independent validators checks"
        require(validatorAddress != agentOwner, "Self-validation not allowed");
        require(validatorAddress != msg.sender, "Self-validation not allowed");
        
        // SECURITY: Prevent requestHash hijacking
        // Once a request exists, it cannot be overwritten
        require(!_requestExists[requestHash], "Request hash already exists");
        
        // Store request
        _requests[requestHash] = Request({
            validatorAddress: validatorAddress,
            agentId: agentId,
            requestURI: requestURI,
            requestHash: requestHash,
            timestamp: block.timestamp
        });
        
        // Add to tracking arrays
        _agentValidations[agentId].push(requestHash);
        _validatorRequests[validatorAddress].push(requestHash);
        _requestExists[requestHash] = true;
        
        emit ValidationRequest(validatorAddress, agentId, requestURI, requestHash);
    }
    
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
    ) external {
        // Validate response range
        require(response <= 100, "Response must be 0-100");
        
        // Get request
        Request storage request = _requests[requestHash];
        require(request.validatorAddress != address(0), "Request not found");
        
        // Verify caller is the designated validator
        require(msg.sender == request.validatorAddress, "Not authorized validator");
        
        // Store or update response
        _responses[requestHash] = Response({
            validatorAddress: request.validatorAddress,
            agentId: request.agentId,
            response: response,
            responseHash: responseHash,
            tag: tag,
            lastUpdate: block.timestamp
        });
        
        emit ValidationResponse(
            request.validatorAddress,
            request.agentId,
            requestHash,
            response,
            responseURI,
            responseHash,
            tag
        );
    }

    // ============ Read Functions ============
    
    /**
     * @notice Get validation status for a request
     * @dev Returns default values (address(0), 0, 0, bytes32(0), "", 0) for pending requests without responses
     * @dev To distinguish pending from non-existent requests, check if request exists via requestExists()
     * @param requestHash The request hash
     * @return validatorAddress The validator address (address(0) if no response yet)
     * @return agentId The agent ID (0 if no response yet)
     * @return response The validation response (0-100, or 0 if no response yet)
     * @return responseHash The hash of the response data (bytes32(0) if no response yet)
     * @return tag The response tag ("" if no response yet)
     * @return lastUpdate Timestamp of last update (0 if no response yet)
     */
    function getValidationStatus(bytes32 requestHash) external view returns (
        address validatorAddress,
        uint256 agentId,
        uint8 response,
        bytes32 responseHash,
        string memory tag,
        uint256 lastUpdate
    ) {
        Response storage resp = _responses[requestHash];
        
        // Return default values for pending requests (no revert)
        // This allows callers to distinguish between:
        // - Non-existent request: validatorAddress == 0 && !_requestExists[requestHash]
        // - Pending request: validatorAddress == 0 && _requestExists[requestHash]
        // - Responded request: validatorAddress != 0
        return (
            resp.validatorAddress,
            resp.agentId,
            resp.response,
            resp.responseHash,
            resp.tag,
            resp.lastUpdate
        );
    }
    
    /**
     * @notice Get aggregated validation summary for an agent
     * @dev IMPORTANT: This function is designed for OFF-CHAIN consumption.
     *      For agents with many validation requests, calling without filters may exceed gas limits.
     *      Use the `validatorAddresses` and/or `tag` filters for popular agents to prevent DoS.
     *      As per ERC-8004 (Jan 2026 Update): validation aggregation is expected to happen off-chain.
     * @param agentId The agent ID (mandatory)
     * @param validatorAddresses Filter by validators (RECOMMENDED for popular agents)
     * @param tag Filter by tag (optional, empty string to skip)
     * @return count Number of validations
     * @return averageResponse Average response value (0-100)
     */
    function getSummary(
        uint256 agentId,
        address[] calldata validatorAddresses,
        string calldata tag
    ) external view returns (uint64 count, uint8 averageResponse) {
        bytes32[] memory requestHashes = _agentValidations[agentId];
        
        uint256 totalResponse = 0;
        uint64 validCount = 0;
        bool filterTag = bytes(tag).length > 0;
        
        for (uint256 i = 0; i < requestHashes.length; i++) {
            Response storage resp = _responses[requestHashes[i]];
            
            // Skip if no response yet
            if (resp.validatorAddress == address(0)) continue;
            
            // Apply validator filter
            if (validatorAddresses.length > 0) {
                bool matchesValidator = false;
                for (uint256 j = 0; j < validatorAddresses.length; j++) {
                    if (resp.validatorAddress == validatorAddresses[j]) {
                        matchesValidator = true;
                        break;
                    }
                }
                if (!matchesValidator) continue;
            }
            
            // Apply tag filter
            if (filterTag && keccak256(bytes(resp.tag)) != keccak256(bytes(tag))) continue;
            
            totalResponse += resp.response;
            validCount++;
        }
        
        count = validCount;
        averageResponse = validCount > 0 ? uint8(totalResponse / validCount) : 0;
    }
    
    /**
     * @notice Get all validation request hashes for an agent
     * @param agentId The agent ID
     * @return requestHashes Array of request hashes
     */
    function getAgentValidations(uint256 agentId) external view returns (bytes32[] memory requestHashes) {
        return _agentValidations[agentId];
    }
    
    /**
     * @notice Get all validation request hashes for a validator
     * @param validatorAddress The validator address
     * @return requestHashes Array of request hashes
     */
    function getValidatorRequests(address validatorAddress) external view returns (bytes32[] memory requestHashes) {
        return _validatorRequests[validatorAddress];
    }
    
    /**
     * @notice Check if a validation request exists
     * @param requestHash The request hash
     * @return exists True if the request has been created
     */
    function requestExists(bytes32 requestHash) external view returns (bool exists) {
        return _requestExists[requestHash];
    }
    
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
    ) {
        Request storage request = _requests[requestHash];
        require(request.validatorAddress != address(0), "Request not found");
        
        return (
            request.validatorAddress,
            request.agentId,
            request.requestURI,
            request.timestamp
        );
    }
    
    /**
     * @notice Get the identity registry address
     * @return registry The identity registry address
     */
    function getIdentityRegistry() external view returns (address registry) {
        return address(identityRegistry);
    }
}
