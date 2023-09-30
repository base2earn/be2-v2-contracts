// Import the required libraries
const {
  loadFixture,
  getStorageAt,
  time,
} = require("@nomicfoundation/hardhat-network-helpers");
const { expect } = require("chai");
const { BigNumber } = require("ethers");
const { tracer, ethers, upgrades, storageLayout } = require("hardhat");
const IUniswapV2Router02ABI = require("../scripts/UniswapV2RouterABI.json");

require("dotenv").config();

ETHtoBN = ethers.utils.parseEther;
BNtoETH = ethers.utils.formatEther;
BN = ethers.BigNumber.from;

// TODO
/**
 * - don't I get tons more tokens when I buy? since the pool gives me baseAmount but in my wallet it becomes reflected?
 */

// Use describe to group the tests
describe("Token contract", function () {

  const routers = {
    56:     "0x10ED43C718714eb63d5aA57B78B54704E256024E", // bsc
    1:      "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D", // eth
    137:    "0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff", // poly
    250:    "0xF491e7B69E4244ad4002BC14e878a34207E38c29", // ftm
    42161:  "0xc873fEcbd354f5A56E00E710B90EF4201db2448d", // arbi
    // 8453:   "0x327Df1E6de05895d2ab08513aaDD9313Fe505d86", // baseswap
    8453:   "0xcF77a3Ba9A5CA399B7c97c74d54e5b1Beb874E43", // aerodrome
  };

  // Use beforeEach to deploy a new contract instance before each test
  async function deployFixture() {
    // SingleLinkedListLib = await ethers.getContractFactory("SingleLinkedListLib");
    // singleLinkedListLib = await SingleLinkedListLib.deploy();
    // await singleLinkedListLib.deployed();

    const [
      owner,
      newMarketingFeeReceiver,
      newLPfeeReceiver,
      newBuyBackFeeReceiver,
      newTreasuryFeeReceiver,
      ...otherSigners
    ] = await ethers.getSigners();

    const OmniCogFactory = await ethers.getContractFactory("BaseReflectionBurn", owner);

    const initLiqETH = ethers.utils.parseEther("0.66");

    const omniCogInstance = await upgrades.deployProxy(
      OmniCogFactory, 
      [
        newMarketingFeeReceiver.address,
        newLPfeeReceiver.address,
        newBuyBackFeeReceiver.address,
        newTreasuryFeeReceiver.address,
      ], {
        initialize: "initialize",
        redeployImplementation: "onchange",
        unsafeAllow: ["constructor", "state-variable-immutable"],
        constructorArgs: [
          routers[String(process.env.TARGET_CHAIN)]
        ]
      });
    await omniCogInstance.deployed();

    await omniCogInstance.connect(owner).addLiquidity(
      ETHtoBN("750000000"),  // tokens for liquidity
      {value: initLiqETH}
    );

    // --- build router
    const IUniswapV2Router02 = await ethers.getContractAt(
      IUniswapV2Router02ABI,
      routers[String(process.env.TARGET_CHAIN)],
    );
    const WETH = await ethers.getContractAt(
      ["function balanceOf(address owner) view returns (uint256)"],
      await IUniswapV2Router02.WETH(),
    );

    const factory = await ethers.getContractAt(
      [
        "function getPair(address tokenA, address tokenB) external view returns (address pair)",
      ],
      await IUniswapV2Router02.factory(),
    );
    const tokenList = [
      await IUniswapV2Router02.WETH(),
      omniCogInstance.address,
    ];
    const pairAddress = await factory.getPair(...tokenList);

    // console.log("Pair address", pairAddress);

    async function f(msg) {
      console.log(
        msg +
          ` ### Reflections: ${ethers.utils.formatEther(
            await omniCogInstance.baseToReflectionAmount(
              ethers.utils.parseEther("1"),
              owner.address,
            ),
          )} ### Total reflected: ${BNtoETH(
            await omniCogInstance.totalReflected(),
          )}`,
      );
      console.log(
        "--------------------------------------------------------------------------------------------------------------------------------------------------------",
      );
      await printAddressState("BaseReflectionBurn", omniCogInstance);
      await printAddressState("LP", { address: pairAddress });
      await printReserves(pairAddress);
      await printAddressState("Owner", owner);
      await printAddressState("MarketingFeeReceiver", newMarketingFeeReceiver);
      await printAddressState("LPfeeReceiver", newLPfeeReceiver);
      await printAddressState("BuyBackFeeReceiver", newBuyBackFeeReceiver);
      await printAddressState("TreasuryFeeReceiver", newTreasuryFeeReceiver);
      await printAddressState("User A", otherSigners[0]);
      await printAddressState("User B", otherSigners[1]);
      console.log();

      async function printAddressState(name, s) {
        console.log(
          `${name.padEnd(32)} ${s.address} ${ethers.utils
            .formatEther(await omniCogInstance.balanceOf(s.address))
            .padStart(28)} BRB ${ethers.utils
            .formatEther(await ethers.provider.getBalance(s.address))
            .padStart(28)} ETH ${ethers.utils
            .formatEther(await WETH.balanceOf(s.address))
            .padStart(28)} WETH`,
        );
      }

      async function printReserves(addr) {

        const pairContract = await ethers.getContractAt(
          ["function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast)"],
          addr
        );
        const [res0, res1, t] = await pairContract.getReserves();

        console.log(
          `${"Reserves".padEnd(75)} ${ethers.utils
            .formatEther(res1)
            .padStart(28)} BRB ${" ".padStart(32)} ${ethers.utils
            .formatEther(res0)
            .padStart(28)} WETH`,
        );

      }
    }

    return {
      omniCog: omniCogInstance,
      router: IUniswapV2Router02,
      pairAddress: pairAddress,
      owner: owner,
      marketing: newMarketingFeeReceiver,
      lpReceiver: newLPfeeReceiver,
      buyback: newBuyBackFeeReceiver,
      treasury: newTreasuryFeeReceiver,
      otherSigners: otherSigners,
      printState: f,
    };

    // await storageLayout.export();
  }

  describe.skip("Basics", () => {
    it("Should deploy", async () => {
      const [
        owner,
        newMarketingFeeReceiver,
        newLPfeeReceiver,
        newBuyBackFeeReceiver,
        newTreasuryFeeReceiver,
        ...otherSigners
      ] = await ethers.getSigners();

      const OmniCogFactory = await ethers.getContractFactory("BaseReflectionBurn", owner);

      const omniCogInstance = await upgrades.deployProxy(OmniCogFactory, [
        newMarketingFeeReceiver.address,
        newLPfeeReceiver.address,
        newBuyBackFeeReceiver.address,
        newTreasuryFeeReceiver.address,
      ]);
      await omniCogInstance.deployed();
    });
  });

  describe.skip("Governance", () => {
    let omniCog,
      router,
      pairAddress,
      owner,
      marketing,
      lpReceiver,
      buyback,
      treasury,
      otherSigners,
      printState;

    beforeEach(async () => {
      ({
        omniCog,
        router,
        pairAddress,
        owner,
        marketing,
        lpReceiver,
        buyback,
        treasury,
        otherSigners,
        printState,
      } = await loadFixture(deployFixture));
    });

    describe("clearStuckBalance", () => {
      let amount;
      beforeEach(async () => {
        // transfer ETH to BaseReflectionBurn contract

        const randomSigner = otherSigners[0];
        amount = ethers.utils.parseEther(Math.random().toFixed(18));

        await randomSigner.sendTransaction({
          to: omniCog.address,
          value: amount,
        });
      });

      it("Should clear stuck ETH", async () => {
        await expect(
          omniCog.connect(owner).clearStuckBalance(),
        ).to.changeEtherBalances(
          [owner, omniCog],
          [BigNumber.from(amount), BigNumber.from(amount).mul("-1")],
        );
      });

      it("Should NOT clear stuck ETH (not owner)", async () => {
        const imposterSigner = otherSigners[1];
        await expect(
          omniCog.connect(imposterSigner).clearStuckBalance(),
        ).to.be.revertedWith("Ownable: caller is not the owner");
      });
    });

    describe("clearStuckToken", () => {
      let amount;
      beforeEach(async () => {
        amount = ethers.utils.parseEther(Math.random().toFixed(18));
        await omniCog.connect(owner).transfer(omniCog.address, amount);
      });

      // skipping because not sure if we want to use a different way to transfer BaseReflectionBurn tokens or even generalise the function so can transfer any ERC20 tokens
      describe.skip("owner", () => {
        it("Should clear stuck BaseReflectionBurn token", async () => {
          await expect(
            omniCog.connect(owner).clearStuckToken(),
          ).to.changeTokenBalances(
            omniCog,
            [owner, omniCog],
            [BigNumber.from(amount), BigNumber.from(amount).mul("-1")],
          );
        });
      });

      describe("not owner", () => {
        it("Should NOT clear stuck BaseReflectionBurn token", async () => {
          const imposterSigner = otherSigners[1];
          await expect(
            omniCog.connect(imposterSigner).clearStuckToken(),
          ).to.be.revertedWith("Ownable: caller is not the owner");
        });
      });
    });

    describe("setSwapBackSettings", () => {
      describe("owner", () => {
        describe("_enabled", () => {
          it("Should enable claiming fees", async () => {
            await expect(
              omniCog
                .connect(owner)
                .setSwapBackSettings(
                  1,
                  ethers.utils.parseEther(Math.random().toFixed(18)),
                ),
            ).to.not.be.reverted;

            expect(await omniCog.feesEnabled()).to.be.eql(BigNumber.from(1));
          });

          it("Should disable claiming fees", async () => {
            // enable
            await expect(
              omniCog
                .connect(owner)
                .setSwapBackSettings(
                  1,
                  ethers.utils.parseEther(Math.random().toFixed(18)),
                ),
            ).to.not.be.reverted;

            // disable
            await expect(
              omniCog
                .connect(owner)
                .setSwapBackSettings(
                  0,
                  ethers.utils.parseEther(Math.random().toFixed(18)),
                ),
            ).to.not.be.reverted;

            expect(await omniCog.feesEnabled()).to.be.eql(BigNumber.from(0));
          });
        });

        describe("_amount", () => {
          it("Should set swap threshold", async () => {
            const _amount = ethers.utils.parseEther(Math.random().toFixed(18));

            await expect(
              omniCog
                .connect(owner)
                .setSwapBackSettings((Math.random() * 2).toFixed(0), _amount),
            ).to.not.be.reverted;

            expect(await omniCog.swapThreshold()).to.be.eql(
              BigNumber.from(_amount),
            );
          });
          it("Should increase swap threshold", async () => {
            const _amount = ethers.utils.parseEther(Math.random().toFixed(18));

            await expect(
              omniCog
                .connect(owner)
                .setSwapBackSettings((Math.random() * 2).toFixed(0), _amount),
            ).to.not.be.reverted;

            const currentAmount = await omniCog.swapThreshold();

            const increaseBy = ethers.utils.parseEther(
              Math.random().toFixed(18),
            );
            const newAmount = BigNumber.from(_amount).add(
              BigNumber.from(increaseBy),
            );

            await expect(
              omniCog
                .connect(owner)
                .setSwapBackSettings((Math.random() * 2).toFixed(0), newAmount),
            ).to.not.be.reverted;

            expect(await omniCog.swapThreshold()).to.be.eql(newAmount);

            expect(
              (await omniCog.swapThreshold()).sub(currentAmount),
            ).to.be.eql(increaseBy);
          });
          it("Should decrease swap threshold", async () => {
            const _amount = ethers.utils.parseEther(Math.random().toFixed(18));

            await expect(
              omniCog
                .connect(owner)
                .setSwapBackSettings((Math.random() * 2).toFixed(0), _amount),
            ).to.not.be.reverted;

            const currentAmount = await omniCog.swapThreshold();

            const decreaseBy = BigNumber.from(_amount).div(
              (Math.random() * 10 + 1).toFixed(0),
            );

            const newAmount = BigNumber.from(_amount).sub(
              BigNumber.from(decreaseBy),
            );

            await expect(
              omniCog
                .connect(owner)
                .setSwapBackSettings((Math.random() * 2).toFixed(0), newAmount),
            ).to.not.be.reverted;

            expect(await omniCog.swapThreshold()).to.be.eql(newAmount);

            expect(currentAmount.sub(await omniCog.swapThreshold())).to.be.eql(
              decreaseBy,
            );
          });
        });
      });

      describe("NOT owner", () => {
        it("Should NOT be able to call function", async () => {
          const imposterSigner = otherSigners[1];
          await expect(
            omniCog
              .connect(imposterSigner)
              .setSwapBackSettings(
                (Math.random() * 2).toFixed(0),
                ethers.utils.parseEther(Math.random().toFixed(18)),
              ),
          ).to.be.revertedWith("Ownable: caller is not the owner");
        });
      });
    });

    describe("changeFees", () => {
      describe("owner", () => {
        describe("fees <= MAX_FEE", () => {
          let buyFeeList = [],
            buyFeeTotal,
            sellFeeList = [],
            sellFeeTotal;
          before(() => {
            for (let i = 0; i < 8; i++) {
              buyFeeList.push(Math.random() * 2 ** 8);
              sellFeeList.push(Math.random() * 2 ** 8);
            }

            buyFeeTotal = buyFeeList.reduce((a, b) => +a + +b);
            sellFeeTotal = sellFeeList.reduce((a, b) => +a + +b);

            const buyScalingFactor = Math.random();
            buyFeeList = buyFeeList.map((e) =>
              ((e / buyFeeTotal) * 2 ** 8 * buyScalingFactor).toFixed(0),
            );

            const sellScalingFactor = Math.random();
            sellFeeList = sellFeeList.map((e) =>
              ((e / sellFeeTotal) * 2 ** 8 * sellScalingFactor).toFixed(0),
            );

            buyFeeTotal = buyFeeList.reduce((a, b) => +a + +b).toString();
            sellFeeTotal = sellFeeList.reduce((a, b) => +a + +b).toString();

            buyFeeList.push(buyFeeTotal);
            sellFeeList.push(sellFeeTotal);
          });

          it("Should correctly assign buy and sell fees", async () => {
            await expect(omniCog.changeFees(buyFeeList, sellFeeList)).to.not.be
              .reverted;

            expect(
              (await omniCog.buyFee()).map((e) => BigNumber.from(e)),
            ).to.be.eql([...buyFeeList.map((e) => BigNumber.from(e))]);

            expect(
              (await omniCog.sellFee()).map((e) => BigNumber.from(e)),
            ).to.be.eql([...sellFeeList.map((e) => BigNumber.from(e))]);
          });
        });

        describe("fees > MAX_FEE", () => {
          it("Should revert since total is greater than MAX_FEE", async () => {
            let buyFeeList = [],
              sellFeeList = [];
            for (let i = 0; i < 8; i++) {
              buyFeeList.push((Math.random() * 2 ** 8).toFixed(0));
              sellFeeList.push((Math.random() * 2 ** 8).toFixed(0));
            }

            const buyFeeTotal = buyFeeList.reduce((a, b) => +a + +b).toString();
            const sellFeeTotal = sellFeeList
              .reduce((a, b) => +a + +b)
              .toString();

            buyFeeList.push(buyFeeTotal);
            sellFeeList.push(sellFeeTotal);

            await expect(
              omniCog.connect(owner).changeFees(buyFeeList, sellFeeList),
            ).to.not.be.reverted;
          });
        });
      });

      describe("NOT owner", () => {
        it("Should NOT be able to call function", async () => {
          const imposterSigner = otherSigners[1];

          let buyFeeList = [],
            sellFeeList = [];
          for (let i = 0; i < 8; i++) {
            buyFeeList.push((Math.random() * 2 ** 8).toFixed(0));
            sellFeeList.push((Math.random() * 2 ** 8).toFixed(0));
          }

          const buyFeeTotal = buyFeeList.reduce((a, b) => +a + +b).toString();
          const sellFeeTotal = sellFeeList.reduce((a, b) => +a + +b).toString();

          buyFeeList.push(buyFeeTotal);
          sellFeeList.push(sellFeeTotal);

          await expect(
            omniCog.connect(imposterSigner).changeFees(buyFeeList, sellFeeList),
          ).to.be.revertedWith("Ownable: caller is not the owner");
        });
      });
    });

    describe("setFeeReceivers", () => {
      describe("owner", () => {
        it("Should set correct fee receivers", async () => {
          await expect(
            omniCog
              .connect(owner)
              .setFeeReceivers(
                marketing.address,
                lpReceiver.address,
                buyback.address,
                treasury.address,
              ),
          ).to.not.be.reverted;

          /* expects for when those receivers are exposed publicly */
          // expect(await omniCog.marketingFeeReceiver()).to.be.eql(
          //   marketing.address
          // );
          // expect(await omniCog.lpFeeReceiver()).to.be.eql(lpReceiver.address);
          // expect(await omniCog.buybackFeeReceiver()).to.be.eql(buyback.address);
          // expect(await omniCog.treasuryReceiver()).to.be.eql(treasury.address);
        });
      });

      describe("NOT owner", () => {
        it("Should NOT be able to call function", async () => {
          const imposterSigner = otherSigners[1];
          await expect(
            omniCog
              .connect(imposterSigner)
              .setFeeReceivers(
                imposterSigner.address,
                imposterSigner.address,
                imposterSigner.address,
                imposterSigner.address,
              ),
          ).to.be.revertedWith("Ownable: caller is not the owner");
        });
      });
    });

    describe.skip("setTrustedRemoteWithInfo", () => {
      describe("owner", () => {});

      describe("NOT owner", () => {
        it("Should NOT be able to call function", async () => {
          const imposterSigner = otherSigners[1];
          await expect(omniCog.connect(imposterSigner)).to.be.revertedWith(
            "Ownable: caller is not the owner",
          );
        });
      });
    });

    describe.skip("setRegistredPool", () => {
      describe("owner", () => {});

      describe("NOT owner", () => {
        it("Should NOT be able to call function", async () => {
          const imposterSigner = otherSigners[1];
          await expect(omniCog.connect(imposterSigner)).to.be.revertedWith(
            "Ownable: caller is not the owner",
          );
        });
      });
    });

    describe.skip("removeChain", () => {
      describe("owner", () => {});

      describe("NOT owner", () => {
        it("Should NOT be able to call function", async () => {
          const imposterSigner = otherSigners[1];
          await expect(omniCog.connect(imposterSigner)).to.be.revertedWith(
            "Ownable: caller is not the owner",
          );
        });
      });
    });
  });

  describe.only("Swaps", () => {

    it("Should reflect the correct amount on transfers (with change of LP)", async () => {

      const { owner, router, omniCog, pairAddress, otherSigners, printState } = await deployFixture();
      const [userA, userB, userC, ...remainingSigners] = otherSigners;
      const amountToTransfer = ethers.utils.parseEther("1");
      const weth = await router.WETH();
      
      // no launch fee
      await network.provider.send("evm_increaseTime", [7_000_000]);
      await network.provider.send("evm_mine");

      await printState("Pre everything");

      /**
       * - input amount - 6% fees and then reflected ...
       * - post reflection amount can differ depending on whether contract's
       *   BaseReflectionBurn balance has been swapped in the tx and thus the LP balance changed;
       *   to circumvent this, set swapThreshold to uint.max and write a separate
       *   test WITH a guarateed swap elsewhere
       */
      // to guarantee that no swapBack is performed
      await omniCog
        .connect(owner)
        .setSwapBackSettings(0, ethers.constants.MaxUint256);

      // # Transfer some tokens to reference account to check reflection maths
      await omniCog.connect(owner).transfer(userA.address, amountToTransfer);

      // reenable fees
      await omniCog
        .connect(owner)
        .setSwapBackSettings(1, ethers.constants.MaxUint256);

      await printState("Post frist transfer")

      // # Record states pre swap

      // ## total reflected amount so far
      const pre_totalReflected = await omniCog.totalReflected();
      const pre_totalSubLPBalance = await omniCog.totalSubLPBalance();
      // ## owner balance
      const pre_ownerBalance = await omniCog.balanceOf(owner.address);
      // ## contract balance
      const pre_contractBalance = await omniCog.balanceOf(omniCog.address);
      // ## pool balance
      const pre_poolBalance = await omniCog.balanceOf(pairAddress);
      // ## userA balance
      const pre_userABalance = await omniCog.balanceOf(userA.address);

      await printState("Post transfer");

      // # Perform swap
      await expect(
        router
          .connect(owner)
          .swapExactETHForTokensSupportingFeeOnTransferTokens(
            // amountOutMin
            0,
            //path
            [weth, omniCog.address],
            //to
            userB.address,
            //deadline
            1689510989000,
            {
              value: amountToTransfer,
            },
          ),
      ).to.not.be.reverted;

      await printState("Post swap");

      // # Check post conditions

      // ## total sub LP balance should have changed
      const post_poolBalance = await omniCog.balanceOf(pairAddress);
      const should_totalSubLPBalance = (await omniCog.totalSupply()).sub(post_poolBalance);
      const is_totalSubLPBalance = await omniCog.totalSubLPBalance();

      expect(
        is_totalSubLPBalance, 
        "total sub LP balance"
      ).to.be.closeTo(
        should_totalSubLPBalance,
        ETHtoBN("0.000001"),
      );

      // ## total reflected amount should have changed
      const post_totalReflected = await omniCog.totalReflected();
      const expectedReflectionAmount = pre_poolBalance
        .sub(post_poolBalance)
        .div(100);
      const should_totalReflected = pre_totalReflected.add(
        expectedReflectionAmount
      );

      expect(
        post_totalReflected, 
        "total reflected"
      ).to.be.closeTo(
        should_totalReflected,
        ETHtoBN("0.0000001")
      );

      // ### user should have received correct reflections from transaction
      // const should_userABalance = pre_userABalance
      //   .mul(pre_totalSubLPBalance)
      //   .div(
      //     pre_totalSubLPBalance.sub(
      //       pre_totalReflected.add(expectedReflectionAmount),
      //     ),
      //   );
      
      const rgf = BN(100); // await omniCog.REFLECTION_GROWTH_FACTOR();
      // 2 * baseAmount - ( baseAmount * local_totalSubLPBalance / (REFLECTION_GROWTH_FACTOR * totalReflected + local_totalSubLPBalance))
      const should_userABalance =
        BN(2)
          .mul(pre_userABalance)
          .sub(
            pre_userABalance
              .mul(is_totalSubLPBalance)
              .div(
                rgf
                  .mul(post_totalReflected)
                  .add(is_totalSubLPBalance)
              )
          );
        
      const is_userABalance = await omniCog.balanceOf(userA.address);

      expect(
        is_userABalance,
        "Users should receive the correct amount of reflections",
      ).to.be.closeTo(
        should_userABalance, 
        ETHtoBN("0.0001")
      );

    });

    it("Should sell", async () => {
      const { owner, router, omniCog, pairAddress, printState, otherSigners } =
        await deployFixture();
      const [userA, userB, userC, ...remainingSigners] = otherSigners;
      const weth_address = await router.WETH();
      const WETH = await ethers.getContractAt(
        ["function balanceOf(address) view returns(uint256)"],
        weth_address,
      );
      const amountToTransfer = ETHtoBN("1000");

      await printState("Pre everything");

      await expect(
        omniCog.approve(router.address, amountToTransfer)
      ).to.not.be.reverted;

      await network.provider.send("evm_increaseTime", [7_000_000]);
      await network.provider.send("evm_mine");

      /**
       * - input amount - 6% fees and then reflected ...
       * - post reflection amount can differ depending on whether contract's
       *   BaseReflectionBurn balance has been swapped in the tx and thus the LP balance changed;
       *   to circumvent this, set swapThreshold to uint.max and write a separate
       *   test WITH a guarateed swap elsewhere
       */
      // to guarantee that no swapBack is performed
      await omniCog
        .connect(owner)
        .setSwapBackSettings(0, ethers.constants.MaxUint256);

      // # Transfer some tokens to reference account to check reflection maths
      await omniCog.connect(owner).transfer(userA.address, amountToTransfer);

      // # enable fees again
      await omniCog
        .connect(owner)
        .setSwapBackSettings(1, ethers.constants.MaxUint256);

      // ## total reflected amount so far
      const pre_totalReflected = await omniCog.totalReflected();
      const pre_totalSubLPBalance = await omniCog.totalSubLPBalance();
      // ## owner balance
      const pre_ownerBalance = await omniCog.balanceOf(owner.address);
      // ## owner ETH balance
      const pre_ownerETHBalance = await ethers.provider.getBalance(owner.address);
      // ## contract balance
      const pre_contractBalance = await omniCog.balanceOf(omniCog.address);
      // ## pool balance
      const pre_poolBalance = await omniCog.balanceOf(pairAddress);
      // ## userA balance
      const pre_userABalance = await omniCog.balanceOf(userA.address);

      await printState("Pre swap");

      // console.log(
      //   "\n   Total supply",
      //   BNtoETH(await omniCog.totalSupply()),
      //   "\n    LP balance ",
      //   BNtoETH(await omniCog.balanceOf(pairAddress)),
      //   "\n   Total - LP  ",
      //   BNtoETH(await omniCog.totalSubLPBalance()),
      //   "\nTotal - LP + LP",
      //   BNtoETH((await omniCog.totalSubLPBalance()).add(await omniCog.balanceOf(pairAddress)))
      // )

      // # Perform sell
      await expect(
        router
          .connect(owner)
          .swapExactTokensForTokensSupportingFeeOnTransferTokens(
            // amountin
            amountToTransfer,
            // outmin
            0,
            //path
            [omniCog.address, weth_address],
            //to
            owner.address,
            //deadline
            5689510989000,
          ),
      ).to.not.be.reverted;

      // console.log(
      //   "\n   Total supply",
      //   BNtoETH(await omniCog.totalSupply()),
      //   "\n    LP balance ",
      //   BNtoETH(await omniCog.balanceOf(pairAddress)),
      //   "\n   Total - LP  ",
      //   BNtoETH(await omniCog.totalSubLPBalance()),
      //   "\nTotal - LP + LP",
      //   BNtoETH((await omniCog.totalSubLPBalance()).add(await omniCog.balanceOf(pairAddress)))
      // )

      await printState("Post swap");

      const post_ownerETHBalance = (
        await ethers.provider.getBalance(owner.address)
      ).add(await WETH.balanceOf(owner.address));

      expect(
        post_ownerETHBalance.gt(pre_ownerETHBalance),
        "owner (W)ETH balance should have increased",
      ).to.be.true;

      // # Check post conditions

      // ...LP balance should have increased by equivalent baseAmount(94% of transferred amount)
      // fees hardcoded
      const transferredBaseAmount = amountToTransfer
        .mul(pre_totalSubLPBalance.sub(pre_totalReflected))
        .div(pre_totalSubLPBalance)
        .mul(9_400)
        .div(10_000);
      const should_postPoolBalance = pre_poolBalance.add(transferredBaseAmount);
      const post_poolBalance = await omniCog.balanceOf(pairAddress);

      expect(post_poolBalance, "post pool balance").to.be.closeTo(
        should_postPoolBalance,
        ETHtoBN("0.000001"),
      );

      // ## total sub LP balance should have changed
      const should_totalSubLPBalance = pre_totalSubLPBalance.sub(
        transferredBaseAmount,
      );
      const is_totalSubLPBalance = await omniCog.totalSubLPBalance();

      expect(is_totalSubLPBalance, "total sub LP balance").to.be.closeTo(
        should_totalSubLPBalance,
        ETHtoBN("0.000001"),
      );

      // ## total reflected amount should have changed
      const post_totalReflected = await omniCog.totalReflected();
      // const expectedReflectionAmount = amountToTransfer.div(100);
      const expectedReflectionAmount = amountToTransfer
        .mul(pre_totalSubLPBalance.sub(pre_totalReflected))
        .div(pre_totalSubLPBalance)
        .div(100);
      const should_totalReflected = pre_totalReflected.add(
        expectedReflectionAmount,
      );

      expect(
        post_totalReflected, 
        "total reflected"
      ).to.be.closeTo(
        should_totalReflected,
        ETHtoBN("0.0000001"),
      );

      // ## received correct amount of BaseReflectionBurn
      const rgf = BN(100); // await omniCog.REFLECTION_GROWTH_FACTOR();
      // 2 * baseAmount - ( baseAmount * local_totalSubLPBalance / (REFLECTION_GROWTH_FACTOR * totalReflected + local_totalSubLPBalance))
      const should_userABalance =
        BN(2)
          .mul(pre_userABalance)
          .sub(
            pre_userABalance
              .mul(is_totalSubLPBalance)
              .div(
                rgf
                  .mul(post_totalReflected)
                  .add(is_totalSubLPBalance)
              )
          );
      const is_userABalance = await omniCog.balanceOf(userA.address);

      expect(
        is_userABalance,
        "Users should receive the correct amount of reflections",
      ).to.be.closeTo(
        should_userABalance, 
        ETHtoBN("0.0000001")
      );

    });

    it("Should allow consecutive swaps (k stays intact)", async () => {
      const { owner, router, omniCog, pairAddress, otherSigners, printState } =
        await deployFixture();
      const [userA, userB, userC, ...remainingSigners] = otherSigners;
      const weth = await router.WETH();
      const amountToTransfer = ethers.utils.parseEther("100");

      /**
       * - input amount - 6% fees and then reflected ...
       * - post reflection amount can differ depending on whether contract's
       *   BaseReflectionBurn balance has been swapped in the tx and thus the LP balance changed;
       *   to circumvent this, set swapThreshold to uint.max and write a separate
       *   test WITH a guarateed swap elsewhere
       */
      // to guarantee that no swapBack is performed
      await omniCog
        .connect(owner)
        .setSwapBackSettings(1, ethers.constants.MaxUint256);

      await network.provider.send("evm_increaseTime", [7_000_000]);
      await network.provider.send("evm_mine");

      // # Transfer some tokens to reference account to check reflection maths
      await omniCog.connect(owner).transfer(userA.address, amountToTransfer);

      // # Record states pre swap

      // ## total reflected amount so far
      const pre_totalReflected = await omniCog.totalReflected();
      const totalSubLPBalance = await omniCog.totalSubLPBalance();
      // ## owner balance
      const pre_ownerBalance = await omniCog.balanceOf(owner.address);
      // ## contract balance
      const pre_contractBalance = await omniCog.balanceOf(omniCog.address);
      // ## pool balance
      const pre_poolBalance = await omniCog.balanceOf(pairAddress);
      // ## userA balance
      const pre_userABalance = await omniCog.balanceOf(userA.address);

      // await printState("Pre first swap")

      // # Perform buy
      await expect(
        router
          .connect(owner)
          .swapExactETHForTokensSupportingFeeOnTransferTokens(
            // amountOutMin
            0,
            //path
            [weth, omniCog.address],
            //to
            owner.address,
            //deadline
            1689510989000,
            {
              value: amountToTransfer,
            },
          ),
        "first swap",
      ).to.not.be.reverted;

      // await printState("Post first swap")

      // # Buy again
      await expect(
        router
          .connect(owner)
          .swapExactETHForTokensSupportingFeeOnTransferTokens(
            // amountOutMin
            0,
            //path
            [weth, omniCog.address],
            //to
            owner.address,
            //deadline
            1689510989000,
            {
              value: amountToTransfer,
            },
          ),
        "second swap",
      ).to.not.be.reverted;

      // # Perform sell
      await expect(
        omniCog.connect(owner).approve(router.address, amountToTransfer),
      ).to.not.be.reverted;
      
      await expect(
        router
          .connect(owner)
          .swapExactTokensForTokensSupportingFeeOnTransferTokens(
            // amountin
            amountToTransfer,
            // outmin
            0,
            //path
            [omniCog.address, weth],
            //to
            owner.address,
            //deadline
            5689510989000,
          ),
      ).to.not.be.reverted;

    });

    // done
    it("Should swap fees when threshold reached", async () => {
      const { owner, router, omniCog, pairAddress, otherSigners, printState } =
        await deployFixture();
      const [userA, userB, userC, ...remainingSigners] = otherSigners;
      const weth = await router.WETH();
      const amountToTransfer = ethers.utils.parseEther("107"); // 1 / 0.94

      await network.provider.send("evm_increaseTime", [7_000_000]);
      await network.provider.send("evm_mine");

      await printState("Pre everything");

      // to guarantee that no swapBack is performed on transfer of reference tokens
      await omniCog
        .connect(owner)
        .setSwapBackSettings(0, ethers.constants.MaxUint256);

      // # Transfer some tokens to reference account to check reflection maths
      await omniCog.connect(owner).transfer(userA.address, amountToTransfer);

      // # to trigger swapback on transfer
      await omniCog.connect(owner).setSwapBackSettings(1, ETHtoBN("10"));

      await printState("Post ref transfers")

      // # Record states pre swap

      // ## total reflected amount so far
      const pre_totalReflected = await omniCog.totalReflected();
      const pre_totalSubLPBalance = await omniCog.totalSubLPBalance();
      // ## owner balance
      const pre_ownerBalance = await omniCog.balanceOf(owner.address);
      // ## contract balance
      const pre_contractBalance = await omniCog.balanceOf(omniCog.address);
      // ## pool balance
      const pre_poolBalance = await omniCog.balanceOf(pairAddress);
      // ## userA balance
      const pre_userABalance = await omniCog.balanceOf(userA.address);

      // # Trigger transfers to userB (act as sells)

      // ## First transfer to fill contract with BaseReflectionBurn
      await omniCog.connect(owner).transfer(userB.address, amountToTransfer);
      // ## Second transfer should now trigger fee swap
      await omniCog.connect(owner).transfer(userB.address, amountToTransfer);

      await printState("Post swap");

      // # Check post conditions

      // TODO
    });

    // done
    it("Should reflect the correct amount on transfers (w/o change of LP)", async () => {

      const { owner, router, omniCog, pairAddress, otherSigners } = await deployFixture();
      const [userA, userB, userC, ...remainingSigners] = otherSigners;
      const amountToTransfer = ethers.utils.parseEther("1000");

      // pre reflection state
      const totalSubLPBalance = await omniCog.totalSubLPBalance();
      const pre_totalReflected = await omniCog.totalReflected();
      const pre_userABalance = await omniCog.balanceOf(userA.address);

      // to guarantee that no swapBack is performed right now (would distort LP balance)
      await omniCog
        .connect(owner)
        .setSwapBackSettings(1, ethers.constants.MaxUint256);

      // transfer some amount to non-owner account
      await omniCog.connect(owner).transfer(userA.address, amountToTransfer);

      // userA should now have 94% of transferred amount + reflection
      const receivedAmount = amountToTransfer.mul(9_400).div(10_000);
      // 1% reflection will be added to total reflected
      const expectedReflectionAmount = amountToTransfer.div(100);

      // baseAmount * local_totalSubLPBalance / (local_totalSubLPBalance - totalReflected);
      const post_totalReflected = await omniCog.totalReflected();
      const should_postTotalRefleted = pre_totalReflected.add(expectedReflectionAmount);

      console.log(`
      post_totalReflected         ${BNtoETH(post_totalReflected)}
      should_postTotalRefleted    ${BNtoETH(should_postTotalRefleted)}
      `)

      expect(
        post_totalReflected,
        "reflection amount is 1% of transferred value",
      ).to.be.closeTo(
        should_postTotalRefleted,
        ETHtoBN("0.0000001")
      );
      const is_totalSubLPBalance = await omniCog.totalSubLPBalance();

      // ## received correct amount of BaseReflectionBurn
      const rgf = BN(100); // await omniCog.REFLECTION_GROWTH_FACTOR();
      // 2 * baseAmount - ( baseAmount * local_totalSubLPBalance / (REFLECTION_GROWTH_FACTOR * totalReflected + local_totalSubLPBalance))
      const should_userABalance =
        BN(2)
          .mul(receivedAmount)
          .sub(
            receivedAmount
              .mul(is_totalSubLPBalance)
              .div(
                rgf
                  .mul(post_totalReflected)
                  .add(is_totalSubLPBalance)
              )
          );
      const is_userABalance = await omniCog.balanceOf(userA.address);

      console.log(`
      pre userA bal           ${BNtoETH(pre_userABalance)}
      is_totalSubLPBalance    ${BNtoETH(is_totalSubLPBalance)}
      post_totalReflected     ${BNtoETH(post_totalReflected)}
      `)

      expect(
        is_userABalance,
        "Recipient balance has the correct reflection received",
      ).to.be.closeTo(
        should_userABalance, 
        ETHtoBN("0.0000001"));
    });

    it("Should sell despite launch fee", async () => {

      const { owner, router, omniCog, pairAddress, otherSigners, printState } = await deployFixture();
      const [userA, userB, userC, ...remainingSigners] = otherSigners;
      const weth = await router.WETH();
      const amountToTransfer = ethers.utils.parseEther("100");

      // await printState("Pre everything");

      /**
       * - input amount - 6% fees and then reflected ...
       * - post reflection amount can differ depending on whether contract's
       *   BaseReflectionBurn balance has been swapped in the tx and thus the LP balance changed;
       *   to circumvent this, set swapThreshold to uint.max and write a separate
       *   test WITH a guarateed swap elsewhere
       */
      // to guarantee that no swapBack is performed
      await omniCog
        .connect(owner)
        .setSwapBackSettings(0, ethers.constants.MaxUint256);

      // # Transfer some tokens to reference account to check reflection maths
      await omniCog.connect(owner).transfer(userA.address, amountToTransfer);

      // to guarantee that no swapBack is performed
      await omniCog
        .connect(owner)
        .setSwapBackSettings(1, ethers.constants.MaxUint256);

      // await printState("Pre sell");

      // # Record states pre swap

      // ## total reflected amount so far
      const pre_totalReflected = await omniCog.totalReflected();
      const pre_totalSubLPBalance = await omniCog.totalSubLPBalance();
      // ## owner balance
      const pre_ownerBalance = await omniCog.balanceOf(owner.address);
      // ## contract balance
      const pre_contractBalance = await omniCog.balanceOf(omniCog.address);
      // ## pool balance
      const pre_poolBalance = await omniCog.balanceOf(pairAddress);
      // ## userA balance
      const pre_userABalance = await omniCog.balanceOf(userA.address);

      // # Perform sell
      await omniCog.connect(owner).approve(router.address, amountToTransfer);
      await expect(
        router
          .connect(owner)
          .swapExactTokensForTokensSupportingFeeOnTransferTokens(
            // amountIn
            amountToTransfer,
            // amountOutMin
            0,
            //path
            [omniCog.address, weth],
            //to
            owner.address,
            //deadline
            1689510989000,
          ),
      ).to.not.be.reverted;

      // await printState("Post sell");

      // # Check post conditions

      // ## total sub LP balance should have changed
      const post_poolBalance = await omniCog.balanceOf(pairAddress);
      const should_totalSubLPBalance = (await omniCog.totalSupply()).sub(post_poolBalance);
      const is_totalSubLPBalance = await omniCog.totalSubLPBalance();

      expect(
        is_totalSubLPBalance, 
        "total sub LP balance"
      ).to.be.closeTo(
        should_totalSubLPBalance,
        ETHtoBN("0.000001")
      );

      // ## total reflected amount should have changed
      const post_totalReflected = await omniCog.totalReflected();
      const expectedReflectionAmount = amountToTransfer.div(100);
      const should_totalReflected = pre_totalReflected.add(expectedReflectionAmount);

      expect(
        post_totalReflected, 
        "total reflected"
      ).to.be.closeTo(
        should_totalReflected,
        ETHtoBN("0.0000001"),
      );

      // ## users received correct amount of BaseReflectionBurn reflections

      // ## received correct amount of BaseReflectionBurn
      const rgf = BN(100); // await omniCog.REFLECTION_GROWTH_FACTOR();
      // 2 * baseAmount - ( baseAmount * local_totalSubLPBalance / (REFLECTION_GROWTH_FACTOR * totalReflected + local_totalSubLPBalance))
      const should_userABalance =
        BN(2)
          .mul(pre_userABalance)
          .sub(
            pre_userABalance
              .mul(is_totalSubLPBalance)
              .div(
                rgf
                  .mul(post_totalReflected)
                  .add(is_totalSubLPBalance)
              )
          );
      const is_userABalance = await omniCog.balanceOf(userA.address);

      expect(
        should_userABalance,
        "Users should receive the correct amount of reflections",
      ).to.be.closeTo(
        is_userABalance, 
        ETHtoBN("0.0000001")
      );

    });

    it.only("Should enforce tx & wallet limits", async () => {

      const { owner, router, omniCog, pairAddress, otherSigners, printState } = await deployFixture();
      const [userA, userB, userC, ...remainingSigners] = otherSigners;
      const weth = await router.WETH();

      // is the correct amount burned from user balance?
      // does the contract balance decrease?
      // does the user get paid out the correct amount?

      await network.provider.send("evm_increaseTime", [7_000_000]);
      await network.provider.send("evm_mine");
      
      const maxWallet = await omniCog.baseToReflectionAmount(await omniCog.MAX_TX(), userA.address);
      console.log("hey")
      let getmaxBuy = async () => (await router.getAmountsIn(maxWallet, [weth, omniCog.address]))[0];
      console.log("ho")

      // # Buy below limit
      await expect(
        router
          .connect(userA)
          .swapExactETHForTokensSupportingFeeOnTransferTokens(
            // amountOutMin
            0,
            //path
            [weth, omniCog.address],
            //to
            userA.address,
            //deadline
            1689510989000,
            {
              value: await getmaxBuy(),
            },
          ),
        "Buy below limit",
      ).to.not.be.reverted;
      await printState("Post buy below limit")

      // # Buy below limit again
      await expect(
        router
          .connect(userA)
          .swapExactETHForTokensSupportingFeeOnTransferTokens(
            // amountOutMin
            0,
            //path
            [weth, omniCog.address],
            //to
            userA.address,
            //deadline
            1689510989000,
            {
              value: await getmaxBuy(),
            },
          ),
        "Buy below limit",
      ).to.not.be.reverted;
      await printState("Post buy below limit 2")

      // # Buy to hit wallet limit restriction
      await expect(
        router
          .connect(userA)
          .swapExactETHForTokensSupportingFeeOnTransferTokens(
            // amountOutMin
            0,
            //path
            [weth, omniCog.address],
            //to
            userA.address,
            //deadline
            1689510989000,
            {
              value: await getmaxBuy(),
            },
          ),
        "Buy above limit",
      ).to.be.revertedWith("Pancake: TRANSFER_FAILED");
      await printState("Post buy above walelt limit")
      
      const postBuyBalance = await omniCog.balanceOf(userA.address);
      
      // # Approve
      await expect(
        omniCog.connect(userA).approve(router.address, postBuyBalance),
      ).to.not.be.reverted;

      // # Sell too much
      await expect(
        router
          .connect(userA)
          .swapExactTokensForTokensSupportingFeeOnTransferTokens(
            // amountin
            postBuyBalance,
            // outmin
            0,
            //path
            [omniCog.address, weth],
            //to
            userA.address,
            //deadline
            5689510989000,
          ),
      ).to.be.revertedWith("TransferHelper: TRANSFER_FROM_FAILED");

      // # Sell right amount
      await expect(
        router
          .connect(userA)
          .swapExactTokensForTokensSupportingFeeOnTransferTokens(
            // amountin
            postBuyBalance.div(2),
            // outmin
            0,
            //path
            [omniCog.address, weth],
            //to
            userA.address,
            //deadline
            5689510989000,
          ),
      ).to.not.be.reverted;

    })

    it("Should burn to earn", async () => {

      const { owner, router, omniCog, pairAddress, otherSigners, printState } = await deployFixture();
      const [userA, userB, userC, ...remainingSigners] = otherSigners;
      const weth = await router.WETH();

      // is the correct amount burned from user balance?
      // does the contract balance decrease?
      // does the user get paid out the correct amount?

      await network.provider.send("evm_increaseTime", [7_000_000]);
      await network.provider.send("evm_mine");

      await printState("Pre 20 ETH volume");

      // Buy & Sell 10x in a row
      const EthToBuyFor = ETHtoBN("1");
      for(let i = 0; i < 1; i++) {

        // # Buy
        await expect(
          router
            .connect(userA)
            .swapExactETHForTokensSupportingFeeOnTransferTokens(
              // amountOutMin
              0,
              //path
              [weth, omniCog.address],
              //to
              userA.address,
              //deadline
              1689510989000,
              {
                value: EthToBuyFor,
              },
            ),
          "second swap",
        ).to.not.be.reverted;

        // await printState(`Post buy ${i+1}`)

        const postBuyBalance = await omniCog.balanceOf(userA.address);

        // # Approve
        await expect(
          omniCog.connect(userA).approve(router.address, postBuyBalance),
        ).to.not.be.reverted;

        // # Sell
        await expect(
          router
            .connect(userA)
            .swapExactTokensForTokensSupportingFeeOnTransferTokens(
              // amountin
              postBuyBalance,
              // outmin
              0,
              //path
              [omniCog.address, weth],
              //to
              userA.address,
              //deadline
              5689510989000,
            ),
        ).to.not.be.reverted;

        // await printState(`Post sell ${i+1}`)

      }
      
      // get B2E info
      const [
        _totalBurned, 
        _totalBurnRewards, 
        _b2eETHbalance,
        _timeToNextBurn,
        _maxTokensToBurn,
        _burnCapInEth,
        _maxEthOutput
      ] = await omniCog.getB2Einfo();

      expect(_maxTokensToBurn, "max tokens to burn").to.be.gt(0);

      console.log(`
      _totalBurned        ${BNtoETH(_totalBurned)} 
      _totalBurnRewards   ${BNtoETH(_totalBurnRewards)}
      _b2eETHbalance      ${BNtoETH(_b2eETHbalance)}
      actual balance      ${BNtoETH(await ethers.provider.getBalance(omniCog.address))}
      _timeToNextBurn     ${_timeToNextBurn}
      _maxTokensToBurn    ${BNtoETH(_maxTokensToBurn)}
      _burnCapInEth       ${BNtoETH(_burnCapInEth)}
      _maxEthOutput       ${BNtoETH( _maxEthOutput)}

      owner balance       ${BNtoETH(await omniCog.balanceOf(owner.address))}
      `)

      // // # Approve
      // await expect(
      //   omniCog.connect(owner).approve(router.address, _maxTokensToBurn),
      // ).to.not.be.reverted;

      // // # Sell
      // await expect(
      //   router
      //     .connect(owner)
      //     .swapExactTokensForTokensSupportingFeeOnTransferTokens(
      //       // amountin
      //       _maxTokensToBurn,
      //       // outmin
      //       0,
      //       //path
      //       [omniCog.address, weth],
      //       //to
      //       userB.address,
      //       //deadline
      //       5689510989000,
      //     ),
      // ).to.not.be.reverted;

      // await printState(`Post sell`)

      await printState("Pre B2E");
      await omniCog.connect(owner).burn2Earn(_maxTokensToBurn);
      await printState("Post B2E");

    })

    // -------------------------------------------------------------

    xit("Should add liquidity", async () => {
      // TODO not prio since only POL and this is already done in the fixture
      const { owner, router, omniCog, pairAddress } = await deployFixture();
      const weth = await router.WETH();
      const amountToTransfer = ethers.utils.parseEther("1000");

      await expect(router.add).to.not.be.reverted;
    });

    xit("Should withdraw liquidity", async () => {
      // TODO not prio since only POL
    });
  });

  xdescribe("Arbitrum deployment", () => {

    it("Should deploy to Arbitrum", async () => {

      const testing = process.env.TESTING == "true";
      console.log("Testing:", testing);

      // Wrap the provider so we can override fee data.
      let provider = ethers.provider;

      // --- required for polygon rpc gas override
      if (process.env.TARGET_CHAIN == 137) {
        provider = new ethers.providers.FallbackProvider([ethers.provider], 1);
        const FEE_DATA = {
          maxFeePerGas: ethers.utils.parseUnits("1000", "gwei"),
          maxPriorityFeePerGas: ethers.utils.parseUnits("1000", "gwei"),
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
        [owner, treasury, marketing, lp, buyback, ...otherSigners] =
          await ethers.getSigners();
        treasury = treasury.address;
        marketing = marketing.address;
        lp = lp.address;
        buyback = buyback.address;
      }

      const routerAddress = "0xc873fEcbd354f5A56E00E710B90EF4201db2448d";
      const endpoint = "0x3c2269811836af69497E5F486A85D7316753cf62";

      /* deployment */
      const Deployer = await ethers.getContractFactory("Deployer");
      const deployer = await Deployer.connect(owner).deploy(
        routerAddress,
        endpoint,
        marketing,
        lp,
        buyback,
        treasury,
      );
      await deployer.deployed();

      const proxy_address = await deployer.tup();
      const proxy = await ethers.getContractAt(
        "TransparentUpgradeableProxy",
        proxy_address
      );

      const admin_address = await deployer.proxyAdmin();
      const admin = await ethers.getContractAt(
        "ProxyAdmin",
        admin_address
      );

      // const admin_address = (new ethers.utils.AbiCoder()).decode(
      //   [ "address" ],
      //   await getStorageAt(
      //     proxy_address, 
      //     "0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103"
      //   )
      // )[0];
      // const admin = await ethers.getContractAt(
      //   "ProxyAdmin",
      //   admin_address
      // );

      const impl_address = await deployer.impl();
      const impl = await ethers.getContractAt(
        "BaseReflectionBurn",
        impl_address
      );

      const proxy_admin = await admin.getProxyAdmin(proxy_address);

      console.log(`
      proxy:          ${proxy.address}
      admin:          ${admin.address}
      impl:           ${impl.address}
      
      owner EOA:      ${owner.address}
      admin owner:    ${await admin.owner()} (should be EOA)
      proxy admin:    ${proxy_admin}
      `);

      const instance = await ethers.getContractAt(
        "BaseReflectionBurn",
        proxy_address
      );

      const liquidityToAddinEther = ethers.utils.parseEther("0.0000001");
      // TODO magic number?
      const liquidityToAddInToken = ethers.utils.parseEther("30000000");

      await instance.addLiquidity(
        3_333, // shares for chain
        liquidityToAddInToken,  // tokens for liquidity
        {value: liquidityToAddinEther}
      );

    })

  })

  describe.skip("BSC swap", () => {

    it("Should sell on BSC", async () => {

      // Wrap the provider so we can override fee data.
      let provider = ethers.provider;

      // --- required for polygon rpc gas override
      if (process.env.TARGET_CHAIN == 137) {
        provider = new ethers.providers.FallbackProvider([ethers.provider], 1);
        const FEE_DATA = {
          maxFeePerGas: ethers.utils.parseUnits("1000", "gwei"),
          maxPriorityFeePerGas: ethers.utils.parseUnits("1000", "gwei"),
        };
        provider.getFeeData = async () => FEE_DATA;
      }

      // Deploying
      let owner, treasury, marketing, lp, buyback;
      owner = new ethers.Wallet(process.env.OWNER_PK, provider);
      console.log("Owner wallet nonce:", await owner.getTransactionCount());
      treasury = process.env.TREASURY_ADDRESS;
      marketing = process.env.MARKETING_ADDRESS;
      lp = process.env.LP_ADDRESS;
      buyback = process.env.BUYBACK_ADDRESS;

      const BaseReflectionBurn_address = "0xE28637A24c15920fC77381c310Ef2f7284306c99";
      // const pair_address = "0x5f4Ca34b88bbA15ccecAC867B8A91F5c8a2A1a30";

      // const instance = await ethers.getContractAt(
      //   "BaseReflectionBurn",
      //   "0xE28637A24c15920fC77381c310Ef2f7284306c99"
      // );

      const router = await ethers.getContractAt(
        IUniswapV2Router02ABI,
        routers[String(process.env.TARGET_CHAIN)],
      );
      const weth = await router.WETH();

      await expect(
        router
          .connect(owner)
          .swapExactTokensForTokensSupportingFeeOnTransferTokens(
            // amountin
            ETHtoBN("100000"),
            // outmin
            0,
            //path
            [BaseReflectionBurn_address, weth],
            //to
            owner.address,
            //deadline
            5689510989000,
          ),
      ).to.not.be.reverted;

    })

    it("Should sell on Base", async () => {

      // Wrap the provider so we can override fee data.
      let provider = ethers.provider;

      // --- required for polygon rpc gas override
      if (process.env.TARGET_CHAIN == 137) {
        provider = new ethers.providers.FallbackProvider([ethers.provider], 1);
        const FEE_DATA = {
          maxFeePerGas:         ethers.utils.parseUnits("1000", "gwei"),
          maxPriorityFeePerGas: ethers.utils.parseUnits("1000", "gwei"),
        };
        provider.getFeeData = async () => FEE_DATA;
      }

      // Deploying
      let owner, treasury, marketing, lp, buyback;
      owner = new ethers.Wallet(process.env.OWNER_PK, provider);
      console.log("Owner wallet nonce:", await owner.getTransactionCount());
      treasury = process.env.TREASURY_ADDRESS;
      marketing = process.env.MARKETING_ADDRESS;
      lp = process.env.LP_ADDRESS;
      buyback = process.env.BUYBACK_ADDRESS;

      const BaseReflectionBurn_address = "0xe99f0EdF6089Ae35c97660Cf40aB5FD34249C84e";
      // const pair_address = "0x5f4Ca34b88bbA15ccecAC867B8A91F5c8a2A1a30";

      // const instance = await ethers.getContractAt(
      //   "BaseReflectionBurn",
      //   "0xE28637A24c15920fC77381c310Ef2f7284306c99"
      // );

      const router = await ethers.getContractAt(
        IUniswapV2Router02ABI,
        routers[String(process.env.TARGET_CHAIN)],
      );
      const weth = await router.WETH();

      await expect(
        router
          .connect(owner)
          .swapExactTokensForTokensSupportingFeeOnTransferTokens(
            // amountin
            ETHtoBN("10000"),
            // outmin
            0,
            //path
            [BaseReflectionBurn_address, weth],
            //to
            owner.address,
            //deadline
            5689510989000,
          ),
      ).to.not.be.reverted;

    })

  })

});
