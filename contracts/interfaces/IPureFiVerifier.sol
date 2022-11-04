// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../VerificationInfo.sol";

interface IPureFiVerifier{

    function verifyIssuerSignature(uint256[] memory data, bytes memory signature) external view returns (bool);
    function defaultAMLCheck(VerificationInfo.VerificationData calldata expectedData, uint256[] memory data, bytes memory signature) external view returns (uint16, string memory);
    function defaultKYCCheck(VerificationInfo.VerificationData calldata expectedData, uint256[] memory data, bytes memory signature) external view returns (uint16, string memory);
    function defaultKYCAMLCheck(VerificationInfo.VerificationData calldata expectedData, uint256[] memory data, bytes memory signature) external view returns (uint16, string memory);
    function verifyAgainstRule(VerificationInfo.VerificationData calldata expectedData, uint256 expectedRuleID, uint256[] memory data, bytes memory signature) external view returns (uint16, string memory);
    function verifyAgainstRuleIM(VerificationInfo.VerificationData calldata expectedData, uint256 expectedRuleID, uint256[] memory data, bytes memory signature) external view returns (uint16, string memory);
    function verifyAgainstRuleW(address expectedFundsSender, uint256 expectedRuleID) external view returns (uint16, string memory);  
}