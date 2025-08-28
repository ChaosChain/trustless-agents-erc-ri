// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IValidator {
    function validate(bytes32 dataHash, bytes memory demand) external;
}
