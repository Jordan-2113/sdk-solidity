// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../openzeppelin-contracts-upgradeable-master/contracts/proxy/utils/Initializable.sol";
import "./interfaces/IPureFiVerifier.sol";
import "./VerificationInfo.sol";
abstract contract PureFiContext is Initializable{

    enum DefaultRule {NONE, KYC, AML, KYCAML} 
    
    uint256 internal constant _NOT_VERIFIED = 0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffa;
    uint256 internal constant _VERIFICATION_SUCCESS = 0;
    string internal constant _NOT_VERIFIED_REASON = "PureFi: Not verified";


    uint256 private _txLocalCheckResult; //similar to re-entrancy guard status or ThreadLocal in Java
    string private _txLocalCheckReason; //similar to re-entrancy guard status or ThreadLocal in Java
    
    IPureFiVerifier internal pureFiVerifier;

    function __PureFiContext_init_unchained(address _pureFiVerifier) internal initializer{
        _txLocalCheckResult = _NOT_VERIFIED;
        _txLocalCheckReason = _NOT_VERIFIED_REASON;
        pureFiVerifier = IPureFiVerifier(_pureFiVerifier);
    }

    modifier rejectUnverified() {
        require(_txLocalCheckResult == _VERIFICATION_SUCCESS, _txLocalCheckReason);
        _;
    }

    modifier requiresOnChainKYC(address user){

        VerificationInfo.VerificationData memory expectedData = VerificationInfo.VerificationData({
            from : user,
            to : address(0),
            token : address(0),
            amount : 0
        });
        uint256[] memory data = new uint256[](4);
        bytes memory signature;
        (_txLocalCheckResult, _txLocalCheckReason) = pureFiVerifier.defaultKYCCheck(expectedData, data, signature);
        require(_txLocalCheckResult == _VERIFICATION_SUCCESS, _txLocalCheckReason);
        //here the smart contract can decide whether to fail a transaction in case of check failed

        _;

        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _txLocalCheckResult = _NOT_VERIFIED;
        _txLocalCheckReason = _NOT_VERIFIED_REASON;
    }


    modifier compliesDefaultRule(DefaultRule rule, VerificationInfo.VerificationData calldata expectedData, uint256[] memory data, bytes memory signature) {
        // set context variable
        if(rule == DefaultRule.NONE){
            _txLocalCheckResult = _VERIFICATION_SUCCESS;
        } else {
            if(rule == DefaultRule.KYC){
                (_txLocalCheckResult, _txLocalCheckReason) = pureFiVerifier.defaultKYCCheck(expectedData, data, signature);
            } else if (rule == DefaultRule.AML){
                (_txLocalCheckResult, _txLocalCheckReason) = pureFiVerifier.defaultAMLCheck(expectedData, data, signature);
            } else if (rule == DefaultRule.KYCAML){
                (_txLocalCheckResult, _txLocalCheckReason) = pureFiVerifier.defaultKYCAMLCheck(expectedData, data, signature);
            }
            require(_txLocalCheckResult == _VERIFICATION_SUCCESS, _txLocalCheckReason);
        }
        
        //here the smart contract can decide whether to fail a transaction in case of check failed

        _;

        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _txLocalCheckResult = _NOT_VERIFIED;
        _txLocalCheckReason = _NOT_VERIFIED_REASON;
    }

    modifier compliesCustomRule(uint256 expectedRuleID, VerificationInfo.VerificationData calldata expectedData, uint256[] memory data, bytes memory signature) {

        (_txLocalCheckResult, _txLocalCheckReason) = pureFiVerifier.verifyAgainstRule(expectedData, expectedRuleID, data, signature);
        require(_txLocalCheckResult == _VERIFICATION_SUCCESS, _txLocalCheckReason);
        
        //here the smart contract can decide whether to fail a transaction in case of check failed

        _;

        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _txLocalCheckResult = _NOT_VERIFIED;
        _txLocalCheckReason = _NOT_VERIFIED_REASON;
    }

}
