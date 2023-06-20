import { ethers, upgrades} from "hardhat";
import hre from "hardhat";
import { BigNumber, utils } from "ethers";

//BSC
const PROXY_ADMIN = "0x3958341e490B8a8075F6C84de68563f3586840D9";
const SUBSCRIPTION_SERVICE = "0xBbC3Df0Af62b4a469DD44c1bc4e8804268dB1ea3";
//MAINNET
// const PROXY_ADMIN = "0x3f11558964F51Db1AF18825D0f4F8D7FC8bb6ac7";
// const SUBSCRIPTION_SERVICE = "0xbA5B61DFa9c182E202354F66Cb7f8400484d7071";
//POLYGON-Mainnet
// const PROXY_ADMIN = "0xFB46f35941571dD2fce8A5Ea24E0826720aE8dab";
// const SUBSCRIPTION_SERVICE = "0x139D492Cce168c7B870383dF6b425FC5df447559";
//AURORA-MAINNET
// const PROXY_ADMIN = "0xDc347dDC11Fb058b2f19941B1f6c324477015505";
// const SUBSCRIPTION_SERVICE = "";




async function main(){

    const SubscriptionService = await ethers.getContractFactory("PureFiSubscriptionService");
    const subServiceMasterCopy = await SubscriptionService.deploy();

    await subServiceMasterCopy.deployed();
    console.log("SubscriptionService master copy address : ", subServiceMasterCopy.address);

    const subscriptionContractProxy = await ethers.getContractAt("PureFiSubscriptionService", SUBSCRIPTION_SERVICE);

    console.log("Subscription service current version : ", await subscriptionContractProxy.version());

    const proxyAdmin = await ethers.getContractAt("PProxyAdmin", PROXY_ADMIN);
    
    await(await proxyAdmin.upgrade(subscriptionContractProxy.address, subServiceMasterCopy.address )).wait();

    console.log("Updated SubscriptionService version : ", await subscriptionContractProxy.version());

    //add business subscription
     
    // let yearTS = 86400*365;
    // const decimals = BigNumber.from(10).pow(18);
    // let USDdecimals = decimals;//10^18 // for current contract implementation
    // await(await subscriptionContractProxy.setTierData(10,yearTS,BigNumber.from(10000).mul(USDdecimals),0,1000,10000)).wait();
    // console.log("subscription added");

}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
  