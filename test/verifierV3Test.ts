import { expect } from "chai";
import hre, { ethers } from "hardhat";

import { utils } from "ethers";
import { ContextTestContract, PureFiIssuerRegistry, PureFiVerifier } from "../typechain-types";
import { BigNumber } from "ethers";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { arrayify, Bytes, defaultAbiCoder, keccak256, ParamType, parseEther, recoverAddress, solidityPack, toUtf8Bytes } from "ethers/lib/utils";
import EthCrypto, { publicKeyByPrivateKey, sign, util } from 'eth-crypto';
import { VerificationPackageStruct } from "../typechain-types/contracts/PureFiVerifier";


const ADDRESS_STUB = "0x0000000000000000000000000000000000001230";
const NULL_ADDRESS = "0x0000000000000000000000000000000000000000"
const DEFAULT_AML_RULE = 100;
const DEFAULT_KYC_RULE = 200;
const DEFAULT_AML_KYC_RULE = 300;
describe("VerifierV3", function () {

    let admin: SignerWithAddress;
    let alice: SignerWithAddress;
    // let bob: SignerWithAddress;
    // let carl: SignerWithAddress;
    let verifier: PureFiVerifier;
    let issuerRegistry : PureFiIssuerRegistry;
    let test : ContextTestContract;
    const currentTimestamp = BigNumber.from(1664541916 + 123456789);
    const ruleId = 431017;
    const sessionId = 123321;
    const privateKey = "e3ad95aa7e9678e96fb3d867c789e765db97f9d2018fca4068979df0832a5178";
    const signerIdentity = {
        privateKey : privateKey,
        publicKey : EthCrypto.publicKeyByPrivateKey(privateKey),
        address : EthCrypto.publicKey.toAddress(publicKeyByPrivateKey(privateKey))
    };



    before(async () => {
        [admin, alice] = await ethers.getSigners();

        const VERIFIER = await hre.ethers.getContractFactory("PureFiVerifier");
        const ISSUER_REGISTRY = await hre.ethers.getContractFactory("PureFiIssuerRegistry");
        const CONTEXT_TEST = await hre.ethers.getContractFactory("ContextTestContract");

        issuerRegistry = await ISSUER_REGISTRY.deploy();
        await issuerRegistry.deployed();
        issuerRegistry.initialize(admin.address);

        verifier = await VERIFIER.deploy();
        await verifier.deployed();

        test = await CONTEXT_TEST.deploy(verifier.address);
        await test.deployed();

        await verifier.initialize(issuerRegistry.address, ADDRESS_STUB);
        const proof = utils.arrayify("0x0000000000000000000000000000000000000000000000000000000000000123");
        await issuerRegistry.register(signerIdentity.address, proof);
        await verifier.setUint256(3, 300);

        await verifier.setUint256(4, DEFAULT_AML_RULE);
        await verifier.setUint256(5, DEFAULT_KYC_RULE);
        await verifier.setUint256(6, DEFAULT_AML_KYC_RULE);
        
    });

    xit("test validatePureFiData", async function () {
        
        //purefipackage
        const packageType = 1;
        // packagedata
        const sender = signerIdentity.address;
        // rule id 
        const ruleId = 100;
        const timestamp = currentTimestamp;
        const sessionId = 1234;

        const purefiPackage = defaultAbiCoder.encode(["uint8", "uint256", "uint256", "address"], [packageType, ruleId, sessionId, sender]);
        const message = solidityPack(["uint64", "bytes"], [timestamp, purefiPackage]);
        const hash = keccak256(message);
        const signature = sign(signerIdentity.privateKey, hash);
        const purefiData = defaultAbiCoder.encode(["uint64", "bytes", "bytes"], [ timestamp, signature, purefiPackage ]);

        // console.log("Result : \n", await verifier.validatePureFiData(purefiData));
        const [infoBytes, statusCode] = await verifier.validatePureFiData(purefiData);

        expect(statusCode).eq(0);
        const info = await verifier.decodePureFiPackage(infoBytes);

        expect(info[0]).eq(1);
        expect(info[1]).eq(BigNumber.from(sessionId));
        expect(info[2]).eq(BigNumber.from(ruleId));
        expect(info[3]).eq(sender);
        expect(info[4]).eq(NULL_ADDRESS);
        expect(info[5]).eq(NULL_ADDRESS);
        expect(info[6]).eq(BigNumber.from(0));
        expect(info[7]).eq("0x");
        
    });

    xit("test decodePureFiPackage type 2", async function (){
        const type = 2;
        const sender = signerIdentity.address;
        const receiver = alice.address;
        const token = ADDRESS_STUB;
        const amount = BigNumber.from(1000000000000);
        const packageToDecode = utils.defaultAbiCoder.encode(
            ["uint8", "uint256", "uint256", "address", "address", "address", "uint256"],
            [type, ruleId, sessionId, sender, receiver, token,  amount]
        );
        const info =  await verifier.decodePureFiPackage(packageToDecode);
        expect(info[0]).eq(2);
        expect(info[1]).eq(BigNumber.from(sessionId));
        expect(info[2]).eq(BigNumber.from(ruleId));
        expect(info[3]).eq(sender);
        expect(info[4]).eq(receiver);
        expect(info[5]).eq(token);
        expect(info[6]).eq(amount);
        expect(info[7]).eq("0x");
        

    });

    xit("test decodePureFiPackage type 3", async function (){
        const type = 3;
        const payload = defaultAbiCoder.encode(["uint256"], [456]);
        const packageToDecode = utils.defaultAbiCoder.encode(
            ["uint8", "uint256", "uint256", "bytes"],
            [type, ruleId, sessionId, payload]
        );
        const info = await verifier.decodePureFiPackage(packageToDecode);
        expect(info[0]).eq(3);
        expect(info[1]).eq(BigNumber.from(sessionId));
        expect(info[2]).eq(BigNumber.from(ruleId));
        expect(info[3]).eq(NULL_ADDRESS);
        expect(info[4]).eq(NULL_ADDRESS);
        expect(info[5]).eq(NULL_ADDRESS);
        expect(info[6]).eq(BigNumber.from(0));
        expect(info[7]).eq(payload);
    });

    xit("test PureFiContext withPureFiContext modifier", async function () {
        {
            const type = 1;
            const sender = signerIdentity.address;
            const ruleId = 100;
            const purefiPackage = defaultAbiCoder.encode(["uint8", "uint256", "uint256", "address"], [type, ruleId, sessionId, sender]);
            const message = solidityPack(["uint64", "bytes"], [currentTimestamp, purefiPackage]);
            const hash = keccak256(message);
            const signature = sign(signerIdentity.privateKey, hash);
            const purefiData = defaultAbiCoder.encode(["uint64", "bytes", "bytes"], [ currentTimestamp, signature, purefiPackage ]);

            await test.funcWithPureFiContext(purefiData);
            // assert with hardoced value
            expect(await test.getCounter()).eq(100);

            
        }
        
        {
            const type = 2;
            const sender = signerIdentity.address;
            const ruleId = 100;
            const receiver = alice.address;
            const token = ADDRESS_STUB;
            const amount = BigNumber.from(1000000000000);
            const purefiPackage = defaultAbiCoder.encode(
                ["uint8", "uint256", "uint256", "address", "address", "address", "uint256" ],
                [type, ruleId, sessionId, sender, receiver, token, amount]
                );
            
            const message = solidityPack(["uint64", "bytes"], [currentTimestamp, purefiPackage]);
            const hash = keccak256(message);
            const signature = sign(signerIdentity.privateKey, hash);
            const purefiData = defaultAbiCoder.encode(["uint64", "bytes", "bytes"], [currentTimestamp, signature, purefiPackage]);
            // console.log("Res type 2: \n", (await test.funcWithPureFiContext(purefiData)).data );
            await test.funcWithPureFiContext(purefiData)

        }
        {
            const type = 3;
            const ruleId = 100;
            const payload = defaultAbiCoder.encode(["uint256"], [456]);
            const purefiPackage = defaultAbiCoder.encode(
                ["uint8", "uint256", "uint256", "bytes" ],
                [type, ruleId, sessionId, payload]
                );
            
            const message = solidityPack(["uint64", "bytes"], [currentTimestamp, purefiPackage]);
            const hash = keccak256(message);
            const signature = sign(signerIdentity.privateKey, hash);
            const purefiData = defaultAbiCoder.encode(["uint64", "bytes", "bytes"], [currentTimestamp, signature, purefiPackage]);
            // console.log("Res type 3: \n", (await test.funcWithPureFiContext(purefiData)).data );
            await test.funcWithPureFiContext(purefiData)


        }
        
    });

    it("test PureFiContext withDefaultAddressVerification modifier", async function(){

        {
            const type = 1;
            const sender = signerIdentity.address;
            const ruleId = DEFAULT_AML_RULE;
            const purefiPackage = defaultAbiCoder.encode(["uint8", "uint256", "uint256", "address"], [type, ruleId, sessionId, sender]);
            const message = solidityPack(["uint64", "bytes"], [currentTimestamp, purefiPackage]);
            const hash = keccak256(message);
            const signature = sign(signerIdentity.privateKey, hash);
            const purefiData = defaultAbiCoder.encode(["uint64", "bytes", "bytes"], [ currentTimestamp, signature, purefiPackage ]);

            await test.funcWithDefaultAddressVerification(2, sender, purefiData);
            expect(await test.getCounter()).eq(200);
        }

        {
            const type = 1;
            const sender = signerIdentity.address;
            const ruleId = DEFAULT_KYC_RULE;
            const purefiPackage = defaultAbiCoder.encode(["uint8", "uint256", "uint256", "address"], [type, ruleId, sessionId, sender]);
            const message = solidityPack(["uint64", "bytes"], [currentTimestamp, purefiPackage]);
            const hash = keccak256(message);
            const signature = sign(signerIdentity.privateKey, hash);
            const purefiData = defaultAbiCoder.encode(["uint64", "bytes", "bytes"], [ currentTimestamp, signature, purefiPackage ]);

            await test.funcWithDefaultAddressVerification(1, sender, purefiData);
        }

        {
            const type = 1;
            const sender = signerIdentity.address;
            const ruleId = DEFAULT_AML_KYC_RULE;
            const purefiPackage = defaultAbiCoder.encode(["uint8", "uint256", "uint256", "address"], [type, ruleId, sessionId, sender]);
            const message = solidityPack(["uint64", "bytes"], [currentTimestamp, purefiPackage]);
            const hash = keccak256(message);
            const signature = sign(signerIdentity.privateKey, hash);
            const purefiData = defaultAbiCoder.encode(["uint64", "bytes", "bytes"], [ currentTimestamp, signature, purefiPackage ]);

            await test.funcWithDefaultAddressVerification(3, sender, purefiData);
        }

        
    });
    it("test PureFiContext withCustomAddressVerification modifier", async function(){
        {
            const type = 1;
            const sender = signerIdentity.address;
            const ruleId = 123456;
            const purefiPackage = defaultAbiCoder.encode(["uint8", "uint256", "uint256", "address"], [type, ruleId, sessionId, sender]);
            const message = solidityPack(["uint64", "bytes"], [currentTimestamp, purefiPackage]);
            const hash = keccak256(message);
            const signature = sign(signerIdentity.privateKey, hash);
            const purefiData = defaultAbiCoder.encode(["uint64", "bytes", "bytes"], [ currentTimestamp, signature, purefiPackage ]);

            await test.funcWithCustomAddressVerification(ruleId, sender, purefiData);
            expect(await test.getCounter()).eq(300);
        }
    });
    

});
