require("@nomicfoundation/hardhat-toolbox");
const path = require("path");
require("dotenv").config();
require('@openzeppelin/hardhat-upgrades');

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    compilers: [
      {
        version: "0.8.29",
      },
      {
        version: "0.6.11",
      },
    ],
  },

  paths: {
    sources: "./src", // 🔁 Tell Hardhat to look in `src/` instead of `contracts/`
    artifacts: "./artifacts",
    cache: "./cache"
  },
  resolve: {
    modules: [path.resolve(__dirname, "lib"), "node_modules"]
  },
  networks: {
    hardhat: {
      accounts: {
        count: 20,
        accountsBalance: "150000000000000000000000" // 150,000 ETH
      }
    },

    pushchain: {
      url: "https://evm.pn1.dev.push.org",
      accounts: [process.env.PRIVATE]
      ,
    },
    pushlocalnet: {
      url: "http://127.0.0.1:8545",
      accounts: [process.env.PRIVATE]
      ,
    },

    sepolia: {
      url: `https://sepolia.infura.io/v3/${process.env.INFURA_PROJECT_ID}`,
      accounts: [process.env.PRIVATE]

    }
  },
};
