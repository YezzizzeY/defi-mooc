const { expect } = require("chai");
const { network, ethers } = require("hardhat");
const { BigNumber, utils } = require("ethers");  // Correctly import BigNumber
const { writeFile } = require('fs');

describe("Liquidation", function () {
    it("test", async function () {
      // Reset network state and perform mainnet forking
      await network.provider.request({
        method: "hardhat_reset",
        params: [{
          forking: {
            jsonRpcUrl: "https://eth-mainnet.g.alchemy.com/v2/SP9G8921Cnj220AGvYJuKi8IMMwl389l",
            blockNumber: 12489619,
          }
        }]
      });
  
      const gasPrice = 0;  // Set the gas price
      const accounts = await ethers.getSigners();  // Get account information
      const liquidator = accounts[0].address;
  
      // Get the balance before liquidation
      const beforeLiquidationBalance = BigNumber.from(await hre.network.provider.request({
        method: "eth_getBalance",
        params: [liquidator],
      }));
  
      // Deploy the LiquidationOperator contract
      const LiquidationOperator = await ethers.getContractFactory("LiquidationOperator");
      const liquidationOperator = await LiquidationOperator.deploy(overrides = {gasPrice: gasPrice});
      await liquidationOperator.deployed();
  
      // Perform binary search to find the best w value that maximizes the calculateArbitrage value
      let left = BigNumber.from("504965363370543592245");
      let right = BigNumber.from("1004965363370543592245");
      let bestW = left;
      let maxArbitrage = BigNumber.from("0");
  
      // Set a larger threshold to extend the search time
      const threshold = BigNumber.from("1"); // Relax the condition
      const maxIterations = 1000;  // Maximum number of iterations
  
      // Track the arbitrage value from the previous round
      let prevArbitrageValue = BigNumber.from("0");
      let iterations = 0;
  
      while (right.sub(left).gte(threshold) && iterations < maxIterations) {
        // Calculate the middle value
        const mid = left.add(right).div(2);
        const arbitrageValue = await liquidationOperator.calculateArbitrage(mid);
  
        console.log(`Testing w = ${mid.toString()}: Arbitrage Value = ${arbitrageValue.toString()}`);
  
        // Update the maximum arbitrage value and best w
        if (arbitrageValue.gt(maxArbitrage)) {
          maxArbitrage = arbitrageValue;
          bestW = mid;
        }
  
        // Check the trend of arbitrageValue changes
        if (arbitrageValue.eq(prevArbitrageValue)) {
          // If arbitrageValue doesn't change, continue searching
          console.log("arbitrageValue has not significantly changed, continue searching...");
        }
  
        // Update the previous round's arbitrageValue
        prevArbitrageValue = arbitrageValue;
  
        // Check if arbitrageValue is still increasing
        const nextArbitrageValue = await liquidationOperator.calculateArbitrage(mid.add(1));
  
        if (arbitrageValue.gt(nextArbitrageValue)) {
          right = mid.sub(1);  // Search in the left half
        } else {
          left = mid.add(1);  // Search in the right half
        }
  
        iterations++;
      }
  
      console.log(`Max Arbitrage Value: ${maxArbitrage.toString()} at w = ${bestW.toString()}`);
    });
});
