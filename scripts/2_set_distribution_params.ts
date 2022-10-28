import { ethers, upgrades} from "hardhat";
import hre from "hardhat";


const SUBSCRIPTION_SERVICE = "0xBbC3Df0Af62b4a469DD44c1bc4e8804268dB1ea3";

const DISTRIBUTION_CONTRACT = "0x6C65ffE266C02aC96ab9c455B8b8CfC26f275bF9";
const PART = 20; // % 
const INTERVAL = 60 * 60 * 24 * 7; // 1 week

async function main() {
    
    const subService = await ethers.getContractAt("PureFiSubscriptionService", SUBSCRIPTION_SERVICE);
    const res = await subService.setProfitDistributionParams(
        DISTRIBUTION_CONTRACT,
        PART,
        INTERVAL
    );
    console.log("SetProfitDistributionParams tx hash :", res.hash);

}


main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
  