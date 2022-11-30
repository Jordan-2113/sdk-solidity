pragma solidity ^0.8.0;


import "../../PureFiVerifier.sol";
import "../../PureFiContext.sol";
import "../../tokenbuyer/PureFiTokenBuyerETH.sol";

contract UFIBuyerETHWithCheck is PureFiTokenBuyerETH, PureFiContext{

    function initialize(address _pureFiVerifier) external initializer {
        __Ownable_init();
        __tokenBuyer_init_unchained(100);
        __PureFiContext_init_unchained(_pureFiVerifier);
    }

     function version() public pure returns(uint32){
        // 000.000.000 - Major.minor.internal
        return 2000000;
    }

    /**
    * buys UFI tokens for the full amount of _value provided.
    * @param _to - address to send bought tokens to
    * @param _purefidata - a signed data package from the PureFi Issuer
    */
    function buyForWithAML(address _to,
                    bytes calldata _purefidata
                    ) external payable withDefaultAddressVerification (DefaultRule.AML, msg.sender, _purefidata) {
        _buy(_to);
    }

    /**
    * buys UFI tokens for the full amount of _value provided.
    * @param _to - address to send bought tokens to
    * @param _purefidata - a signed data package from the PureFi Issuer
    */
    function buyForWithKYC(address _to,
                    bytes calldata _purefidata
                    ) external payable withDefaultAddressVerification (DefaultRule.KYC, msg.sender, _purefidata) {
        _buy(_to);
    }

    /**
    * buys UFI tokens for the full amount of _value provided.
    * @param _to - address to send bought tokens to
    * @param _purefidata - a signed data package from the PureFi Issuer
    */
    function buyForWithKYCAML(address _to,
                    bytes calldata _purefidata
                    ) external payable withDefaultAddressVerification (DefaultRule.KYCAML, msg.sender, _purefidata) {
        _buy(_to);
    }

    function _beforeBuy(address _from, address _to, uint256 _amountSent) internal virtual override rejectUnverified() {}

}