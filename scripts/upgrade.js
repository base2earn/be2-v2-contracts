const { ethers, upgrades } = require("hardhat");
require("dotenv").config();
const testing = process.env.TESTING == "true";

async function main() {

  const networkNames = {
    56: "bsc",
    1: "mainnet",
    137: "polygon",
    250: "fantom",
    42161: "arbitrum",
    8453: "base",
    43114: "avalanche",
  };

  const routers = {
    56:     "0x10ED43C718714eb63d5aA57B78B54704E256024E", // bsc
    1:      "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D", // eth
    137:    "0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff", // poly
    250:    "0xF491e7B69E4244ad4002BC14e878a34207E38c29", // ftm
    42161:  "0xc873fEcbd354f5A56E00E710B90EF4201db2448d", // arbi
    8453:   "0x327Df1E6de05895d2ab08513aaDD9313Fe505d86", // baseswap
  };

  const FEE_DATA = {
    maxFeePerGas:         ethers.utils.parseUnits('5', 'gwei'),
    maxPriorityFeePerGas: ethers.utils.parseUnits('5', 'gwei'),
};

  // Wrap the provider so we can override fee data.
  const provider = new ethers.providers.FallbackProvider([ethers.provider], 1);
  provider.getFeeData = async () => FEE_DATA;

  let signer;
  if (!testing) {
    signer = new ethers.Wallet(process.env.OWNER_PK, provider);
  } else {
    signer = ethers.provider;
  }

  // Upgrading
  const versionTwo = await ethers.getContractFactory("BaseReflectionBurn", signer);

  const upgraded = await upgrades.upgradeProxy(
    // proxy address
    "0x1Af8cb7660330F4db7Fa9F62a24830DE226A0f65", 
    versionTwo, 
    {
      unsafeAllow: ["constructor", "state-variable-immutable"],
      constructorArgs: [
        routers[String(process.env.TARGET_CHAIN)]
      ],
      timeout: 0
    });

  console.log("Upgraded:", upgraded);
}

main();
