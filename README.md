# Flash Loan based Liquidation

## Defi Model



#### **1. Loan WETH:**

Get `w` *WETH* from **<*WBTC*, *WETH*>** **pair**
$$
\text { loan amount } (WETH) = w
\\
\text{in} 
<WBTC, WETH>pair1
\\
$$
I use `pair1` because the reserve information will change, and I will need to use this pair in the subsequent steps



#### **2. Swap WETH to USDT:**

Swap WETH to USDT in **<WETH, USDT>** **pair**, here I define the **USDT amount to get** is `u`. 
$$
\text{Repay} \; u=\operatorname{getAmountOut}(w)   
\\
\text{in} 
<WETH, USDT>pair
\\using
\\
\text{amountOut} = \frac{\text{amountIn} \times (1 - \text{fee}) \times \text{reserveOut}}{\text{reserveIn} + \text{amountIn} \times (1 - \text{fee})}
$$
Here fee=0.3%, reserve0 and reserve1 are  *WETH*, *USDT* token amounts in **<WETH, USDT>** pair. 



#### **3. Perform Liquidation:**

Perform liquidation, now I have `u` *USDT*, here I define the liquidation award of *WBTC* is `l`, **Liquidation Spread(Liquidation Bonus)** is `LS` and got Price of *WBTC-USDT*
$$
l=\operatorname{Price}(W B T C / U S D T) \times L S \times u
$$
I believe the price should be obtained from the AAVE Oracle, but the Oracle value deviates significantly from the experimental results, and I’m unsure why. The price from Uniswap also seems incorrect, so I resorted to performing a Max Liquidation and extracted the `Price(WBTC/USDT)` from the Max Liquidation data by dividing the values.

`LS` should be 1110, got from interface. (By the way, WETH is 5%)



#### **4. Repay WBTC:**

The flashSwap fee is equal to normal swap fee, so here we only need to calculate the *WBTC* amount according to loan *WETH* amount. Here I define the repay amount is `r`.


$$
\text{Repay} \; r=\operatorname{getAmountIn}(w)   
\\
\text{in} 
<WBTC, WETH>pair1
\\
using
\\
\text{amountIn} = \frac{\text{reserveIn} \times \text{amountOut}}{(\text{reserveOut} - \text{amountOut}) \times (1 - \text{fee})}
$$
Fee is also 0.03.

And now we get WBTC amount is 
$$
l-r
$$


#### **5. Swap WBTC to WETH:**

Since after the flash swap, *WBTC* and *WETH* amount has changed in ***<WBTC, WETH>*** **pair**, first we need to calculate new reserves in ***<WBTC, WETH>*** **pair2**
$$
Reserve\_ WETH_{new} = Reserve\_WETH_{original}-w
\\
Reserve\_WBTC_{new} = Reserve\_WBTC_{original}+r
$$
Then, calculate the amount out from **pair2**
$$
\text{Arbitrage} \; Output=\operatorname{getAmountOut}(l-r)
\\
in <WBTC, WETH>pair2
$$


What we need to do is to **Maximize** **Arbitrage Output**. This is implemented as **calculateArbitrage()** function in the smart contract, and used binary method to test within the maximum number of liquidation(WETH), and the test script is located in the script folder.





## Transaction overview

Overall, first loan *WETH*, then swap *WETH* for *USDT*, use *USDT* for liquidation and finally swap collateral *WBTC* back to *WETH*

#### **1. Contract Initialization:**

The `LiquidationOperator` contract is designed to perform liquidation operations on the AAVE lending platform and interacts with the Uniswap V2 protocol. 

#### **2. `operate()` Function:**

The `operate()` function is the main entry point for initiating the liquidation process.

- **Flash Swap:** The contract calls the `flashSwap()` function, initiating a flash loan on Uniswap to acquire a specified amount of WBTC.
- **Withdraw WETH:** The acquired WETH balance is withdrawn, and the corresponding amount is transferred to the sender’s address.

#### **3. `flashSwap()`) Function:**

The `flashSwap()` function performs the following:

- **Get Swap Amount:** It calculates the required amount of WBTC to swap WETH. This include the 0.3% fee.
- **Execute Swap:** Use WBTC to swap WETH using the `swap()` function, with amountIn 0, thus flashswap.

#### **4. `uniswapV2Call()` Function:**

This function is called by Uniswap after the flash loan is executed. It performs several steps:

- **Swap WETH for USDT:** The contract swaps WETH for USDT by interacting with the Uniswap pair for `WETH/USDT`.
- **Liquidation:** The `performLiquidation()` function is triggered, perform the liquidation of the user's collateral(USDT->WBTC).
- **Repay Flash Loan:** The contract repays the flash loan in WBTC, sending the borrowed amount to the Uniswap pair.

#### **5. Liquidation Reward Calculation (`LiquidationReward()`):**

The `LiquidationReward()` function calculates the reward for the liquidation operator. It takes in the amount of WETH involved in the flashloan swap and liquidation and returns a reward value based on a fixed formula.



## Things to improve

- Maybe could do more arbitrage action, like short WBTC

- Could use Gradient Descent Algorithm or Newton's method to replace binary method to get Max Profit
