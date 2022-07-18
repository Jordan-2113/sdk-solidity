// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "../openzeppelin-contracts-upgradeable-master/contracts/security/PausableUpgradeable.sol";
import "../openzeppelin-contracts-upgradeable-master/contracts/access/OwnableUpgradeable.sol";
import "../openzeppelin-contracts-master/contracts/access/Ownable.sol";
import "./libraries/SignLib.sol";
import "./PureFiRouter.sol";
import "./utils/ParamStorage.sol";


contract PureFiVerifier is PausableUpgradeable, OwnableUpgradeable, ParamStorage, SignLib{

  uint16 public constant ERROR_ISSUER_SIGNATURE_INVALID = 1;
  uint16 public constant ERROR_FUNDS_SENDER_DOESNT_MATCH_ADDRESS_VERIFIED = 2;
  uint16 public constant ERROR_PROOF_VALIDITY_EXPIRED = 3;
  uint16 public constant ERROR_RULE_DOESNT_MATCH = 4;

  uint16 private constant PARAM_DEFAULT_AML_GRACETIME = 3;
  uint16 private constant PARAM_DEFAULT_AML_RULE = 4;

  PureFiRouter public router;
  mapping (address => TagetConfiguration) configurations;

  struct TagetConfiguration{
    uint64 graceTime;//verification grace time in seconds
    uint256 ruleID; //required ruleid for verification
  }
  // event Verified(address indexed )
  event TargetVerificationConfigured(address indexed target, uint64 graceTime, uint256 circuit);

  function initialize(address _router) public initializer{
    __Ownable_init();
    __Pausable_init_unchained();
    router = PureFiRouter(_router);
  }

    /**
  Changelog:
  version 1001001:
   */
  function version() public pure returns(uint32){
    // 000.000.000 - Major.minor.internal
    return 1001001;
  }

  /**
  * preconfigure verification rules for the target (specified by msg.sender).
  * Only contract can configure a rule for itself. No other options are available for pre-configuration
   */
  function configureTarget(uint64 _graceTime, uint256 _ruleID) external {
    configurations[msg.sender] = TagetConfiguration(_graceTime, _ruleID);
    emit TargetVerificationConfigured(msg.sender, _graceTime, _ruleID);
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
      return router.isValidIssuer(recovered);
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
    address recovered = recoverSigner(keccak256(abi.encodePacked(data[0], data[1], data[2], data[3])), signature);

    if(!router.isValidIssuer(recovered)){
      return _fail(ERROR_ISSUER_SIGNATURE_INVALID); //"Signature invalid"
    }
    if(fundsSender != address(uint160(data[3]))){
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
    // AML Risk Score rule checks:
    // 431001...431099: 
    // [431] stands for AML Risk Score Check, 
    // [001..099] - risk score threshold. I.e. validation passed when risk score <= [xxx]; 
    if(data[1] != uintParams[PARAM_DEFAULT_AML_RULE]){
      //"DefaultAMLCheck: rule verification failed"
      return _fail(ERROR_RULE_DOESNT_MATCH);
    }
    return _succeed();
  }

  function getDefaultAMLRule() external view returns (uint256){
    return uintParams[PARAM_DEFAULT_AML_RULE];
  }

  //************* PRIVATE FUNCTIONS ****************** */
  function _fail(uint16 _errorCode) private view returns (uint16, string memory) {
    return (_errorCode, stringParams[_errorCode]);
  }

  function _succeed() private pure returns (uint16, string memory) {
    return (0, "DefaultAMLCheck succeeded");
  }

  function _verifyData(
    address target,
    uint256[] memory data,
    bytes memory signature)
    internal returns (bool){
      address recovered = recoverSigner(keccak256(abi.encodePacked(data[0], data[1], data[2], data[3])), signature);
      require(router.isValidIssuer(recovered),"Verifier: Invalid issuer signature");
      require(address(uint160(data[3])) == msg.sender, "Verifier: tx sender doesn't match verified wallet");
      require(data[2] + configurations[target].graceTime >= block.timestamp, "Verifier: verification data expired");
      require(data[1] == configurations[target].ruleID,"Verifier: circuit data invalid");
      return true;
    }

  function _authorizeSetter(address _setter) internal override view returns (bool){
    return owner() == _setter;
  }

}
