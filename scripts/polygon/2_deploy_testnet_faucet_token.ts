import { BigNumber } from "ethers";
import { config, ethers } from "hardhat";
import hre from "hardhat";


const decimals = BigNumber.from(10).pow(18);
const SUPPLY = BigNumber.from("100000000").mul(decimals);
const NAME = "TestUFI";
const SYMBOL = "tUFI";


async function main(){

    const ERC20 = await ethers.getContractFactory("TestTokenFaucet");
    const token = await ERC20.deploy(SUPPLY, NAME, SYMBOL);

    console.log("Test UFI address : ", token.address);
}


main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
  