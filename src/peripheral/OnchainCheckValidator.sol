// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../interfaces/IValidationRegistry.sol";
import "../interfaces/IIdentityRegistry.sol";
import "../interfaces/IValidator.sol";

contract OnchainCheckValidator is IValidator {
    // DemandData could be anything. in this example, we check that keccak256(data) == dataHash
    struct DemandData {
        bytes data;
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
        bytes32 dataHash,
        DemandData memory demand
    ) internal pure returns (uint8) {
        // this could represent any on-chain computation on (demand, fulfillment dataHash)
        // in this example, we just check that keccak256(demand.data) == dataHash
        if (keccak256(demand.data) != dataHash) {
            return 0;
        }
        return 100;
    }

    function validate(bytes32 dataHash, bytes memory demand) external {
        DemandData memory demandData = abi.decode(demand, (DemandData));

        validationRegistry.validationResponse(
            dataHash,
            _onchainCheck(dataHash, demandData)
        );
    }
}
