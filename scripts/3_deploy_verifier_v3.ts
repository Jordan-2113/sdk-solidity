import { ethers, upgrades} from "hardhat";
import hre from "hardhat";



const ISSUER_REGISTRY = "0x8bc1862398D2c03A1dBeE2238E97c8fC9FABB7eC";
const WHITELIST = "0xF2292e44f294b406484A05942b6717B07a063A23";


const RULE = 631050090;

async function main(){
    
    const PROXY_ADMIN = await ethers.getContractFactory("PProxyAdmin");
    const PROXY = await ethers.getContractFactory("PPRoxy");
    const VERIFIER = await ethers.getContractFactory("PureFiVerifier");

    const proxy_admin = await PROXY_ADMIN.deploy();
    await proxy_admin.deployed();

    console.log("Proxy admin : ", proxy_admin.address);

    const verifierMasterCopy = await VERIFIER.deploy();
    await verifierMasterCopy.deployed();
    console.log("Verififer master copy : ", verifierMasterCopy.address);

    const verifierProxy = await PROXY.deploy(verifierMasterCopy.address, proxy_admin.address, '0x');
    await verifierProxy.deployed();

    console.log("VerifierV3 address : ", verifierProxy.address);

    
    const verifier = await ethers.getContractAt("PureFiVerifier", verifierProxy.address);
    await verifier.initialize(ISSUER_REGISTRY, WHITELIST);

    // set uint params
    

}


main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
  