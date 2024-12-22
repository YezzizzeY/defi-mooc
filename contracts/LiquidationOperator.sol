//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.7;

import "hardhat/console.sol";

// ----------------------INTERFACE------------------------------

interface IPriceOracleGetter {
    function getAssetPrice(address _asset) external view returns (uint256);
}

// Aave
// https://docs.aave.com/developers/the-core-protocol/lendingpool/ilendingpool

interface ILendingPool {
    struct EModeCategory {
        // each eMode category has a custom ltv and liquidation threshold
        uint16 ltv;
        uint16 liquidationThreshold;
        uint16 liquidationBonus;
        // each eMode category may or may not have a custom oracle to override the individual assets price oracles
        address priceSource;
        string label;
    }

    /**
     * Function to liquidate a non-healthy position collateral-wise, with Health Factor below 1
     * - The caller (liquidator) covers `debtToCover` amount of debt of the user getting liquidated, and receives
     *   a proportionally amount of the `collateralAsset` plus a bonus to cover market risk
     * @param collateralAsset The address of the underlying asset used as collateral, to receive as result of theliquidation
     * @param debtAsset The address of the underlying borrowed asset to be repaid with the liquidation
     * @param user The address of the borrower getting liquidated
     * @param debtToCover The debt amount of borrowed `asset` the liquidator wants to cover
     * @param receiveAToken `true` if the liquidators wants to receive the collateral aTokens, `false` if he wants
     * to receive the underlying collateral asset directly
     **/
    function liquidationCall(
        address collateralAsset,
        address debtAsset,
        address user,
        uint256 debtToCover,
        bool receiveAToken
    ) external;

    /**
     * Returns the user account data across all the reserves
     * @param user The address of the user
     * @return totalCollateralETH the total collateral in ETH of the user
     * @return totalDebtETH the total debt in ETH of the user
     * @return availableBorrowsETH the borrowing power left of the user
     * @return currentLiquidationThreshold the liquidation threshold of the user
     * @return ltv the loan to value of the user
     * @return healthFactor the current health factor of the user
     **/
    function getUserAccountData(address user)
        external
        view
        returns (
            uint256 totalCollateralETH,
            uint256 totalDebtETH,
            uint256 availableBorrowsETH,
            uint256 currentLiquidationThreshold,
            uint256 ltv,
            uint256 healthFactor
        );

    function getEModeCategoryData(uint8 id)
        external
        view
        returns (EModeCategory memory);

    function getUserEMode(address user) external view returns (uint256);

    /**
     * @dev Returns the state and configuration of the reserve
     * @param asset The address of the underlying asset of the reserve
     * @return The state of the reserve
     **/
    function getReserveData(address asset)
        external
        view
        returns (DataTypes.ReserveData memory);

    function getReservesList() external view returns (address[] memory);

    /**
     * @dev Returns the configuration of the user across all the reserves
     * @param user The user address
     * @return The configuration of the user
     **/
    function getUserConfiguration(address user)
        external
        view
        returns (DataTypes.UserConfigurationMap memory);

    /**
     * @dev Returns the configuration of the reserve
     * @param asset The address of the underlying asset of the reserve
     * @return The configuration of the reserve
     **/
    function getConfiguration(address asset)
        external
        view
        returns (DataTypes.ReserveConfigurationMap memory);
}

// UniswapV2

// https://github.com/Uniswap/v2-core/blob/master/contracts/interfaces/IERC20.sol
// https://docs.uniswap.org/protocol/V2/reference/smart-contracts/Pair-ERC-20
interface IERC20 {
    // Returns the account balance of another account with address _owner.
    function balanceOf(address owner) external view returns (uint256);

    /**
     * Allows _spender to withdraw from your account multiple times, up to the _value amount.
     * If this function is called again it overwrites the current allowance with _value.
     * Lets msg.sender set their allowance for a spender.
     **/
    function approve(address spender, uint256 value) external; // return type is deleted to be compatible with USDT

    /**
     * Transfers _value amount of tokens to address _to, and MUST fire the Transfer event.
     * The function SHOULD throw if the message caller’s account balance does not have enough tokens to spend.
     * Lets msg.sender send pool tokens to an address.
     **/
    function transfer(address to, uint256 value) external returns (bool);
}

// https://github.com/Uniswap/v2-periphery/blob/master/contracts/interfaces/IWETH.sol
interface IWETH is IERC20 {
    function deposit() external payable;

    // Convert the wrapped token back to Ether.
    function withdraw(uint256) external;
}

// https://github.com/Uniswap/v2-core/blob/master/contracts/interfaces/IUniswapV2Callee.sol
// The flash loan liquidator we plan to implement this time should be a UniswapV2 Callee
interface IUniswapV2Callee {
    function uniswapV2Call(
        address sender,
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) external;
}

// https://github.com/Uniswap/v2-core/blob/master/contracts/interfaces/IUniswapV2Factory.sol
// https://docs.uniswap.org/protocol/V2/reference/smart-contracts/factory
interface IUniswapV2Factory {
    // Returns the address of the pair for tokenA and tokenB, if it has been created, else address(0).
    function getPair(address tokenA, address tokenB)
        external
        view
        returns (address pair);
}

// https://github.com/Uniswap/v2-core/blob/master/contracts/interfaces/IUniswapV2Pair.sol
// https://docs.uniswap.org/protocol/V2/reference/smart-contracts/pair
interface IUniswapV2Pair {
    /**
     * Swaps tokens. For regular swaps, data.length must be 0.
     * Also see [Flash Swaps](https://docs.uniswap.org/protocol/V2/concepts/core-concepts/flash-swaps).
     **/
    function swap(
        uint256 amount0Out,
        uint256 amount1Out,
        address to,
        bytes calldata data
    ) external;

    /**
     * Returns the reserves of token0 and token1 used to price trades and distribute liquidity.
     * See Pricing[https://docs.uniswap.org/protocol/V2/concepts/advanced-topics/pricing].
     * Also returns the block.timestamp (mod 2**32) of the last block during which an interaction occured for the pair.
     **/
    function getReserves()
        external
        view
        returns (
            uint112 reserve0,
            uint112 reserve1,
            uint32 blockTimestampLast
        );
}

library DataTypes {
    // refer to the whitepaper, section 1.1 basic concepts for a formal description of these properties.
    struct ReserveData {
        //stores the reserve configuration
        ReserveConfigurationMap configuration;
        //the liquidity index. Expressed in ray
        uint128 liquidityIndex;
        //variable borrow index. Expressed in ray
        uint128 variableBorrowIndex;
        //the current supply rate. Expressed in ray
        uint128 currentLiquidityRate;
        //the current variable borrow rate. Expressed in ray
        uint128 currentVariableBorrowRate;
        //the current stable borrow rate. Expressed in ray
        uint128 currentStableBorrowRate;
        uint40 lastUpdateTimestamp;
        //tokens addresses
        address aTokenAddress;
        address stableDebtTokenAddress;
        address variableDebtTokenAddress;
        //address of the interest rate strategy
        address interestRateStrategyAddress;
        //the id of the reserve. Represents the position in the list of the active reserves
        uint8 id;
    }

    struct ReserveConfigurationMap {
        //bit 0-15: LTV
        //bit 16-31: Liq. threshold
        //bit 32-47: Liq. bonus
        //bit 48-55: Decimals
        //bit 56: Reserve is active
        //bit 57: reserve is frozen
        //bit 58: borrowing is enabled
        //bit 59: stable rate borrowing enabled
        //bit 60-63: reserved
        //bit 64-79: reserve factor
        uint256 data;
    }

    struct UserConfigurationMap {
        uint256 data;
    }
}

contract LiquidationOperator is IUniswapV2Callee {
    address public USER = 0x59CE4a2AC5bC3f5F225439B2993b86B42f6d3e9F;
    address public AAVE_LENDING_POOL =
        0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9;
    address USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address WBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
    // address USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address UNI_FACTORY = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
    address private PRICE_ORACLE = 0xA50ba011c48153De246E5192C8f9258A2ba79Ca9;

    ILendingPool lendingPool = ILendingPool(AAVE_LENDING_POOL);

    event UniswapV2CallDetails(
        address indexed sender,
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn,
        uint256 repayAmount
    );

    event UserAccountDataFetched(
        uint256 totalCollateralETH,
        uint256 totalDebtETH,
        uint256 availableBorrowsETH,
        uint256 currentLiquidationThreshold,
        uint256 ltv,
        uint256 healthFactor
    );

    function operate() external {
        uint256 liquidationAmount = 879965363370543592245;
        flashSwap(liquidationAmount); // flash swap

        uint256 wethBalance = getWETHBalance();
        IWETH(WETH).withdraw(wethBalance);

        payable(msg.sender).transfer(wethBalance);
    }

    function flashSwap(uint256 amount) public {
        require(amount > 0, "Amount must be greater than zero");
        address pair = IUniswapV2Factory(UNI_FACTORY).getPair(WBTC, WETH);
        require(pair != address(0), "No liquidity pair exists for the token"); // Ensure pair exists
        uint256 amount2 = getAmountIn2(amount, WBTC, WETH);
        bytes memory data = abi.encode(amount2);

        IUniswapV2Pair(pair).swap(uint256(0), amount, address(this), data);
        if (getWBTCBalance() != 0) {
            swap2(getWBTCBalance(), WBTC, WETH);
        }
    }

    function uniswapV2Call(
        address,
        uint256,
        uint256 amount1,
        bytes calldata data
    ) external override {
        uint256 amount2 = abi.decode(data, (uint256));

        uint256 wethBalance = IERC20(WETH).balanceOf(address(this));
        require(wethBalance >= amount1, "Not enough WETH for swap");

        address pair1 = IUniswapV2Factory(UNI_FACTORY).getPair(WETH, USDT);
        IERC20(WETH).approve(pair1, type(uint256).max);

        swap2(amount1, WETH, USDT);

        fetchAndEmitUserAccountData();

        performLiquidation(getUSDTBalance());

        address pair = IUniswapV2Factory(UNI_FACTORY).getPair(WBTC, WETH);
        // this fee calculation is for token-out
        // require(pair != address(0), "No liquidity pair exists for the token");
        // uint256 fee = ((amount2 * 3) / 997) + 1;
        // uint256 repay = amount2 + fee;
        IERC20(WBTC).transfer(pair, amount2);

        // uniswapV2Call event
        emit UniswapV2CallDetails(msg.sender, WBTC, WETH, amount1, amount2);
    }

    receive() external payable {}

    function LiquidationReward(uint256 amount_USDT)
        public
        view
        returns (uint256 reward)
    {
        // (uint256 a, uint256 b) = BTCUSDT_Reserves();
        // uint256 price = a * 10000 /b;
        // uint256 price = getWBTC_USDTPrice();
        // return reward = getWBTC_USDTPrice()*1110/1e15

        return reward = (3232549932 * amount_USDT) / 1e12;
    }

    function calculateArbitrage(uint256 w)
        public
        view
        returns (uint256 output)
    {
        // (uint256 a, uint256 b) = BTCUSDT_Reserves();
        // uint256 price = a * 10000 /b;
        // uint256 price = getWBTC_USDTPrice();

        uint256 u = getAmountOut2(w, WETH, USDT);
        uint256 l = LiquidationReward(u);
        uint256 r = getAmountIn2(w, WBTC, WETH);
        uint256 remain_WBTC = l - r;

        (uint256 reserve0, uint256 reserve1) = BTCETH_Reserves();

        uint256 reserve0_new = reserve0 + r;
        uint256 reserve1_new = reserve1 - w;

        uint256 output = getAmountOut(remain_WBTC, reserve0_new, reserve1_new);

        return output;
    }

    function safeCalculateArbitrage(uint256 w) public returns (uint256) {
        try this.calculateArbitrage(w) returns (uint256 result) {
            return result;
        } catch {
            return 1;
        }
    }

    //------------------------------------------helper functions------------------------------------------
    // some helper function, it is totally fine if you can finish the lab without using these function
    // https://github.com/Uniswap/v2-periphery/blob/master/contracts/libraries/UniswapV2Library.sol
    // given an input amount of an asset and pair reserves, returns the maximum output amount of the other asset
    // safe mul is not necessary since https://docs.soliditylang.org/en/v0.8.9/080-breaking-changes.html
    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) internal pure returns (uint256 amountOut) {
        require(amountIn > 0, "UniswapV2Library: INSUFFICIENT_INPUT_AMOUNT");
        require(
            reserveIn > 0 && reserveOut > 0,
            "UniswapV2Library: INSUFFICIENT_LIQUIDITY"
        );
        uint256 amountInWithFee = amountIn * 997;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = reserveIn * 1000 + amountInWithFee;
        amountOut = numerator / denominator;
    }

    // some helper function, it is totally fine if you can finish the lab without using these function
    // given an output amount of an asset and pair reserves, returns a required input amount of the other asset
    // safe mul is not necessary since https://docs.soliditylang.org/en/v0.8.9/080-breaking-changes.html
    function getAmountIn(
        uint256 amountOut,
        uint256 reserveIn,
        uint256 reserveOut
    ) internal pure returns (uint256 amountIn) {
        require(amountOut > 0, "UniswapV2Library: INSUFFICIENT_OUTPUT_AMOUNT");
        require(
            reserveIn > 0 && reserveOut > 0,
            "UniswapV2Library: INSUFFICIENT_LIQUIDITY"
        );
        uint256 numerator = reserveIn * amountOut * 1000;
        uint256 denominator = (reserveOut - amountOut) * 997;
        amountIn = (numerator / denominator) + 1;
    }

    function getAmountOut2(
        uint256 amountIn,
        address tokenIn,
        address tokenOut
    ) public view returns (uint256) {
        address pair = IUniswapV2Factory(UNI_FACTORY).getPair(
            tokenIn,
            tokenOut
        );

        uint256 reserve1;
        uint256 reserve2;
        (reserve1, reserve2, ) = IUniswapV2Pair(pair).getReserves();

        uint256 reserveIn;
        uint256 reserveOut;
        (reserveIn, reserveOut) = tokenIn < tokenOut
            ? (reserve1, reserve2)
            : (reserve2, reserve1);
        return getAmountOut(amountIn, reserveIn, reserveOut);
    }

    function getAmountIn2(
        uint256 amountOut,
        address tokenIn,
        address tokenOut
    ) public view returns (uint256) {
        address pair = IUniswapV2Factory(UNI_FACTORY).getPair(
            tokenIn,
            tokenOut
        );
        uint256 reserve1;
        uint256 reserve2;
        (reserve1, reserve2, ) = IUniswapV2Pair(pair).getReserves();

        return getAmountIn(amountOut, reserve1, reserve2);
    }

    event SwapExecuted(
        address indexed user,
        uint256 amountIn,
        uint256 amountOut
    );

    function swap2(
        uint256 amountIn,
        address tokenIn,
        address tokenOut
    ) public {
        // get pair
        address pair = IUniswapV2Factory(UNI_FACTORY).getPair(
            tokenIn,
            tokenOut
        );

        require(pair != address(0), "Pair doesn't exist");

        // get interface
        IUniswapV2Pair uniswapV2Pair = IUniswapV2Pair(pair);

        // get pair
        (uint256 reserveIn, uint256 reserveOut, ) = uniswapV2Pair.getReserves();

        // calculate amount out
        uint256 amountOut = getAmountOut2(amountIn, tokenIn, tokenOut);

        // transfer token to pair
        IERC20(tokenIn).transfer(address(uniswapV2Pair), amountIn);

        uint256 amount1;
        uint256 amount2;
        (amount1, amount2) = tokenIn < tokenOut
            ? (uint256(0), amountOut)
            : (amountOut, uint256(0));

        // swap
        uniswapV2Pair.swap(amount1, amount2, address(this), "");
    }

    // Return user debt for asset.
    function getUserDebt() public view returns (uint256) {
        DataTypes.ReserveData memory reserve = ILendingPool(AAVE_LENDING_POOL)
            .getReserveData(USDT);
        uint256 stableDebt = IERC20(reserve.stableDebtTokenAddress).balanceOf(
            USER
        );
        uint256 variableDebt = IERC20(reserve.variableDebtTokenAddress)
            .balanceOf(USER);
        return stableDebt + variableDebt;
    }

    function getUserCollateral() public view returns (uint256) {
        DataTypes.ReserveData memory reserve = ILendingPool(AAVE_LENDING_POOL)
            .getReserveData(WBTC);
        return IERC20(reserve.aTokenAddress).balanceOf(USER);
    }

    // Function to fetch and emit user account data
    function fetchAndEmitUserAccountData() public {
        (
            uint256 totalCollateralETH,
            uint256 totalDebtETH,
            uint256 availableBorrowsETH,
            uint256 currentLiquidationThreshold,
            uint256 ltv,
            uint256 healthFactor
        ) = getUserAccountData();

        emit UserAccountDataFetched(
            totalCollateralETH,
            totalDebtETH,
            availableBorrowsETH,
            currentLiquidationThreshold,
            ltv,
            healthFactor
        );
    }

    // aave getUserAccountData
    function getUserAccountData()
        public
        view
        returns (
            uint256 totalCollateralETH,
            uint256 totalDebtETH,
            uint256 availableBorrowsETH,
            uint256 currentLiquidationThreshold,
            uint256 ltv,
            uint256 healthFactor
        )
    {
        return lendingPool.getUserAccountData(USER);
    }

    function getETHBTCPrice() public view returns (uint256 price) {
        address pair = IUniswapV2Factory(UNI_FACTORY).getPair(WBTC, WETH);
        // Fetch the reserves of the Uniswap V2 pair
        (uint256 reserve0, uint256 reserve1) = BTCETH_Reserves();

        price = uint256(reserve1) / uint256(reserve0); // WBTC / ETH
    }

    function getWBTCPrice() public view returns (uint256 price) {
        IPriceOracleGetter oracle = IPriceOracleGetter(PRICE_ORACLE);
        uint256 price = oracle.getAssetPrice(WBTC);
        return price;
    }

    function getUSDTPrice() public view returns (uint256 price) {
        IPriceOracleGetter oracle = IPriceOracleGetter(PRICE_ORACLE);
        uint256 price = oracle.getAssetPrice(USDT);
        return price;
    }

    function getWBTC_USDTPrice() public view returns (uint256 price) {
        uint256 price = getWBTCPrice() / getUSDTPrice();
        return price;
    }

    // Function to send ETH to WETH contract and convert to WETH
    function depositWETH() public payable {
        // 获取合约当前持有的ETH数量
        uint256 balance = address(this).balance;
        require(balance > 0, "No ETH in contract to deposit");

        IWETH(WETH).deposit{value: balance}();
    }

    // Function to get the eth
    function depositETH() external payable {}

    // Function to get the WETH balance of this contract
    function getWETHBalance() public view returns (uint256) {
        return IERC20(WETH).balanceOf(address(this));
    }

    // Function to get the WBTC balance of this contract
    function getWBTCBalance() public view returns (uint256) {
        return IERC20(WBTC).balanceOf(address(this));
    }

    function getUSDTBalance() public view returns (uint256) {
        return IERC20(USDT).balanceOf(address(this));
    }

    function depositWBTC() public payable {
        depositWETH();
        uint256 balance = getWETHBalance();
        swap2(balance, WETH, WBTC);
    }

    function depositUSDT() public payable {
        depositWETH();
        uint256 balance = getWETHBalance();
        swap2(balance, WETH, USDT);
    }

    // Function to perform liquidation on a user's position
    function performLiquidation(uint256 amount) public {
        IERC20(USDT).approve(AAVE_LENDING_POOL, type(uint256).max);
        // Call the liquidation function
        lendingPool.liquidationCall(WBTC, USDT, USER, amount, false);
    }

    // Function to perform liquidation on a user's position
    function performMaxLiquidation() public {
        IERC20(USDT).approve(AAVE_LENDING_POOL, type(uint256).max);
        // Call the liquidation function
        lendingPool.liquidationCall(WBTC, USDT, USER, type(uint256).max, false);
    }

    // Function to perform liquidation on a user's position
    function performLiquidationWithETH(uint256 amount) public {
        IERC20(USDT).approve(AAVE_LENDING_POOL, type(uint256).max);
        swap2(amount, WETH, USDT);
        // Call the liquidation function
        lendingPool.liquidationCall(WBTC, USDT, USER, getUSDTBalance(), false);
        if (getWBTCBalance() != 0) {
            swap2(getWBTCBalance(), WBTC, WETH);
        }
    }

    // Function to perform liquidation on a user's position
    function performLiquidationWithBTC(uint256 amount) public {
        IERC20(USDT).approve(AAVE_LENDING_POOL, type(uint256).max);
        swap2(amount, WBTC, USDT);
        // Call the liquidation function
        lendingPool.liquidationCall(WBTC, USDT, USER, getUSDTBalance(), false);
    }

    function BTCETH_Reserves() public view returns (uint256, uint256) {
        address pair = IUniswapV2Factory(UNI_FACTORY).getPair(WBTC, WETH);
        IUniswapV2Pair uniswapV2Pair = IUniswapV2Pair(pair);
        (uint256 reserveIn, uint256 reserveOut, ) = uniswapV2Pair.getReserves();
        return (reserveIn, reserveOut);
    }

    function BTCUSDT_Reserves() public view returns (uint256, uint256) {
        address pair = IUniswapV2Factory(UNI_FACTORY).getPair(WBTC, USDT);
        IUniswapV2Pair uniswapV2Pair = IUniswapV2Pair(pair);
        (uint256 reserveIn, uint256 reserveOut, ) = uniswapV2Pair.getReserves();
        return (reserveIn, reserveOut);
    }

    //------------------------------------------unused functions------------------------------------------

    // function getRepay1() public view returns (uint256) {
    //     (
    //         uint256 totalCollateralETH,
    //         uint256 totalDebtETH, // availableBorrowsETH (not used here)
    //         ,
    //         uint256 currentLiquidationThreshold, // ltv (not used here)
    //         ,
    //         uint256 healthFactor
    //     ) = lendingPool.getUserAccountData(USER);

    //     uint256 precisionFactor = 1000000;
    //     uint256 factor105 = 110;

    //     // uint256 numerator = 0;
    //     uint256 thresholdC = currentLiquidationThreshold * totalCollateralETH;
    //     uint256 numerator = totalDebtETH * 10000 - thresholdC;
    //     uint256 denominator = precisionFactor -
    //         (currentLiquidationThreshold * factor105);
    //     // require(denominator > 0, "Denominator cannot be zero");
    //     return (numerator * 100) / denominator;
    // }

    // function getRepay2() public view returns (uint256) {
    //     (
    //         uint256 totalCollateralETH,
    //         uint256 totalDebtETH, // availableBorrowsETH (not used here)
    //         ,
    //         uint256 currentLiquidationThreshold, // ltv (not used here)
    //         ,
    //         uint256 healthFactor
    //     ) = lendingPool.getUserAccountData(USER);

    //     return (totalDebtETH - getRepay1());
    // }

    // // Function to calculate the maximum liquidatable amount
    // function getMaxLiquidationAmount() public view returns (uint256) {
    //     (
    //         uint256 totalCollateralETH,
    //         uint256 totalDebtETH, // availableBorrowsETH (not used here)
    //         ,
    //         uint256 currentLiquidationThreshold, // ltv (not used here)
    //         ,
    //         uint256 healthFactor
    //     ) = lendingPool.getUserAccountData(USER);

    //     // If healthFactor >= 1, liquidation is not possible
    //     if (healthFactor >= 1 ether) {
    //         return 0;
    //     }

    //     // Convert currentLiquidationThreshold from basis points to a percentage
    //     uint256 liquidationThresholdPercent = currentLiquidationThreshold /
    //         10000; // Divide by 10000 to get the percentage

    //     // Collateral value at liquidation threshold
    //     uint256 collateralAtThreshold = (totalCollateralETH *
    //         liquidationThresholdPercent) / 1 ether;

    //     // Excess debt amount (amount above the liquidation threshold)
    //     uint256 excessDebt = totalDebtETH > collateralAtThreshold
    //         ? totalDebtETH - collateralAtThreshold
    //         : 0;

    //     // Maximum liquidatable amount is the minimum of 50% of total debt and excess debt
    //     uint256 maxLiquidatableAmount = totalDebtETH / 2;
    //     return
    //         excessDebt < maxLiquidatableAmount
    //             ? excessDebt
    //             : maxLiquidatableAmount;
    // }
}
