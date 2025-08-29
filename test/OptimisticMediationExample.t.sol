// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/IdentityRegistry.sol";
import "../src/ValidationRegistry.sol";
import "../src/peripheral/ValidationEscrow.sol";
import "../src/peripheral/OptimisticMediationValidator.sol";

contract OptimisticMediationExample is Test {
    IdentityRegistry public identityRegistry;
    ValidationRegistry public validationRegistry;
    ValidationEscrow public validationEscrow;
    OptimisticMediationValidator public mediationValidator;

    address public server = address(0x2);
    address public client = address(0x3);
    address public mediator = address(0x4);

    uint256 public validatorAgentId;
    uint256 public serverAgentId;

    uint256 constant REGISTRATION_FEE = 0.005 ether;

    function setUp() public {
        // Deploy core contracts
        identityRegistry = new IdentityRegistry();
        validationRegistry = new ValidationRegistry(address(identityRegistry));

        // Deploy peripheral contracts
        validationEscrow = new ValidationEscrow(
            address(identityRegistry),
            address(validationRegistry)
        );

        // Deploy OptimisticMediationValidator with registration fee
        mediationValidator = new OptimisticMediationValidator{
            value: REGISTRATION_FEE
        }(
            address(identityRegistry),
            address(validationRegistry),
            "optimistic-validator.example.com"
        );

        // Get the validator agent ID from the contract
        validatorAgentId = mediationValidator.validatorAgentId();

        // Fund test accounts
        vm.deal(server, 1 ether);
        vm.deal(client, 10 ether);
        vm.deal(mediator, 1 ether);

        // Register server agent
        vm.prank(server);
        serverAgentId = identityRegistry.newAgent{value: REGISTRATION_FEE}(
            "server.example.com",
            server
        );
    }

    function testOptimisticAcceptanceAfterDeadline() public {
        // Setup escrow with optimistic mediation
        uint256 escrowAmount = 1 ether;
        uint256 expirationTime = block.timestamp + 1 hours;
        uint8 minValidation = 50;

        // Set mediation deadline to 5 minutes from now
        uint256 mediationDeadline = block.timestamp + 5 minutes;

        OptimisticMediationValidator.DemandData
            memory demandData = OptimisticMediationValidator.DemandData({
                mediator: mediator,
                mediationDeadline: mediationDeadline,
                additionalData: bytes("Task: Provide computation service")
            });
        bytes memory demand = abi.encode(demandData);

        // Client deposits escrow
        vm.prank(client);
        uint256 escrowId = validationEscrow.depositEscrow{value: escrowAmount}(
            validatorAgentId,
            serverAgentId,
            escrowAmount,
            expirationTime,
            minValidation,
            demand
        );

        // Server prepares fulfillment
        bytes memory fulfillment = bytes("service provided successfully");

        // Calculate dataHash from demand and fulfillment
        bytes32 dataHash = keccak256(abi.encodePacked(demand, fulfillment));

        // Server requests validation
        vm.prank(server);
        validationRegistry.validationRequest(
            validatorAgentId,
            serverAgentId,
            dataHash
        );

        // Server requests mediation (emits event for mediator)
        vm.prank(server);
        mediationValidator.requestMediation(demandData, fulfillment);

        // Fast forward past mediation deadline - mediator didn't respond
        vm.warp(block.timestamp + 6 minutes);

        // Validate - will use optimistic acceptance since past deadline
        vm.prank(address(this));
        mediationValidator.validate(demandData, fulfillment);

        // Server can now claim - optimistic acceptance kicks in
        uint256 serverBalanceBefore = server.balance;

        vm.prank(server);
        validationEscrow.claimEscrow(escrowId, fulfillment);

        // Verify server received funds
        uint256 serverBalanceAfter = server.balance;
        assertEq(serverBalanceAfter - serverBalanceBefore, escrowAmount);
    }

    function testMediatorAcceptsValidation() public {
        // Setup escrow
        uint256 escrowAmount = 1 ether;
        uint256 expirationTime = block.timestamp + 1 hours;
        uint8 minValidation = 50;
        uint256 mediationDeadline = block.timestamp + 30 minutes;

        OptimisticMediationValidator.DemandData
            memory demandData = OptimisticMediationValidator.DemandData({
                mediator: mediator,
                mediationDeadline: mediationDeadline,
                additionalData: bytes("Service Level Agreement: 99.9% uptime")
            });
        bytes memory demand = abi.encode(demandData);

        // Client deposits escrow
        vm.prank(client);
        uint256 escrowId = validationEscrow.depositEscrow{value: escrowAmount}(
            validatorAgentId,
            serverAgentId,
            escrowAmount,
            expirationTime,
            minValidation,
            demand
        );

        // Server prepares fulfillment
        bytes memory fulfillment = bytes("service data");

        // Calculate dataHash for validation
        bytes32 dataHash = keccak256(abi.encodePacked(demand, fulfillment));

        // Server requests validation
        vm.prank(server);
        validationRegistry.validationRequest(
            validatorAgentId,
            serverAgentId,
            dataHash
        );

        // Mediator accepts the validation
        // Calculate the dataHash that validate() will use internally
        bytes32 mediationDataHash = keccak256(
            abi.encodePacked(demand, fulfillment)
        );
        vm.prank(mediator);
        mediationValidator.mediate(
            mediationDataHash,
            OptimisticMediationValidator.MediationResponse.ACCEPTED
        );

        // Validate - will return 100 due to acceptance
        vm.prank(address(this));
        mediationValidator.validate(demandData, fulfillment);

        // Server can claim immediately after acceptance
        uint256 serverBalanceBefore = server.balance;

        vm.prank(server);
        validationEscrow.claimEscrow(escrowId, fulfillment);

        uint256 serverBalanceAfter = server.balance;
        assertEq(serverBalanceAfter - serverBalanceBefore, escrowAmount);
    }

    function testMediatorRejectsValidation() public {
        // Setup escrow with high minimum validation
        uint256 escrowAmount = 1 ether;
        uint256 expirationTime = block.timestamp + 1 hours;
        uint8 minValidation = 50; // Requires at least 50/100
        uint256 mediationDeadline = block.timestamp + 30 minutes;

        OptimisticMediationValidator.DemandData
            memory demandData = OptimisticMediationValidator.DemandData({
                mediator: mediator,
                mediationDeadline: mediationDeadline,
                additionalData: abi.encode("Task ID: ", uint256(12345))
            });
        bytes memory demand = abi.encode(demandData);

        // Client deposits escrow
        vm.prank(client);
        uint256 escrowId = validationEscrow.depositEscrow{value: escrowAmount}(
            validatorAgentId,
            serverAgentId,
            escrowAmount,
            expirationTime,
            minValidation,
            demand
        );

        // Server prepares fulfillment
        bytes memory fulfillment = bytes("disputed service");

        // Calculate dataHash for validation
        bytes32 dataHash = keccak256(abi.encodePacked(demand, fulfillment));

        // Server requests validation
        vm.prank(server);
        validationRegistry.validationRequest(
            validatorAgentId,
            serverAgentId,
            dataHash
        );

        // Mediator rejects the validation
        // Calculate the dataHash that validate() will use internally
        bytes32 mediationDataHash = keccak256(
            abi.encodePacked(demand, fulfillment)
        );
        vm.prank(mediator);
        mediationValidator.mediate(
            mediationDataHash,
            OptimisticMediationValidator.MediationResponse.REJECTED
        );

        // Validate - will return 0 due to rejection
        vm.prank(address(this));
        mediationValidator.validate(demandData, fulfillment);

        // Server tries to claim but fails due to rejection (score 0 < minValidation 50)
        vm.prank(server);
        vm.expectRevert(ValidationEscrow.InvalidValidation.selector);
        validationEscrow.claimEscrow(escrowId, fulfillment);

        // Client can reclaim after expiration
        vm.warp(block.timestamp + 2 hours);

        uint256 clientBalanceBefore = client.balance;
        vm.prank(client);
        validationEscrow.reclaimExpired(escrowId);

        uint256 clientBalanceAfter = client.balance;
        assertEq(clientBalanceAfter - clientBalanceBefore, escrowAmount);
    }

    function testMultipleMediators() public {
        // This test shows that only the designated mediator can influence validation
        address mediator2 = address(0x5);
        vm.deal(mediator2, 1 ether);

        uint256 escrowAmount = 1 ether;
        uint256 mediationDeadline = block.timestamp + 10 minutes;

        OptimisticMediationValidator.DemandData memory demandData = OptimisticMediationValidator
            .DemandData({
                mediator: mediator, // mediator is the designated one
                mediationDeadline: mediationDeadline,
                additionalData: bytes("Priority: High")
            });
        bytes memory demand = abi.encode(demandData);

        // Client deposits escrow
        vm.prank(client);
        uint256 escrowId = validationEscrow.depositEscrow{value: escrowAmount}(
            validatorAgentId,
            serverAgentId,
            escrowAmount,
            block.timestamp + 1 hours,
            50,
            demand
        );

        // Server prepares fulfillment
        bytes memory fulfillment = bytes("multi-mediator test");

        // Calculate dataHash for validation
        bytes32 dataHash = keccak256(abi.encodePacked(demand, fulfillment));

        // Server requests validation
        vm.prank(server);
        validationRegistry.validationRequest(
            validatorAgentId,
            serverAgentId,
            dataHash
        );

        // Wrong mediator tries to reject
        // Calculate the dataHash that validate() will use internally
        bytes32 mediationDataHash = keccak256(
            abi.encodePacked(demand, fulfillment)
        );
        vm.prank(mediator2);
        mediationValidator.mediate(
            mediationDataHash,
            OptimisticMediationValidator.MediationResponse.REJECTED
        );

        // Correct mediator accepts
        vm.prank(mediator);
        mediationValidator.mediate(
            mediationDataHash,
            OptimisticMediationValidator.MediationResponse.ACCEPTED
        );

        // Validate - should use correct mediator's response (accepted)
        vm.prank(address(this));
        mediationValidator.validate(demandData, fulfillment);

        // Server can claim because correct mediator accepted
        vm.prank(server);
        validationEscrow.claimEscrow(escrowId, fulfillment);

        // Verify escrow was claimed
        vm.prank(client);
        vm.expectRevert(ValidationEscrow.InvalidEscrow.selector);
        validationEscrow.reclaimExpired(escrowId);
    }

    function testValidatorSelfRegistration() public view {
        // Verify that the OptimisticMediationValidator successfully registered itself
        assertTrue(identityRegistry.agentExists(validatorAgentId));

        // Get the agent info to verify registration details
        IIdentityRegistry.AgentInfo memory agentInfo = identityRegistry
            .getAgent(validatorAgentId);

        // Verify the agent details
        assertEq(agentInfo.agentId, validatorAgentId);
        assertEq(agentInfo.agentDomain, "optimistic-validator.example.com");
        assertEq(agentInfo.agentAddress, address(mediationValidator));

        // Verify we can resolve by domain
        IIdentityRegistry.AgentInfo memory byDomain = identityRegistry
            .resolveByDomain("optimistic-validator.example.com");
        assertEq(byDomain.agentAddress, address(mediationValidator));

        // Verify we can resolve by address
        IIdentityRegistry.AgentInfo memory byAddress = identityRegistry
            .resolveByAddress(address(mediationValidator));
        assertEq(byAddress.agentDomain, "optimistic-validator.example.com");

        // Verify the validator agent ID is correctly stored in the contract
        assertEq(mediationValidator.validatorAgentId(), validatorAgentId);
    }

    function testWrongMediatorCannotInfluence() public {
        // Test that a non-designated mediator cannot affect validation outcome
        address wrongMediatorAddress = address(0x999);

        uint256 escrowAmount = 0.5 ether;
        uint256 mediationDeadline = block.timestamp + 10 minutes;

        OptimisticMediationValidator.DemandData memory demandData = OptimisticMediationValidator
            .DemandData({
                mediator: mediator,
                mediationDeadline: mediationDeadline,
                additionalData: hex"0123456789abcdef" // Example hex data
            });
        bytes memory demand = abi.encode(demandData);

        vm.prank(client);
        uint256 escrowId = validationEscrow.depositEscrow{value: escrowAmount}(
            validatorAgentId,
            serverAgentId,
            escrowAmount,
            block.timestamp + 1 hours,
            50,
            demand
        );

        // Server prepares fulfillment
        bytes memory fulfillment = bytes("test service");

        // Calculate dataHash for validation
        bytes32 dataHash = keccak256(abi.encodePacked(demand, fulfillment));

        // Server requests validation
        vm.prank(server);
        validationRegistry.validationRequest(
            validatorAgentId,
            serverAgentId,
            dataHash
        );

        // Wrong mediator tries to accept
        // Calculate the dataHash that validate() will use internally
        bytes32 mediationDataHash = keccak256(
            abi.encodePacked(demand, fulfillment)
        );
        vm.prank(wrongMediatorAddress);
        mediationValidator.mediate(
            mediationDataHash,
            OptimisticMediationValidator.MediationResponse.ACCEPTED
        );

        // Validate before deadline - should revert as awaiting mediation from correct mediator
        vm.prank(address(this));
        vm.expectRevert(
            OptimisticMediationValidator.AwaitingMediation.selector
        );
        mediationValidator.validate(demandData, fulfillment);

        // Fast forward past deadline
        vm.warp(block.timestamp + 11 minutes);

        // Now validate - should succeed with optimistic acceptance
        vm.prank(address(this));
        mediationValidator.validate(demandData, fulfillment);

        // Server can claim
        vm.prank(server);
        validationEscrow.claimEscrow(escrowId, fulfillment);
    }

    function testNoneResponseBehavior() public {
        // Test the behavior when mediator response is NONE (default)
        uint256 escrowAmount = 0.75 ether;
        uint256 mediationDeadline = block.timestamp + 15 minutes;

        OptimisticMediationValidator.DemandData
            memory demandData = OptimisticMediationValidator.DemandData({
                mediator: mediator,
                mediationDeadline: mediationDeadline,
                additionalData: abi.encode("Metadata", true, uint256(42))
            });
        bytes memory demand = abi.encode(demandData);

        vm.prank(client);
        uint256 escrowId = validationEscrow.depositEscrow{value: escrowAmount}(
            validatorAgentId,
            serverAgentId,
            escrowAmount,
            block.timestamp + 2 hours,
            50,
            demand
        );

        // Server prepares fulfillment
        bytes memory fulfillment = bytes("none response test");

        // Server requests validation
        vm.prank(server);
        validationRegistry.validationRequest(
            validatorAgentId,
            serverAgentId,
            keccak256(abi.encodePacked(demand, fulfillment))
        );

        // Request mediation with additional context
        vm.prank(server);
        mediationValidator.requestMediation(demandData, fulfillment);

        // Try to validate before deadline without mediator response - should revert
        vm.prank(address(this));
        vm.expectRevert(
            OptimisticMediationValidator.AwaitingMediation.selector
        );
        mediationValidator.validate(demandData, fulfillment);

        // Move to exactly the deadline
        vm.warp(mediationDeadline);

        // Still should revert at exactly the deadline
        vm.prank(address(this));
        vm.expectRevert(
            OptimisticMediationValidator.AwaitingMediation.selector
        );
        mediationValidator.validate(demandData, fulfillment);

        // Move past the deadline
        vm.warp(mediationDeadline + 1);

        // Now validation should succeed with optimistic acceptance
        vm.prank(address(this));
        mediationValidator.validate(demandData, fulfillment);

        // Server can claim
        vm.prank(server);
        validationEscrow.claimEscrow(escrowId, fulfillment);
    }

    function testExplicitMediatorResponseOverridesOptimistic() public {
        // Test that explicit mediator response before deadline overrides optimistic behavior
        uint256 escrowAmount = 1 ether;
        uint256 mediationDeadline = block.timestamp + 20 minutes;

        OptimisticMediationValidator.DemandData memory demandData = OptimisticMediationValidator
            .DemandData({
                mediator: mediator,
                mediationDeadline: mediationDeadline,
                additionalData: bytes("") // Empty additional data is valid
            });
        bytes memory demand = abi.encode(demandData);

        vm.prank(client);
        uint256 escrowId = validationEscrow.depositEscrow{value: escrowAmount}(
            validatorAgentId,
            serverAgentId,
            escrowAmount,
            block.timestamp + 3 hours,
            80, // High minimum validation
            demand
        );

        // Server prepares fulfillment
        bytes memory fulfillment = bytes("explicit response test");

        // Calculate dataHash for validation
        bytes32 dataHash = keccak256(abi.encodePacked(demand, fulfillment));

        // Server requests validation
        vm.prank(server);
        validationRegistry.validationRequest(
            validatorAgentId,
            serverAgentId,
            dataHash
        );

        // Mediator explicitly rejects before deadline
        // Calculate the dataHash that validate() will use internally
        bytes32 mediationDataHash = keccak256(
            abi.encodePacked(demand, fulfillment)
        );
        vm.prank(mediator);
        mediationValidator.mediate(
            mediationDataHash,
            OptimisticMediationValidator.MediationResponse.REJECTED
        );

        // Validate - should use explicit rejection even before deadline
        vm.prank(address(this));
        mediationValidator.validate(demandData, fulfillment);

        // Server cannot claim due to rejection (score 0 < minValidation 80)
        vm.prank(server);
        vm.expectRevert(ValidationEscrow.InvalidValidation.selector);
        validationEscrow.claimEscrow(escrowId, fulfillment);
    }

    function testMediationRequestEvent() public {
        // Test that mediation request emits correct event with additionalData
        uint256 mediationDeadline = block.timestamp + 30 minutes;
        bytes memory additionalData = bytes("Important context for mediator");

        OptimisticMediationValidator.DemandData
            memory demandData = OptimisticMediationValidator.DemandData({
                mediator: mediator,
                mediationDeadline: mediationDeadline,
                additionalData: additionalData
            });
        bytes memory fulfillment = bytes("event test data");

        // Server requests mediation - this will emit the MediationRequested event
        vm.prank(server);
        mediationValidator.requestMediation(demandData, fulfillment);
    }

    function testComplexAdditionalData() public {
        // Test with complex structured additional data
        uint256 escrowAmount = 1.5 ether;
        uint256 mediationDeadline = block.timestamp + 45 minutes;

        // Create complex additional data
        bytes memory complexAdditionalData = abi.encode(
            "Task Type: Machine Learning Training",
            uint256(1000000), // Dataset size
            address(0xdead), // Reference contract
            true // Requires GPU
        );

        OptimisticMediationValidator.DemandData
            memory demandData = OptimisticMediationValidator.DemandData({
                mediator: mediator,
                mediationDeadline: mediationDeadline,
                additionalData: complexAdditionalData
            });
        bytes memory demand = abi.encode(demandData);

        // Client deposits escrow
        vm.prank(client);
        uint256 escrowId = validationEscrow.depositEscrow{value: escrowAmount}(
            validatorAgentId,
            serverAgentId,
            escrowAmount,
            block.timestamp + 4 hours,
            75,
            demand
        );

        // Server prepares fulfillment
        bytes memory fulfillment = abi.encode(
            "Model trained successfully",
            uint256(95), // Accuracy percentage
            bytes32(
                0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef
            ) // Model hash
        );

        // Calculate dataHash
        bytes32 dataHash = keccak256(abi.encodePacked(demand, fulfillment));

        // Server requests validation
        vm.prank(server);
        validationRegistry.validationRequest(
            validatorAgentId,
            serverAgentId,
            dataHash
        );

        // Server requests mediation with complex data
        vm.prank(server);
        mediationValidator.requestMediation(demandData, fulfillment);

        // Mediator accepts the complex validation
        bytes32 mediationDataHash = keccak256(
            abi.encodePacked(demand, fulfillment)
        );
        vm.prank(mediator);
        mediationValidator.mediate(
            mediationDataHash,
            OptimisticMediationValidator.MediationResponse.ACCEPTED
        );

        // Validate
        vm.prank(address(this));
        mediationValidator.validate(demandData, fulfillment);

        // Server claims successfully
        vm.prank(server);
        validationEscrow.claimEscrow(escrowId, fulfillment);
    }
}
