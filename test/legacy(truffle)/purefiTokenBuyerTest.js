const { time, expectRevert } = require('@openzeppelin/test-helpers');
const bigDecimal = require('js-big-decimal');
// const web3 = require("web3");
// const BN = web3.utils.BN;
const chai = require('chai');
const expect = chai.expect;
const assert = chai.assert;
// chai.use(require('bn-chai')(BN));
// chai.use(require('chai-match'));

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
const PureFiTokenBuyerETH = artifacts.require('PureFiTokenBuyerETH');
const UFIBuyerCustomAMLCheck = artifacts.require('UFIBuyerCustomAMLCheck');
const UFIBuyerDefaultAMLCheck = artifacts.require('UFIBuyerDefaultAMLCheck');
const TestToken = artifacts.require('TestToken');

function toBN(number) {
    return web3.utils.toBN(number);
}

function printEvents(txResult, strdata){
    console.log(strdata," events:",txResult.logs.length);
    for(var i=0;i<txResult.logs.length;i++){
        let argsLength = Object.keys(txResult.logs[i].args).length;
        console.log("Event ",txResult.logs[i].event, "  length:",argsLength);
        for(var j=0;j<argsLength;j++){
            if(!(typeof txResult.logs[i].args[j] === 'undefined') && txResult.logs[i].args[j].toString().length>0)
                console.log(">",i,">",j," ",txResult.logs[i].args[j].toString());
        }
    }

}


contract('PureFi buy token test', (accounts) => {
 
    let admin   = accounts[0];
    const decimals = toBN(10).pow(toBN(18));
  
    console.log("Test: Admin: "+admin);

    let pureFiToken;
    let botProtection;
    let paymentPlanFD;
    let tokenBuyer;
    // const startDate = 1627383600; // Jul 27 11:00 UTC
    const startDate = Math.round((new Date().getTime())/1000)+10;

    const mode = "ETH";


    before(async () => {

        if(mode == 'ETH'){
            await PureFiTokenBuyerETH.new().then(instance => tokenBuyer = instance);
            pureFiToken = await TestToken.at('0xcDa4e840411C00a614aD9205CAEC807c7458a0E3');
        } 
        if (mode == 'BSC'){
            await PureFiTokenBuyerBSC.new().then(instance => tokenBuyer = instance);
            pureFiToken = await TestToken.at('0xe2a59D5E33c6540E18aAA46BF98917aC3158Db0D');
        }

        await tokenBuyer.initialize.sendTransaction();
        
    });

    it('should buy token', async () => {
        let balanceToken = await pureFiToken.balanceOf.call(admin);
        console.log("balanceToken",balanceToken.div(decimals).toString());

        let toBuyBnb = toBN(1).mul(decimals).div(toBN(1000));
        
        // let sendReceipt = await web3.eth.sendTransaction({
        //     from: admin,
        //     to: tokenBuyer.address, 
        //     value: toBuyBnb
        //   });

        let sendReceipt = await tokenBuyer.buyFor.sendTransaction(admin, {value: toBuyBnb, from: admin});

        printEvents(sendReceipt,"buy");
        let balanceToken2 = await pureFiToken.balanceOf.call(admin);

        console.log("Bought ",balanceToken2.sub(balanceToken).div(decimals).toString());

    });

   
});
