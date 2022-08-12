// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "../openzeppelin-contracts-upgradeable-master/contracts/access/AccessControlUpgradeable.sol";
import "./PureFiVerifier.sol";
import "./PureFiIssuerRegistry.sol";
import "./PureFiWhitelist.sol";
import "./utils/ParamStorage.sol";

// @deprecated
contract PureFiRouter is AccessControlUpgradeable, ParamStorage{

  uint16 private constant PARAM_ISSUER_REGISTRY_ADDRESS = 1;
  uint16 private constant PARAM_VERIFIER_ADDRESS = 2;
  uint16 private constant PARAM_VERIFICATION_WHITELIST = 3;
  
  function initialize(address admin) public initializer{
    __AccessControl_init();
    _setupRole(DEFAULT_ADMIN_ROLE, admin);
  }

  /**
  * changelog:
  * 1000001 -> 1000002: added default AML check
  * 1000002 -> 1001002: adopted for new Whitelist and Verifier, moved default verification into Verifier contract
   */
  function version() public pure returns(uint32){
    // 000.000.000 - Major.minor.internal
    return 1001002;
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

  

  function isValidIssuer(address _issuer) external view returns(bool){
    return PureFiIssuerRegistry(addressParams[PARAM_ISSUER_REGISTRY_ADDRESS]).isValidIssuer(_issuer);
  }

    /**
    * Returns true in case the _address has been verified before and verification 
    * data has been uploaded on-chain
    * @param _user - address to verify
    * @param _ruleID - verification rule
    * returns true/false
    */
  function isAddressVerified(address _user, uint256 _ruleID) external view returns(bool){
    return PureFiWhitelist(addressParams[PARAM_VERIFICATION_WHITELIST]).isAddressVerified(_user ,_ruleID);
  }
  /** 
  * Returns the verification data record for the user address and ruleID
  * @param _user - a user address
  * @param _ruleID - ruleID 
  * @return tuple with the following items:
      [0] - sessionID
      [1] - verified on (timestamp, seconds)
      [2] - valid until (timestamp, seconds)
      [3] - record issuer adddress
  */
  function getAddressVerificationData(address _user, uint256 _ruleID) external view returns(uint256,uint64,uint64,address){
    return PureFiWhitelist(addressParams[PARAM_VERIFICATION_WHITELIST]).getAddressVerificationData(_user, _ruleID);
  }

  function getIssuerRegistryAddress() external view returns (address){
    return addressParams[PARAM_ISSUER_REGISTRY_ADDRESS];
  }

  function getVerifierAddress() external view returns (address){
    return addressParams[PARAM_VERIFIER_ADDRESS];
  }

  function getDefaultAMLRule() external view returns (uint256){
    return PureFiVerifier(addressParams[PARAM_VERIFIER_ADDRESS]).getUint256(4);
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
    return PureFiVerifier(addressParams[PARAM_VERIFIER_ADDRESS]).defaultAMLCheck(fundsSender, data, signature);
  }
  
  function _authorizeSetter(address _setter) internal override view returns (bool){
    return hasRole(DEFAULT_ADMIN_ROLE, _setter);
  }

}
