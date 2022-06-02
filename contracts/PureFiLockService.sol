pragma solidity >=0.8.0;

import "../openzeppelin-contracts-upgradeable-master/contracts/access/AccessControlUpgradeable.sol";
import "./PureFiRouter.sol";

interface IUFILock{
    /**
    returns (lockedBalance, lockedUntil)
     */
    function getLockData(address _holder) external view returns (uint256, uint64);
}

contract PureFiLockService is AccessControlUpgradeable, IUFILock{

    bytes32 public constant UFI_TRUSTED_PAYMENT_SERVICE = keccak256("UFI_TRUSTED_PAYMENT_SERVICE");
    
    mapping (address=>uint256) lockedBalance;
    mapping (address=>uint64) lockedUntil;

    event Locked(address indexed holder, uint256 lockedBalance, uint64 lockedUntil);
    event Unlocked(address indexed holder, uint256 unlockedBalance);

    function version() public pure returns(uint32){
        // 000.000.000 - Major.minor.internal
        return 1000000;
    }

    function initialize(address admin) public initializer{
        __AccessControl_init();
        _setupRole(DEFAULT_ADMIN_ROLE, admin);
    }

    function lockUFI(address _holder, uint256 _lockedBalance, uint64 _lockedUntil) external onlyRole(UFI_TRUSTED_PAYMENT_SERVICE){
        lockedBalance[_holder] = _lockedBalance;
        lockedUntil[_holder] = _lockedUntil;
        emit Locked(_holder,_lockedBalance,_lockedUntil);
    }

    function unlockUFI(address _holder, uint256 _unlockBalance) external onlyRole(UFI_TRUSTED_PAYMENT_SERVICE){
        if(block.timestamp > lockedUntil[_holder]){
            emit Unlocked(_holder, lockedBalance[_holder]);
            delete lockedUntil[_holder];
            delete lockedBalance[_holder];
        } else {
            lockedBalance[_holder] -= _unlockBalance;
            if(lockedBalance[_holder] == 0){
                delete lockedUntil[_holder];
            }
            emit Unlocked(_holder, _unlockBalance);
        }        
    }


    function getLockData(address _holder) external override view returns (uint256, uint64){
        return(lockedBalance[_holder], lockedUntil[_holder]);
    }

}