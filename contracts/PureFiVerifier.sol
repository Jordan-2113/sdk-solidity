// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "../openzeppelin-contracts-upgradeable-master/contracts/security/PausableUpgradeable.sol";
import "../openzeppelin-contracts-upgradeable-master/contracts/access/OwnableUpgradeable.sol";
import "../openzeppelin-contracts-master/contracts/access/Ownable.sol";
import "./libraries/SignLib.sol";
import "./PureFiWhitelist.sol";
import "./PureFiIssuerRegistry.sol";
import "./utils/ParamStorage.sol";
import "./VerificationInfo.sol";


contract PureFiVerifier is OwnableUpgradeable, ParamStorage, SignLib,  VerificationInfo{

  uint16 private constant ERROR_ISSUER_SIGNATURE_INVALID = 1;
  uint16 private constant ERROR_FUNDS_SENDER_DOESNT_MATCH_ADDRESS_VERIFIED = 2;
  uint16 private constant ERROR_PROOF_VALIDITY_EXPIRED = 3;
  uint16 private constant ERROR_RULE_DOESNT_MATCH = 4;
  uint16 private constant ERROR_CREDENTIALS_TIME_MISMATCH = 5;
  uint16 private constant ERROR_DATA_PACKAGE_INVALID = 6;

  uint16 private constant PARAM_DEFAULT_AML_GRACETIME = 3;
  uint16 private constant PARAM_DEFAULT_AML_RULE = 4;
  uint16 private constant PARAM_DEFAULT_KYC_RULE = 5;
  uint16 private constant PARAM_DEFAULT_KYCAML_RULE = 6;
  uint16 private constant PARAM_ISSUER_REGISTRY_ADDRESS = 7;
  uint16 private constant PARAM_WHITELIST_ADDRESS = 8;

  uint16 private constant ERROR_RECIPIENT_MISMATCH = 7;
  uint16 private constant ERROR_ASSET_MISMATCH = 8;
  uint16 private constant ERROR_AMOUNT_MISMATCH = 9;

  function initialize(address _issuerRegistry, address _whitelist) public initializer{
    __Ownable_init();
    addressParams[PARAM_ISSUER_REGISTRY_ADDRESS] = _issuerRegistry;
    addressParams[PARAM_WHITELIST_ADDRESS] = _whitelist;
  }

    /**
  Changelog:
  version 1001001:
   */
  function version() public pure returns(uint32){
    // 000.000.000 - Major.minor.internal
    return 2000003;
  }

  /**
    Verifies signed data package
    Params:
    @param data - signed data package from the off-chain verifier
      data[0] - verification session ID
      data[1] - circuit ID (if required)
      data[2] - verification timestamp
      data[3] - verified wallet - to be the same as msg.sender
    @param signature - Off-chain verifier signature
   */
  function verifyIssuerSignature(uint256[] memory data, bytes memory signature) external view returns (bool){
      address recovered = recoverSigner(keccak256(abi.encodePacked(data[0], data[1], data[2], data[3])), signature);
      return PureFiIssuerRegistry(addressParams[PARAM_ISSUER_REGISTRY_ADDRESS]).isValidIssuer(recovered);
  }

  /**
  performs default AML Verification of the funds sender
  Params:
  @param expectedData- an address sending funds (can't be automatically determined here, so has to be provided by the caller)
  @param data - signed data package from the off-chain verifier
    data[0] - verification session ID
    data[1] - circuit ID (if required)
    data[2] - verification timestamp
    data[3] - verified wallet - to be the same as msg.sender
  @param signature - Off-chain issuer signature
  */
  function defaultAMLCheck(VerificationData calldata expectedData, uint256[] memory data, bytes memory signature) external view returns (uint16, string memory){
    return _verifyAgainstRule_IM(expectedData, uintParams[PARAM_DEFAULT_AML_RULE], data, signature);
  }

  /**
  performs default KYC Verification of the funds sender from on-chain whitelist
  Params:
  @param expectedData - an address sending funds (can't be automatically determined here, so has to be provided by the caller)
  */
  function defaultKYCCheck(VerificationData calldata expectedData, uint256[] memory data, bytes memory signature) external view returns (uint16, string memory){
    if(( data.length == 4 || data.length ==7 ) && data[0] > 0) {
      //attempt IM check if data is filled
      return _verifyAgainstRule_IM(expectedData, uintParams[PARAM_DEFAULT_KYC_RULE], data, signature); 
    } else {
      //try with W check when data is empty.
      return _verifyAgainstRule_W(expectedData.from, uintParams[PARAM_DEFAULT_KYC_RULE]);
    }
  }

  /**
  performs default KYC + AML Verification of the funds sender from on-chain whitelist
  Params:
  @param expectedData - an address sending funds (can't be automatically determined here, so has to be provided by the caller)
  @param data - signed data package from the off-chain verifier
    data[0] - verification session ID
    data[1] - circuit ID (if required)
    data[2] - verification timestamp
    data[3] - verified wallet - to be the same as msg.sender
  @param signature - Off-chain issuer signature
  */
  function defaultKYCAMLCheck(VerificationData calldata expectedData, uint256[] memory data, bytes memory signature) external view returns (uint16, string memory){
    if(data.length !=4 || data.length != 7 ){
      return _fail(ERROR_DATA_PACKAGE_INVALID);
    }
    if(data[1] == uintParams[PARAM_DEFAULT_KYCAML_RULE]){
      //attempt interactive KYC+AML rule check
      return _verifyAgainstRule_IM(expectedData, uintParams[PARAM_DEFAULT_KYCAML_RULE], data, signature);
    } else if(data[1] == uintParams[PARAM_DEFAULT_AML_RULE]){
      //attempt separate KYC/whitelist and AML/Interactive check;
      (uint16 _kycCode, string memory _message) = _verifyAgainstRule_W(expectedData.from, uintParams[PARAM_DEFAULT_KYC_RULE]);
      if(_kycCode > 0 ){
        return (_kycCode, _message); //return original error code 
      } else {
        //attempt separate AML check and return result
        return _verifyAgainstRule_IM(expectedData, uintParams[PARAM_DEFAULT_AML_RULE], data, signature);
      }
    } else {
      return _fail(ERROR_RULE_DOESNT_MATCH);
    }
  }

  /**
  performs verification against the rule specified in combined mode. Attempts Interactive mode if data is filled, then Whitelist mode.
  Params:
  @param expectedData - an address sending funds (can't be automatically determined here, so has to be provided by the caller)
  @param expectedRuleID - a Rule identifier expected by caller
  @param data - signed data package from the off-chain verifier
    data[0] - verification session ID
    data[1] - circuit ID (if required)
    data[2] - verification timestamp

    data[3] - verified wallet - to be the same as msg.sender
    data[4] - recipient wallet
    data[5] - token address
    data[6] - token amount
  @param signature - Off-chain issuer signature
  */
  function verifyAgainstRule(VerificationData calldata expectedData, uint256 expectedRuleID, uint256[] memory data, bytes memory signature) external view returns (uint16, string memory){
    if((data.length == 4 || data.length ==7) && data[0] > 0) {
      //attempt IM check if data is filled
      return _verifyAgainstRule_IM(expectedData, expectedRuleID, data, signature); 
    } else {
      //try with W check when data is empty.
      return _verifyAgainstRule_W(expectedData.from, expectedRuleID);
    }
  }

  /**
  performs verification against the rule specified in Interactive mode
  Params:
  @param expectedData - an address sending funds (can't be automatically determined here, so has to be provided by the caller)
  @param expectedRuleID - a Rule identifier expected by caller
  @param data - signed data package from the off-chain verifier
    data[0] - verification session ID
    data[1] - circuit ID (if required)
    data[2] - verification timestamp
    data[3] - verified wallet - to be the same as msg.sender
  @param signature - Off-chain issuer signature
  */
  function verifyAgainstRuleIM(VerificationData calldata expectedData, uint256 expectedRuleID, uint256[] memory data, bytes memory signature) external view returns (uint16, string memory){
    return _verifyAgainstRule_IM(expectedData, expectedRuleID, data, signature);
  }

  /**
  performs verification against the rule specified in Whitelist mode
  Params:
  @param expectedFundsSender - an address sending funds (can't be automatically determined here, so has to be provided by the caller)
  @param expectedRuleID - a Rule identifier expected by caller
  */
  function verifyAgainstRuleW(address expectedFundsSender, uint256 expectedRuleID) external view returns (uint16, string memory){
    return _verifyAgainstRule_W(expectedFundsSender, expectedRuleID);
  }

  //************* PRIVATE FUNCTIONS ****************** */
  /**
  Whitelist mode rule verification 
  */
  function _verifyAgainstRule_W(address expectedFundsSender, uint256 expectedRuleID) private view returns (uint16, string memory){
    (,uint64 verifiedOn, uint64 verifiedUntil,) = PureFiWhitelist(addressParams[PARAM_WHITELIST_ADDRESS]).getAddressVerificationData(expectedFundsSender, expectedRuleID);
    if(verifiedOn > block.timestamp || verifiedUntil < block.timestamp){
      return _fail(ERROR_CREDENTIALS_TIME_MISMATCH);
    }
    else{
      return _succeed();
    }
  }

  /**
  Interactive mode rule verification (data and signature provided by the Issuer backend)
  */
  function _verifyAgainstRule_IM(VerificationData calldata expectedData, uint256 expectedRuleID, uint256[] memory data, bytes memory signature) private view returns (uint16, string memory){
    if(data.length !=4 && data.length != 7){
      return _fail(ERROR_DATA_PACKAGE_INVALID);
    }
    address recovered = recoverSigner(keccak256(abi.encodePacked(data[0], data[1], data[2], data[3])), signature);

    if(!PureFiIssuerRegistry(addressParams[PARAM_ISSUER_REGISTRY_ADDRESS]).isValidIssuer(recovered)){
      return _fail(ERROR_ISSUER_SIGNATURE_INVALID); //"Signature invalid"
    }
    if(expectedData.from != address(uint160(data[3]))){
      // "DefaultAMLCheck: tx sender doesn't match verified wallet"
      return _fail(ERROR_FUNDS_SENDER_DOESNT_MATCH_ADDRESS_VERIFIED);
    }
    // grace time recommended:
    // Ethereum: 10 min
    // BSC: 3 min
    if(data[2] + uintParams[PARAM_DEFAULT_AML_GRACETIME] < block.timestamp){
      //"DefaultAMLCheck: verification data expired"
      return _fail(ERROR_PROOF_VALIDITY_EXPIRED);
    }
    if(data[1] != expectedRuleID){
      //"DefaultAMLCheck: rule verification failed"
      return _fail(ERROR_RULE_DOESNT_MATCH);
    }

    if(data.length == 7){
      if(expectedData.to != address(uint160(data[4]))){
        return _fail(ERROR_RECIPIENT_MISMATCH);
      }
      if(expectedData.token != address(uint160(data[5]))){
        return _fail(ERROR_ASSET_MISMATCH);
      }

      if( expectedData.amount != data[6] ){
        return _fail(ERROR_AMOUNT_MISMATCH);
      }
    }
    return _succeed();
  }

  function _fail(uint16 _errorCode) private view returns (uint16, string memory) {
    return (_errorCode, stringParams[_errorCode]);
  }

  function _succeed() private pure returns (uint16, string memory) {
    return (0, "Verification passed successfully");
  }

  function _authorizeSetter(address _setter) internal override view returns (bool){
    return owner() == _setter;
  }

}
