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

        // Prepare the demand data - this is what the server must provide
        bytes memory expectedData = "Hello, World!";
        bytes32 expectedDataHash = keccak256(expectedData);

        // Encode the demand for OnchainCheckValidator
        bytes memory demand = abi.encode(
            OnchainCheckValidator.DemandData({data: expectedData})
        );

        // Client deposits escrow
        vm.prank(client);
        uint256 escrowId = validationEscrow.depositEscrow{value: escrowAmount}(
            validatorAgentId,
            serverAgentId,
            escrowAmount,
            expirationTime,
            minValidation,
            address(onchainCheckValidator),
            demand
        );

        // Verify escrow was created
        ValidationEscrow.Escrow memory escrow = validationEscrow.getEscrow(
            escrowId
        );
        assertEq(escrow.escrower, client);
        assertEq(escrow.amount, escrowAmount);
        assertEq(escrow.minValidation, minValidation);

        // 2. Server requests validation for the data they want to submit
        vm.prank(server);
        validationRegistry.validationRequest(
            validatorAgentId,
            serverAgentId,
            expectedDataHash
        );

        // 3. Server claims the escrow by providing the correct data hash
        uint256 serverBalanceBefore = server.balance;

        vm.prank(server);
        validationEscrow.claimEscrow(escrowId, expectedDataHash);

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
        bytes memory expectedData = "Correct Data";
        bytes memory wrongData = "Wrong Data";
        bytes32 wrongDataHash = keccak256(wrongData);

        bytes memory demand = abi.encode(
            OnchainCheckValidator.DemandData({data: expectedData})
        );

        // Client deposits escrow
        vm.prank(client);
        uint256 escrowId = validationEscrow.depositEscrow{value: escrowAmount}(
            validatorAgentId,
            serverAgentId,
            escrowAmount,
            expirationTime,
            minValidation,
            address(onchainCheckValidator),
            demand
        );

        // Server requests validation with wrong data
        vm.prank(server);
        validationRegistry.validationRequest(
            validatorAgentId,
            serverAgentId,
            wrongDataHash
        );

        // Server tries to claim with wrong data hash - should fail
        vm.prank(server);
        vm.expectRevert(ValidationEscrow.InvalidValidation.selector);
        validationEscrow.claimEscrow(escrowId, wrongDataHash);
    }

    function testClientCanReclaimAfterExpiration() public {
        // Setup escrow with short expiration
        uint256 escrowAmount = 0.5 ether;
        uint256 expirationTime = block.timestamp + 1 minutes;
        uint8 minValidation = 50;

        bytes memory demand = abi.encode(
            OnchainCheckValidator.DemandData({data: "Some Data"})
        );

        // Client deposits escrow
        vm.prank(client);
        uint256 escrowId = validationEscrow.depositEscrow{value: escrowAmount}(
            validatorAgentId,
            serverAgentId,
            escrowAmount,
            expirationTime,
            minValidation,
            address(onchainCheckValidator),
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
        // This test shows how OnchainCheckValidator can validate complex data
        uint256 escrowAmount = 2 ether;
        uint256 expirationTime = block.timestamp + 24 hours;
        uint8 minValidation = 75;

        // Create complex data structure
        bytes memory complexData = abi.encode(
            uint256(42),
            "Complex validation test",
            address(this)
        );
        bytes32 dataHash = keccak256(complexData);

        bytes memory demand = abi.encode(
            OnchainCheckValidator.DemandData({data: complexData})
        );

        // Client deposits escrow
        vm.prank(client);
        uint256 escrowId = validationEscrow.depositEscrow{value: escrowAmount}(
            validatorAgentId,
            serverAgentId,
            escrowAmount,
            expirationTime,
            minValidation,
            address(onchainCheckValidator),
            demand
        );

        // Server requests validation
        vm.prank(server);
        validationRegistry.validationRequest(
            validatorAgentId,
            serverAgentId,
            dataHash
        );

        // Server claims with correct complex data
        vm.prank(server);
        validationEscrow.claimEscrow(escrowId, dataHash);

        // Verify claim was successful by checking the escrow can't be reclaimed
        vm.prank(client);
        vm.expectRevert(ValidationEscrow.InvalidEscrow.selector);
        validationEscrow.reclaimExpired(escrowId);
    }

    function testUnauthorizedClaimAttempt() public {
        // Setup escrow
        uint256 escrowAmount = 1 ether;
        bytes memory data = "Test Data";
        bytes32 dataHash = keccak256(data);

        bytes memory demand = abi.encode(
            OnchainCheckValidator.DemandData({data: data})
        );

        vm.prank(client);
        uint256 escrowId = validationEscrow.depositEscrow{value: escrowAmount}(
            validatorAgentId,
            serverAgentId,
            escrowAmount,
            block.timestamp + 1 hours,
            50,
            address(onchainCheckValidator),
            demand
        );

        // Request validation
        vm.prank(server);
        validationRegistry.validationRequest(
            validatorAgentId,
            serverAgentId,
            dataHash
        );

        // Random address tries to claim - should fail
        address randomUser = address(0x999);
        vm.prank(randomUser);
        vm.expectRevert(ValidationEscrow.UnauthorizedClaim.selector);
        validationEscrow.claimEscrow(escrowId, dataHash);
    }

    function testPartialValidationScore() public {
        // This test shows behavior with different validation scores
        uint256 escrowAmount = 1 ether;
        uint8 minValidation = 60; // Requires at least 60/100

        bytes memory correctData = "Correct";
        bytes32 correctHash = keccak256(correctData);

        bytes memory demand = abi.encode(
            OnchainCheckValidator.DemandData({data: correctData})
        );

        vm.prank(client);
        uint256 escrowId = validationEscrow.depositEscrow{value: escrowAmount}(
            validatorAgentId,
            serverAgentId,
            escrowAmount,
            block.timestamp + 1 hours,
            minValidation,
            address(onchainCheckValidator),
            demand
        );

        // Request validation
        vm.prank(server);
        validationRegistry.validationRequest(
            validatorAgentId,
            serverAgentId,
            correctHash
        );

        // OnchainCheckValidator returns 100 for exact match, 0 for mismatch
        // In this case, we have exact match so score is 100, which exceeds minimum of 60
        vm.prank(server);
        validationEscrow.claimEscrow(escrowId, correctHash);

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
}
