const { ethers, upgrades } = require("hardhat");
require("dotenv").config();

const networkNames = {
  56: "bsc",
  1: "mainnet",
  137: "polygon",
  250: "fantom",
  42161: "arbitrum",
  8453: "base",
};

const routers = {
  56: "0x10ED43C718714eb63d5aA57B78B54704E256024E", // bsc
  1: "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D", // eth
  137: "0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff", // poly
  250: "0xF491e7B69E4244ad4002BC14e878a34207E38c29", // ftm
  42161: "0xc873fEcbd354f5A56E00E710B90EF4201db2448d", // arbi
  8453: "0x8c1A3cF8f83074169FE5D7aD50B978e1cD6b37c7", // base
};

async function main() {

  const verify = async (contractAddress, args) => {
    console.log("Verifying contract...");
    try {
      await hre.run("verify:verify", {
        address: contractAddress,
        constructorArguments: args,
        network: networkNames[process.env.TARGET_CHAIN],
      });
    } catch (e) {
      if (e.message.toLowerCase().includes("already verified")) {
        console.log("Already verified!");
      } else {
        console.log(e);
      }
    }
  };

  const contractAddress = "0x9FaF9d874406d51e58e2cD028A79828d8CA7aC22";

  // verify code if not testing
  await verify(contractAddress, [routers[String(process.env.TARGET_CHAIN)]]);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
