// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../interfaces/IValidationRegistry.sol";
import "../interfaces/IIdentityRegistry.sol";
import "../interfaces/IValidator.sol";

contract OptimisticMediationValidator is IValidator {
    struct DemandData {
        address mediator;
        uint256 mediationDeadline;
    }

    enum MediationReponse {
        NONE,
        ACCEPTED,
        REJECTED
    }

    error AwaitingMediation();

    event MediationRequested(
        bytes32 dataHash,
        address mediator,
        uint256 mediationDeadline
    );

    mapping(address => mapping(bytes32 => MediationReponse)) private _responses;

    function mediate(bytes32 dataHash, MediationReponse response) external {
        _responses[msg.sender][dataHash] = response;
    }

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
        bytes32 dataHash,
        address mediator,
        uint256 mediationDeadline
    ) external {
        emit MediationRequested(dataHash, mediator, mediationDeadline);
    }

    function validate(bytes32 dataHash, bytes memory demand) external {
        DemandData memory demandData = abi.decode(demand, (DemandData));

        MediationReponse response = _responses[demandData.mediator][dataHash];

        if (response == MediationReponse.ACCEPTED) {
            validationRegistry.validationResponse(dataHash, 100);
            return;
        }

        if (response == MediationReponse.REJECTED) {
            validationRegistry.validationResponse(dataHash, 0);
            return;
        }

        // If no response (NONE) and past deadline, optimistic acceptance
        if (
            response == MediationReponse.NONE &&
            block.timestamp > demandData.mediationDeadline
        ) {
            // optimistic mediation: accept by default
            validationRegistry.validationResponse(dataHash, 100);
            return;
        }

        // No response and not past deadline - do not validate yet
        revert AwaitingMediation();
    }
}
