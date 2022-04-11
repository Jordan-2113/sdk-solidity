const { time, expectRevert } = require('@openzeppelin/test-helpers');
const bigDecimal = require('js-big-decimal');
// const web3 = require("web3");
const web3Abi = require('web3-eth-abi');
const BN = web3.utils.BN;
const chai = require('chai');
const expect = chai.expect;
const assert = chai.assert;
chai.use(require('bn-chai')(BN));
chai.use(require('chai-match'));
const EthCrypto = require("eth-crypto");
const { test } = require('chai/lib/chai/utils');

const PureFiIssuerRegistry = artifacts.require('PureFiIssuerRegistry');
const PureFiRouter = artifacts.require('PureFiRouter');
const PureFiVerifier = artifacts.require('PureFiVerifier');
const PureFiWhitelist = artifacts.require('PureFiWhitelist');
const TestToken = artifacts.require('TestToken');

function toBN(number) {
    return web3.utils.toBN(number);
}

function printEvents(txResult, strdata){
    console.log(strdata," events:",txResult.logs.length);
    console.log(`${strdata} GasUsed: ${txResult.receipt.gasUsed} `);
    for(var i=0;i<txResult.logs.length;i++){
        let argsLength = Object.keys(txResult.logs[i].args).length;
        console.log("Event ",txResult.logs[i].event, "  length:",argsLength);
        for(var j=0;j<argsLength;j++){
            if(!(typeof txResult.logs[i].args[j] === 'undefined') && txResult.logs[i].args[j].toString().length>0)
                console.log(">",i,">",j," ",txResult.logs[i].args[j].toString());
        }
    }

}

const signMessage = async (message, privateKey) => {

    const publicKeySigner = EthCrypto.publicKeyByPrivateKey(privateKey);
    const signerAddress = EthCrypto.publicKey.toAddress(publicKeySigner);

    const signerIdentity = {
        privateKey: privateKey,
        publicKey: publicKeySigner,
        address: signerAddress
    }

    const publicKey = EthCrypto.publicKeyByPrivateKey(signerIdentity.privateKey);
    const magicAddress = EthCrypto.publicKey.toAddress(publicKey);
    // console.log("Magic address: ", magicAddress);
    const messageHash = EthCrypto.hash.keccak256(message);
    const signature = EthCrypto.sign(signerIdentity.privateKey, messageHash);
    return signature;
}

contract('PureFi Verifier Test', (accounts) => {
 
    let admin   = accounts[0];
    const decimals = toBN(10).pow(toBN(18));
  
    console.log("Test: Admin: "+admin);

    let pureFiToken;
    let verifier;
    let issuerRegistry;


    before(async () => {

        await PureFiVerifier.deployed().then(instance => verifier = instance);

        let issuerRegAddress = await verifier.issuerRegistry.call();

        issuerRegistry = await PureFiIssuerRegistry.at(issuerRegAddress);

        console.log("verifier = ",verifier.address);
        console.log("issuerRegistry = ",issuerRegistry.address);

        
    });

    it('Test simple ETH transfer with verification', async () => {
        let origin = accounts[1];

        let target = accounts[2];
        //configure verifier
        let configureTx = await verifier.configureTarget.sendTransaction(target,toBN(180),toBN(0));
        printEvents(configureTx,"configure target");
        //prepare package
        let currentTime = Math.round((new Date()).getTime()/1000);
            //     @param data - signed data package from the off-chain verifier
    //   data[0] - verification session ID
    //   data[1] - circuit ID (if required)
    //   data[2] - verification timestamp
    //   data[3] - verified wallet - to be the same as msg.sender
        let ardata = [toBN(1), toBN(0), toBN(currentTime), toBN(origin)];
        const privateKey = 'e3ad95aa7e9678e96fb3d867c789e765db97f9d2018fca4068979df0832a5178';
        let message = [{
                type: "uint256",
                value: ardata[0].toString()
            },
            {
                type: "uint256",
                value: ardata[1].toString()
            },
            {
                type: "uint256",
                value: ardata[2].toString()
            },
            {
                type: "uint256",
                value: ardata[3].toString()
            }
        ];

        let signature = await signMessage(message, privateKey);
        let publicKeySigner = EthCrypto.publicKeyByPrivateKey(privateKey);
        let signerAddress = EthCrypto.publicKey.toAddress(publicKeySigner);
        console.log("signerAddress=",signerAddress);
        console.log("verifier version",(await verifier.version.call()).toString()); 
        
        let balanceOfOrigin = toBN(await web3.eth.getBalance(origin));
        let balanceOfTarget = toBN(await web3.eth.getBalance(target));
        console.log("Balance origin before:",balanceOfOrigin.toString());
        console.log("Balance target before:",balanceOfTarget.toString());

        let transferAmt = toBN(1).mul(decimals);

        let verifyTx = await verifier.verifyAndForward.sendTransaction(
            "0x",
            target,
            ardata,
            signature,
            {from:origin, value:transferAmt}
        );
        printEvents(verifyTx);

        let balanceOfOriginAfter = toBN(await web3.eth.getBalance(origin));
        let balanceOfTargetAfter = toBN(await web3.eth.getBalance(target));
        console.log("Balance origin after:",balanceOfOriginAfter.toString());
        console.log("Balance target after:",balanceOfTargetAfter.toString());
        expect(balanceOfTargetAfter).to.be.eq.BN(balanceOfTarget.add(transferAmt));
        expect(balanceOfOriginAfter).to.be.lt.BN(balanceOfOrigin.sub(transferAmt));
  
    });

    it('Test token transfer via Verifier', async () => {
        let testToken;
        await TestToken.new(toBN(100000000).mul(decimals),"TestToken","TST").then(instance => testToken = instance);
        let origin = accounts[1];

        let target = testToken.address;
        //configure verifier
        let configureTx = await verifier.configureTarget.sendTransaction(target,toBN(180),toBN(0));
        printEvents(configureTx,"configure target");
        //prepare package
        let currentTime = Math.round((new Date()).getTime()/1000);
            //     @param data - signed data package from the off-chain verifier
    //   data[0] - verification session ID
    //   data[1] - circuit ID (if required)
    //   data[2] - verification timestamp
    //   data[3] - verified wallet - to be the same as msg.sender
        let ardata = [toBN(1), toBN(0), toBN(currentTime), toBN(origin)];
        const privateKey = 'e3ad95aa7e9678e96fb3d867c789e765db97f9d2018fca4068979df0832a5178';
        let message = [{
                type: "uint256",
                value: ardata[0].toString()
            },
            {
                type: "uint256",
                value: ardata[1].toString()
            },
            {
                type: "uint256",
                value: ardata[2].toString()
            },
            {
                type: "uint256",
                value: ardata[3].toString()
            }
        ];

        let signature = await signMessage(message, privateKey);
        let publicKeySigner = EthCrypto.publicKeyByPrivateKey(privateKey);
        let signerAddress = EthCrypto.publicKey.toAddress(publicKeySigner);
        console.log("signerAddress=",signerAddress);
        console.log("verifier version",(await verifier.version.call()).toString()); 

        await testToken.transfer.sendTransaction(origin,toBN(100000).mul(decimals));


        let receiver = accounts[2];
        
        let balanceOfOrigin = await testToken.balanceOf.call(origin);
        let balanceOfReceiver = await testToken.balanceOf.call(receiver);
        console.log("Balance origin before:",balanceOfOrigin.toString());
        console.log("Balance receiver before:",balanceOfReceiver.toString());

        let transferAmt = toBN(1).mul(decimals);
        //approve
        await testToken.approve.sendTransaction(verifier.address,transferAmt,{from:origin});
        
        //transfer
        let abiSignature = web3Abi.encodeFunctionCall(
            {
                "constant": false,
                "inputs": [
                    {
                       "name": "sender",
                       "type": "address"
                    },
                    {
                      "name": "recipient",
                      "type": "address"
                    },
                    {
                      "name": "amount",
                      "type": "uint256"
                    }
                ],
                "name": "transferFrom",
                "outputs": [],
                "payable": false,
                "stateMutability": "nonpayable",
                "type": "function"
            }, [origin, receiver,transferAmt]
        );

        console.log("abiSignature",abiSignature.toString());

        let verifyTx = await verifier.verifyAndForward.sendTransaction(
            abiSignature,
            target,
            ardata,
            signature,
            {from:origin}
        );
        printEvents(verifyTx);

        let balanceOfOriginAfter = await testToken.balanceOf.call(origin);
        let balanceOfReceiverAfter = await testToken.balanceOf.call(receiver);
        console.log("Balance origin after:",balanceOfOriginAfter.toString());
        console.log("Balance receiver after:",balanceOfReceiverAfter.toString());
        expect(balanceOfReceiverAfter).to.be.eq.BN(balanceOfReceiver.add(transferAmt));
        expect(balanceOfOriginAfter).to.be.eq.BN(balanceOfOrigin.sub(transferAmt));
  
    });

    // it('check autodeploy pancake pair', async () =>{
    //     let regContract;
    //     await PureFiPancakeReg.new('0x10ED43C718714eb63d5aA57B78B54704E256024E').then(instance => regContract = instance);

    //     let router = await regContract.routerAddress();
    //     console.log("pureFiToken.address",pureFiToken.address);
    //     let pairAddress = await regContract.getPairAddress(pureFiToken.address);
    //     console.log("Pair Address", pairAddress);

    //     let whitelist = [router, admin , pairAddress, regContract.address];
        
    //     //whitelist 
    //     await botProtection.setBotLaunchpad(regContract.address, {from:admin});
    //     await botProtection.setBotWhitelists(whitelist, {from:admin});
        
    //     let firewallBlockLength = toBN(10);
    //     let firewallTimeLength = toBN(300);
    //     let amountUFI = toBN(1000).mul(decimals);
    //     let amountBNB = toBN('21308000000000000')//$45

    //     await pureFiToken.transfer(regContract.address, amountUFI, {from:admin});
    //     let regTx = await regContract.registerPair(pureFiToken.address, botProtection.address, amountUFI, amountBNB, firewallBlockLength, firewallTimeLength, {from:admin, value: amountBNB});
    //     printEvents(regTx);

    //     // let pairAddress2 = await regContract.getPairAddress2(pureFiToken.address);
    //     // console.log("Pair Address", pairAddress2);

    //      //expire protection
    //      await time.increase(time.duration.seconds(310));
    //      let currentBlock = await time.latestBlock();
    //      for(let i=0;i<11;i++){
    //          await time.advanceBlock();
    //      }
    //      let shifedBlock = await time.latestBlock();
    //      console.log("Shifting block: ",currentBlock.toString()," => ",shifedBlock.toString());

    //      await botProtection.finalizeBotProtection.sendTransaction({from:admin});
    // });

    
   
});
