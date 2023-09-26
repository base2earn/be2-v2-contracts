require("@nomiclabs/hardhat-waffle");
// require("@nomicfoundation/hardhat-toolbox");
require("@openzeppelin/hardhat-upgrades");
require("hardhat-contract-sizer");
// require('hardhat-storage-layout');
require("hardhat-tracer");
// require("@nomicfoundation/hardhat-verify");
require("dotenv").config();

const RPCs = {

  // --- BSC
  // 56:       "https://bscrpc.com",
  56:       "https://binance.llamarpc.com",

  // --- Arbitrum
  // 42161:    "https://rpc.ankr.com/arbitrum",
  // 42161:    "https://arb1.arbitrum.io/rpc",
  42161:       "https://arbitrum-one.publicnode.com",

  // --- Fantom
  // 250:      "https://rpc.ankr.com/fantom/",
  250:      "https://fantom.publicnode.com",

  // --- Polygon
  137:      "https://polygon-rpc.com",
  // 137:      "https://polygon.llamarpc.com",
  // 137:      "https://polygon-bor.publicnode.com",

  // --- Base
  // 8453:     "https://base.meowrpc.com",
  8453:     "https://mainnet.base.org",

  // --- Main net
  1:        "https://eth.llamarpc.com",

};

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  contractSizer: {
    runOnCompile: true,
  },
  solidity: {
    settings: {
      optimizer: {
        enabled: true,
        runs: 1000000000,
        details: {
          deduplicate: true,
          cse: true,
          constantOptimizer: true
        }
      },
      viaIR: true,
    },
    version: "0.8.19"
  },
  tracer: {
    nameTags: {
      "0xc373bd9a46df0946dd2b8f52bfc8f4f5bc95c6da": "BRBTokenProxy",
      "0x0A0962164D43C564d9d53a63a836D6B027B183ac": "BRBTokenImpl",
      "0x6467982D997226545f4F3063D33E2A9e46572b05": "BRB-WETH Pair",
      "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266": "Owner",
      "0x70997970C51812dc3A010C7d01b50e0d17dc79C8": "Marketing",
      "0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC": "LPfeeReceiver",
      "0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65": "TreasuryFeeReceiver",
      "0x10ed43c718714eb63d5aa57b78b54704e256024e": "Router",
    },
  },
  mocha: {
    // reporter: 'eth-gas-reporter',
    timeout: 100000000,
  },
  networks: {
    
    hardhat: {
      chainId: 31337,

      // transaction gas limit
      // gas: 0x7a1200,
      gas: "auto",

      // blockGasLimit: 0x7a1200,
      // blockGasLimit: 0x1fffffffffffff,
      blockGasLimit: 0x4000000000000,

      forking: {
        url: RPCs[String(process.env.TARGET_CHAIN)],
      },

      // allow unlimited size only if we don't use the optimiser, we have to do
      // that in order for "hardhat test" to recognise custom errors since it doesn't
      // when the opimiser is used
      allowUnlimitedContractSize: false, //(process.env.OPTIMIZER == true) ? false : true,
      mining: {
        auto: true,
      },
      accounts: {
        mnemonic: "test test test test test test test test test test test junk",
        path: "m/44'/60'/0'/0",
        initialIndex: 0,
        count: 10,
        passphrase: "",
      },
    },

    eth: {
      url: RPCs["1"],
      chainId: 1,
    },

    bsc: {
      // url: "https://bsc-dataseed1.binance.org/",
      // url: "https://bscrpc.com",
      url: RPCs["56"],
      // accounts: [process.env.OWNER_PK],
      chainId: 56,
    },

    polygon: {
      // url: "https://polygon.llamarpc.com",
      url: RPCs["137"],
      // accounts: [process.env.OWNER_PK],
      chainId: 137,
    },

    fantom: {
      // url: "https://rpc.ankr.com/fantom/",
      url: RPCs["250"],
      chainId: 250,
    },

    arbitrum: {
      // url: "https://rpc.ankr.com/arbitrum",
      url: RPCs["42161"],
      chainId: 42161,
    },

    base: {
      // url: "https://base.meowrpc.com",
      url: RPCs["8453"],
      chainId: 8453,
    },
  },
  etherscan: {
    apiKey: {
      polygon:      String(process.env.POLYGON_API_KEY),
      bsc:          String(process.env.BSC_API_KEY),
      arbitrumOne:  String(process.env.ARBI_API_KEY),
      // base:         String(process.env.BASE_API_KEY),
    },
    customChains: [
      {
        network: "base",
        chainId: 8453,
        urls: {
          apiURL:     "https://api.basescan.org/api",
          browserURL: "https://basescan.org"
        }
      }
    ]
  },
};
