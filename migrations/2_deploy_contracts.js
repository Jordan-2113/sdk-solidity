const PureFiRouter = artifacts.require('PureFiRouter');
const PureFiVerifier = artifacts.require('PureFiVerifier');
const PureFiIssuerRegistry = artifacts.require('PureFiIssuerRegistry');
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

     //deploy master admin
     let proxyAdmin;
     await PProxyAdmin.new().then(instance => proxyAdmin = instance);
     console.log("Proxy Admin: ",proxyAdmin.address);

    let routerMasterCopy;
    await PureFiRouter.new().then(instance => routerMasterCopy = instance);
    console.log("routerMasterCopy=",routerMasterCopy.address);

    let router;
    await PProxy.new(routerMasterCopy.address,proxyAdmin.address,web3.utils.hexToBytes('0x')).
        then(function(instance){
            return PureFiRouter.at(instance.address);
        }).then(instance => router = instance);
    console.log("Router instance: ", router.address);
    await router.initialize.sendTransaction(accounts[0]);
    console.log("Using router version",(await router.version.call()).toString());

    let regsitryMasterCopy;
    await PureFiIssuerRegistry.new().then(instance => regsitryMasterCopy = instance);
    console.log("regsitryMasterCopy=",regsitryMasterCopy.address);

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
    await whitelist.initialize.sendTransaction(router.address);
    console.log("Using whitelist version",(await whitelist.version.call()).toString());
    

    let verifier;
    await deployer.deploy(PureFiVerifier, registry.address)
    .then(function(){
        console.log("PureFiVerifier instance: ", PureFiVerifier.address);
        return PureFiVerifier.at(PureFiVerifier.address);
    }).then(function (instance){
        verifier = instance; 
    });
    console.log("Using verifier version",(await verifier.version.call()).toString());

    await router.setAddress.sendTransaction(1,registry.address);
    await router.setAddress.sendTransaction(2,verifier.address);
    await router.setAddress.sendTransaction(3,whitelist.address);
    await registry.register.sendTransaction('0x75597e9DEe0B7d88E98fCbcd82323BaED32c50FE',web3.utils.keccak256('PureFITestIssuer'));
    
    if(network == 'test'){
        await registry.register.sendTransaction(accounts[0],web3.utils.keccak256('issuer0'));
        await registry.register.sendTransaction(accounts[1],web3.utils.keccak256('issuer1'));
        await registry.register.sendTransaction('0x84a5B4B863610989197C957c8816cF6a3B91adD2',web3.utils.keccak256('testsinger'));
        
        //address _user, uint256 _sessionID, uint256 _ruleID, uint64 _verifiedOn, uint64 _validUntil
        let testAddress = accounts[9];
        let res = await whitelist.whitelist.sendTransaction(
            testAddress,
            toBN(1),
            toBN(0),
            toBN(1649652010),
            toBN(1670652010)
        );

        let isVerified = await router.isAddressVerified.call(testAddress);
        console.log("isVerified=",isVerified);

        let del = await whitelist.delist.sendTransaction(testAddress);
        let isVerified2 = await router.isAddressVerified.call(testAddress);
        console.log("isVerified2=",isVerified2);

    }

   
    
};