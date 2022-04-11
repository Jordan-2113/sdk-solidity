// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "../openzeppelin-contracts-upgradeable-master/contracts/access/AccessControlUpgradeable.sol";
import "./PureFiVerifier.sol";
import "./PureFiIssuerRegistry.sol";
import "./PureFiWhitelist.sol";

contract PureFiRouter is AccessControlUpgradeable{

  uint16 private constant PARAM_ISSUER_REGISTRY_ADDRESS = 1;
  uint16 private constant PARAM_VERIFIER_ADDRESS = 2;
  uint16 private constant PARAM_VERIFICATION_WHITELIST = 3;

  mapping (uint16 => address) public addressParams;
  
  function initialize(address admin) public initializer{
    __AccessControl_init();
    _setupRole(DEFAULT_ADMIN_ROLE, admin);
  }


  function version() public pure returns(uint32){
    // 000.000.000 - Major.minor.internal
    return 1000001;
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
    return PureFiVerifier(addressParams[PARAM_VERIFIER_ADDRESS]).verifyIssuerSignature(data, signature);
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
  
  function getAddress(uint16 key) external view returns (address){
    return addressParams[key];
  }
  
  // ************ ADMIN FUNCTIONS ******************
  function setAddress(uint16 _key, address _value) public onlyRole(DEFAULT_ADMIN_ROLE) {
    addressParams[_key] = _value;
  }

}
