import { ethers } from "hardhat";
import hre from "hardhat";
import { BigNumber, utils } from "ethers";

const SUBSCRIPTION_SERVICE = "0x139D492Cce168c7B870383dF6b425FC5df447559";
const decimals = BigNumber.from(10).pow(18);

async function main(){

    const sub_service = await ethers.getContractAt("PureFiSubscriptionService", SUBSCRIPTION_SERVICE);

    let yearTS = 86400*365;
    let USDdecimals = decimals;//10^18 // for current contract implementation
    await(await sub_service.setTierData(1,yearTS,BigNumber.from(50).mul(USDdecimals),20,1,5)).wait();
    await(await sub_service.setTierData(2,yearTS,BigNumber.from(100).mul(USDdecimals),20,1,15)).wait();
    await(await sub_service.setTierData(3,yearTS,BigNumber.from(300).mul(USDdecimals),20,1,45)).wait();
    
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });