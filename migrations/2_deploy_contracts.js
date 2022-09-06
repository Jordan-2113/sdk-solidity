const UFIBuyerETHWithCheck = artifacts.require('UFIBuyerETHWithCheck');
const PureFiVerifier = artifacts.require('PureFiVerifier');
const PureFiIssuerRegistry = artifacts.require('PureFiIssuerRegistry');
const PureFiTokenBuyerETH = artifacts.require('PureFiTokenBuyerETH');
const PureFiSubscriptionService = artifacts.require('PureFiSubscriptionService');
const PureFiWhitelist = artifacts.require('PureFiWhitelist');
const PProxyAdmin = artifacts.require('PProxyAdmin');
const PProxy = artifacts.require('PProxy');
const web3 = require("web3");
const BN = web3.utils.BN;
const { time } = require('@openzeppelin/test-helpers');

function toBN(number) {
    return web3.utils.toBN(number);
}

module.exports = async function (deployer, network, accounts) {
    
    let admin = accounts[0];
    console.log("Deploy: Admin: "+admin);
    let burnAddress = accounts[0];

    let pureFiTokenAddress = '0xcDa4e840411C00a614aD9205CAEC807c7458a0E3';

     //deploy master admin
     let proxyAdmin = await PProxyAdmin.at('0x3f11558964F51Db1AF18825D0f4F8D7FC8bb6ac7');
     console.log("Proxy Admin: ",proxyAdmin.address);

    let regsitryMasterCopy;
    await PureFiIssuerRegistry.new().then(instance => regsitryMasterCopy = instance);
    console.log("registryMasterCopy=",regsitryMasterCopy.address);

    let registry;
    await PProxy.new(regsitryMasterCopy.address,proxyAdmin.address,web3.utils.hexToBytes('0x')).
        then(function(instance){
            return PureFiIssuerRegistry.at(instance.address);
        }).then(instance => registry = instance);
    console.log("Registry instance: ", registry.address);
    await registry.initialize.sendTransaction(accounts[0]);
    console.log("Using Registry version",(await registry.version.call()).toString());

    let whitelistMasterCopy;
    await PureFiWhitelist.new().then(instance => whitelistMasterCopy = instance);
    console.log("whitelistMasterCopy=",whitelistMasterCopy.address);

    let whitelist;
    await PProxy.new(whitelistMasterCopy.address,proxyAdmin.address,web3.utils.hexToBytes('0x')).
        then(function(instance){
            return PureFiWhitelist.at(instance.address);
        }).then(instance => whitelist = instance);
    console.log("whitelist instance: ", whitelist.address);
    await whitelist.initialize.sendTransaction(registry.address);
    console.log("Using whitelist version",(await whitelist.version.call()).toString());
    

    let verifierMasterCopy;
    await PureFiVerifier.new().then(instance => verifierMasterCopy = instance);
    console.log("verifierMasterCopy=",verifierMasterCopy.address);

    let verifier;
    await PProxy.new(verifierMasterCopy.address,proxyAdmin.address,web3.utils.hexToBytes('0x')).
        then(function(instance){
            return PureFiVerifier.at(instance.address);
        }).then(instance => verifier = instance);
    console.log("verifier instance: ", verifier.address);
    await verifier.initialize.sendTransaction(registry.address, whitelist.address);
    console.log("Using verifier version",(await verifier.version.call()).toString());

    // uint16 private constant PARAM_DEFAULT_AML_GRACETIME = 3;
    // uint16 private constant PARAM_DEFAULT_AML_RULE = 4;
    // uint16 private constant PARAM_DEFAULT_KYC_RULE = 5;
    // uint16 private constant PARAM_DEFAULT_KYCAML_RULE = 6;
    // uint16 private constant PARAM_ISSUER_REGISTRY_ADDRESS = 7;
    // uint16 private constant PARAM_WHITELIST_ADDRESS = 8;
    
    await verifier.setUint256.sendTransaction(3, toBN(300)); //default rule
    await verifier.setUint256.sendTransaction(4, toBN(431040)); //default rule
    await verifier.setUint256.sendTransaction(5, toBN(777)); //default rule
    await verifier.setUint256.sendTransaction(6, toBN(731040)); //default rule

    // uint16 private constant ERROR_ISSUER_SIGNATURE_INVALID = 1;
    // uint16 private constant ERROR_FUNDS_SENDER_DOESNT_MATCH_ADDRESS_VERIFIED = 2;
    // uint16 private constant ERROR_PROOF_VALIDITY_EXPIRED = 3;
    // uint16 private constant ERROR_RULE_DOESNT_MATCH = 4;
    // uint16 private constant ERROR_CREDENTIALS_TIME_MISMATCH = 5;
    // uint16 private constant ERROR_DATA_PACKAGE_INVALID = 6;

    await verifier.setString.sendTransaction(1, "PureFiVerifier: Issuer signature invalid");
    await verifier.setString.sendTransaction(2, "PureFiVerifier: Funds sender doesn't match verified wallet");
    await verifier.setString.sendTransaction(3, "PureFiVerifier: Verification data expired");
    await verifier.setString.sendTransaction(4, "PureFiVerifier: Rule verification failed");
    await verifier.setString.sendTransaction(5, "PureFiVerifier: Credentials time mismatch");
    await verifier.setString.sendTransaction(6, "PureFiVerifier: Data package invalid")

    await registry.register.sendTransaction('0xee5FF7E46FB99BdAd874c6aDb4154aaE3C90E698',web3.utils.keccak256('PureFi Issuer'));
    
    //******** subsciptions */
    let tokenBuyer;
    await PureFiTokenBuyerETH.new().then(instance => tokenBuyer = instance); 
    console.log("PureFiTokenBuyerETH instance: ", tokenBuyer.address);
    await tokenBuyer.initialize.sendTransaction();

    let subscriptionServiceMasterCopy;
    await PureFiSubscriptionService.new().then(instance => subscriptionServiceMasterCopy = instance);
    console.log("PureFiSubscriptionService master copy=",subscriptionServiceMasterCopy.address);

    let subscriptionContract;//
    await PProxy.new(subscriptionServiceMasterCopy.address,proxyAdmin.address,web3.utils.hexToBytes('0x')).
        then(function(instance){
            return PureFiSubscriptionService.at(instance.address);
        }).then(instance => subscriptionContract = instance);
    console.log("PureFiSubscriptionService2 instance: ", subscriptionContract.address);
    await subscriptionContract.initialize(accounts[0],pureFiTokenAddress,tokenBuyer.address,burnAddress);
    console.log("Using PureFiSubscriptionService version",(await subscriptionContract.version.call()).toString());

    let yearTS = 86400*365;
    let decimals = web3.utils.toBN(10).pow(web3.utils.toBN(18));
    await subscriptionContract.setTierData.sendTransaction(web3.utils.toBN(1),web3.utils.toBN(yearTS),web3.utils.toBN(50).mul(decimals),web3.utils.toBN(20),web3.utils.toBN(1),web3.utils.toBN(5));
    await subscriptionContract.setTierData.sendTransaction(web3.utils.toBN(2),web3.utils.toBN(yearTS),web3.utils.toBN(100).mul(decimals),web3.utils.toBN(20),web3.utils.toBN(1),web3.utils.toBN(15));
    await subscriptionContract.setTierData.sendTransaction(web3.utils.toBN(3),web3.utils.toBN(yearTS),web3.utils.toBN(300).mul(decimals),web3.utils.toBN(20),web3.utils.toBN(1),web3.utils.toBN(45));

    //******** example contracts */
    let ex2defaultMasterCopy;
    await UFIBuyerETHWithCheck.new().then(instance => ex2defaultMasterCopy = instance);
    console.log("UFIBuyerETHWithCheck=",ex2defaultMasterCopy.address);

    let ex2default;
    await PProxy.new(ex2defaultMasterCopy.address,proxyAdmin.address,web3.utils.hexToBytes('0x')).
        then(function(instance){
            return UFIBuyerETHWithCheck.at(instance.address);
        }).then(instance => ex2default = instance);
    console.log("ex2default instance: ", ex2default.address);
    await ex2default.initialize.sendTransaction(verifier.address);
    console.log("Using ex2default version",(await ex2default.version.call()).toString()); 
    
};