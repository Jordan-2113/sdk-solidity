// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "../../../openzeppelin-contracts-master/contracts/security/Pausable.sol";
import "../../../openzeppelin-contracts-master/contracts/access/Ownable.sol";
import "./../../libraries/SignLib.sol";
import "./../../PureFiIssuerRegistry.sol";


contract PureFiForwarder is Pausable, Ownable, SignLib{
  
  address public issuerRegistry;

  mapping (address => TagetConfiguration) configurations;

  struct TagetConfiguration{
    uint64 graceTime;//verification grace time in seconds
    uint256 circuit; //required circuit id for verification
  }
  // event Verified(address indexed )
  event TargetVerificationConfigured(address indexed target, uint64 graceTime, uint256 circuit);

  constructor(address _issuerRegistry){
    issuerRegistry = _issuerRegistry;
  }
  /**
  Changelog:
  version 1000001:
   */
  function version() public pure returns(uint32){
    // 000.000.000 - Major.minor.internal
    return 1000001;
  }

  function pause() onlyOwner external {
    super._pause();
  }

  function unpause() onlyOwner external {
    super._unpause();
  }

  function configureTarget(address _target, uint64 _graceTime, uint256 _circuit) public onlyOwner{
    configurations[_target] = TagetConfiguration(_graceTime, _circuit);
    emit TargetVerificationConfigured(_target, _graceTime, _circuit);
  }

  /**
    Verifies signed data package and forwards raw transaction
    Params:
    @param rawtx - raw transaction data to be forwarded 
    @param target - target address a raw transaction to be forwarded to
    @param data - signed data package from the off-chain verifier
      data[0] - verification session ID
      data[1] - circuit ID (if required)
      data[2] - verification timestamp
      data[3] - verified wallet - to be the same as msg.sender
    @param signature - Off-chain verifier signature
   */
  function verifyAndForward(
    bytes memory rawtx,
    address target,
    uint256[] memory data,
    bytes memory signature
  ) public payable whenNotPaused {
    uint256 initialgas = gasleft();
    
    _verifyData(target,data,signature);
    //perform transaction
    (bool success, bytes memory returndata) = target.call{value: msg.value}(rawtx);
    
    require(success, "Verifier: nested transaction failed"); 
    // Validate that the relayer has sent enough gas for the call.
    // See https://ronan.eth.link/blog/ethereum-gas-dangers/
    if (gasleft() <= initialgas / 63) {
        // We explicitly trigger invalid opcode to consume all gas and bubble-up the effects, since
        // neither revert or assert consume all gas since Solidity 0.8.0
        // https://docs.soliditylang.org/en/v0.8.0/control-structures.html#panic-via-assert-and-error-via-require
        assembly {
            invalid()
        }
    }
  }

  /**
    Verifies signed data package and forwards raw transaction
    Params:
    @param rawtx - raw transaction data to be forwarded 
    @param target - target address a raw transaction to be forwarded to
    @param data - signed data package from the off-chain verifier
      data[0] - verification session ID
      data[1] - circuit ID (if required)
      data[2] - verification timestamp
      data[3] - verified wallet - to be the same as msg.sender
    @param signature - Off-chain verifier signature
   */
  function verifyAndForwardEIP712(
    bytes memory rawtx,
    address target,
    uint256[] memory data,
    bytes memory signature
  ) public payable whenNotPaused {
    uint256 initialgas = gasleft();
    _verifyData(target,data,signature);
     //perform transaction
    (bool success, bytes memory returndata) = target.call{value: msg.value}(abi.encodePacked(rawtx, address(uint160(data[3]))));
    
    require(success, "Verifier: nested transaction failed"); 
    // Validate that the relayer has sent enough gas for the call.
    // See https://ronan.eth.link/blog/ethereum-gas-dangers/
    if (gasleft() <= initialgas / 63) {
        // We explicitly trigger invalid opcode to consume all gas and bubble-up the effects, since
        // neither revert or assert consume all gas since Solidity 0.8.0
        // https://docs.soliditylang.org/en/v0.8.0/control-structures.html#panic-via-assert-and-error-via-require
        assembly {
            invalid()
        }
    }
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
      return PureFiIssuerRegistry(issuerRegistry).isValidIssuer(recovered);
  }

  function _verifyData(
    address target,
    uint256[] memory data,
    bytes memory signature)
    internal returns (bool){
      address recovered = recoverSigner(keccak256(abi.encodePacked(data[0], data[1], data[2], data[3])), signature);
      require(PureFiIssuerRegistry(issuerRegistry).isValidIssuer(recovered),"Verifier: Invalid issuer signature");
      require(address(uint160(data[3])) == msg.sender, "Verifier: tx sender doesn't match verified wallet");
      require(data[2] + configurations[target].graceTime >= block.timestamp, "Verifier: verification data expired");
      require(data[1] == configurations[target].circuit,"Verifier: circuit data invalid");
      return true;
    }

}
