pragma solidity >=0.8.0;


import "../../../openzeppelin-contracts-upgradeable-master/contracts/token/ERC20/IERC20Upgradeable.sol";
import "../../../openzeppelin-contracts-upgradeable-master/contracts/token/ERC20/ERC20Upgradeable.sol";
import "../../../openzeppelin-contracts-upgradeable-master/contracts/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "./IERC20Full.sol";
import "../../PureFiVerifier.sol";
import "../../PureFiRouter.sol";

contract FilteredPool is ERC20Upgradeable{

    using SafeERC20Upgradeable for IERC20Full;

    IERC20Full public basicToken;

    PureFiRouter public pureFiRouter;

    uint256 public totalCap;

    event Deposit(address indexed writer, uint256 amount);
    event Withdraw(address indexed writer, uint256 amount);

    function __Pool_init(address _basicToken, address _pureFiRouter, string memory _description, string memory _symbol) internal initializer {
        __ERC20_init(_description, _symbol);
        __Pool_init_unchained(_basicToken, _pureFiRouter);
    }

    function __Pool_init_unchained(address _basicToken, address _pureFiRouter) internal initializer {
        basicToken = IERC20Full(_basicToken);
        pureFiRouter = PureFiRouter(_pureFiRouter);
    }

    /**
    * deposit ERC20 tokens function, assigns Liquidity tokens to provided address.
    * @param _amount - amount to deposit
    * @param _to - address to assign liquidity tokens to
    * @param data - signed data package from the off-chain verifier
    *    data[0] - verification session ID
    *    data[1] - circuit ID (if required)
    *    data[2] - verification timestamp
    *    data[3] - verified wallet - to be the same as msg.sender
    * @param signature - Off-chain verifier signature
    */
    function depositTo(
        uint256 _amount,
        address _to,
        uint256[] memory data, 
        bytes memory signature
    ) external virtual {
        require(pureFiRouter.verifyIssuerSignature(data,signature), "Signature invalid");
        require(address(uint160(data[3])) == msg.sender, "Verifier: tx sender doesn't match verified wallet");
        // grace time recommended:
        // Ethereum: 10 min
        // BSC: 3 min
        require(data[2] + 600 >= block.timestamp, "Verifier: verification data expired");
        // AML Risk Score circuits:
        // 431001...431099: 
        // [431] stands for AML Risk Score Check, 
        // [001..099] - risk score threshold. I.e. validation passed when risk score <= [xxx]; 
        require(data[1] == 431040, "Verifier: circuit data invalid");
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
    ) external virtual {
        _withdraw(_amount,_to);
    }

    function _deposit(uint256 amount, address to) internal virtual {
        _beforeDeposit(amount, msg.sender, to);
        basicToken.safeTransferFrom(msg.sender, address(this), amount);
        uint256 mintAmount = totalCap != 0 ? amount * totalSupply() / totalCap : amount * (10**uint256(decimals()))/ (10**uint256(basicToken.decimals()));
        _mint(to, mintAmount);
        totalCap += amount;
        emit Deposit(to, amount);
        _afterDeposit(amount, mintAmount,  msg.sender, to);
    }

    function _withdraw(uint256 amountLiquidity, address to) internal virtual {
        _beforeWithdraw(amountLiquidity, msg.sender, to);
        uint256 revenue = totalSupply() != 0 ? amountLiquidity * totalCap / totalSupply() : amountLiquidity;
        require(revenue <= basicToken.balanceOf(address(this)), "Not enough Basic Token tokens on the balance to withdraw");
        totalCap -= revenue;
        _burn(msg.sender, amountLiquidity);
        basicToken.safeTransfer(to, revenue);
        emit Withdraw(msg.sender, revenue);
        _afterWithdraw(revenue, msg.sender, to);
    }

    function _beforeDeposit(uint256 amountTokenSent, address sender, address holder) internal virtual {}
    function _afterDeposit(uint256 amountTokenSent, uint256 amountLiquidityGot, address sender, address holder) internal virtual {}
    function _beforeWithdraw(uint256 amountLiquidity, address holder, address receiver) internal virtual {}
    function _afterWithdraw(uint256 amountTokenReceived, address holder, address receiver) internal virtual {}

    uint256[10] private __gap;
}
