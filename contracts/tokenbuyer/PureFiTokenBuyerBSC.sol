pragma solidity ^0.8.0;

import "./pancake/interfaces/IPancakeRouter01.sol";
import "./pancake/interfaces/IPancakePair.sol";
import "./pancake/interfaces/IPancakeFactory.sol";
import "../../openzeppelin-contracts-upgradeable-master/contracts/access/OwnableUpgradeable.sol";
import "./ITokenBuyer.sol";

contract PureFiTokenBuyerBSC is OwnableUpgradeable, ITokenBuyer {

    uint16 public constant PERCENT_DENOM = 10000;
    address public constant targetTokenAddress = 0xe2a59D5E33c6540E18aAA46BF98917aC3158Db0D;
    uint16 public slippage;// 

    event TokenPurchase(address indexed who, uint256 bnbIn, uint256 ufiOut);

    function initialize() public initializer{
        __Ownable_init();
        __tokenBuyer_init_unchained(100);
    }

    function __tokenBuyer_init_unchained(uint16 _slippage) internal initializer{
        slippage = _slippage;
    }

    function changeSlippage(uint16 _slippage) public onlyOwner{
        require(_slippage <= PERCENT_DENOM, "Slippage too high");
        slippage = _slippage;
    }

    receive () external payable {
        _buy(msg.sender);
    }

    function buyFor(address _to) external payable {
        _buy(_to);
    }

    function routerAddress() public pure returns(address) {
      return 0x10ED43C718714eb63d5aA57B78B54704E256024E;
    }

    function buyToken(address _token, address _to) external override payable returns (uint256){
        if(_token == 0xe2a59D5E33c6540E18aAA46BF98917aC3158Db0D){
            return _buy(_to);
        }
        else {
            revert("unknown token");
        }
    }

    function busdToUFI(uint256 _amountBUSD) external override view returns (uint256,uint256) { //returns (amount WBNB, amount UFI)
        address[] memory evaluatePath = new address[](3);
        evaluatePath[0]=0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56; //busd
        evaluatePath[1]=IPancakeRouter01(routerAddress()).WETH(); //wbnb 
        evaluatePath[2]=targetTokenAddress; //ufi 

        uint[] memory amounts = IPancakeRouter01(routerAddress()).getAmountsOut(_amountBUSD, evaluatePath);
        return (amounts[1], amounts[2]);
    }

    function buyExactTokens(uint256 _amountToken, address _to) external override payable {
        _beforeBuy(msg.sender, _to, msg.value);

        address[] memory path = new address[](2);
        path[0] = IPancakeRouter01(routerAddress()).WETH();
        path[1] = targetTokenAddress;
        (IPancakeRouter01(routerAddress())).swapExactETHForTokens{value: msg.value}(_amountToken, path, _to, block.timestamp);
    }  

    // returns sorted token addresses, used to handle return values from pairs sorted in this order
    function sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        require(tokenA != tokenB, 'PancakeLibrary: IDENTICAL_ADDRESSES');
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'PancakeLibrary: ZERO_ADDRESS');
    }

    function _buy(address _to) internal returns (uint256){
        _beforeBuy(msg.sender, _to, msg.value);

        IPancakeRouter01 router = IPancakeRouter01(routerAddress());
        address wethAddress = IPancakeRouter01(routerAddress()).WETH();

         
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

    function _beforeBuy(address _from, address _to, uint256 _amountSent) internal virtual {}

}