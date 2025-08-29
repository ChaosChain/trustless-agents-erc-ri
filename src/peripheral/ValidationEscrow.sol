// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../interfaces/IValidationRegistry.sol";
import "../interfaces/IIdentityRegistry.sol";

contract ValidationEscrow {
    struct Escrow {
        address escrower;
        uint256 agentValidatorId;
        uint256 agentServerId;
        uint256 amount;
        uint256 expirationTime;
        uint8 minValidation;
        bytes demand;
    }

    event EscrowDepositEvent(
        uint256 indexed escrowId,
        address indexed escrower
    );
    event EscrowClaimEvent(
        uint256 indexed escrowId,
        address indexed claimant,
        bytes fulfillment
    );
    event EscrowReclaimEvent(
        uint256 indexed escrowId,
        address indexed escrower
    );

    error AgentNotFound();
    error InvalidEscrow();
    error InvalidEscrowParameters();
    error InvalidValidation();
    error UnauthorizedClaim();
    error TransferFailed();

    IIdentityRegistry public immutable identityRegistry;
    IValidationRegistry public immutable validationRegistry;

    uint256 private _escrowCounter;
    mapping(uint256 => Escrow) private _escrows;
    mapping(uint256 => bool) private _claimed;

    constructor(address _identityRegistry, address _validationRegistry) {
        identityRegistry = IIdentityRegistry(_identityRegistry);
        validationRegistry = IValidationRegistry(_validationRegistry);
    }

    function depositEscrow(
        uint256 agentValidatorId,
        uint256 agentServerId,
        uint256 amount,
        uint256 expirationTime,
        uint8 minValidation,
        bytes memory demand
    ) external payable returns (uint256 escrowId_) {
        if (!identityRegistry.agentExists(agentValidatorId)) {
            revert AgentNotFound();
        }
        if (!identityRegistry.agentExists(agentServerId)) {
            revert AgentNotFound();
        }
        if (amount == 0) {
            revert InvalidEscrowParameters();
        }
        if (expirationTime < block.timestamp) {
            revert InvalidEscrowParameters();
        }

        if (msg.value != amount) {
            revert TransferFailed();
        }

        escrowId_ = _escrowCounter++;
        _escrows[escrowId_] = Escrow(
            msg.sender,
            agentValidatorId,
            agentServerId,
            amount,
            expirationTime,
            minValidation,
            demand
        );

        emit EscrowDepositEvent(escrowId_, msg.sender);
    }

    function claimEscrow(
        uint256 escrowId,
        bytes calldata fulfillment
    ) external {
        Escrow storage escrow = _escrows[escrowId];
        if (escrow.amount == 0) {
            revert InvalidEscrow();
        }
        if (escrow.expirationTime < block.timestamp) {
            revert InvalidEscrow();
        }
        if (_claimed[escrowId]) {
            revert InvalidEscrow();
        }

        IIdentityRegistry.AgentInfo memory serverAgent = identityRegistry
            .getAgent(escrow.agentServerId);
        if (msg.sender != serverAgent.agentAddress) {
            revert UnauthorizedClaim();
        }

        bytes32 dataHash = keccak256(
            abi.encodePacked(escrow.demand, fulfillment)
        );

        IValidationRegistry.Request
            memory validationRequest = validationRegistry.getValidationRequest(
                dataHash
            );
        if (validationRequest.dataHash == 0) {
            revert InvalidValidation();
        }
        if (validationRequest.agentValidatorId != escrow.agentValidatorId) {
            revert InvalidValidation();
        }
        if (validationRequest.agentServerId != escrow.agentServerId) {
            revert InvalidValidation();
        }

        (bool hasResponse, uint8 validationResponse) = validationRegistry
            .getValidationResponse(dataHash);
        if (!hasResponse) {
            revert InvalidValidation();
        }
        if (validationResponse < escrow.minValidation) {
            revert InvalidValidation();
        }

        (bool success, ) = payable(msg.sender).call{value: escrow.amount}("");
        if (!success) {
            revert TransferFailed();
        }

        _claimed[escrowId] = true;
        emit EscrowClaimEvent(escrowId, msg.sender, fulfillment);
    }

    function reclaimExpired(uint256 escrowId) external {
        Escrow storage escrow = _escrows[escrowId];
        if (escrow.amount == 0) {
            revert InvalidEscrow();
        }
        if (_claimed[escrowId]) {
            revert InvalidEscrow();
        }
        if (msg.sender != escrow.escrower) {
            revert UnauthorizedClaim();
        }
        if (escrow.expirationTime > block.timestamp) {
            revert UnauthorizedClaim();
        }

        (bool success, ) = payable(msg.sender).call{value: escrow.amount}("");
        if (!success) {
            revert TransferFailed();
        }

        _claimed[escrowId] = true;
        emit EscrowReclaimEvent(escrowId, msg.sender);
    }

    function getEscrow(uint256 escrowId) external view returns (Escrow memory) {
        return _escrows[escrowId];
    }
}
