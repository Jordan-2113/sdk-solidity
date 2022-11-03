import { ethers, upgrades } from "hardhat";
import hre from "hardhat";

const ADMIN = "0x5c8C756c8379d7189F0a773D7459f54F792aE270";

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


}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
