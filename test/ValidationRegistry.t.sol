// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/IdentityRegistry.sol";
import "../src/ValidationRegistry.sol";

/**
 * @title ValidationRegistryTest
 * @dev Comprehensive test suite for ERC-8004 v1.0 Validation Registry
 * @author ChaosChain Labs
 */
contract ValidationRegistryTest is Test {
    IdentityRegistry public identityRegistry;
    ValidationRegistry public validationRegistry;
    
    address public agentOwner = address(0x1);
    address public validator = address(0x2);
    address public validator2 = address(0x3);
    
    uint256 public agentId;
    
    string constant TOKEN_URI = "ipfs://QmTest/agent.json";
    string constant REQUEST_URI = "ipfs://QmRequest/validation-request.json";
    string constant RESPONSE_URI = "ipfs://QmResponse/validation-response.json";
    
    bytes32 constant REQUEST_HASH = keccak256("request_data");
    bytes32 constant RESPONSE_HASH = keccak256("response_data");
    string constant TAG = "hard-finality";
    
    event ValidationRequest(
        address indexed validatorAddress,
        uint256 indexed agentId,
        string requestUri,
        bytes32 indexed requestHash
    );
    
    event ValidationResponse(
        address indexed validatorAddress,
        uint256 indexed agentId,
        bytes32 indexed requestHash,
        uint8 response,
        string responseURI,
        bytes32 responseHash,
        string tag
    );

    function setUp() public {
        identityRegistry = new IdentityRegistry();
        validationRegistry = new ValidationRegistry(address(identityRegistry));
        
        // Register agent
        vm.prank(agentOwner);
        agentId = identityRegistry.register(TOKEN_URI);
    }

    // ============ Validation Request Tests ============

    function test_ValidationRequest_Success() public {
        vm.prank(agentOwner);
        vm.expectEmit(true, true, true, true);
        emit ValidationRequest(validator, agentId, REQUEST_URI, REQUEST_HASH);
        
        validationRegistry.validationRequest(validator, agentId, REQUEST_URI, REQUEST_HASH);
        
        // Verify request was stored
        (address validatorAddr, uint256 storedAgentId, string memory requestUri, uint256 timestamp) = 
            validationRegistry.getRequest(REQUEST_HASH);
        
        assertEq(validatorAddr, validator);
        assertEq(storedAgentId, agentId);
        assertEq(requestUri, REQUEST_URI);
        assertEq(timestamp, block.timestamp);
        
        // Verify tracking arrays
        bytes32[] memory agentValidations = validationRegistry.getAgentValidations(agentId);
        assertEq(agentValidations.length, 1);
        assertEq(agentValidations[0], REQUEST_HASH);
        
        bytes32[] memory validatorRequests = validationRegistry.getValidatorRequests(validator);
        assertEq(validatorRequests.length, 1);
        assertEq(validatorRequests[0], REQUEST_HASH);
    }
    
    function test_ValidationRequest_RequiresHash() public {
        // Jan 2026 Update: requestHash is now mandatory (not auto-generated)
        vm.prank(agentOwner);
        vm.expectRevert("Request hash required");
        validationRegistry.validationRequest(validator, agentId, REQUEST_URI, bytes32(0));
    }

    function test_ValidationRequest_MultipleRequests() public {
        bytes32 hash1 = keccak256("request1");
        bytes32 hash2 = keccak256("request2");
        
        vm.startPrank(agentOwner);
        validationRegistry.validationRequest(validator, agentId, REQUEST_URI, hash1);
        validationRegistry.validationRequest(validator2, agentId, REQUEST_URI, hash2);
        vm.stopPrank();
        
        bytes32[] memory agentValidations = validationRegistry.getAgentValidations(agentId);
        assertEq(agentValidations.length, 2);
    }
    
    function test_ValidationRequest_InvalidValidator_Reverts() public {
        vm.prank(agentOwner);
        vm.expectRevert("Invalid validator address");
        validationRegistry.validationRequest(address(0), agentId, REQUEST_URI, REQUEST_HASH);
    }
    
    function test_ValidationRequest_EmptyURI_Reverts() public {
        vm.prank(agentOwner);
        vm.expectRevert("Empty request URI");
        validationRegistry.validationRequest(validator, agentId, "", REQUEST_HASH);
    }
    
    function test_ValidationRequest_NonExistentAgent_Reverts() public {
        vm.prank(agentOwner);
        vm.expectRevert("Agent does not exist");
        validationRegistry.validationRequest(validator, 999, REQUEST_URI, REQUEST_HASH);
    }
    
    function test_ValidationRequest_NotOwner_Reverts() public {
        vm.prank(validator);
        vm.expectRevert("Not authorized");
        validationRegistry.validationRequest(validator, agentId, REQUEST_URI, REQUEST_HASH);
    }
    
    function test_ValidationRequest_SelfValidation_Reverts() public {
        // Agent owner tries to validate own work
        vm.prank(agentOwner);
        vm.expectRevert("Self-validation not allowed");
        validationRegistry.validationRequest(agentOwner, agentId, REQUEST_URI, REQUEST_HASH);
    }
    
    function test_ValidationRequest_ApprovedOperator_Success() public {
        // Approve operator
        vm.prank(agentOwner);
        identityRegistry.approve(validator, agentId);
        
        // Operator can make validation request
        vm.prank(validator);
        validationRegistry.validationRequest(validator2, agentId, REQUEST_URI, REQUEST_HASH);
        
        (address validatorAddr,,,) = validationRegistry.getRequest(REQUEST_HASH);
        assertEq(validatorAddr, validator2);
    }
    
    function test_ValidationRequest_ApprovedForAll_Success() public {
        // Set approval for all
        vm.prank(agentOwner);
        identityRegistry.setApprovalForAll(validator, true);
        
        // Operator can make validation request
        vm.prank(validator);
        validationRegistry.validationRequest(validator2, agentId, REQUEST_URI, REQUEST_HASH);
        
        (address validatorAddr,,,) = validationRegistry.getRequest(REQUEST_HASH);
        assertEq(validatorAddr, validator2);
    }

    // ============ Validation Response Tests ============

    function test_ValidationResponse_Success() public {
        // Create request first
        vm.prank(agentOwner);
        validationRegistry.validationRequest(validator, agentId, REQUEST_URI, REQUEST_HASH);
        
        // Provide response
        vm.prank(validator);
        vm.expectEmit(true, true, true, true);
        emit ValidationResponse(validator, agentId, REQUEST_HASH, 100, RESPONSE_URI, RESPONSE_HASH, TAG);
        
        validationRegistry.validationResponse(REQUEST_HASH, 100, RESPONSE_URI, RESPONSE_HASH, TAG);
        
        // Verify response was stored
        (address validatorAddr, uint256 storedAgentId, uint8 response, bytes32 storedRespHash, string memory tag, uint256 lastUpdate) = 
            validationRegistry.getValidationStatus(REQUEST_HASH);
        
        assertEq(validatorAddr, validator);
        assertEq(storedAgentId, agentId);
        assertEq(response, 100);
        assertEq(storedRespHash, RESPONSE_HASH);
        assertEq(tag, TAG);
        assertEq(lastUpdate, block.timestamp);
    }
    
    function test_ValidationResponse_MultipleResponses() public {
        // Create request
        vm.prank(agentOwner);
        validationRegistry.validationRequest(validator, agentId, REQUEST_URI, REQUEST_HASH);
        
        // First response (soft finality)
        vm.prank(validator);
        validationRegistry.validationResponse(REQUEST_HASH, 80, RESPONSE_URI, bytes32(0), "soft-finality");

        (,,uint8 response1,, string memory tag1,) = validationRegistry.getValidationStatus(REQUEST_HASH);
        assertEq(response1, 80);
        assertEq(tag1, "soft-finality");
        
        // Second response (hard finality) - updates the first
        vm.prank(validator);
        validationRegistry.validationResponse(REQUEST_HASH, 100, RESPONSE_URI, bytes32(0), "hard-finality");

        (,,uint8 response2,, string memory tag2,) = validationRegistry.getValidationStatus(REQUEST_HASH);
        assertEq(response2, 100);
        assertEq(tag2, "hard-finality");
    }
    
    function test_ValidationResponse_ScoreTooHigh_Reverts() public {
        vm.prank(agentOwner);
        validationRegistry.validationRequest(validator, agentId, REQUEST_URI, REQUEST_HASH);
        
        vm.prank(validator);
        vm.expectRevert("Response must be 0-100");
        validationRegistry.validationResponse(REQUEST_HASH, 101, RESPONSE_URI, bytes32(0), TAG);
    }
    
    function test_ValidationResponse_RequestNotFound_Reverts() public {
        vm.prank(validator);
        vm.expectRevert("Request not found");
        validationRegistry.validationResponse(keccak256("nonexistent"), 100, RESPONSE_URI, bytes32(0), TAG);
    }
    
    function test_ValidationResponse_NotAuthorizedValidator_Reverts() public {
        vm.prank(agentOwner);
        validationRegistry.validationRequest(validator, agentId, REQUEST_URI, REQUEST_HASH);
        
        vm.prank(validator2);
        vm.expectRevert("Not authorized validator");
        validationRegistry.validationResponse(REQUEST_HASH, 100, RESPONSE_URI, bytes32(0), TAG);
    }
    
    function test_ValidationResponse_EmptyResponseURI() public {
        vm.prank(agentOwner);
        validationRegistry.validationRequest(validator, agentId, REQUEST_URI, REQUEST_HASH);
        
        // Empty response URI is allowed
        vm.prank(validator);
        validationRegistry.validationResponse(REQUEST_HASH, 100, "", bytes32(0), TAG);
        
        (,,uint8 response,,,) = validationRegistry.getValidationStatus(REQUEST_HASH);
        assertEq(response, 100);
    }
    
    // ============ Aggregation Tests ============
    
    function test_GetSummary_NoFilters() public {
        // Create multiple validations
        _createAndRespondValidation(validator, 90);
        _createAndRespondValidation(validator2, 80);
        
        address[] memory emptyValidators = new address[](0);
        (uint64 count, uint8 avgResponse) = validationRegistry.getSummary(agentId, emptyValidators, "");
        
        assertEq(count, 2);
        assertEq(avgResponse, 85); // (90 + 80) / 2
    }
    
    function test_GetSummary_FilterByValidator() public {
        _createAndRespondValidation(validator, 90);
        _createAndRespondValidation(validator2, 80);
        
        address[] memory validators = new address[](1);
        validators[0] = validator;
        
        (uint64 count, uint8 avgResponse) = validationRegistry.getSummary(agentId, validators, "");
        
        assertEq(count, 1);
        assertEq(avgResponse, 90);
    }
    
    function test_GetSummary_FilterByTag() public {
        string memory tag1 = "zkml";
        string memory tag2 = "tee";
        
        _createAndRespondValidationWithTag(validator, 90, tag1);
        _createAndRespondValidationWithTag(validator2, 80, tag2);
        
        address[] memory emptyValidators = new address[](0);
        (uint64 count, uint8 avgResponse) = validationRegistry.getSummary(agentId, emptyValidators, tag1);
        
        assertEq(count, 1);
        assertEq(avgResponse, 90);
    }
    
    function test_GetSummary_ExcludesUnresponded() public {
        // Create validation but don't respond
        vm.prank(agentOwner);
        validationRegistry.validationRequest(validator, agentId, REQUEST_URI, keccak256("unresponded"));
        
        // Create and respond to another
        _createAndRespondValidation(validator2, 85);
        
        address[] memory emptyValidators = new address[](0);
        (uint64 count, uint8 avgResponse) = validationRegistry.getSummary(agentId, emptyValidators, "");
        
        assertEq(count, 1);
        assertEq(avgResponse, 85);
    }
    
    // ============ Read Function Tests ============
    
    function test_GetAgentValidations_ReturnsAllRequests() public {
        bytes32 hash1 = keccak256("request1");
        bytes32 hash2 = keccak256("request2");
        
        vm.startPrank(agentOwner);
        validationRegistry.validationRequest(validator, agentId, REQUEST_URI, hash1);
        validationRegistry.validationRequest(validator2, agentId, REQUEST_URI, hash2);
        vm.stopPrank();
        
        bytes32[] memory validations = validationRegistry.getAgentValidations(agentId);
        assertEq(validations.length, 2);
        assertEq(validations[0], hash1);
        assertEq(validations[1], hash2);
    }
    
    function test_GetValidatorRequests_ReturnsAllRequests() public {
        bytes32 hash1 = keccak256("request1");
        bytes32 hash2 = keccak256("request2");
        
        vm.startPrank(agentOwner);
        validationRegistry.validationRequest(validator, agentId, REQUEST_URI, hash1);
        validationRegistry.validationRequest(validator, agentId, REQUEST_URI, hash2);
        vm.stopPrank();
        
        bytes32[] memory requests = validationRegistry.getValidatorRequests(validator);
        assertEq(requests.length, 2);
        assertEq(requests[0], hash1);
        assertEq(requests[1], hash2);
    }
    
    function test_GetRequest_NonExistent_Reverts() public {
        vm.expectRevert("Request not found");
        validationRegistry.getRequest(keccak256("nonexistent"));
    }
    
    function test_GetValidationStatus_NonExistent_ReturnsDefaults() public {
        // Non-existent requests return default values (no revert)
        bytes32 nonExistentHash = keccak256("nonexistent");
        (address validatorAddr, uint256 storedAgentId, uint8 resp, bytes32 respHash, string memory tagStr, uint256 lastUpd) = 
            validationRegistry.getValidationStatus(nonExistentHash);
        
        assertEq(validatorAddr, address(0), "Should return address(0)");
        assertEq(storedAgentId, 0, "Should return 0");
        assertEq(resp, 0, "Should return 0");
        assertEq(respHash, bytes32(0), "Should return bytes32(0)");
        assertEq(bytes(tagStr).length, 0, "Should return empty string");
        assertEq(lastUpd, 0, "Should return 0");
        assertFalse(validationRegistry.requestExists(nonExistentHash), "Should not exist");
    }
    
    function test_GetValidationStatus_Pending_ReturnsDefaults() public {
        // Create request but no response yet
        vm.prank(agentOwner);
        validationRegistry.validationRequest(validator, agentId, REQUEST_URI, REQUEST_HASH);
        
        // Should return defaults for pending request (no revert)
        (address returnedValidator, uint256 returnedAgentId, uint8 response, bytes32 pendingRespHash, string memory pendingTag, uint256 lastUpdate) = 
            validationRegistry.getValidationStatus(REQUEST_HASH);
        
        assertEq(returnedValidator, address(0), "Pending: should return address(0)");
        assertEq(returnedAgentId, 0, "Pending: should return 0");
        assertEq(response, 0, "Pending: should return 0");
        assertEq(pendingRespHash, bytes32(0), "Pending: should return bytes32(0)");
        assertEq(bytes(pendingTag).length, 0, "Pending: should return empty string");
        assertEq(lastUpdate, 0, "Pending: should return 0");
        assertTrue(validationRegistry.requestExists(REQUEST_HASH), "Request should exist");
    }
    
    function test_GetIdentityRegistry_ReturnsCorrectAddress() public {
        assertEq(validationRegistry.getIdentityRegistry(), address(identityRegistry));
    }
    
    // ============ Edge Cases ============
    
    function test_ValidationRequest_SameHashTwice_Reverts() public {
        vm.startPrank(agentOwner);
        validationRegistry.validationRequest(validator, agentId, REQUEST_URI, REQUEST_HASH);
        
        // SECURITY: Attempting to use the same hash again should revert to prevent hijacking
        vm.expectRevert("Request hash already exists");
        validationRegistry.validationRequest(validator, agentId, REQUEST_URI, REQUEST_HASH);
        vm.stopPrank();
    }
    
    function test_ValidationResponse_BinaryScores() public {
        bytes32 hash1 = keccak256("pass");
        bytes32 hash2 = keccak256("fail");
        
        vm.startPrank(agentOwner);
        validationRegistry.validationRequest(validator, agentId, REQUEST_URI, hash1);
        validationRegistry.validationRequest(validator, agentId, REQUEST_URI, hash2);
        vm.stopPrank();
        
        vm.startPrank(validator);
        validationRegistry.validationResponse(hash1, 100, "", bytes32(0), "pass");
        validationRegistry.validationResponse(hash2, 0, "", bytes32(0), "fail");
        vm.stopPrank();
        
        (,,uint8 response1,,,) = validationRegistry.getValidationStatus(hash1);
        (,,uint8 response2,,,) = validationRegistry.getValidationStatus(hash2);
        
        assertEq(response1, 100);
        assertEq(response2, 0);
    }
    
    function test_ValidationResponse_SpectrumScores() public {
        bytes32[] memory hashes = new bytes32[](5);
        uint8[] memory scores = new uint8[](5);
        scores[0] = 20;
        scores[1] = 40;
        scores[2] = 60;
        scores[3] = 80;
        scores[4] = 100;
        
        for (uint i = 0; i < 5; i++) {
            hashes[i] = keccak256(abi.encodePacked("request", i));
            
            vm.prank(agentOwner);
            validationRegistry.validationRequest(validator, agentId, REQUEST_URI, hashes[i]);
            
            vm.prank(validator);
            validationRegistry.validationResponse(hashes[i], scores[i], "", bytes32(0), "");
        }
        
        address[] memory emptyValidators = new address[](0);
        (uint64 count, uint8 avgResponse) = validationRegistry.getSummary(agentId, emptyValidators, "");
        
        assertEq(count, 5);
        assertEq(avgResponse, 60); // (20+40+60+80+100)/5
    }
    
    // ============ Helper Functions ============
    
    function _createAndRespondValidation(address _validator, uint8 score) internal {
        bytes32 hash = keccak256(abi.encodePacked(_validator, score, block.timestamp));
        
        vm.prank(agentOwner);
        validationRegistry.validationRequest(_validator, agentId, REQUEST_URI, hash);
        
        vm.prank(_validator);
        validationRegistry.validationResponse(hash, score, RESPONSE_URI, bytes32(0), TAG);
    }
    
    function _createAndRespondValidationWithTag(address _validator, uint8 score, string memory tag) internal {
        bytes32 hash = keccak256(abi.encodePacked(_validator, score, tag, block.timestamp));
        
        vm.prank(agentOwner);
        validationRegistry.validationRequest(_validator, agentId, REQUEST_URI, hash);
        
        vm.prank(_validator);
        validationRegistry.validationResponse(hash, score, RESPONSE_URI, bytes32(0), tag);
    }
    
    // ============ Fuzz Tests ============
    
    function testFuzz_ValidationResponse_ValidScores(uint8 score) public {
        vm.assume(score <= 100);
        
        vm.prank(agentOwner);
        validationRegistry.validationRequest(validator, agentId, REQUEST_URI, REQUEST_HASH);
        
        vm.prank(validator);
        validationRegistry.validationResponse(REQUEST_HASH, score, RESPONSE_URI, bytes32(0), TAG);
        
        (,,uint8 storedScore,,,) = validationRegistry.getValidationStatus(REQUEST_HASH);
        assertEq(storedScore, score);
    }
    
    function testFuzz_ValidationResponse_InvalidScores(uint8 score) public {
        vm.assume(score > 100);
        
        vm.prank(agentOwner);
        validationRegistry.validationRequest(validator, agentId, REQUEST_URI, REQUEST_HASH);
        
        vm.prank(validator);
        vm.expectRevert("Response must be 0-100");
        validationRegistry.validationResponse(REQUEST_HASH, score, RESPONSE_URI, bytes32(0), TAG);
    }
}
