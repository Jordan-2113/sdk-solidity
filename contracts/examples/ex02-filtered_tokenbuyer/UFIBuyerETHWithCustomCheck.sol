pragma solidity ^0.8.0;


import "../../PureFiVerifier.sol";
import "../../PureFiContext.sol";
import "../../tokenbuyer/PureFiTokenBuyerETH.sol";

contract UFIBuyerETHWithCustomCheck is PureFiTokenBuyerETH, PureFiContext{

    uint256 public ruleID;

    function initialize(address _pureFiVerifier) external initializer {
        __Ownable_init();
        __tokenBuyer_init_unchained(100);
        __PureFiContext_init_unchained(_pureFiVerifier);
        ruleID = 431040; //default AML with Risk Score <40
    }

    function version() public pure returns(uint32){
        // 000.000.000 - Major.minor.internal
        return 2000000;
    }

    function setRuleID(uint256 _newRuleID) public onlyOwner {
        ruleID = _newRuleID;
    }

    /**
    * buys UFI tokens for the full amount of _value provided.
    * @param _to - address to send bought tokens to
    * @param _purefidata - a signed data package from the PureFi Issuer
    */
    function buyForWithCompliance(address _to,
                    bytes calldata _purefidata
                    ) external payable withCustomAddressVerification(ruleID, msg.sender, _purefidata) {
        _buy(_to);
    }

    function _beforeBuy(address _from, address _to, uint256 _amountSent) internal virtual override rejectUnverified {}

}