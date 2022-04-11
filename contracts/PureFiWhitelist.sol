pragma solidity >=0.8.0;

import "../openzeppelin-contracts-upgradeable-master/contracts/security/PausableUpgradeable.sol";
import "../openzeppelin-contracts-upgradeable-master/contracts/access/OwnableUpgradeable.sol";
import "./PureFiRouter.sol";

contract PureFiWhitelist is PausableUpgradeable, OwnableUpgradeable{
    
    PureFiRouter private router;
    mapping (address=>Verification) registry;

    event AddressWhitelisted(address indexed user, uint256 indexed ruleID);
    event AddressDelisted(address indexed user);

    struct Verification{
        uint256 sessionID; //verification session ID
        uint256 ruleID; //verification rule ID (if required)
        uint64 verifiedOn; //verification timestamp 
        uint64 validUntil;
        address issuer;
    }

    function version() public pure returns(uint32){
        // 000.000.000 - Major.minor.internal
        return 1000001;
    }

    function initialize(address _router) public initializer{
        __Ownable_init();
        __Pausable_init_unchained();
        router = PureFiRouter(_router);
    }

    modifier onlyIssuer(){
        require (router.isValidIssuer(msg.sender), "Whitelist: sender is not a registered Issuer");
        _;
    }

    function pause() onlyOwner external {
        super._pause();
    }

    function unpause() onlyOwner external {
        super._unpause();
    }

    function whitelist(address _user, uint256 _sessionID, uint256 _ruleID, uint64 _verifiedOn, uint64 _validUntil) public onlyIssuer {
        registry[_user] = Verification(_sessionID,_ruleID,_verifiedOn,_validUntil,msg.sender);
        emit AddressWhitelisted(_user,_ruleID);
    }

    function delist(address _user) public onlyIssuer{
        require (registry[_user].issuer == msg.sender,"Whitelist: only the same issuer can revoke the record");
        delete registry[_user];
        emit AddressDelisted(_user);
    }

    /**
    Returns true in case the _address has been verified before and verification 
    data has been uploaded on-chain
    @param _address - address to verify
    returns true/false
    */
    function isAddressVerified(address _address) external view returns(bool){
        return registry[_address].validUntil > block.timestamp;
    }

    function getAddressVerificationData(address _address) external view returns(uint256,uint256,uint64,uint64,address){
        return (
            registry[_address].sessionID,
            registry[_address].ruleID,
            registry[_address].verifiedOn,
            registry[_address].validUntil,
            registry[_address].issuer
        );
    }

}