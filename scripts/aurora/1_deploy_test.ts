import { ethers, upgrades } from "hardhat";
import hre from "hardhat";
import { BigNumber } from "ethers";

const ADMIN = "0x1e1Baf37B7C89341DEdd688CE74785A703e2e0E3";
const ISSUER = "0xee5FF7E46FB99BdAd874c6aDb4154aaE3C90E698";
async function main() {

    const ISSUER_REGISTRY = await ethers.getContractFactory("PureFiIssuerRegistry");
    const VERIFIER = await ethers.getContractFactory("PureFiVerifier");
    const WHITELIST = await ethers.getContractFactory("PureFiWhitelist");

    const PPROXY_ADMIN = await ethers.getContractFactory("PProxyAdmin");
    const PPROXY = await ethers.getContractFactory("PPRoxy");

    const proxyAdmin = await PPROXY_ADMIN.deploy();
    await proxyAdmin.deployed();

    console.log("Proxy admin : ", proxyAdmin.address);

    let registry;
    {
        const registryMasterCopy = await ISSUER_REGISTRY.deploy();
        await registryMasterCopy.deployed();

        const issuer = await PPROXY.deploy(registryMasterCopy.address, proxyAdmin.address, "0x");
        await issuer.deployed();

        registry = await ethers.getContractAt("PureFiIssuerRegistry", issuer.address);
        console.log("Issuer registry : ", registry.address);
    }

    await registry.initialize(ADMIN);

    let whitelist;
    {
        const whitelistMasterCopy = await WHITELIST.deploy();
        await whitelistMasterCopy.deployed();

        const whitelist_proxy = await PPROXY.deploy(whitelistMasterCopy.address, proxyAdmin.address, "0x");
        await whitelist_proxy.deployed();
        whitelist = await ethers.getContractAt("PureFiWhitelist", whitelist_proxy.address);
        console.log("Whitelist :", whitelist.address);
    }
    await whitelist.initialize(registry.address);

    let verifier;
    {
        const verifierMaster = await VERIFIER.deploy();
        await verifierMaster.deployed();

        const verifier_proxy = await PPROXY.deploy(verifierMaster.address, proxyAdmin.address, "0x");
        await verifier_proxy.deployed();

        verifier = await ethers.getContractAt("PureFiVerifier", verifier_proxy.address);
        console.log("Verififer : ", verifier.address);
    }

    await verifier.initialize(registry.address, whitelist.address);


    // add params

    await verifier.setUint256(BigNumber.from(3), BigNumber.from(300));
    await verifier.setUint256(BigNumber.from(4), BigNumber.from(431040));
    await verifier.setUint256(BigNumber.from(5), BigNumber.from(777));
    await verifier.setUint256(BigNumber.from(6), BigNumber.from(731040));
    await verifier.setString(1, "PureFiVerifier: Issuer signature invalid");
    await verifier.setString(2, "PureFiVerifier: Funds sender doesn't match verified wallet");
    await verifier.setString(3, "PureFiVerifier: Verification data expired");
    await verifier.setString(4, "PureFiVerifier: Rule verification failed");
    await verifier.setString(5, "PureFiVerifier: Credentials time mismatch");
    await verifier.setString(6, "PureFiVerifier: Data package invalid")


    // // add issuer

    console.log("12");
    const tx = await registry.register(
        ISSUER,
        '0x1111111111111111111111111111111111111111111111111111111111111111'
    );
    console.log("hash : ", tx.hash);
}


main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
