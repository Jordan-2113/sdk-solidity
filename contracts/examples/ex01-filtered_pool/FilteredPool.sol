pragma solidity >=0.8.0;


import "../../../openzeppelin-contracts-upgradeable-master/contracts/token/ERC20/IERC20Upgradeable.sol";
import "../../../openzeppelin-contracts-upgradeable-master/contracts/token/ERC20/ERC20Upgradeable.sol";
import "../../../openzeppelin-contracts-upgradeable-master/contracts/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "./IERC20Full.sol";
import "../../PureFiContext.sol";

contract FilteredPool is ERC20Upgradeable, PureFiContext {

    using SafeERC20Upgradeable for IERC20Full;

    IERC20Full public basicToken;

    uint256 public totalCap;

    event Deposit(address indexed writer, uint256 amount);
    event Withdraw(address indexed writer, uint256 amount);

    function __Pool_init(address _basicToken, address _pureFiVerifier, string memory _description, string memory _symbol) internal initializer {
        __ERC20_init(_description, _symbol);
        __PureFiContext_init_unchained(_pureFiVerifier);
        __Pool_init_unchained(_basicToken);
    }

    function __Pool_init_unchained(address _basicToken) internal initializer {
        basicToken = IERC20Full(_basicToken);
    }

    /**
    * deposit ERC20 tokens function, assigns Liquidity tokens to provided address.
    * @param _amount - amount to deposit
    * @param _to - address to assign liquidity tokens to
    * @param _purefidata - purefi data
    */
    function depositTo(
        uint256 _amount,
        address _to,
        bytes calldata _purefidata
    ) external virtual withDefaultAddressVerification(DefaultRule.KYCAML, msg.sender, _purefidata) {
        _deposit(_amount, _to);
    }

    /**
    * converts spefied amount of Liquidity tokens to Basic Token and returns to user (withdraw). The balance of the User (msg.sender) is decreased by specified amount of Liquidity tokens. 
    * Resulted amount of tokens are transferred to specified address
    * @param _amount - amount of liquidity tokens to exchange to Basic token.
    * @param _to - address to send resulted amount of tokens to
     */
    function withdrawTo(
        uint256 _amount,
        address _to
    ) external  {
        _withdraw(_amount,_to);
    }

    function _deposit(uint256 amount, address to) private {
        _beforeDeposit(amount, msg.sender, to);
        basicToken.safeTransferFrom(msg.sender, address(this), amount);
        uint256 mintAmount = totalCap != 0 ? amount * totalSupply() / totalCap : amount * (10**uint256(decimals()))/ (10**uint256(basicToken.decimals()));
        _mint(to, mintAmount);
        totalCap += amount;
        emit Deposit(to, amount);
        _afterDeposit(amount, mintAmount,  msg.sender, to);
    }

    function _withdraw(uint256 amountLiquidity, address to) private {
        _beforeWithdraw(amountLiquidity, msg.sender, to);
        uint256 revenue = totalSupply() != 0 ? amountLiquidity * totalCap / totalSupply() : amountLiquidity;
        require(revenue <= basicToken.balanceOf(address(this)), "Not enough Basic Token tokens on the balance to withdraw");
        totalCap -= revenue;
        _burn(msg.sender, amountLiquidity);
        basicToken.safeTransfer(to, revenue);
        emit Withdraw(msg.sender, revenue);
        _afterWithdraw(revenue, msg.sender, to);
    }

    /** Reject unverified user transaction that result in pool token transfers */
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual override {}

    function _beforeDeposit(uint256 amountTokenSent, address sender, address holder) internal virtual {}
    function _afterDeposit(uint256 amountTokenSent, uint256 amountLiquidityGot, address sender, address holder) internal virtual {}
    function _beforeWithdraw(uint256 amountLiquidity, address holder, address receiver) internal virtual {}
    function _afterWithdraw(uint256 amountTokenReceived, address holder, address receiver) internal virtual {}

    uint256[10] private __gap;
}
