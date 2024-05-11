require("@nomicfoundation/hardhat-toolbox");
require('@openzeppelin/hardhat-upgrades');


module.exports = {
  solidity: "0.8.0",
  sourcify: {
    enabled: true
  },
  networks: {
    swisstronik: {
      url: "https://json-rpc.testnet.swisstronik.com/", 
      accounts: [""], 
    },
  },
};