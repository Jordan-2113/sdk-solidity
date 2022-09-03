pragma solidity >=0.8.0;

import "../openzeppelin-contracts-upgradeable-master/contracts/access/AccessControlUpgradeable.sol";
import "../openzeppelin-contracts-upgradeable-master/contracts/token/ERC20/IERC20Upgradeable.sol";
import "../openzeppelin-contracts-upgradeable-master/contracts/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "./tokenbuyer/ITokenBuyer.sol";


contract PureFiSubscriptionService is AccessControlUpgradeable {

    using SafeERC20Upgradeable for IERC20Upgradeable;

    uint256 private constant P100 = 100; //100% denominator
    uint256 private constant MONTH = 30*24*60*60; //30 days in seconds
 
    IERC20Upgradeable private ufiToken;
    ITokenBuyer private tokenBuyer;
    address private profitCollectionAddress;

    // uint256 collectedProfit; //amount of tokens collected as a profit from subsciptions selling

    //0x - 04 bytes //number of users
    //0x - 12 bytes //sigma dep_i
    //0x - 16 bytes //sigma t_i*dep_i
    uint256 private userstat; 
    
    mapping (uint8 => Tier) tiers;
    mapping (address => UserSubscription) userSubscriptions;

    struct Tier{
        uint8 isactive; //1 - active, 0 - non acvite (can't subscribe)
        uint48 subscriptionDuration; //subscriptionDuration = token lockup time in seconds.
        uint128 priceInUSD; // tier price in USD 
        uint8 burnRatePercent; // burn rate in percents with 0 decimals (100% = P100)
        uint16 kycIncluded;
        uint48 amlIncluded;
    }

    struct UserSubscription{
        uint8 tier;
        uint64 dateSubscribed;
        uint128 tokensDeposited; //tokens tokensDeposited
        uint48 userdata;//storage reserve for future 
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
        return 2000002;
    }

    function initialize(address _admin, address _ufi, address _tokenBuyer, address _profitCollectionAddress) public initializer{
        __AccessControl_init();
        _setupRole(DEFAULT_ADMIN_ROLE, _admin);
        // lockService = PureFiLockService(_lock);
        ufiToken = IERC20Upgradeable(_ufi);
        tokenBuyer = ITokenBuyer(_tokenBuyer);
        profitCollectionAddress = _profitCollectionAddress;
    }

    function setTokenBuyer(address _tokenBuyer) external onlyRole(DEFAULT_ADMIN_ROLE){
        tokenBuyer = ITokenBuyer(_tokenBuyer);
    }

    function setProfitCollectionAddress(address _profitCollectionAddress) external onlyRole(DEFAULT_ADMIN_ROLE){
        profitCollectionAddress = _profitCollectionAddress;
    }

    function setTierData(
        uint8 _tierID,
        uint48 _subscriptionDuration, //subscriptionDuration = token lockup time in seconds.
        uint128 _priceInUSD, // tier price in USD 
        uint8 _burnRatePercent, // burn rate in percents with 2 decimals (100% = 10000)
        uint16 _kycIncluded,
        uint48 _amlIncluded) external onlyRole(DEFAULT_ADMIN_ROLE){
        tiers[_tierID] = Tier(1, _subscriptionDuration,_priceInUSD,_burnRatePercent,_kycIncluded,_amlIncluded);
    }

    function setTierIsActive(uint8 _tierID, uint8 _isActive) external onlyRole(DEFAULT_ADMIN_ROLE){
        tiers[_tierID].isactive = _isActive;
    }

    function subscribe(uint8 _tier) external payable {
       _subscribe(_tier, msg.sender);
    }
    
    function subscribeFor(uint8 _tier, address _subscriber) external payable {
       _subscribe(_tier, _subscriber);
    }

    function unsubscribe() external payable {
        uint8 userSubscriptionTier = userSubscriptions[msg.sender].tier;
        require(userSubscriptionTier > 0, "No subscription found");
        uint256 timeSubscribed = block.timestamp - userSubscriptions[msg.sender].dateSubscribed;
        // round timeSubscribed up to month
        timeSubscribed = (1 + timeSubscribed / MONTH) * MONTH;
        // for expired subscriptions set subscribed time to initial tier duration.
        if (timeSubscribed > tiers[userSubscriptionTier].subscriptionDuration)
            timeSubscribed = tiers[userSubscriptionTier].subscriptionDuration;
        uint256 profit = userSubscriptions[msg.sender].tokensDeposited * timeSubscribed * tiers[userSubscriptionTier].burnRatePercent / (tiers[userSubscriptionTier].subscriptionDuration * P100); 

        if(profit > 0){
            ufiToken.safeTransfer(profitCollectionAddress, profit);
        }
        ufiToken.safeTransfer(msg.sender, userSubscriptions[msg.sender].tokensDeposited - profit);
        removeUser(userSubscriptions[msg.sender].dateSubscribed, userSubscriptions[msg.sender].tokensDeposited);
        delete userSubscriptions[msg.sender];
        emit Unsubscribed(msg.sender, userSubscriptionTier, uint64(block.timestamp), profit);
    }

    /**
    returns:
    0: amount of UFI to be on a balance for subscription
    1: amount of ETH(BNB) to set as a transaction value for subscription to be successful
    2: amount of UFI that will be locked when subscription applied
    */
    function estimateSubscriptionPrice(address _holder, uint8 _tier) external view returns (uint256, uint256, uint256){
        require(tiers[_tier].priceInUSD > 0, 'Invalid tier provided');
        require(tiers[_tier].isactive > 0, "Tier is not active. Can't subscribe");

        uint256 tokensLeftFromCurrentSubscription = 0;
        //check for existing subscription
        uint8 userSubscriptionTier = userSubscriptions[_holder].tier;
        
        if(userSubscriptionTier > 0){
            uint256 timeSubscribed = block.timestamp - userSubscriptions[_holder].dateSubscribed;
            // round timeSubscribed up to month
            timeSubscribed = (1 + timeSubscribed / MONTH) * MONTH;
            // for expired subscriptions set subscribed time to initial tier duration.
            if (timeSubscribed > tiers[userSubscriptionTier].subscriptionDuration)
                timeSubscribed = tiers[userSubscriptionTier].subscriptionDuration;
            uint256 unrealizedProfitFromCurrentSubscription = userSubscriptions[_holder].tokensDeposited * timeSubscribed * tiers[userSubscriptionTier].burnRatePercent / (tiers[userSubscriptionTier].subscriptionDuration * P100); 
            tokensLeftFromCurrentSubscription = userSubscriptions[_holder].tokensDeposited - unrealizedProfitFromCurrentSubscription;
        }
        //subscripbe to the _tier
        (uint newSubscriptionPriceInWBNB, uint256 newSubscriptionPriceInUFI) = tokenBuyer.busdToUFI(tiers[_tier].priceInUSD);
        uint256 userBalanceUFI = ufiToken.balanceOf(_holder);


        if(tokensLeftFromCurrentSubscription >= newSubscriptionPriceInUFI){
            //this is the case when user subsribes to lower package and remaining tokens are more then enough
            //=> refunding tokens back to user
            return (0, 0, newSubscriptionPriceInUFI);
        }
        else {
            //this is the case when remaining user tokens on the contract is not enough for the new subscription 
            if(newSubscriptionPriceInUFI - tokensLeftFromCurrentSubscription > userBalanceUFI){
                uint256 ufiTokenToBuy = newSubscriptionPriceInUFI - tokensLeftFromCurrentSubscription - userBalanceUFI + 1;
                uint256 ethToSend = newSubscriptionPriceInWBNB * ufiTokenToBuy * 1001 / 1000 / newSubscriptionPriceInUFI;
                return (newSubscriptionPriceInUFI - tokensLeftFromCurrentSubscription, ethToSend, newSubscriptionPriceInUFI);
            } else {
                return (newSubscriptionPriceInUFI - tokensLeftFromCurrentSubscription, 0, newSubscriptionPriceInUFI);
            }

        }
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
        return (userSubscriptions[_user].tier,
                userSubscriptions[_user].dateSubscribed,
                userSubscriptions[_user].dateSubscribed + ((userSubscriptions[_user].tier > 0)?tiers[userSubscriptions[_user].tier].subscriptionDuration:0),
                userSubscriptions[_user].userdata,
                userSubscriptions[_user].tokensDeposited);
        
    }

    /**
    returns: 
        0: subscription Duration
        1: price in USD
        2: burn rate percent
        3: kyc Included
        4: aml Included
        5: is active flag
     */
    function getTierData(uint8 _tier) external view returns(uint48, uint128, uint8, uint16, uint48, uint8){
        return (tiers[_tier].subscriptionDuration,
                tiers[_tier].priceInUSD,
                tiers[_tier].burnRatePercent,
                tiers[_tier].kycIncluded,
                tiers[_tier].amlIncluded,
                tiers[_tier].isactive
                );
    }

    function getUserStat() external view returns(uint256, uint256, uint256) {
        uint256 usersAmount = (userstat >> 224) & 0x00000000000000000000000000000000000000000000000000000000FFFFFFFF; //32
        uint256 sDepi =       (userstat >> 128) & 0x0000000000000000000000000000000000000000FFFFFFFFFFFFFFFFFFFFFFFF; //96
        uint256 sTiDepi =     (userstat)        & 0x00000000000000000000000000000000FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF; //128
        return(usersAmount,sDepi,sTiDepi);
    }

    function addUser(uint256 dateSubscribed, uint256 tokensDeposited) private {
        //0x - 04 bytes //number of users
        //0x - 12 bytes //sigma dep_i
        //0x - 16 bytes //sigma t_i*dep_i
        uint256 usersAmount = (userstat >> 224) & 0x00000000000000000000000000000000000000000000000000000000FFFFFFFF; //32
        uint256 sDepi =       (userstat >> 128) & 0x0000000000000000000000000000000000000000FFFFFFFFFFFFFFFFFFFFFFFF; //96
        uint256 sTiDepi =     (userstat)        & 0x00000000000000000000000000000000FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF; //128

        usersAmount += 1;
        sDepi += uint96(tokensDeposited);
        sTiDepi += uint128(tokensDeposited * dateSubscribed);

        uint256 stat = (usersAmount << 224)
                        + ((sDepi & 0x0000000000000000000000000000000000000000FFFFFFFFFFFFFFFFFFFFFFFF) << 128)
                        + (sTiDepi & 0x00000000000000000000000000000000FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF);
        //update user stat
        userstat = stat;
    }

    function removeUser(uint256 dateSubscribed, uint256 tokensDeposited) private {
        //0x - 04 bytes //number of users
        //0x - 12 bytes //sigma dep_i
        //0x - 16 bytes //sigma t_i*dep_i
        uint256 usersAmount = (userstat >> 224) & 0x00000000000000000000000000000000000000000000000000000000FFFFFFFF; //32
        uint256 sDepi =       (userstat >> 128) & 0x0000000000000000000000000000000000000000FFFFFFFFFFFFFFFFFFFFFFFF; //96
        uint256 sTiDepi =     (userstat)        & 0x00000000000000000000000000000000FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF; //128

        usersAmount -= 1;
        sDepi -= uint96(tokensDeposited);
        sTiDepi -= uint128(tokensDeposited * dateSubscribed);  
        
        uint256 stat = (usersAmount << 224)
                        + ((sDepi & 0x0000000000000000000000000000000000000000FFFFFFFFFFFFFFFFFFFFFFFF) << 128)
                        + ((sTiDepi & 0x00000000000000000000000000000000FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF));
        // update user stat
        userstat = stat;
    }

    function _subscribe(uint8 _tier, address _subscriber) private {
        require(tiers[_tier].priceInUSD > 0, 'Invalid tier provided');
        require(tiers[_tier].isactive > 0, "Tier is not active. Can't subscribe");

        uint256 tokensLeftFromCurrentSubscription = 0;
        //check for existing subscription
        uint8 userCurrentSubscriptionTier = userSubscriptions[_subscriber].tier;
        if(userCurrentSubscriptionTier > 0){
            uint256 timeSubscribed = block.timestamp - userSubscriptions[_subscriber].dateSubscribed;
            // round timeSubscribed up to month
            timeSubscribed = (1 + timeSubscribed / MONTH) * MONTH;
            // for expired subscriptions set subscribed time to initial tier duration.
            if (timeSubscribed > tiers[userCurrentSubscriptionTier].subscriptionDuration)
                timeSubscribed = tiers[userCurrentSubscriptionTier].subscriptionDuration;
            uint256 unrealizedProfitFromCurrentSubscription = userSubscriptions[_subscriber].tokensDeposited * timeSubscribed * tiers[userCurrentSubscriptionTier].burnRatePercent / (tiers[userCurrentSubscriptionTier].subscriptionDuration * P100); 
            if(unrealizedProfitFromCurrentSubscription > 0){
                ufiToken.safeTransfer(profitCollectionAddress, unrealizedProfitFromCurrentSubscription);
            }
            tokensLeftFromCurrentSubscription = userSubscriptions[_subscriber].tokensDeposited - unrealizedProfitFromCurrentSubscription;
            emit Unsubscribed(_subscriber, userCurrentSubscriptionTier, uint64(block.timestamp), unrealizedProfitFromCurrentSubscription);
            removeUser(userSubscriptions[_subscriber].dateSubscribed, userSubscriptions[_subscriber].tokensDeposited);
            delete userSubscriptions[_subscriber];
        }
        //subscripbe to the _tier
        (uint newSubscriptionPriceInWBNB, uint256 newSubscriptionPriceInUFI) = tokenBuyer.busdToUFI(tiers[_tier].priceInUSD);
        uint256 userBalanceUFI = ufiToken.balanceOf(_subscriber);
        uint256 ethRemaining = msg.value;
        if(tokensLeftFromCurrentSubscription >= newSubscriptionPriceInUFI){
            //this is the case when user subsribes to lower package and remaining tokens are more then enough
            //=> refunding tokens back to user
            ufiToken.safeTransfer(_subscriber, tokensLeftFromCurrentSubscription - newSubscriptionPriceInUFI);
        }
        else {
            //this is the case when remaining user tokens on the contract is not enough for the new subscription 
            if(newSubscriptionPriceInUFI - tokensLeftFromCurrentSubscription > userBalanceUFI){
                //this is the case when user doesn't have enough UFI tokens on his/her balance
                //0. take all users UFI tokens
                ufiToken.safeTransferFrom(msg.sender, address(this), userBalanceUFI);
                //not enough UFI balance on users wallet => buy UFI. 
                //1. buy exact UFI amount that user lacks for subscription
                //2. set ethToSend to a 0.1% more then estimated to make sure there will be enough UFI for subscription.
                uint256 ufiTokenToBuy = newSubscriptionPriceInUFI - tokensLeftFromCurrentSubscription - userBalanceUFI + 1;
                uint256 ethToSend = newSubscriptionPriceInWBNB * ufiTokenToBuy * 1001 / 1000 / newSubscriptionPriceInUFI;
                require(ethRemaining >= ethToSend, "Not enough msg.value for transaction");
                tokenBuyer.buyExactTokens{value:ethToSend}(ufiTokenToBuy, address(this));
                ethRemaining-=ethToSend;
            } else {
                //this is the case when user has enough tokens on his/her balance
                uint256 ufiToClaim = newSubscriptionPriceInUFI - tokensLeftFromCurrentSubscription;
                ufiToken.safeTransferFrom(msg.sender, address(this), ufiToClaim);
            }

        }
        
        userSubscriptions[_subscriber] = UserSubscription(_tier, uint64(block.timestamp), uint128(newSubscriptionPriceInUFI), 0);
        emit Subscribed(_subscriber, _tier, uint64(block.timestamp), newSubscriptionPriceInUFI);
        addUser(block.timestamp, newSubscriptionPriceInUFI);
        if(ethRemaining > 0){
            payable(msg.sender).transfer(ethRemaining);
        }
    }
    

}