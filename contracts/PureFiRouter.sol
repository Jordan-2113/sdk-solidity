// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "../openzeppelin-contracts-upgradeable-master/contracts/access/AccessControlUpgradeable.sol";
import "./PureFiVerifier.sol";
import "./PureFiIssuerRegistry.sol";
import "./PureFiWhitelist.sol";

contract PureFiRouter is AccessControlUpgradeable{

  uint16 public constant ERROR_ISSUER_SIGNATURE_INVALID = 1;
  uint16 public constant ERROR_FUNDS_SENDER_DOESNT_MATCH_ADDRESS_VERIFIED = 2;
  uint16 public constant ERROR_PROOF_VALIDITY_EXPIRED = 3;
  uint16 public constant ERROR_RULE_DOESNT_MATCH = 4;

  uint16 private constant PARAM_ISSUER_REGISTRY_ADDRESS = 1;
  uint16 private constant PARAM_VERIFIER_ADDRESS = 2;
  uint16 private constant PARAM_VERIFICATION_WHITELIST = 3;
  uint16 private constant PARAM_DEFAULT_AML_RULE = 4;

  mapping (uint16 => address) public addressParams;
  mapping (uint16 => uint256) public uintParams;
  mapping (uint16 => string) private errorMessages;

  event AddressValueChanged(uint16 key, address oldValue, address newValue);
  event UintValueChanged(uint16 key, uint256 oldValue, uint256 newValue);
  event ErrorMessageChanged(uint16 key, string oldValue, string newValue);
  
  function initialize(address admin) public initializer{
    __AccessControl_init();
    _setupRole(DEFAULT_ADMIN_ROLE, admin);
  }

  /**
  * changelog:
  * 1000001 -> 1000002: added default AML check
   */
  function version() public pure returns(uint32){
    // 000.000.000 - Major.minor.internal
    return 1000002;
  }

  /**
  Verifies signed data package
  Params:
  @param data - signed data package from the off-chain verifier
    data[0] - verification session ID
    data[1] - circuit ID (if required)
    data[2] - verification timestamp
    data[3] - verified wallet - to be the same as msg.sender
  @param signature - Off-chain issuer signature
  */
  function verifyIssuerSignature(uint256[] memory data, bytes memory signature) external view returns (bool){
    return PureFiVerifier(addressParams[PARAM_VERIFIER_ADDRESS]).verifyIssuerSignature(data, signature);
  }

  /**
  performs default AML Verification agains funds sender
  Params:
  @param fundsSender - an address sending funds (can't be automatically determined here, so has to be provided by the caller)
  @param data - signed data package from the off-chain verifier
    data[0] - verification session ID
    data[1] - circuit ID (if required)
    data[2] - verification timestamp
    data[3] - verified wallet - to be the same as msg.sender
  @param signature - Off-chain issuer signature
  */
  function defaultAMLCheck(address fundsSender, uint256[] memory data, bytes memory signature) external view returns (uint16, string memory){
    if(!PureFiVerifier(addressParams[PARAM_VERIFIER_ADDRESS]).verifyIssuerSignature(data, signature)){
      return fail(ERROR_ISSUER_SIGNATURE_INVALID); //"Signature invalid"
    }
    if(fundsSender != address(uint160(data[3]))){
      // "DefaultAMLCheck: tx sender doesn't match verified wallet"
      return fail(ERROR_FUNDS_SENDER_DOESNT_MATCH_ADDRESS_VERIFIED);
    }
    // grace time recommended:
    // Ethereum: 10 min
    // BSC: 3 min
    if(data[2] + 180 < block.timestamp){
      //"DefaultAMLCheck: verification data expired"
      return fail(ERROR_PROOF_VALIDITY_EXPIRED);
    }
    // AML Risk Score rule checks:
    // 431001...431099: 
    // [431] stands for AML Risk Score Check, 
    // [001..099] - risk score threshold. I.e. validation passed when risk score <= [xxx]; 
    if(data[1] != uintParams[PARAM_DEFAULT_AML_RULE]){
      //"DefaultAMLCheck: rule verification failed"
      return fail(ERROR_RULE_DOESNT_MATCH);
    }
    return succeed();
  }

  function isValidIssuer(address _issuer) external view returns(bool){
      return PureFiIssuerRegistry(addressParams[PARAM_ISSUER_REGISTRY_ADDRESS]).isValidIssuer(_issuer);
  }

   /**
  Returns true in case the _address has been verified before and verification 
  data has been uploaded on-chain
  @param _address - address to verify
  returns true/false
  */
  function isAddressVerified(address _address) external view returns(bool){
    return PureFiWhitelist(addressParams[PARAM_VERIFICATION_WHITELIST]).isAddressVerified(_address);
  }

  function getAddressVerificationData(address _address) external view returns(uint256,uint256,uint64,uint64,address){
    return PureFiWhitelist(addressParams[PARAM_VERIFICATION_WHITELIST]).getAddressVerificationData(_address);
  }

  function getIssuerRegistryAddress() external view returns (address){
    return addressParams[PARAM_ISSUER_REGISTRY_ADDRESS];
  }

  function getVerifierAddress() external view returns (address){
    return addressParams[PARAM_VERIFIER_ADDRESS];
  }

  function getDefaultAMLRule() external view returns (uint256){
    return uintParams[PARAM_DEFAULT_AML_RULE];
  }
  
  function getAddress(uint16 key) external view returns (address){
    return addressParams[key];
  }

  function getUint256(uint16 key) external view returns (uint256){
    return uintParams[key];
  }
  
  // ************ ADMIN FUNCTIONS ******************
  function setAddress(uint16 _key, address _value) public onlyRole(DEFAULT_ADMIN_ROLE) {
    address oldValue = addressParams[_key];
    addressParams[_key] = _value;
    emit AddressValueChanged(_key, oldValue, addressParams[_key]);
  }

  function setUint256(uint16 _key, uint256 _value) public onlyRole(DEFAULT_ADMIN_ROLE) {
    uint256 oldValue = uintParams[_key];
    uintParams[_key] = _value;
    emit UintValueChanged(_key, oldValue, uintParams[_key]);
  }

  function setErrorMessage(uint16 _key, string memory _value) public onlyRole(DEFAULT_ADMIN_ROLE) {
    string memory oldValue = errorMessages[_key];
    errorMessages[_key] = _value;
    emit ErrorMessageChanged(_key, oldValue, errorMessages[_key]);
  }

  //************* PRIVATE FUNCTIONS ****************** */
  function fail(uint16 _errorCode) private view returns (uint16, string memory) {
    return (_errorCode, errorMessages[_errorCode]);
  }

  function succeed() private pure returns (uint16, string memory) {
    return (0, "DefaultAMLCheck succeeded");
  }
}
