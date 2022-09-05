pragma solidity ^0.8.0;


import "../../PureFiVerifier.sol";
import "../../PureFiContext.sol";
import "../../tokenbuyer/PureFiTokenBuyerBSC.sol";

contract UFIBuyerBSCWithCheck is PureFiTokenBuyerBSC, PureFiContext{

    function initialize(address _pureFiVerifier) external initializer {
        __Ownable_init();
        __tokenBuyer_init_unchained(100);
        __PureFiContext_init_unchained(_pureFiVerifier);
    }

     function version() public pure returns(uint32){
        // 000.000.000 - Major.minor.internal
        return 2000002;
    }

    function setVerifier(address _verifier) external onlyOwner{
        pureFiVerifier = PureFiVerifier(_verifier);
    }

    /**
    * buys UFI tokens for the full amount of _value provided.
    * @param _to - address to send bought tokens to
    * @param data - signed data package from the off-chain verifier
    *    data[0] - verification session ID
    *    data[1] - rule ID (if required)
    *    data[2] - verification timestamp
    *    data[3] - verified wallet - to be the same as msg.sender
    * @param signature - Off-chain verifier signature
    */
    function buyForWithAML(address _to,
                    uint256[] memory data, 
                    bytes memory signature
                    ) external payable compliesDefaultRule (DefaultRule.AML, msg.sender, data, signature) {
        _buy(_to);
    }

    /**
    * buys UFI tokens for the full amount of _value provided.
    * @param _to - address to send bought tokens to
    * @param data - signed data package from the off-chain verifier
    *    data[0] - verification session ID
    *    data[1] - rule ID (if required)
    *    data[2] - verification timestamp
    *    data[3] - verified wallet - to be the same as msg.sender
    * @param signature - Off-chain verifier signature
    */
    function buyForWithKYC(address _to,
                    uint256[] memory data, 
                    bytes memory signature
                    ) external payable compliesDefaultRule (DefaultRule.KYC, msg.sender, data, signature) {
        _buy(_to);
    }

    /**
    * buys UFI tokens for the full amount of _value provided.
    * @param _to - address to send bought tokens to
    * @param data - signed data package from the off-chain verifier
    *    data[0] - verification session ID
    *    data[1] - rule ID (if required)
    *    data[2] - verification timestamp
    *    data[3] - verified wallet - to be the same as msg.sender
    * @param signature - Off-chain verifier signature
    */
    function buyForWithKYCAML(address _to,
                    uint256[] memory data, 
                    bytes memory signature
                    ) external payable compliesDefaultRule (DefaultRule.KYCAML, msg.sender, data, signature) {
        _buy(_to);
    }

    function _beforeBuy(address _from, address _to, uint256 _amountSent) internal virtual override rejectUnverified() {}

}