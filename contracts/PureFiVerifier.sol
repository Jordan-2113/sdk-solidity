// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "../openzeppelin-contracts-upgradeable-master/contracts/security/PausableUpgradeable.sol";
import "../openzeppelin-contracts-upgradeable-master/contracts/access/OwnableUpgradeable.sol";
import "../openzeppelin-contracts-master/contracts/access/Ownable.sol";
import "./libraries/SignLib.sol";
import "./PureFiWhitelist.sol";
import "./PureFiIssuerRegistry.sol";
import "./utils/ParamStorage.sol";
import "./interfaces/IPureFiVerifier.sol";




contract PureFiVerifier is OwnableUpgradeable, ParamStorage, SignLib, IPureFiVerifier{

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
      address recovered = recoverSigner(keccak256(_encodeData(data)), signature);
      return PureFiIssuerRegistry(addressParams[PARAM_ISSUER_REGISTRY_ADDRESS]).isValidIssuer(recovered);
  }

  /**
  performs default AML Verification of the funds sender
  Params:
  @param data - signed data package from the off-chain verifier
    data[0] - verification session ID
    data[1] - circuit ID (if required)
    data[2] - verification timestamp
    data[3] - verified wallet - to be the same as msg.sender
  @param signature - Off-chain issuer signature
  */
  function defaultAMLCheck( uint256[] memory data, bytes memory signature) external view returns (VerificationData memory, uint16){
    return _verifyAgainstRule_IM(data, signature);
  }

  /**
  performs default KYC Verification of the funds sender from on-chain whitelist
  Params:
  */
  function defaultKYCCheck(uint256[] memory data, bytes memory signature) external view returns (VerificationData memory, uint16){
    if(( data.length == 4 || data.length ==7 ) && data[0] > 0) {
      //attempt IM check if data is filled
      return _verifyAgainstRule_IM(data, signature); 
    } else {
      //try with W check when data is empty.
      // TODO : Questinable moment. It can be unclear for customer what data must be
      (uint16 statusCode, ) = _verifyAgainstRule_W(address(uint160(data[0])), uintParams[PARAM_DEFAULT_KYC_RULE]);
      return (_getEmptyVerificationData(), statusCode);
    }
  }

  /**
  performs default KYC + AML Verification of the funds sender from on-chain whitelist
  Params:
  @param data - signed data package from the off-chain verifier
    data[0] - verification session ID
    data[1] - circuit ID (if required)
    data[2] - verification timestamp
    data[3] - verified wallet - to be the same as msg.sender
  @param signature - Off-chain issuer signature
  */
  function defaultKYCAMLCheck(uint256[] memory data, bytes memory signature) external view returns (VerificationData memory, uint16){
    if(data.length !=4 || data.length != 7 ){
      return ( _getEmptyVerificationData(), ERROR_DATA_PACKAGE_INVALID);
    }
    if(data[1] == uintParams[PARAM_DEFAULT_KYCAML_RULE]){
      //attempt interactive KYC+AML rule check
      return _verifyAgainstRule_IM(data, signature);
    } else if(data[1] == uintParams[PARAM_DEFAULT_AML_RULE]){
      //attempt separate KYC/whitelist and AML/Interactive check;
      (uint16 _kycCode, ) = _verifyAgainstRule_W(address(uint160(data[3])), uintParams[PARAM_DEFAULT_KYC_RULE]);
      if(_kycCode > 0 ){
        return (_getEmptyVerificationData(), _kycCode); //return original error code 
      } else {
        //attempt separate AML check and return result
        return _verifyAgainstRule_IM(data, signature);
      }
    } else {
      return (_getEmptyVerificationData() , ERROR_RULE_DOESNT_MATCH);
    }
  }

  /**
  performs verification against the rule specified in combined mode. Attempts Interactive mode if data is filled, then Whitelist mode.
  Params:
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
  function verifyAgainstRule( uint256[] memory data, bytes memory signature) external view returns (VerificationData memory, uint16){
    if((data.length == 4 || data.length ==7) && data[0] > 0) {
      //attempt IM check if data is filled
      return _verifyAgainstRule_IM(data, signature); 
    } else {
      //try with W check when data is empty.
      (uint16 status, ) = _verifyAgainstRule_W(address(uint160(data[3])), data[1]);
      return (_getEmptyVerificationData(), status);
    }
  }

  /**
  performs verification against the rule specified in Interactive mode
  Params:
  @param data - signed data package from the off-chain verifier
    data[0] - verification session ID
    data[1] - circuit ID (if required)
    data[2] - verification timestamp
    data[3] - verified wallet - to be the same as msg.sender
  @param signature - Off-chain issuer signature
  */
  function verifyAgainstRuleIM( uint256[] memory data, bytes memory signature) external view returns (VerificationData memory, uint16){
    return _verifyAgainstRule_IM(data, signature);
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
  function _verifyAgainstRule_IM(uint256[] memory data, bytes memory signature) private view returns (VerificationData memory, uint16){
    
    uint length = data.length;
    require(length == 4 || length == 7 || length == 8, "PureFi Verifier : Invalid data package");

    address recovered = recoverSigner(keccak256(_encodeData(data)), signature);

    require(
      PureFiIssuerRegistry(addressParams[PARAM_ISSUER_REGISTRY_ADDRESS]).isValidIssuer(recovered), 
      "PureFi Verifier : Invalid signature"
    );

    // grace time recommended:
    // Ethereum: 10 min
    // BSC: 3 min
    require(
      data[2] + uintParams[PARAM_DEFAULT_AML_GRACETIME] > block.timestamp, 
      "PureFi Verifier : Proof validity expired"
    );

    return (_getDataFromArray(data), 0);

  }

  function _encodeData( uint256[] memory data ) internal pure returns(bytes memory encodedData){
      for(uint i = 0; i < data.length; i++){
        encodedData = bytes.concat(encodedData, abi.encodePacked(data[i]));
      }
  }

  function _getDataFromArray( uint256[] memory data ) internal pure returns( VerificationData memory verificationData ){
    verificationData = _getEmptyVerificationData();

    // common field 
    verificationData.from = address(uint160(data[3]));

    if( data.length == 4 ){
      verificationData.typ = 1;
    }else if(data.length >= 7){
      verificationData.typ = 2;
      verificationData.to = address(uint160(data[4]));
      verificationData.token = address(uint160(data[5]));
      verificationData.amount = data[6];
    }
    //TODO : set payload field

  }

  function _getEmptyVerificationData() internal pure returns (VerificationData memory){
    return VerificationData({
      typ : 0,
      from : address(0),
      to : address(0),
      token : address(0),
      amount : 0,
      payload : ''
    });
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
