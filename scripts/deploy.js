require("dotenv").config();
const testing = process.env.TESTING == "true";
const { ethers, upgrades } = require("hardhat");
const uniswapABI = require("./UniswapV2RouterABI.json");

async function main() {

  console.log("Testing:", testing);

  // Wrap the provider so we can override fee data.
  let provider = ethers.provider;

  // --- required for polygon rpc gas override
  if (process.env.TARGET_CHAIN == 137) {
    provider = new ethers.providers.FallbackProvider([ethers.provider], 1);
    const FEE_DATA = {
      maxFeePerGas:         ethers.utils.parseUnits("10000", "gwei"),
      maxPriorityFeePerGas: ethers.utils.parseUnits("10000", "gwei"),
    };
    provider.getFeeData = async () => FEE_DATA;
  }

  // Deploying
  let owner, treasury, marketing, lp, buyback;
  if (!testing) {
    owner = new ethers.Wallet(process.env.OWNER_PK, provider);
    console.log("Owner wallet nonce:", await owner.getTransactionCount());
    treasury = process.env.TREASURY_ADDRESS;
    marketing = process.env.MARKETING_ADDRESS;
    lp = process.env.LP_ADDRESS;
    buyback = process.env.BUYBACK_ADDRESS;
  } else {
    [owner, treasury, marketing, lp, buyback, ...otherSigners] = await ethers.getSigners();
    treasury = treasury.address;
    marketing = marketing.address;
    lp = lp.address;
    buyback = buyback.address;
  }

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

  async function gasUsed(tx) {
    let receipt = await tx.wait();
    return ethers.utils.formatEther(receipt.gasUsed.mul(receipt.effectiveGasPrice));
  }

  const liquidityToAddinEther = ethers.utils.parseEther("0.0000000001"); //0.66
  const liquidityToAddInToken = ethers.utils.parseEther("750000000");

  // --- Deployment
  const factory = await ethers.getContractFactory("BaseReflectionBurn");
  let connectedFactory = factory.connect(owner);
  if(process.env.TARGET_CHAIN == 137) {
    connectedFactory = factory.connect(owner);
  }

  console.log("Deploying...")

  const instance = await upgrades.deployProxy(
    connectedFactory,
    [
      marketing,
      lp,
      buyback,
      treasury,
    ], {
      initialize: "initialize",
      redeployImplementation: "onchange",
      unsafeAllow: ["constructor", "state-variable-immutable"],
      constructorArgs: [
        routers[String(process.env.TARGET_CHAIN)]
      ],
      timeout: 0
    }
  );
  let tx = (await instance.deployed()).deployTransaction;
  console.log(" ✓ Deployed at address: ", instance.address, "(Cost: ", await gasUsed(tx), ")");

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

  // verify code if not testing
  if (!testing) {
    await verify(instance.address, [routers[String(process.env.TARGET_CHAIN)]]);
    console.log(" ✓ Successfully verified!");
  }

  console.log("Adding liquidity...");
  tx = await instance.connect(owner).addLiquidity(
    liquidityToAddInToken,  // tokens for liquidity
    {value: liquidityToAddinEther}
  );

  console.log(" ✓ Added liquidity successfully!", "(Cost: ", await gasUsed(tx), ")");
  console.log("Done!");
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
