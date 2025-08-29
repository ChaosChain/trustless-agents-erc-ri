// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/IdentityRegistry.sol";
import "../src/ValidationRegistry.sol";
import "../src/peripheral/ValidationEscrow.sol";
import "../src/peripheral/OnchainCheckValidator.sol";

contract ValidationEscrowExample is Test {
    IdentityRegistry public identityRegistry;
    ValidationRegistry public validationRegistry;
    ValidationEscrow public validationEscrow;
    OnchainCheckValidator public onchainCheckValidator;

    address public server = address(0x2);
    address public client = address(0x3);

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

        // Deploy OnchainCheckValidator with registration fee
        onchainCheckValidator = new OnchainCheckValidator{
            value: REGISTRATION_FEE
        }(
            address(identityRegistry),
            address(validationRegistry),
            "validator.example.com"
        );

        // Get the validator agent ID from the contract
        validatorAgentId = onchainCheckValidator.validatorAgentId();

        // Fund test accounts
        vm.deal(server, 1 ether);
        vm.deal(client, 10 ether);

        // Register server agent
        vm.prank(server);
        serverAgentId = identityRegistry.newAgent{value: REGISTRATION_FEE}(
            "server.example.com",
            server
        );
    }

    function testSuccessfulEscrowClaimFlow() public {
        // 1. Client deposits escrow with specific validation requirements
        uint256 escrowAmount = 1 ether;
        uint256 expirationTime = block.timestamp + 1 hours;
        uint8 minValidation = 50; // Minimum validation score of 50/100

        // Prepare the demand data - what the server must compute
        OnchainCheckValidator.DemandData
            memory demandData = OnchainCheckValidator.DemandData({
                a: 10,
                b: 20
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

        // Verify escrow was created
        ValidationEscrow.Escrow memory escrow = validationEscrow.getEscrow(
            escrowId
        );
        assertEq(escrow.escrower, client);
        assertEq(escrow.amount, escrowAmount);
        assertEq(escrow.minValidation, minValidation);

        // 2. Server prepares fulfillment (correct sum)
        OnchainCheckValidator.FulfillmentData memory fulfillmentData = OnchainCheckValidator
            .FulfillmentData({
                sum: 30 // 10 + 20 = 30
            });
        bytes memory fulfillment = abi.encode(fulfillmentData);

        // Calculate dataHash from demand and fulfillment
        bytes32 dataHash = keccak256(abi.encodePacked(demand, fulfillment));

        // 3. Server requests validation
        vm.prank(server);
        validationRegistry.validationRequest(
            validatorAgentId,
            serverAgentId,
            dataHash
        );

        // 4. Validator validates the request
        vm.prank(address(this)); // Anyone can call validate
        onchainCheckValidator.validate(demandData, fulfillmentData);

        // 5. Server claims the escrow by providing the fulfillment
        uint256 serverBalanceBefore = server.balance;

        vm.prank(server);
        validationEscrow.claimEscrow(escrowId, fulfillment);

        // Verify server received the funds
        uint256 serverBalanceAfter = server.balance;
        assertEq(serverBalanceAfter - serverBalanceBefore, escrowAmount);
    }

    function testValidationFailureDoesNotReleaseFunds() public {
        // Setup escrow with high minimum validation requirement
        uint256 escrowAmount = 0.5 ether;
        uint256 expirationTime = block.timestamp + 1 hours;
        uint8 minValidation = 100; // Requires perfect validation score

        // Prepare demand data
        OnchainCheckValidator.DemandData
            memory demandData = OnchainCheckValidator.DemandData({a: 5, b: 10});
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

        // Server prepares wrong fulfillment
        OnchainCheckValidator.FulfillmentData memory wrongFulfillmentData = OnchainCheckValidator
            .FulfillmentData({
                sum: 20 // Wrong! Should be 15
            });
        bytes memory wrongFulfillment = abi.encode(wrongFulfillmentData);

        // Calculate dataHash
        bytes32 wrongDataHash = keccak256(
            abi.encodePacked(demand, wrongFulfillment)
        );

        // Server requests validation with wrong data
        vm.prank(server);
        validationRegistry.validationRequest(
            validatorAgentId,
            serverAgentId,
            wrongDataHash
        );

        // Validator validates (will return 0 for wrong sum)
        vm.prank(address(this));
        onchainCheckValidator.validate(demandData, wrongFulfillmentData);

        // Server tries to claim with wrong fulfillment - should fail
        vm.prank(server);
        vm.expectRevert(ValidationEscrow.InvalidValidation.selector);
        validationEscrow.claimEscrow(escrowId, wrongFulfillment);
    }

    function testClientCanReclaimAfterExpiration() public {
        // Setup escrow with short expiration
        uint256 escrowAmount = 0.5 ether;
        uint256 expirationTime = block.timestamp + 1 minutes;
        uint8 minValidation = 50;

        OnchainCheckValidator.DemandData
            memory demandData = OnchainCheckValidator.DemandData({a: 1, b: 2});
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

        // Fast forward past expiration
        vm.warp(block.timestamp + 2 minutes);

        // Client reclaims expired escrow
        uint256 clientBalanceBefore = client.balance;

        vm.prank(client);
        validationEscrow.reclaimExpired(escrowId);

        uint256 clientBalanceAfter = client.balance;
        assertEq(clientBalanceAfter - clientBalanceBefore, escrowAmount);
    }

    function testComplexDemandValidation() public {
        // This test shows how OnchainCheckValidator validates complex computations
        uint256 escrowAmount = 2 ether;
        uint256 expirationTime = block.timestamp + 24 hours;
        uint8 minValidation = 75;

        // Create complex demand
        OnchainCheckValidator.DemandData
            memory demandData = OnchainCheckValidator.DemandData({
                a: 123456,
                b: 654321
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

        // Server computes correct fulfillment
        OnchainCheckValidator.FulfillmentData memory fulfillmentData = OnchainCheckValidator
            .FulfillmentData({
                sum: 777777 // 123456 + 654321
            });
        bytes memory fulfillment = abi.encode(fulfillmentData);

        bytes32 dataHash = keccak256(abi.encodePacked(demand, fulfillment));

        // Server requests validation
        vm.prank(server);
        validationRegistry.validationRequest(
            validatorAgentId,
            serverAgentId,
            dataHash
        );

        // Validate
        vm.prank(address(this));
        onchainCheckValidator.validate(demandData, fulfillmentData);

        // Server claims with correct fulfillment
        vm.prank(server);
        validationEscrow.claimEscrow(escrowId, fulfillment);

        // Verify claim was successful by checking the escrow can't be reclaimed
        vm.prank(client);
        vm.expectRevert(ValidationEscrow.InvalidEscrow.selector);
        validationEscrow.reclaimExpired(escrowId);
    }

    function testUnauthorizedClaimAttempt() public {
        // Setup escrow
        uint256 escrowAmount = 1 ether;

        OnchainCheckValidator.DemandData
            memory demandData = OnchainCheckValidator.DemandData({a: 7, b: 3});
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

        // Prepare fulfillment
        OnchainCheckValidator.FulfillmentData
            memory fulfillmentData = OnchainCheckValidator.FulfillmentData({
                sum: 10
            });
        bytes memory fulfillment = abi.encode(fulfillmentData);
        bytes32 dataHash = keccak256(abi.encodePacked(demand, fulfillment));

        // Request validation
        vm.prank(server);
        validationRegistry.validationRequest(
            validatorAgentId,
            serverAgentId,
            dataHash
        );

        // Validate
        vm.prank(address(this));
        onchainCheckValidator.validate(demandData, fulfillmentData);

        // Random address tries to claim - should fail
        address randomUser = address(0x999);
        vm.prank(randomUser);
        vm.expectRevert(ValidationEscrow.UnauthorizedClaim.selector);
        validationEscrow.claimEscrow(escrowId, fulfillment);
    }

    function testPartialValidationScore() public {
        // This test shows behavior with different validation scores
        uint256 escrowAmount = 1 ether;
        uint8 minValidation = 60; // Requires at least 60/100

        OnchainCheckValidator.DemandData
            memory demandData = OnchainCheckValidator.DemandData({
                a: 100,
                b: 200
            });
        bytes memory demand = abi.encode(demandData);

        vm.prank(client);
        uint256 escrowId = validationEscrow.depositEscrow{value: escrowAmount}(
            validatorAgentId,
            serverAgentId,
            escrowAmount,
            block.timestamp + 1 hours,
            minValidation,
            demand
        );

        // Prepare correct fulfillment
        OnchainCheckValidator.FulfillmentData memory fulfillmentData = OnchainCheckValidator
            .FulfillmentData({
                sum: 300 // Correct sum
            });
        bytes memory fulfillment = abi.encode(fulfillmentData);
        bytes32 dataHash = keccak256(abi.encodePacked(demand, fulfillment));

        // Request validation
        vm.prank(server);
        validationRegistry.validationRequest(
            validatorAgentId,
            serverAgentId,
            dataHash
        );

        // OnchainCheckValidator returns 100 for exact match, 0 for mismatch
        // In this case, we have exact match so score is 100, which exceeds minimum of 60
        vm.prank(address(this));
        onchainCheckValidator.validate(demandData, fulfillmentData);

        vm.prank(server);
        validationEscrow.claimEscrow(escrowId, fulfillment);

        // Verify successful claim
        assertEq(server.balance, 2 ether - REGISTRATION_FEE); // Initial 1 ETH - 0.005 ETH fee + 1 ETH claimed = 1.995 ETH
    }

    function testValidatorSelfRegistration() public {
        // Verify that the OnchainCheckValidator successfully registered itself
        assertTrue(identityRegistry.agentExists(validatorAgentId));

        // Get the agent info to verify registration details
        IIdentityRegistry.AgentInfo memory agentInfo = identityRegistry
            .getAgent(validatorAgentId);

        // Verify the agent details
        assertEq(agentInfo.agentId, validatorAgentId);
        assertEq(agentInfo.agentDomain, "validator.example.com");
        assertEq(agentInfo.agentAddress, address(onchainCheckValidator));

        // Verify we can resolve by domain
        IIdentityRegistry.AgentInfo memory byDomain = identityRegistry
            .resolveByDomain("validator.example.com");
        assertEq(byDomain.agentAddress, address(onchainCheckValidator));

        // Verify we can resolve by address
        IIdentityRegistry.AgentInfo memory byAddress = identityRegistry
            .resolveByAddress(address(onchainCheckValidator));
        assertEq(byAddress.agentDomain, "validator.example.com");

        // Verify the validator agent ID is correctly stored in the contract
        assertEq(onchainCheckValidator.validatorAgentId(), validatorAgentId);

        // Deploy another validator with different domain to verify unique registration
        OnchainCheckValidator anotherValidator = new OnchainCheckValidator{
            value: REGISTRATION_FEE
        }(
            address(identityRegistry),
            address(validationRegistry),
            "another-validator.example.com"
        );

        // Verify it gets a different agent ID
        assertTrue(anotherValidator.validatorAgentId() != validatorAgentId);
        assertTrue(
            identityRegistry.agentExists(anotherValidator.validatorAgentId())
        );
    }

    function testMissingValidationRequest() public {
        // Setup escrow
        uint256 escrowAmount = 0.5 ether;

        OnchainCheckValidator.DemandData
            memory demandData = OnchainCheckValidator.DemandData({a: 5, b: 5});
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

        // Prepare fulfillment but don't request validation
        OnchainCheckValidator.FulfillmentData
            memory fulfillmentData = OnchainCheckValidator.FulfillmentData({
                sum: 10
            });
        bytes memory fulfillment = abi.encode(fulfillmentData);

        // Try to claim without requesting validation - should fail
        vm.prank(server);
        vm.expectRevert(IValidationRegistry.ValidationRequestNotFound.selector);
        validationEscrow.claimEscrow(escrowId, fulfillment);
    }

    function testValidationWithoutResponse() public {
        // Setup escrow
        uint256 escrowAmount = 0.5 ether;

        OnchainCheckValidator.DemandData
            memory demandData = OnchainCheckValidator.DemandData({a: 3, b: 4});
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

        // Prepare fulfillment
        OnchainCheckValidator.FulfillmentData
            memory fulfillmentData = OnchainCheckValidator.FulfillmentData({
                sum: 7
            });
        bytes memory fulfillment = abi.encode(fulfillmentData);
        bytes32 dataHash = keccak256(abi.encodePacked(demand, fulfillment));

        // Request validation but don't call validate
        vm.prank(server);
        validationRegistry.validationRequest(
            validatorAgentId,
            serverAgentId,
            dataHash
        );

        // Try to claim without validation response - should fail
        vm.prank(server);
        vm.expectRevert(ValidationEscrow.InvalidValidation.selector);
        validationEscrow.claimEscrow(escrowId, fulfillment);
    }
}
