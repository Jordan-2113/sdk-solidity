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

  uint16 private constant PARAM_DEFAULT_AML_GRACETIME = 3;
  uint16 private constant PARAM_ISSUER_REGISTRY_ADDRESS = 7;
  uint16 private constant PARAM_WHITELIST_ADDRESS = 8;

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
    return 2000004;
  }

  // IMPORTANT
  // _purefidata = {uint64 timestamp, bytes signature, bytes purefipackage}. 
  //      timestamp = uint64, 8 bytes,
  //      signature = bytes, 65 bytes fixed length (bytes32+bytes32+uint8)
  //      purefipackage = bytes, dynamic, remaining data
  // purefipackage = {uint8 purefipackagetype, bytes packagedata}. 
  //      purefipackagetype = uint8, 1 byte
  //      packagedata = bytes, dynamic, remaining data
  // if(purefipackagetype = 1) => packagedata = {uint256 ruleID, address sender}
  // if(purefipackagetype = 2) => packagedata = {uint256 ruleID, address sender, address receiver, address token, uint258 amount}
  // if(purefipackagetype = 3) => packagedata = {uint256 ruleID, bytes payload}
  // later on we'll add purefipackagetype = 4. with non-interactive mode data, and this will go into payload

  function validatePureFiData(bytes memory _purefidata) external override view returns (bytes memory, uint16){
    //min package size = 8+65 +1+32
    require(_purefidata.length >= (8+65+1+32), "PureFiVerifier: _purefidata too short");
    
    (uint64 timestamp, bytes memory signature, bytes memory purefipackage) = abi.decode(_purefidata, (uint64, bytes, bytes));

    //get issuer address from the signature
    address issuer = recoverSigner(keccak256(abi.encodePacked(timestamp, purefipackage)), signature);

    require(
      PureFiIssuerRegistry(addressParams[PARAM_ISSUER_REGISTRY_ADDRESS]).isValidIssuer(issuer), 
      "PureFi Verifier : Invalid signature"
    );

    // grace time recommended:
    // Ethereum: 10 min
    // BSC: 3 min
    require(
      timestamp + uintParams[PARAM_DEFAULT_AML_GRACETIME] > block.timestamp, 
      "PureFi Verifier : Proof validity expired"
    );

    return (purefipackage, 0);
  }


  // decode PureFi data package
  function decodePureFiPackage(bytes calldata _purefipackage) external override pure returns (VerificationPackage memory){
    uint8 packagetype = uint8(_purefipackage[0]);
    if(packagetype == 1){
      (uint256 ruleID, uint256 sessionID, address sender) = abi.decode(_purefipackage[1:], (uint256, uint256, address));
      return VerificationPackage({
          packagetype : 1,
          session: sessionID,
          rule : ruleID,
          from : sender,
          to : address(0),
          token : address(0),
          amount : 0,
          payload : ''
        }); 
    }
    else if(packagetype == 2){
      (uint256 ruleID, uint256 sessionID, address sender, address receiver, address token_addr, uint256 tx_amount) = abi.decode(_purefipackage[1:], (uint256, uint256, address, address, address, uint256));
      return VerificationPackage({
          packagetype : 2,
          rule : ruleID,
          session: sessionID,
          from : sender,
          to : receiver,
          token : token_addr,
          amount : tx_amount,
          payload : ''
        }); 
    }
    else if(packagetype == 3){
      (uint256 ruleID, uint256 sessionID, bytes memory payload_data) = abi.decode(_purefipackage[1:], (uint256, uint256, bytes));
      return VerificationPackage({
          packagetype : 2,
          rule : ruleID,
          session: sessionID,
          from : address(0),
          to : address(0),
          token : address(0),
          amount : 0,
          payload : payload_data
        }); 
    }
    require (false, "PureFiVerifier : invalid package data");
  }

  function _authorizeSetter(address _setter) internal virtual override view returns (bool){
    require(_setter == owner(), "PureFi Verifier : param setter not the owner");
    return true;
  }

}
