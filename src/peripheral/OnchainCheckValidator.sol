// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../interfaces/IValidationRegistry.sol";
import "../interfaces/IIdentityRegistry.sol";

contract OnchainCheckValidator {
    // DemandData and FulfillmentData could be anything. in this example, we check that a + b == sum
    struct DemandData {
        uint256 a;
        uint256 b;
    }

    struct FulfillmentData {
        uint256 sum;
    }

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

    function _onchainCheck(
        DemandData memory demand,
        FulfillmentData memory fulfillment
    ) internal pure returns (uint8) {
        // this could represent any on-chain computation on fulfillment, demand)
        // in this example, we check that demand.a + demand.b == fulfillment.sum
        if (fulfillment.sum == demand.a + demand.b) {
            return 100;
        }
        return 0;
    }

    function validate(
        DemandData memory demand,
        FulfillmentData memory fulfillment
    ) external returns (uint8 response) {
        response = _onchainCheck(demand, fulfillment);

        bytes memory demandBytes = abi.encode(demand);
        bytes memory fulfillmentBytes = abi.encode(fulfillment);
        bytes32 dataHash = keccak256(
            abi.encodePacked(demandBytes, fulfillmentBytes)
        );

        validationRegistry.validationResponse(dataHash, response);
    }
}
