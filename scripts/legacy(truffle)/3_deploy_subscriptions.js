const PureFiRouter = artifacts.require('PureFiRouter');
const PureFiVerifier = artifacts.require('PureFiVerifier');
const PureFiIssuerRegistry = artifacts.require('PureFiIssuerRegistry');
const PureFiWhitelist = artifacts.require('PureFiWhitelist');
const PProxyAdmin = artifacts.require('PProxyAdmin');
const PProxy = artifacts.require('PProxy');
const TestBotProtection = artifacts.require('TestBotProtection');
const PureFiLockService = artifacts.require('PureFiLockService');
const PureFiSubscriptionService = artifacts.require('PureFiSubscriptionService');
const PureFiTokenBuyerBSC = artifacts.require('PureFiTokenBuyerBSC');
const TestToken = artifacts.require('TestToken');
const web3 = require("web3");
const BN = web3.utils.BN;
const { time } = require('@openzeppelin/test-helpers');

function toBN(number) {
    return web3.utils.toBN(number);
}

module.exports = async function (deployer, network, accounts) {
    
    let admin = accounts[0];
    console.log("Deploy: Admin: "+admin);

     //deploy master admin
    let proxyAdmin = await PProxyAdmin.at('0x3958341e490B8a8075F6C84de68563f3586840D9');
    let router = await PureFiRouter.at('0x360B0586244404D0Ee67728F5bA5C4763D755218');
    let pureFiToken = await TestToken.at('0xe2a59D5E33c6540E18aAA46BF98917aC3158Db0D');
    let burnAddress = accounts[0];
      
    // let lockServiceMasterCopy;
    // await PureFiLockService.new().then(instance => lockServiceMasterCopy = instance);
    // console.log("PureFiLockService master copy=",lockServiceMasterCopy.address);

    let lockContract = await PureFiLockService.at('0xACD92EfaC7f5fC184a1d580E4C87c50A40f39B8F');
    // await PProxy.new(lockServiceMasterCopy.address,proxyAdmin.address,web3.utils.hexToBytes('0x')).
    //     then(function(instance){
    //         return PureFiLockService.at(instance.address);
    //     }).then(instance => lockContract = instance);
    // console.log("PureFiLockService instance: ", lockContract.address);
    // await lockContract.initialize(accounts[0]);
    console.log("Using PureFiLockService version",(await lockContract.version.call()).toString());

    // let tokenBuyer;
    // await PureFiTokenBuyerBSC.new().then(instance => tokenBuyer = instance); 
    // console.log("PureFiTokenBuyerBSC instance: ", tokenBuyer.address);


    // let subscriptionServiceMasterCopy;
    // await PureFiSubscriptionService.new().then(instance => subscriptionServiceMasterCopy = instance);
    // console.log("PureFiSubscriptionService master copy=",subscriptionServiceMasterCopy.address);

    let subscriptionContract = await PureFiSubscriptionService.at('0xb86d329f8f5eF34d72D270EAca7B27fDb7331229');
    // await PProxy.new(subscriptionServiceMasterCopy.address,proxyAdmin.address,web3.utils.hexToBytes('0x')).
    //     then(function(instance){
    //         return PureFiSubscriptionService.at(instance.address);
    //     }).then(instance => subscriptionContract = instance);
    // console.log("PureFiSubscriptionService instance: ", subscriptionContract.address);
    // await subscriptionContract.initialize(accounts[0],pureFiToken.address,lockContract.address,tokenBuyer.address,burnAddress);
    console.log("Using PureFiSubscriptionService version",(await subscriptionContract.version.call()).toString());

   
    // await lockContract.grantRole.sendTransaction(web3.utils.keccak256('UFI_TRUSTED_PAYMENT_SERVICE'),subscriptionContract.address,{from:admin});

    if(network != 'test'){
        await router.setAddress.sendTransaction(4,lockContract.address);
        await router.setAddress.sendTransaction(5,subscriptionContract.address);
    }
    
   
    
};