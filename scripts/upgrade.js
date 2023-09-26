const { ethers, upgrades } = require("hardhat");
require("dotenv").config();
const testing = process.env.TESTING == "true";

async function main() {
  let signer;
  if (testing) {
    signer = new ethers.Wallet(process.env.OWNER_PK, ethers.provider);
  } else {
    signer = ethers.provider;
  }

  const instance = await ethers.getContractAt(
    "Test",
    String(process.env.PROXY_ADDRESS),
    new ethers.Wallet(process.env.OWNER_PK, ethers.provider),
  );

  // Upgrading
  const versionTwo = await ethers.getContractFactory("Testv2");
  const upgraded = await upgrades.upgradeProxy(instance.address, versionTwo);

  console.log("Upgraded:", upgraded);
}

main();
