// SPDX-License-Identifier: CC0-1.0
pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";

/**
 * @title IIdentityRegistry
 * @dev Interface for ERC-8004 Identity Registry (Jan 2026 Update)
 * @notice ERC-721 based agent registry with metadata storage
 * 
 * This interface extends ERC-721 to provide agent registration functionality
 * with on-chain metadata storage. Each agent is represented as an NFT, making
 * agents immediately browsable and transferable with NFT-compliant applications.
 * 
 * @author ChaosChain Labs
 */
interface IIdentityRegistry is IERC721, IERC721Metadata {
    
    // ============ Structs ============
    
    /**
     * @dev Metadata entry structure for batch metadata setting
     * @param metadataKey The metadata key
     * @param metadataValue The metadata value as bytes
     */
    struct MetadataEntry {
        string metadataKey;
        bytes metadataValue;
    }

    // ============ Events ============
    
    /**
     * @dev Emitted when a new agent is registered
     * @param agentId The newly assigned agent ID (tokenId)
     * @param agentURI The URI pointing to the agent's registration file
     * @param owner The address that owns the agent NFT
     */
    event Registered(uint256 indexed agentId, string agentURI, address indexed owner);
    
    /**
     * @dev Emitted when metadata is set for an agent
     * @param agentId The agent ID
     * @param indexedMetadataKey Indexed version of the key for filtering
     * @param metadataKey The metadata key
     * @param metadataValue The metadata value
     */
    event MetadataSet(
        uint256 indexed agentId, 
        string indexed indexedMetadataKey, 
        string metadataKey, 
        bytes metadataValue
    );
    
    /**
     * @dev Emitted when agentURI is updated
     * @param agentId The agent ID
     * @param newURI The new agent URI
     * @param updatedBy The address that updated the URI
     */
    event URIUpdated(uint256 indexed agentId, string newURI, address indexed updatedBy);
    
    /**
     * @dev Emitted when agentWallet is set or updated
     * @param agentId The agent ID
     * @param newWallet The new wallet address
     * @param setBy The address that set the wallet
     */
    event AgentWalletSet(uint256 indexed agentId, address indexed newWallet, address indexed setBy);

    // ============ Registration Functions ============
    
    /**
     * @notice Register a new agent with agentURI and metadata
     * @param agentURI The URI pointing to the agent's registration JSON file
     * @param metadata Array of metadata entries to set for the agent
     * @return agentId The newly assigned agent ID
     */
    function register(
        string calldata agentURI, 
        MetadataEntry[] calldata metadata
    ) external returns (uint256 agentId);
    
    /**
     * @notice Register a new agent with agentURI only
     * @param agentURI The URI pointing to the agent's registration JSON file
     * @return agentId The newly assigned agent ID
     */
    function register(string calldata agentURI) external returns (uint256 agentId);
    
    /**
     * @notice Register a new agent without agentURI (can be set later)
     * @dev The agentURI can be set later using setAgentURI() by the owner
     * @return agentId The newly assigned agent ID
     */
    function register() external returns (uint256 agentId);

    // ============ Metadata Functions ============
    
    /**
     * @notice Set metadata for an agent
     * @dev Only the owner or approved operator can set metadata
     * @dev Cannot set the reserved "agentWallet" key - use setAgentWallet() instead
     * @param agentId The agent ID
     * @param metadataKey The metadata key
     * @param metadataValue The metadata value as bytes
     */
    function setMetadata(
        uint256 agentId, 
        string calldata metadataKey, 
        bytes calldata metadataValue
    ) external;
    
    /**
     * @notice Get metadata for an agent
     * @param agentId The agent ID
     * @param metadataKey The metadata key
     * @return metadataValue The metadata value as bytes
     */
    function getMetadata(
        uint256 agentId, 
        string calldata metadataKey
    ) external view returns (bytes memory metadataValue);
    
    /**
     * @notice Update the agentURI for an agent
     * @dev Only the owner or approved operator can update
     * @param agentId The agent ID
     * @param newURI The new agent URI
     */
    function setAgentURI(uint256 agentId, string calldata newURI) external;
    
    /**
     * @notice Set the agentWallet address with signature verification
     * @dev The new wallet must sign to prove ownership (EIP-712 for EOA, ERC-1271 for contracts)
     * @dev Only the owner or approved operator can call this
     * @param agentId The agent ID
     * @param newWallet The new wallet address
     * @param deadline Signature expiration timestamp
     * @param signature The signature from newWallet proving ownership
     */
    function setAgentWallet(
        uint256 agentId,
        address newWallet,
        uint256 deadline,
        bytes calldata signature
    ) external;
    
    /**
     * @notice Get the agentWallet address for an agent
     * @param agentId The agent ID
     * @return wallet The agent's payment wallet address
     */
    function getAgentWallet(uint256 agentId) external view returns (address wallet);
    
    /**
     * @notice Clear the agentWallet address (reset to zero address)
     * @dev Only the owner or approved operator can call this
     * @param agentId The agent ID
     */
    function unsetAgentWallet(uint256 agentId) external;

    // ============ View Functions ============
    
    /**
     * @notice Get the total number of registered agents
     * @return count The total number of agents
     */
    function totalAgents() external view returns (uint256 count);
    
    /**
     * @notice Check if an agent exists
     * @param agentId The agent ID to check
     * @return exists True if the agent exists
     */
    function agentExists(uint256 agentId) external view returns (bool exists);
}
