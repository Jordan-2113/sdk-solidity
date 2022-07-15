pragma solidity ^0.8.0;

import "../pancake/interfaces/IPancakeRouter01.sol";
import "../pancake/interfaces/IPancakePair.sol";
import "../pancake/interfaces/IPancakeFactory.sol";
import "../../../openzeppelin-contracts-upgradeable-master/contracts/access/OwnableUpgradeable.sol";
import "../../PureFiRouter.sol";

contract UFIBuyerDefaultAMLCheck is OwnableUpgradeable{

    uint16 public constant PERCENT_DENOM = 10000;
    uint16 public slippage;// 
    address public targetTokenAddress;
    address[] private evaluatePath;
    PureFiRouter public purefiRouter;

    event TokenPurchase(address indexed who, uint256 bnbIn, uint256 ufiOut);

    function initialize(address _router) external initializer {
        __Ownable_init();
        slippage = 100;
        targetTokenAddress = 0xe2a59D5E33c6540E18aAA46BF98917aC3158Db0D;
        evaluatePath.push(0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56); //busd
        evaluatePath.push(IPancakeRouter01(routerAddress()).WETH()); //wbnb 
        evaluatePath.push(targetTokenAddress); //ufi 
        purefiRouter = PureFiRouter(_router);
    }

     function version() public pure returns(uint32){
        // 000.000.000 - Major.minor.internal
        return 1000001;
    }

    function changeSlippage(uint16 _slippage) public onlyOwner{
        require(_slippage <= PERCENT_DENOM, "Slippage too high");
        slippage = _slippage;
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
    function buyFor(address _to,
                    uint256[] memory data, 
                    bytes memory signature
                    ) external payable {
        (uint16 _checkRes, string memory _checkReason) = purefiRouter.defaultAMLCheck(msg.sender, data, signature);
        //here the smart contract can decide whether to fail a transaction in case of check failed
        require(_checkRes == 0, _checkReason);
        _buy(_to);
    }


     /**
    * buys exact amount of UFI tokens and sends to the address provided. Remaining _value is returned back to msg.sender
    * @param _amountToken - exact amount of tokens to buy
    * @param _to - address to send bought tokens to
    * @param data - signed data package from the off-chain verifier
    *    data[0] - verification session ID
    *    data[1] - rule ID (if required)
    *    data[2] - verification timestamp
    *    data[3] - verified wallet - to be the same as msg.sender
    * @param signature - Off-chain verifier signature
    */
    function buyExactTokens(uint256 _amountToken, 
                        address _to,
                        uint256[] memory data, 
                        bytes memory signature
                        ) external payable {
        (uint16 _checkRes, string memory _checkReason) = purefiRouter.defaultAMLCheck(msg.sender, data, signature);
        //here the smart contract can decide whether to fail a transaction in case of check failed
        require(_checkRes == 0, _checkReason);

        address[] memory path = new address[](2);
        path[0] = evaluatePath[1];
        path[1] = targetTokenAddress;
        (IPancakeRouter01(routerAddress())).swapExactETHForTokens{value: msg.value}(_amountToken, path, _to, block.timestamp);
    }  

    /***********************************************************************************************************************/

    // returns sorted token addresses, used to handle return values from pairs sorted in this order
    function sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        require(tokenA != tokenB, 'PancakeLibrary: IDENTICAL_ADDRESSES');
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'PancakeLibrary: ZERO_ADDRESS');
    }

    function routerAddress() public pure returns(address) {
      return 0x10ED43C718714eb63d5aA57B78B54704E256024E;
    }

    function _buy(address _to) internal returns (uint256){
        IPancakeRouter01 router = IPancakeRouter01(routerAddress());
        address wethAddress = evaluatePath[1];

         
        address[] memory path = new address[](2);
        path[0] = wethAddress;
        path[1] = targetTokenAddress;

        (address token0, address token1) = sortTokens(wethAddress, targetTokenAddress);
        address pairAddress = address(uint160(uint256(keccak256(abi.encodePacked(
                hex'ff',
                router.factory(),
                keccak256(abi.encodePacked(token0, token1)),
                hex'00fb7f630766e6a796048ea87d01acd3068e8ff67d078148a3fa3f4a84f69bd5' // init code hash
            )))));

        uint256 ufiExpected;
        {
            (uint112 reserve0, uint112 reserve1, ) = IPancakePair(pairAddress).getReserves();
            ufiExpected = token0 == wethAddress ? router.getAmountOut(msg.value, reserve0, reserve1) : router.getAmountOut(msg.value, reserve1, reserve0);
        }
        
        uint256 minUFIExpected = ufiExpected * (PERCENT_DENOM - slippage) / PERCENT_DENOM;

        uint[] memory out = router.swapExactETHForTokens{value: msg.value}(minUFIExpected, path, _to, block.timestamp);
        emit TokenPurchase(_to, out[0], out[1]);
        return out[1];
    }

}