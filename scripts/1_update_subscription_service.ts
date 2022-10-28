import { ethers, upgrades} from "hardhat";
import hre from "hardhat";


const PROXY_ADMIN = "0x3958341e490B8a8075F6C84de68563f3586840D9";
const SUBSCRIPTION_SERVICE = "0xBbC3Df0Af62b4a469DD44c1bc4e8804268dB1ea3";


async function main(){

    const SubscriptionService = await ethers.getContractFactory("PureFiSubscriptionService");
    const subServiceMasterCopy = await SubscriptionService.deploy();

    await subServiceMasterCopy.deployed();
    console.log("SubscriptionService master copy address : ", subServiceMasterCopy.address);

    const subscriptionContractProxy = await ethers.getContractAt("PureFiSubscriptionService", SUBSCRIPTION_SERVICE);

    console.log("Subscription service current version : ", await subscriptionContractProxy.version());

    const proxyAdmin = await ethers.getContractAt("PProxyAdmin", PROXY_ADMIN);
    
    await proxyAdmin.upgrade(subscriptionContractProxy.address, subServiceMasterCopy.address );

    console.log("Updated SubscriptionService version : ", await subscriptionContractProxy.version());


}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
  