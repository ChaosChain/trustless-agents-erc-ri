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

        bytes memory demand = abi.encode(
            OptimisticMediationValidator.DemandData({
                mediator: mediator,
                mediationDeadline: mediationDeadline
            })
        );

        // Client deposits escrow
        vm.prank(client);
        uint256 escrowId = validationEscrow.depositEscrow{value: escrowAmount}(
            validatorAgentId,
            serverAgentId,
            escrowAmount,
            expirationTime,
            minValidation,
            address(mediationValidator),
            demand
        );

        bytes32 dataHash = keccak256("service provided successfully");

        // Server requests validation
        vm.prank(server);
        validationRegistry.validationRequest(
            validatorAgentId,
            serverAgentId,
            dataHash
        );

        // Server requests mediation (emits event for mediator)
        vm.prank(server);
        mediationValidator.requestMediation(
            dataHash,
            mediator,
            mediationDeadline
        );

        // Fast forward past mediation deadline - mediator didn't respond
        vm.warp(block.timestamp + 6 minutes);

        // Server can now claim - optimistic acceptance kicks in
        uint256 serverBalanceBefore = server.balance;

        vm.prank(server);
        validationEscrow.claimEscrow(escrowId, dataHash);

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

        bytes memory demand = abi.encode(
            OptimisticMediationValidator.DemandData({
                mediator: mediator,
                mediationDeadline: mediationDeadline
            })
        );

        // Client deposits escrow
        vm.prank(client);
        uint256 escrowId = validationEscrow.depositEscrow{value: escrowAmount}(
            validatorAgentId,
            serverAgentId,
            escrowAmount,
            expirationTime,
            minValidation,
            address(mediationValidator),
            demand
        );

        bytes32 dataHash = keccak256("service data");

        // Server requests validation
        vm.prank(server);
        validationRegistry.validationRequest(
            validatorAgentId,
            serverAgentId,
            dataHash
        );

        // Mediator accepts the validation
        vm.prank(mediator);
        mediationValidator.mediate(
            dataHash,
            OptimisticMediationValidator.MediationReponse.ACCEPTED
        );

        // Server can claim immediately after acceptance
        uint256 serverBalanceBefore = server.balance;

        vm.prank(server);
        validationEscrow.claimEscrow(escrowId, dataHash);

        uint256 serverBalanceAfter = server.balance;
        assertEq(serverBalanceAfter - serverBalanceBefore, escrowAmount);
    }

    function testMediatorRejectsValidation() public {
        // Setup escrow with high minimum validation
        uint256 escrowAmount = 1 ether;
        uint256 expirationTime = block.timestamp + 1 hours;
        uint8 minValidation = 50; // Requires at least 50/100
        uint256 mediationDeadline = block.timestamp + 30 minutes;

        bytes memory demand = abi.encode(
            OptimisticMediationValidator.DemandData({
                mediator: mediator,
                mediationDeadline: mediationDeadline
            })
        );

        // Client deposits escrow
        vm.prank(client);
        uint256 escrowId = validationEscrow.depositEscrow{value: escrowAmount}(
            validatorAgentId,
            serverAgentId,
            escrowAmount,
            expirationTime,
            minValidation,
            address(mediationValidator),
            demand
        );

        bytes32 dataHash = keccak256("disputed service");

        // Server requests validation
        vm.prank(server);
        validationRegistry.validationRequest(
            validatorAgentId,
            serverAgentId,
            dataHash
        );

        // Mediator rejects the validation
        vm.prank(mediator);
        mediationValidator.mediate(
            dataHash,
            OptimisticMediationValidator.MediationReponse.REJECTED
        );

        // Server cannot claim - validation score is 0
        vm.prank(server);
        vm.expectRevert(ValidationEscrow.InvalidValidation.selector);
        validationEscrow.claimEscrow(escrowId, dataHash);

        // Client can reclaim after expiration
        vm.warp(block.timestamp + 2 hours);

        uint256 clientBalanceBefore = client.balance;

        vm.prank(client);
        validationEscrow.reclaimExpired(escrowId);

        uint256 clientBalanceAfter = client.balance;
        assertEq(clientBalanceAfter - clientBalanceBefore, escrowAmount);
    }

    function testMultipleMediators() public {
        // This test shows how different escrows can have different mediators
        address mediator1 = address(0x100);
        address mediator2 = address(0x200);

        bytes32 dataHash1 = keccak256("service1");
        bytes32 dataHash2 = keccak256("service2");

        // First escrow with mediator1
        bytes memory demand1 = abi.encode(
            OptimisticMediationValidator.DemandData({
                mediator: mediator1,
                mediationDeadline: block.timestamp + 10 minutes
            })
        );

        vm.prank(client);
        uint256 escrowId1 = validationEscrow.depositEscrow{value: 0.5 ether}(
            validatorAgentId,
            serverAgentId,
            0.5 ether,
            block.timestamp + 1 hours,
            50,
            address(mediationValidator),
            demand1
        );

        // Second escrow with mediator2
        bytes memory demand2 = abi.encode(
            OptimisticMediationValidator.DemandData({
                mediator: mediator2,
                mediationDeadline: block.timestamp + 20 minutes
            })
        );

        vm.prank(client);
        uint256 escrowId2 = validationEscrow.depositEscrow{value: 0.5 ether}(
            validatorAgentId,
            serverAgentId,
            0.5 ether,
            block.timestamp + 1 hours,
            50,
            address(mediationValidator),
            demand2
        );

        // Request validations
        vm.startPrank(server);
        validationRegistry.validationRequest(
            validatorAgentId,
            serverAgentId,
            dataHash1
        );
        validationRegistry.validationRequest(
            validatorAgentId,
            serverAgentId,
            dataHash2
        );
        vm.stopPrank();

        // Mediator1 accepts, Mediator2 rejects
        vm.prank(mediator1);
        mediationValidator.mediate(
            dataHash1,
            OptimisticMediationValidator.MediationReponse.ACCEPTED
        );

        vm.prank(mediator2);
        mediationValidator.mediate(
            dataHash2,
            OptimisticMediationValidator.MediationReponse.REJECTED
        );

        // Server can claim escrow1 but not escrow2
        vm.prank(server);
        validationEscrow.claimEscrow(escrowId1, dataHash1); // Success

        vm.prank(server);
        vm.expectRevert(ValidationEscrow.InvalidValidation.selector);
        validationEscrow.claimEscrow(escrowId2, dataHash2); // Fails
    }

    function testValidatorSelfRegistration() public {
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

        // Deploy another validator with different domain
        OptimisticMediationValidator anotherValidator = new OptimisticMediationValidator{
                value: REGISTRATION_FEE
            }(
                address(identityRegistry),
                address(validationRegistry),
                "another-optimistic.example.com"
            );

        // Verify it gets a different agent ID
        assertTrue(anotherValidator.validatorAgentId() != validatorAgentId);
        assertTrue(
            identityRegistry.agentExists(anotherValidator.validatorAgentId())
        );
    }

    function testWrongMediatorCannotInfluence() public {
        // Test that only the designated mediator can influence validation
        address wrongMediator = address(0x999);

        bytes memory demand = abi.encode(
            OptimisticMediationValidator.DemandData({
                mediator: mediator, // Correct mediator
                mediationDeadline: block.timestamp + 30 minutes
            })
        );

        vm.prank(client);
        uint256 escrowId = validationEscrow.depositEscrow{value: 1 ether}(
            validatorAgentId,
            serverAgentId,
            1 ether,
            block.timestamp + 1 hours,
            50,
            address(mediationValidator),
            demand
        );

        bytes32 dataHash = keccak256("some service");

        vm.prank(server);
        validationRegistry.validationRequest(
            validatorAgentId,
            serverAgentId,
            dataHash
        );

        // Wrong mediator tries to accept
        vm.prank(wrongMediator);
        mediationValidator.mediate(
            dataHash,
            OptimisticMediationValidator.MediationReponse.ACCEPTED
        );

        // With NONE enum value, uninitialized responses are properly handled.
        // Without the correct mediator's response, validation should fail
        // before the deadline.

        // Before deadline, no valid response from correct mediator
        vm.warp(block.timestamp + 10 minutes);

        // Server tries to claim - should fail because correct mediator hasn't responded
        vm.prank(server);
        vm.expectRevert(
            OptimisticMediationValidator.AwaitingMediation.selector
        );
        validationEscrow.claimEscrow(escrowId, dataHash);

        // But after deadline, optimistic acceptance works
        vm.warp(block.timestamp + 31 minutes);

        vm.prank(server);
        validationEscrow.claimEscrow(escrowId, dataHash); // Now succeeds via optimistic acceptance
    }

    function testNoneResponseBehavior() public {
        // This test explicitly verifies NONE enum behavior
        bytes memory demand = abi.encode(
            OptimisticMediationValidator.DemandData({
                mediator: mediator,
                mediationDeadline: block.timestamp + 30 minutes
            })
        );

        vm.prank(client);
        uint256 escrowId = validationEscrow.depositEscrow{value: 1 ether}(
            validatorAgentId,
            serverAgentId,
            1 ether,
            block.timestamp + 2 hours,
            50,
            address(mediationValidator),
            demand
        );

        bytes32 dataHash = keccak256("test data");

        // Request validation
        vm.prank(server);
        validationRegistry.validationRequest(
            validatorAgentId,
            serverAgentId,
            dataHash
        );

        // Before deadline, with NONE response (default), validation should revert
        vm.prank(server);
        vm.expectRevert(
            OptimisticMediationValidator.AwaitingMediation.selector
        );
        validationEscrow.claimEscrow(escrowId, dataHash);

        // Fast forward past deadline
        vm.warp(block.timestamp + 31 minutes);

        // Now with NONE response but past deadline, optimistic acceptance occurs
        uint256 serverBalanceBefore = server.balance;

        vm.prank(server);
        validationEscrow.claimEscrow(escrowId, dataHash);

        uint256 serverBalanceAfter = server.balance;
        assertEq(serverBalanceAfter - serverBalanceBefore, 1 ether);
    }

    function testExplicitMediatorResponseOverridesOptimistic() public {
        // Test that explicit mediator response before deadline takes precedence
        bytes memory demand = abi.encode(
            OptimisticMediationValidator.DemandData({
                mediator: mediator,
                mediationDeadline: block.timestamp + 30 minutes
            })
        );

        vm.prank(client);
        uint256 escrowId = validationEscrow.depositEscrow{value: 1 ether}(
            validatorAgentId,
            serverAgentId,
            1 ether,
            block.timestamp + 2 hours,
            50,
            address(mediationValidator),
            demand
        );

        bytes32 dataHash = keccak256("service data");

        // Request validation
        vm.prank(server);
        validationRegistry.validationRequest(
            validatorAgentId,
            serverAgentId,
            dataHash
        );

        // Mediator explicitly rejects before deadline
        vm.prank(mediator);
        mediationValidator.mediate(
            dataHash,
            OptimisticMediationValidator.MediationReponse.REJECTED
        );

        // Even after deadline, rejection stands (not optimistic acceptance)
        vm.warp(block.timestamp + 31 minutes);

        vm.prank(server);
        vm.expectRevert(ValidationEscrow.InvalidValidation.selector);
        validationEscrow.claimEscrow(escrowId, dataHash);
    }
}
