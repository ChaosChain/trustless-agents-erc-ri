// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../interfaces/IValidationRegistry.sol";
import "../interfaces/IIdentityRegistry.sol";

contract OptimisticMediationValidator {
    struct DemandData {
        address mediator;
        uint256 mediationDeadline;
    }

    enum MediationResponse {
        NONE,
        ACCEPTED,
        REJECTED
    }

    error AwaitingMediation();

    event MediationRequested(
        address mediator,
        uint256 mediationDeadline,
        bytes demand,
        bytes fulfillment
    );

    mapping(address => mapping(bytes32 => MediationResponse))
        private _responses;

    mapping(address => mapping(bytes32 => uint8)) private _mediations;

    IIdentityRegistry public immutable identityRegistry;
    IValidationRegistry public immutable validationRegistry;
    uint256 public immutable validatorAgentId;

    uint256 private constant REGISTRATION_FEE = 0.005 ether;

    constructor(
        address _identityRegistry,
        address _validationRegistry,
        string memory _agentDomain
    ) payable {
        require(msg.value >= REGISTRATION_FEE, "Insufficient registration fee");

        identityRegistry = IIdentityRegistry(_identityRegistry);
        validationRegistry = IValidationRegistry(_validationRegistry);

        // Self-register as validator agent
        validatorAgentId = identityRegistry.newAgent{value: REGISTRATION_FEE}(
            _agentDomain,
            address(this)
        );

        // Refund excess ETH if any
        if (msg.value > REGISTRATION_FEE) {
            (bool success, ) = msg.sender.call{
                value: msg.value - REGISTRATION_FEE
            }("");
            require(success, "Refund failed");
        }
    }

    function requestMediation(
        bytes memory demand,
        bytes memory fulfillment,
        address mediator,
        uint256 mediationDeadline
    ) external {
        emit MediationRequested(
            mediator,
            mediationDeadline,
            demand,
            fulfillment
        );
    }

    function mediate(
        bytes32 dataHash, // keccak256(abi.encodePacked(demand, fulfillment))
        MediationResponse response
    ) external {
        _responses[msg.sender][dataHash] = response;
    }

    function validate(
        DemandData memory demand,
        bytes memory fulfillment
    ) external {
        bytes memory demandBytes = abi.encode(demand);
        bytes32 dataHash = keccak256(
            abi.encodePacked(demandBytes, fulfillment)
        );

        MediationResponse response = _responses[demand.mediator][dataHash];

        if (response == MediationResponse.ACCEPTED) {
            validationRegistry.validationResponse(dataHash, 100);
            return;
        }

        if (response == MediationResponse.REJECTED) {
            validationRegistry.validationResponse(dataHash, 0);
            return;
        }

        // If no response (NONE) and past deadline, optimistic acceptance
        if (
            response == MediationResponse.NONE &&
            block.timestamp > demand.mediationDeadline
        ) {
            // optimistic mediation: accept by default
            validationRegistry.validationResponse(dataHash, 100);
            return;
        }

        // No response and not past deadline - do not validate yet
        revert AwaitingMediation();
    }
}
