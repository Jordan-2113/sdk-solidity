import { ethers } from "hardhat";
import hre from "hardhat";
import { utils } from "ethers";


// params for verifier

const PARAM_DEFAULT_AML_GRACETIME_KEY = 3;
const DEFAULT_GRACETIME_VALUE = 300;

const DEFAULT_AML_RULE = "431050";
const DEFAULT_KYC_RULE = "777";
const DEFAULT_KYCAML_RULE = "731090";

const PARAM_TYPE1_DEFAULT_AML_RULE = 4;
const PARAM_TYPE1_DEFAULT_KYC_RULE = 5;
const PARAM_TYPE1_DEFAULT_KYCAML_RULE = 6;

const PROXY_ADMIN_ADDRESS = "0xFB46f35941571dD2fce8A5Ea24E0826720aE8dab";

// issuer_registry params

const VALID_ISSUER_ADDRESS = "0xee5FF7E46FB99BdAd874c6aDb4154aaE3C90E698";
const PROOF = utils.keccak256(utils.toUtf8Bytes("PureFi Issuer")); 
const ADMIN = "0xcE14bda2d2BceC5247C97B65DBE6e6E570c4Bb6D";  // admin of issuer_registry


// SUBSCRIPTION_SERVICE params

const UFI_TOKEN = "0x3c205C8B3e02421Da82064646788c82f7bd753B9";
const TOKEN_BUYER = "";
const PROFIT_COLLECTION_ADDRESS = "0xcE14bda2d2BceC5247C97B65DBE6e6E570c4Bb6D";


async function main(){

    if ( PROOF.length == 0 || ADMIN.length == 0 ){
        throw new Error('ADMIN or PROOF variable is missed');
    }

    const PPROXY = await ethers.getContractFactory("PPRoxy");
    const PPROXY_ADMIN = await ethers.getContractFactory("PProxyAdmin");

    const WHITELIST = await ethers.getContractFactory("PureFiWhitelist");
    const ISSUER_REGISTRY = await ethers.getContractFactory("PureFiIssuerRegistry");
    const VERIFIER = await ethers.getContractFactory("PureFiVerifier");
    const SUBSCRIPTION_SERVICE = await ethers.getContractFactory("PureFiSubscriptionService");

    // DEPLOY PROXY_ADMIN //
    // ------------------------------------------------------------------- //
    const proxy_admin = await ethers.getContractAt("PProxyAdmin", PROXY_ADMIN_ADDRESS);
    
    console.log("PROXY_ADMIN address : ", proxy_admin.address);

    // DEPLOY ISSUER_REGISTRY //
    // ------------------------------------------------------------------- //
    const issuer_registry_mastercopy = await ISSUER_REGISTRY.deploy();
    await issuer_registry_mastercopy.deployed();

    console.log("ISSUER_REGISTRY_MASTERCOPY address : ", issuer_registry_mastercopy.address);


    const issuer_registry_proxy = await PPROXY.deploy(issuer_registry_mastercopy.address, proxy_admin.address, "0x");
    await issuer_registry_proxy.deployed();

    console.log("issuer_registry address : ", issuer_registry_proxy.address);

    // initialize issuer_registry
    const issuer_registry = await ethers.getContractAt("PureFiIssuerRegistry", issuer_registry_proxy.address);

    await issuer_registry.initialize(ADMIN);

    // set issuer
    await issuer_registry.register(VALID_ISSUER_ADDRESS, PROOF);


    // DEPLOY WHITELIST // 
    // ------------------------------------------------------------------- //

    const whitelist_mastercopy = await WHITELIST.deploy();
    await whitelist_mastercopy.deployed();

    console.log("whitelist_mastercopy address : ", whitelist_mastercopy.address);

    const whitelist_proxy = await PPROXY.deploy(whitelist_mastercopy.address, proxy_admin.address, "0x");
    await whitelist_proxy.deployed();

    console.log("whitelist_proxy address : ", whitelist_proxy.address);

    const whitelist = await ethers.getContractAt("PureFiWhitelist", whitelist_proxy.address);

    // initialize whitelist
    await whitelist.initialize(issuer_registry.address);

    // DEPLOY VERIFIER // 
    // ------------------------------------------------------------------- //

    const verifier_mastercopy = await VERIFIER.deploy();
    await verifier_mastercopy.deployed();

    console.log("verifier_mastercopy address : ", verifier_mastercopy.address);

    const verifier_proxy = await PPROXY.deploy(verifier_mastercopy.address, proxy_admin.address, "0x");
    await verifier_proxy.deployed();

    console.log("verifier_proxy address : ", verifier_proxy.address);
    
    // initialize verifier
    const verifier = await ethers.getContractAt("PureFiVerifier", verifier_proxy.address);
    await verifier.initialize(issuer_registry.address, whitelist.address);

    // set verifier params

    await verifier.setUint256(PARAM_DEFAULT_AML_GRACETIME_KEY, DEFAULT_GRACETIME_VALUE );

    await verifier.setUint256(PARAM_TYPE1_DEFAULT_AML_RULE, DEFAULT_AML_RULE);

    await verifier.setUint256(PARAM_TYPE1_DEFAULT_KYC_RULE, DEFAULT_KYC_RULE);

    await verifier.setUint256(PARAM_TYPE1_DEFAULT_KYCAML_RULE, DEFAULT_KYCAML_RULE);
    
    await verifier.setString(1, "PureFiVerifier: Issuer signature invalid");
    await verifier.setString(2, "PureFiVerifier: Funds sender doesn't match verified wallet");
    await verifier.setString(3, "PureFiVerifier: Verification data expired");
    await verifier.setString(4, "PureFiVerifier: Rule verification failed");
    await verifier.setString(5, "PureFiVerifier: Credentials time mismatch");
    await verifier.setString(6, "PureFiVerifier: Data package invalid")


    // DEPLOY SUBSCRIPTION_SERVICE // 
    // ------------------------------------------------------------------- //

    const sub_service_mastercopy = await SUBSCRIPTION_SERVICE.deploy();
    
    console.log("Subscription master copy : ", sub_service_mastercopy.address);

    const sub_service_proxy = await PPROXY.deploy(sub_service_mastercopy.address, proxy_admin.address, "0x");
    await sub_service_proxy.deployed();

    console.log("Subscription service address : ", sub_service_proxy.address);

    // initialize sub_service 
    const sub_service = await ethers.getContractAt("PureFiSubscriptionService", sub_service_proxy.address);
    await(await sub_service.initialize(
        ADMIN,
        UFI_TOKEN,
        TOKEN_BUYER,
        PROFIT_COLLECTION_ADDRESS
    )).wait();

    let yearTS = 86400*365;
    let USDdecimals = 1000000;//10^6
    await sub_service.setTierData(1,yearTS,50*USDdecimals,20,1,5);
    await sub_service.setTierData(2,yearTS,100*USDdecimals,20,1,15);
    await sub_service.setTierData(3,yearTS,300*USDdecimals,20,1,45);
  

    // pause profitDistribution functionality

    await (await sub_service.pauseProfitDistribution()).wait();

    console.log("isProfitDistibutionPaused : ", await sub_service.isProfitDistributionPaused());

}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
  