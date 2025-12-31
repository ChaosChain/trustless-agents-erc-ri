// SPDX-License-Identifier: CC0-1.0
pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./interfaces/IIdentityRegistry.sol";

/**
 * @title IdentityRegistry
 * @dev ERC-8004 v1.0 Identity Registry - Reference Implementation
 * @notice ERC-721 based agent registry with metadata storage
 * 
 * This contract implements the Identity Registry as specified in ERC-8004 v1.0.
 * Each agent is represented as an ERC-721 NFT, making agents immediately browsable
 * and transferable with NFT-compliant applications.
 * 
 * Key Features:
 * - ERC-721 compliance with URIStorage extension
 * - Flexible registration with optional metadata
 * - On-chain key-value metadata storage
 * - Transferable agent ownership
 * 
 * @author ChaosChain Labs
 */
contract IdentityRegistry is ERC721URIStorage, ReentrancyGuard, IIdentityRegistry {
    using Counters for Counters.Counter;

    // ============ State Variables ============
    
    /// @dev Counter for agent IDs (tokenIds)
    Counters.Counter private _agentIdCounter;
    
    /// @dev Mapping from agentId to metadata key to metadata value
    mapping(uint256 => mapping(string => bytes)) private _metadata;

    // ============ Constructor ============
    
    /**
     * @dev Initializes the ERC-721 contract with name and symbol
     */
    constructor() ERC721("ERC-8004 Trustless Agent", "AGENT") {
        // Agent IDs start from 1 (0 is reserved for non-existent agents)
        _agentIdCounter.increment();
    }

    // ============ Registration Functions ============
    
    /**
     * @notice Register a new agent with tokenURI and metadata
     * @param tokenURI_ The URI pointing to the agent's registration JSON file
     * @param metadata Array of metadata entries to set for the agent
     * @return agentId The newly assigned agent ID
     */
    function register(
        string calldata tokenURI_, 
        MetadataEntry[] calldata metadata
    ) external nonReentrant returns (uint256 agentId) {
        agentId = _mintAgent(msg.sender, tokenURI_);
        
        // Set metadata if provided
        if (metadata.length > 0) {
            _setMetadataBatch(agentId, metadata);
        }
    }
    
    /**
     * @notice Register a new agent with tokenURI only
     * @param tokenURI_ The URI pointing to the agent's registration JSON file
     * @return agentId The newly assigned agent ID
     */
    function register(string calldata tokenURI_) external nonReentrant returns (uint256 agentId) {
        agentId = _mintAgent(msg.sender, tokenURI_);
    }
    
    /**
     * @notice Register a new agent without tokenURI (can be set later)
     * @dev The tokenURI can be set later using _setTokenURI() by the owner
     * @return agentId The newly assigned agent ID
     */
    function register() external nonReentrant returns (uint256 agentId) {
        agentId = _mintAgent(msg.sender, "");
    }

    // ============ Metadata Functions ============
    
    /**
     * @notice Set metadata for an agent
     * @dev Only the owner or approved operator can set metadata
     * @param agentId The agent ID
     * @param key The metadata key
     * @param value The metadata value as bytes
     */
    function setMetadata(
        uint256 agentId, 
        string calldata key, 
        bytes calldata value
    ) external {
        require(_isApprovedOrOwner(msg.sender, agentId), "Not authorized");
        require(bytes(key).length > 0, "Empty key");
        
        _metadata[agentId][key] = value;
        
        emit MetadataSet(agentId, key, key, value);
    }
    
    /**
     * @notice Get metadata for an agent
     * @param agentId The agent ID
     * @param key The metadata key
     * @return value The metadata value as bytes
     */
    function getMetadata(
        uint256 agentId, 
        string calldata key
    ) external view returns (bytes memory value) {
        require(_exists(agentId), "Agent does not exist");
        return _metadata[agentId][key];
    }

    // ============ View Functions ============
    
    /**
     * @notice Get the total number of registered agents
     * @return count The total number of agents
     */
    function totalAgents() external view returns (uint256 count) {
        return _agentIdCounter.current() - 1;
    }
    
    /**
     * @notice Check if an agent exists
     * @param agentId The agent ID to check
     * @return exists True if the agent exists
     */
    function agentExists(uint256 agentId) external view returns (bool exists) {
        return _exists(agentId);
    }

    // ============ Internal Functions ============
    
    /**
     * @dev Mints a new agent NFT
     * @param to The address to mint the agent to
     * @param tokenURI_ The token URI
     * @return agentId The newly minted agent ID
     */
    function _mintAgent(
        address to, 
        string memory tokenURI_
    ) internal returns (uint256 agentId) {
        agentId = _agentIdCounter.current();
        _agentIdCounter.increment();
        
        _safeMint(to, agentId);
        
        if (bytes(tokenURI_).length > 0) {
            _setTokenURI(agentId, tokenURI_);
        }
        
        emit Registered(agentId, tokenURI_, to);
    }
    
    /**
     * @dev Sets multiple metadata entries in batch
     * @param agentId The agent ID
     * @param metadata Array of metadata entries
     */
    function _setMetadataBatch(
        uint256 agentId, 
        MetadataEntry[] calldata metadata
    ) internal {
        for (uint256 i = 0; i < metadata.length; i++) {
            require(bytes(metadata[i].key).length > 0, "Empty key");
            _metadata[agentId][metadata[i].key] = metadata[i].value;
            emit MetadataSet(
                agentId, 
                metadata[i].key, 
                metadata[i].key, 
                metadata[i].value
            );
        }
    }

    function supportsInterface(bytes4 interfaceId)
    public
    view
    override(ERC721, IERC165)
    returns (bool)
{
    return interfaceId == type(IIdentityRegistry).interfaceId || super.supportsInterface(interfaceId);
}
}
