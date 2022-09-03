pragma solidity ^0.8.0;

import "./uniswap/RouterInterface.sol";
import "./uniswap/interfaces/IUniswapV2Pair.sol";
import "../../openzeppelin-contracts-upgradeable-master/contracts/access/OwnableUpgradeable.sol";
import "./ITokenBuyer.sol";

contract PureFiTokenBuyerETH is OwnableUpgradeable, ITokenBuyer {

    uint16 public constant PERCENT_DENOM = 10000;
    address public constant targetTokenAddress = 0xcDa4e840411C00a614aD9205CAEC807c7458a0E3;

    uint16 public slippage;

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
      return 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    }

    function buyToken(address _token, address _to) external override payable returns (uint256){
        if(_token == targetTokenAddress){
            return _buy(_to);
        }
        else {
            revert("unknown token");
        }
    }

    function busdToUFI(uint256 _amountBUSD) external override view returns (uint256,uint256) { //returns (amount WBNB, amount UFI)
        address[] memory evaluatePath = new address[](3);
        evaluatePath[0]=0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; //USDC
        evaluatePath[1]=IUniswapV2Router01(routerAddress()).WETH(); //WETH
        evaluatePath[2]=targetTokenAddress;//UFI

        uint[] memory amounts = IUniswapV2Router01(routerAddress()).getAmountsOut(_amountBUSD, evaluatePath);
        return (amounts[1], amounts[2]);
    }

    function buyExactTokens(uint256 _amountToken, address _to) external override payable {
        _beforeBuy(msg.sender, _to, msg.value);

        address[] memory path = new address[](2);
        path[0] = IUniswapV2Router01(routerAddress()).WETH();
        path[1] = targetTokenAddress;
        (IUniswapV2Router01(routerAddress())).swapExactETHForTokens{value: msg.value}(_amountToken, path, _to, block.timestamp);
    } 

    // returns sorted token addresses, used to handle return values from pairs sorted in this order
    function sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        require(tokenA != tokenB, 'UniswapV2Library: IDENTICAL_ADDRESSES');
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'UniswapV2Library: ZERO_ADDRESS');
    }

    // calculates the CREATE2 address for a pair without making any external calls
    function pairFor(address factory, address tokenA, address tokenB) internal pure returns (address pair) {
        (address token0, address token1) = sortTokens(tokenA, tokenB);
        pair = address(uint160(uint256(keccak256(abi.encodePacked(
                hex'ff',
                factory,
                keccak256(abi.encodePacked(token0, token1)),
                hex'96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f' // init code hash
            )))));
    }

    function _buy(address _to) internal returns (uint256){
        _beforeBuy(msg.sender, _to, msg.value);

        IUniswapV2Router01 router = IUniswapV2Router01(routerAddress());
        address wethAddress = IUniswapV2Router01(routerAddress()).WETH();

         
        address[] memory path = new address[](2);
        path[0] = wethAddress;
        path[1] = targetTokenAddress;

        (address token0, address token1) = sortTokens(wethAddress, targetTokenAddress);

        address pairAddress = address(uint160(uint256(keccak256(abi.encodePacked(
                hex'ff',
                router.factory(),
                keccak256(abi.encodePacked(token0, token1)),
                hex'96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f' // init code hash
            )))));

        uint256 ufiExpected;
        {
            (uint112 reserve0, uint112 reserve1, ) = IUniswapV2Pair(pairAddress).getReserves();
            ufiExpected = token0 == wethAddress ? router.getAmountOut(msg.value, reserve0, reserve1) : router.getAmountOut(msg.value, reserve1, reserve0);
        }
        
        uint256 minUFIExpected = ufiExpected * (PERCENT_DENOM - slippage) / PERCENT_DENOM;

        uint[] memory out = router.swapExactETHForTokens{value: msg.value}(minUFIExpected, path, _to, block.timestamp);
        emit TokenPurchase(_to, out[0], out[1]);
        return out[1];
    }

    function _beforeBuy(address _from, address _to, uint256 _amountSent) internal virtual {}

}