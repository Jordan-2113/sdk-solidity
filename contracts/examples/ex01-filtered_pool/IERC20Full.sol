pragma solidity >=0.8.0;


import "../../../openzeppelin-contracts-upgradeable-master/contracts/token/ERC20/IERC20Upgradeable.sol";

interface IERC20Full is IERC20Upgradeable{

    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
}
