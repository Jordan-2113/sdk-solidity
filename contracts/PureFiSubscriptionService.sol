pragma solidity >=0.8.0;

import "../openzeppelin-contracts-upgradeable-master/contracts/access/AccessControlUpgradeable.sol";
import "../openzeppelin-contracts-upgradeable-master/contracts/token/ERC20/IERC20Upgradeable.sol";
import "../openzeppelin-contracts-upgradeable-master/contracts/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "./PureFiRouter.sol";
import "./PureFiLockService.sol";
import "./tokenbuyer/ITokenBuyer.sol";


contract PureFiSubscriptionService is AccessControlUpgradeable {

    using SafeERC20Upgradeable for IERC20Upgradeable;

    uint256 private constant P100 = 100; //100% denominator
    uint256 private constant MONTH = 30*24*60*60; //30 days in seconds
 
    PureFiLockService private lockService;
    IERC20Upgradeable private ufiToken;
    ITokenBuyer private tokenBuyer;
    address public burnAddress;
    
    mapping (uint8 => Tier) tiers;
    mapping (address => UserSubscription) userSubscriptions;

    struct Tier{
        uint64 subscriptionDuration; //subscriptionDuration = token lockup time in seconds.
        uint128 priceInUSD; // tier price in USD 
        uint8 burnRatePercent; // burn rate in percents with 2 decimals (100% = 10000)
        uint8 kycIncluded;
        uint32 amlIncluded;
    }

    struct UserSubscription{
        uint8 tier;
        uint64 dateSubscribed;
        uint184 userdata; //storage reserve for future
    }

    event Subscribed(address indexed subscriber, uint8 tier, uint64 dateSubscribed, uint256 UFILocked);
    event Unsubscribed(address indexed subscriber, uint8 tier, uint64 dateUnsubscribed, uint256 ufiBurned);

    /**
    Changelog:
    1000001 -> 1000002
    1. fixed issue with getUserData();
    1000002 -> 1000003
    1. changed subscription time calculation to round up to nearest month. I.e. minimum subscription time = 1 month;
    */
    function version() public pure returns(uint32){
        // 000.000.000 - Major.minor.internal
        return 1000003;
    }

    function initialize(address _admin, address _ufi, address _lock, address _tokenBuyer, address _burnAddress) public initializer{
        __AccessControl_init();
        _setupRole(DEFAULT_ADMIN_ROLE, _admin);
        lockService = PureFiLockService(_lock);
        ufiToken = IERC20Upgradeable(_ufi);
        tokenBuyer = ITokenBuyer(_tokenBuyer);
        burnAddress = _burnAddress;
    }

    function setTokenBuyer(address _tokenBuyer) external onlyRole(DEFAULT_ADMIN_ROLE){
        tokenBuyer = ITokenBuyer(_tokenBuyer);
    }

    function setLockService(address _lock) external onlyRole(DEFAULT_ADMIN_ROLE){
        lockService = PureFiLockService(_lock);
    }

    function setTierData(
        uint8 _tierID,
        uint64 _subscriptionDuration, //subscriptionDuration = token lockup time in seconds.
        uint128 _priceInUSD, // tier price in USD 
        uint8 _burnRatePercent, // burn rate in percents with 2 decimals (100% = 10000)
        uint8 _kycIncluded,
        uint32 _amlIncluded) external onlyRole(DEFAULT_ADMIN_ROLE){
        tiers[_tierID] = Tier(_subscriptionDuration,_priceInUSD,_burnRatePercent,_kycIncluded,_amlIncluded);
    }

    function subscribe(uint8 _tier) external payable {
        require(tiers[_tier].priceInUSD > 0, 'Invalid tier provided');

        uint256 burnDebt = 0;
        //check for existing subscription
        uint8 userSubscriptionTier = userSubscriptions[msg.sender].tier;
        
        if(userSubscriptionTier > 0){
            (uint256 lockedBalance,) = lockService.getLockData(msg.sender);
            uint256 timeSubscribed = block.timestamp - userSubscriptions[msg.sender].dateSubscribed;
            // round timeSubscribed up to month
            timeSubscribed = (1 + timeSubscribed / MONTH) * MONTH;
            // for expired subscriptions set subscribed time to initial tier duration.
            if (timeSubscribed > tiers[userSubscriptionTier].subscriptionDuration)
                timeSubscribed = tiers[userSubscriptionTier].subscriptionDuration;
            burnDebt = lockedBalance * timeSubscribed * tiers[userSubscriptionTier].burnRatePercent / (tiers[userSubscriptionTier].subscriptionDuration * P100); 
            lockService.unlockUFI(msg.sender, lockedBalance);
            emit Unsubscribed(msg.sender, userSubscriptionTier, uint64(block.timestamp), burnDebt);
            delete userSubscriptions[msg.sender];
        }
        //subscripbe to the _tier
        (uint s_wbnb, uint256 s_ufi) = tokenBuyer.busdToUFI(tiers[_tier].priceInUSD);
        uint256 userBalanceUFI = ufiToken.balanceOf(msg.sender);
        uint256 ethRemaining = msg.value;
        if(s_ufi + burnDebt > userBalanceUFI){
            //not enough UFI balance on users wallet => buy UFI. 
            //1. buy exact UFI amount that user lacks for subscription
            //2. set ethToSend to a 0.1% more then estimated to make sure there will be enough UFI for subscription.
            uint256 ethToSend = s_wbnb * (s_ufi + burnDebt - userBalanceUFI + 1) * 1001 / 1000 / s_ufi;
            require(ethRemaining >= ethToSend, "Not enough msg.value for transaction");
            tokenBuyer.buyExactTokens{value:ethToSend}((s_ufi + burnDebt - userBalanceUFI + 1), msg.sender);
            ethRemaining-=ethToSend;
        }
        if(burnDebt > 0){
            ufiToken.safeTransferFrom(msg.sender, burnAddress, burnDebt);
        }
        //re-read balance
        userBalanceUFI = ufiToken.balanceOf(msg.sender);
        require(s_ufi <= userBalanceUFI, "Not enought UFI tokens on the subrsibers balance");
        lockService.lockUFI(msg.sender, s_ufi, uint64(block.timestamp + tiers[_tier].subscriptionDuration));
        userSubscriptions[msg.sender] = UserSubscription(_tier,uint64(block.timestamp),0);
        emit Subscribed(msg.sender,_tier,uint64(block.timestamp),s_ufi);
        if(ethRemaining > 0){
            payable(msg.sender).transfer(ethRemaining);
        }
    }

    function unsubscribe() external payable {
        uint8 userSubscriptionTier = userSubscriptions[msg.sender].tier;
        require(userSubscriptionTier > 0, "No subscription found");
        (uint256 lockedBalance,) = lockService.getLockData(msg.sender);
        uint256 timeSubscribed = block.timestamp - userSubscriptions[msg.sender].dateSubscribed;
        // round timeSubscribed up to month
        timeSubscribed = (1 + timeSubscribed / MONTH) * MONTH;
        // for expired subscriptions set subscribed time to initial tier duration.
        if (timeSubscribed > tiers[userSubscriptionTier].subscriptionDuration)
            timeSubscribed = tiers[userSubscriptionTier].subscriptionDuration;
        uint256 burnDebt = lockedBalance * timeSubscribed * tiers[userSubscriptionTier].burnRatePercent / (tiers[userSubscriptionTier].subscriptionDuration * P100); 

        if(burnDebt > 0){
            ufiToken.safeTransferFrom(msg.sender, burnAddress, burnDebt);
        }
        delete userSubscriptions[msg.sender];
        emit Unsubscribed(msg.sender, userSubscriptionTier, uint64(block.timestamp), burnDebt);
    }

    /**
    returns:
    0: amount of UFI to be on a balance for subscription
    1: amount of ETH(BNB) to set as a transaction value for subscription to be successful
    2: amount of UFI that will be locked when subscription applied
    */
    function estimateSubscriptionPrice(address _holder, uint8 _tier) external view returns (uint256, uint256, uint256){
        require(tiers[_tier].priceInUSD > 0, 'Invalid tier provided');

        uint256 burnDebt = 0;
        uint256 ethToSend = 0;
        //check for existing subscription
        uint8 userSubscriptionTier = userSubscriptions[_holder].tier;
        
        if(userSubscriptionTier > 0){
            (uint256 lockedBalance,) = lockService.getLockData(_holder);
            uint256 timeSubscribed = block.timestamp - userSubscriptions[msg.sender].dateSubscribed;
            // round timeSubscribed up to month
            timeSubscribed = (1 + timeSubscribed / MONTH) * MONTH;
            // for expired subscriptions set subscribed time to initial tier duration.
            if (timeSubscribed > tiers[userSubscriptionTier].subscriptionDuration)
                timeSubscribed = tiers[userSubscriptionTier].subscriptionDuration;
            burnDebt = lockedBalance * timeSubscribed * tiers[userSubscriptionTier].burnRatePercent / (tiers[userSubscriptionTier].subscriptionDuration * P100); 
        }
        //subscripbe to the _tier
        (uint s_wbnb, uint256 s_ufi) = tokenBuyer.busdToUFI(tiers[_tier].priceInUSD);
        uint256 userBalanceUFI = ufiToken.balanceOf(_holder);
        if(s_ufi + burnDebt > userBalanceUFI){
            //not enough UFI balance on users wallet => buy UFI. 
            //1. buy exact UFI amount that user lacks for subscription
            //2. set ethToSend to a 0.1% more then estimated to make sure there will be enough UFI for subscription.
            ethToSend = s_wbnb * (s_ufi + burnDebt - userBalanceUFI + 1) * 1001 / 1000 / s_ufi;
        }
        return (s_ufi + burnDebt, ethToSend, s_ufi);
    }

    /**
    returns: 
        0: subscription tier
        1: date subscribed
        2: date subscription expires
        3: userdata
        4: locked tokens amount
     */
    function getUserData(address _user) external view returns (uint8, uint64, uint64, uint184, uint256) {
        (uint256 lockedBalance,uint64 lockedUntil) = lockService.getLockData(_user);
        return (userSubscriptions[_user].tier,
                userSubscriptions[_user].dateSubscribed,
                lockedUntil,
                userSubscriptions[_user].userdata,
                lockedBalance);
        
    }

    /**
    returns: 
        0: subscription Duration
        1: price in USD
        2: burn rate percent
        3: kyc Included
        4: aml Included
     */
    function getTierData(uint8 _tier) external view returns(uint64, uint128, uint16, uint8, uint32){
        return (tiers[_tier].subscriptionDuration,
                tiers[_tier].priceInUSD,
                tiers[_tier].burnRatePercent,
                tiers[_tier].kycIncluded,
                tiers[_tier].amlIncluded
                );
    }
    

}