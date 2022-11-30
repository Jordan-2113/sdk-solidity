import { ethers, upgrades} from "hardhat";
import hre from "hardhat";



const ISSUER_REGISTRY = "0x9f5346721884ECA7F6A99D87866eb6323493AA33";
const WHITELIST = "0x4C194a586935B8A29adaf37E86A809279536d865";
const PROXY_ADMIN_ADDRESS = "0x3f11558964F51Db1AF18825D0f4F8D7FC8bb6ac7";
// params 

const PARAM_DEFAULT_AML_GRACETIME_KEY = 3;
const DEFAULT_GRACETIME_VALUE = 600;

const DEFAULT_AML_RULE = "431050";
const DEFAULT_KYC_RULE = "777";
const DEFAULT_KYCAML_RULE = "731090";

const PARAM_TYPE1_DEFAULT_AML_RULE = 4;
const PARAM_TYPE1_DEFAULT_KYC_RULE = 5;
const PARAM_TYPE1_DEFAULT_KYCAML_RULE = 6;


async function main(){
    
    const PROXY = await ethers.getContractFactory("PPRoxy");
    const VERIFIER = await ethers.getContractFactory("PureFiVerifier");

    const proxy_admin = await ethers.getContractAt("PProxyAdmin", PROXY_ADMIN_ADDRESS);

    console.log("Proxy admin : ", proxy_admin.address);

    // const verifierMasterCopy = await VERIFIER.deploy();
    // await verifierMasterCopy.deployed();
    // console.log("Verififer master copy : ", verifierMasterCopy.address);

    // const verifierProxy = await PROXY.deploy(verifierMasterCopy.address, proxy_admin.address, '0x');
    // await verifierProxy.deployed();

    // console.log("VerifierV3 address : ", verifierProxy.address);

    // const verifier = await ethers.getContractAt("PureFiVerifier", verifierProxy.address);
    const verifier = await ethers.getContractAt("PureFiVerifier", '0xBa8bFC223Cb1BCDcdd042494FF2C07b167DDC6CA');
    // await verifier.initialize(ISSUER_REGISTRY, WHITELIST);

    // set uint params

    await verifier.setUint256(PARAM_DEFAULT_AML_GRACETIME_KEY, DEFAULT_GRACETIME_VALUE );

    await verifier.setUint256(PARAM_TYPE1_DEFAULT_AML_RULE, DEFAULT_AML_RULE);

    await verifier.setUint256(PARAM_TYPE1_DEFAULT_KYC_RULE, DEFAULT_KYC_RULE);

    await verifier.setUint256(PARAM_TYPE1_DEFAULT_KYCAML_RULE, DEFAULT_KYCAML_RULE);

    console.log("Verifier version: ", (await verifier.version()).toString());
    console.log("completed");
}


main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
  