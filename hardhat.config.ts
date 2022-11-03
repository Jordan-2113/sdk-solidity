  
import "@nomicfoundation/hardhat-toolbox";
import { HardhatUserConfig } from "hardhat/types";
import "@nomicfoundation/hardhat-chai-matchers";
import "@openzeppelin/hardhat-upgrades";
import "hardhat-contract-sizer";
import { infuraApiKey, privateKey, mnemonic, etherscanApiKey, bscnode, privateKeyTest } from "./network_keys/secrets.json";

const Infura = {
  Mainnet: "https://mainnet.infura.io/v3/" + infuraApiKey,
  Ropsten: "https://ropsten.infura.io/v3/" + infuraApiKey,
  Rinkeby: "https://rinkeby.infura.io/v3/" + infuraApiKey,
  Kovan: "https://kovan.infura.io/v3/" + infuraApiKey,
  BSC: "https://bsc-dataseed1.binance.org "
};
const config: HardhatUserConfig = {
  solidity: {
    version : "0.8.12",
    settings : {
      optimizer : {
        enabled : true,
        runs : 200
      }
    }
  },
  networks: {
    hardhat: {
      forking: {
        url: Infura.Mainnet,
        blockNumber: 15646235
      }
    },
    rinkeby: {
      url: Infura.Rinkeby,
      gas: 10000000,
      gasPrice: 10000000000,
      accounts: { mnemonic : mnemonic }
    },
    mainnet : {
      url : Infura.Mainnet,
      gas: "auto",
      gasPrice: "auto",
      minGasPrice: 10000000000,
      accounts : { mnemonic : mnemonic }
    },
    ropsten : {
      url : Infura.Ropsten,
      gas: 5000000,
      gasPrice: 6000000000,
      accounts : { mnemonic : mnemonic }
    },
    kovan : {
      url : Infura.Kovan,
      gas: 10000000,
      accounts : { mnemonic : mnemonic }
    },
    bsc : {
      url : bscnode,
      gas: 5000000,
      gasPrice: 5000000000,
      accounts : { mnemonic : mnemonic }
    },

    bsctest : {
      url : "https://data-seed-prebsc-1-s1.binance.org:8545",
      gas: 5000000,
      gasPrice: 10000000000,
      accounts : { mnemonic : mnemonic }
    },
    auroratest : {
      url : "https://testnet.aurora.dev",
      accounts : [ privateKeyTest ]
    }


  },
  etherscan : {
    apiKey : etherscanApiKey,
  }
  

};
export default config;
