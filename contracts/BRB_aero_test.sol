// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {IERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import {IERC165Upgradeable} from "@openzeppelin/contracts-upgradeable/utils/introspection/IERC165Upgradeable.sol";

interface IUniswapV2Router02 {
    function factory() external view returns (address);

    function WETH() external view returns (address);

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;

    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    )
        external
        payable
    returns (uint amountToken, uint amountETH, uint liquidity);

    function getAmountsOut(uint amountIn, address[] memory path) external view returns (uint[] memory amounts);

    function getAmountsIn(uint amountOut, address[] memory path) external view returns (uint[] memory amounts);
}

interface IUniswapV2Factory {
    function createPair(
        address tokenA,
        address tokenB
    ) external returns (address);
}

interface ISolidlyFactory {
    function createPool(address tokenA, address tokenB, bool stable) external returns (address pool);
}

interface ISolidlyRouter {
    struct Route {
        address from;
        address to;
        bool stable;
        address factory;
    }

    error ETHTransferFailed();
    error Expired();
    error InsufficientAmount();
    error InsufficientAmountA();
    error InsufficientAmountB();
    error InsufficientAmountADesired();
    error InsufficientAmountBDesired();
    error InsufficientAmountAOptimal();
    error InsufficientLiquidity();
    error InsufficientOutputAmount();
    error InvalidAmountInForETHDeposit();
    error InvalidTokenInForETHDeposit();
    error InvalidPath();
    error InvalidRouteA();
    error InvalidRouteB();
    error OnlyWETH();
    error PoolDoesNotExist();
    error PoolFactoryDoesNotExist();
    error SameAddresses();
    error ZeroAddress();

    /// @notice Address of FactoryRegistry.sol
    function factoryRegistry() external view returns (address);

    /// @notice Address of Protocol PoolFactory.sol
    function defaultFactory() external view returns (address);

    /// @notice Address of Voter.sol
    function voter() external view returns (address);

    /// @notice Interface of WETH contract used for WETH => ETH wrapping/unwrapping
    function weth() external view returns (address);

    /// @dev Represents Ether. Used by zapper to determine whether to return assets as ETH/WETH.
    function ETHER() external view returns (address);

    /// @dev Struct containing information necessary to zap in and out of pools
    /// @param tokenA           .
    /// @param tokenB           .
    /// @param stable           Stable or volatile pool
    /// @param factory          factory of pool
    /// @param amountOutMinA    Minimum amount expected from swap leg of zap via routesA
    /// @param amountOutMinB    Minimum amount expected from swap leg of zap via routesB
    /// @param amountAMin       Minimum amount of tokenA expected from liquidity leg of zap
    /// @param amountBMin       Minimum amount of tokenB expected from liquidity leg of zap
    struct Zap {
        address tokenA;
        address tokenB;
        bool stable;
        address factory;
        uint256 amountOutMinA;
        uint256 amountOutMinB;
        uint256 amountAMin;
        uint256 amountBMin;
    }

    /// @notice Sort two tokens by which address value is less than the other
    /// @param tokenA   Address of token to sort
    /// @param tokenB   Address of token to sort
    /// @return token0  Lower address value between tokenA and tokenB
    /// @return token1  Higher address value between tokenA and tokenB
    function sortTokens(address tokenA, address tokenB) external pure returns (address token0, address token1);

    /// @notice Calculate the address of a pool by its' factory.
    ///         Used by all Router functions containing a `Route[]` or `_factory` argument.
    ///         Reverts if _factory is not approved by the FactoryRegistry
    /// @dev Returns a randomly generated address for a nonexistent pool
    /// @param tokenA   Address of token to query
    /// @param tokenB   Address of token to query
    /// @param stable   True if pool is stable, false if volatile
    /// @param _factory Address of factory which created the pool
    function poolFor(
        address tokenA,
        address tokenB,
        bool stable,
        address _factory
    ) external view returns (address pool);

    /// @notice Fetch and sort the reserves for a pool
    /// @param tokenA       .
    /// @param tokenB       .
    /// @param stable       True if pool is stable, false if volatile
    /// @param _factory     Address of PoolFactory for tokenA and tokenB
    /// @return reserveA    Amount of reserves of the sorted token A
    /// @return reserveB    Amount of reserves of the sorted token B
    function getReserves(
        address tokenA,
        address tokenB,
        bool stable,
        address _factory
    ) external view returns (uint256 reserveA, uint256 reserveB);

    /// @notice Perform chained getAmountOut calculations on any number of pools
    function getAmountsOut(uint256 amountIn, Route[] memory routes) external view returns (uint256[] memory amounts);

    // **** ADD LIQUIDITY ****

    /// @notice Quote the amount deposited into a Pool
    /// @param tokenA           .
    /// @param tokenB           .
    /// @param stable           True if pool is stable, false if volatile
    /// @param _factory         Address of PoolFactory for tokenA and tokenB
    /// @param amountADesired   Amount of tokenA desired to deposit
    /// @param amountBDesired   Amount of tokenB desired to deposit
    /// @return amountA         Amount of tokenA to actually deposit
    /// @return amountB         Amount of tokenB to actually deposit
    /// @return liquidity       Amount of liquidity token returned from deposit
    function quoteAddLiquidity(
        address tokenA,
        address tokenB,
        bool stable,
        address _factory,
        uint256 amountADesired,
        uint256 amountBDesired
    ) external view returns (uint256 amountA, uint256 amountB, uint256 liquidity);

    /// @notice Quote the amount of liquidity removed from a Pool
    /// @param tokenA       .
    /// @param tokenB       .
    /// @param stable       True if pool is stable, false if volatile
    /// @param _factory     Address of PoolFactory for tokenA and tokenB
    /// @param liquidity    Amount of liquidity to remove
    /// @return amountA     Amount of tokenA received
    /// @return amountB     Amount of tokenB received
    function quoteRemoveLiquidity(
        address tokenA,
        address tokenB,
        bool stable,
        address _factory,
        uint256 liquidity
    ) external view returns (uint256 amountA, uint256 amountB);

    /// @notice Add liquidity of two tokens to a Pool
    /// @param tokenA           .
    /// @param tokenB           .
    /// @param stable           True if pool is stable, false if volatile
    /// @param amountADesired   Amount of tokenA desired to deposit
    /// @param amountBDesired   Amount of tokenB desired to deposit
    /// @param amountAMin       Minimum amount of tokenA to deposit
    /// @param amountBMin       Minimum amount of tokenB to deposit
    /// @param to               Recipient of liquidity token
    /// @param deadline         Deadline to receive liquidity
    /// @return amountA         Amount of tokenA to actually deposit
    /// @return amountB         Amount of tokenB to actually deposit
    /// @return liquidity       Amount of liquidity token returned from deposit
    function addLiquidity(
        address tokenA,
        address tokenB,
        bool stable,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB, uint256 liquidity);

    /// @notice Add liquidity of a token and WETH (transferred as ETH) to a Pool
    /// @param token                .
    /// @param stable               True if pool is stable, false if volatile
    /// @param amountTokenDesired   Amount of token desired to deposit
    /// @param amountTokenMin       Minimum amount of token to deposit
    /// @param amountETHMin         Minimum amount of ETH to deposit
    /// @param to                   Recipient of liquidity token
    /// @param deadline             Deadline to add liquidity
    /// @return amountToken         Amount of token to actually deposit
    /// @return amountETH           Amount of tokenETH to actually deposit
    /// @return liquidity           Amount of liquidity token returned from deposit
    function addLiquidityETH(
        address token,
        bool stable,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external payable returns (uint256 amountToken, uint256 amountETH, uint256 liquidity);

    // **** REMOVE LIQUIDITY ****

    /// @notice Remove liquidity of two tokens from a Pool
    /// @param tokenA       .
    /// @param tokenB       .
    /// @param stable       True if pool is stable, false if volatile
    /// @param liquidity    Amount of liquidity to remove
    /// @param amountAMin   Minimum amount of tokenA to receive
    /// @param amountBMin   Minimum amount of tokenB to receive
    /// @param to           Recipient of tokens received
    /// @param deadline     Deadline to remove liquidity
    /// @return amountA     Amount of tokenA received
    /// @return amountB     Amount of tokenB received
    function removeLiquidity(
        address tokenA,
        address tokenB,
        bool stable,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB);

    /// @notice Remove liquidity of a token and WETH (returned as ETH) from a Pool
    /// @param token            .
    /// @param stable           True if pool is stable, false if volatile
    /// @param liquidity        Amount of liquidity to remove
    /// @param amountTokenMin   Minimum amount of token to receive
    /// @param amountETHMin     Minimum amount of ETH to receive
    /// @param to               Recipient of liquidity token
    /// @param deadline         Deadline to receive liquidity
    /// @return amountToken     Amount of token received
    /// @return amountETH       Amount of ETH received
    function removeLiquidityETH(
        address token,
        bool stable,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountToken, uint256 amountETH);

    /// @notice Remove liquidity of a fee-on-transfer token and WETH (returned as ETH) from a Pool
    /// @param token            .
    /// @param stable           True if pool is stable, false if volatile
    /// @param liquidity        Amount of liquidity to remove
    /// @param amountTokenMin   Minimum amount of token to receive
    /// @param amountETHMin     Minimum amount of ETH to receive
    /// @param to               Recipient of liquidity token
    /// @param deadline         Deadline to receive liquidity
    /// @return amountETH       Amount of ETH received
    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        bool stable,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountETH);

    // **** SWAP ****

    /// @notice Swap one token for another
    /// @param amountIn     Amount of token in
    /// @param amountOutMin Minimum amount of desired token received
    /// @param routes       Array of trade routes used in the swap
    /// @param to           Recipient of the tokens received
    /// @param deadline     Deadline to receive tokens
    /// @return amounts     Array of amounts returned per route
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        Route[] calldata routes,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    /// @notice Swap ETH for a token
    /// @param amountOutMin Minimum amount of desired token received
    /// @param routes       Array of trade routes used in the swap
    /// @param to           Recipient of the tokens received
    /// @param deadline     Deadline to receive tokens
    /// @return amounts     Array of amounts returned per route
    function swapExactETHForTokens(
        uint256 amountOutMin,
        Route[] calldata routes,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts);

    /// @notice Swap a token for WETH (returned as ETH)
    /// @param amountIn     Amount of token in
    /// @param amountOutMin Minimum amount of desired ETH
    /// @param routes       Array of trade routes used in the swap
    /// @param to           Recipient of the tokens received
    /// @param deadline     Deadline to receive tokens
    /// @return amounts     Array of amounts returned per route
    function swapExactTokensForETH(
        uint256 amountIn,
        uint256 amountOutMin,
        Route[] calldata routes,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    /// @notice Swap one token for another without slippage protection
    /// @return amounts     Array of amounts to swap  per route
    /// @param routes       Array of trade routes used in the swap
    /// @param to           Recipient of the tokens received
    /// @param deadline     Deadline to receive tokens
    function UNSAFE_swapExactTokensForTokens(
        uint256[] memory amounts,
        Route[] calldata routes,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory);

    // **** SWAP (supporting fee-on-transfer tokens) ****

    /// @notice Swap one token for another supporting fee-on-transfer tokens
    /// @param amountIn     Amount of token in
    /// @param amountOutMin Minimum amount of desired token received
    /// @param routes       Array of trade routes used in the swap
    /// @param to           Recipient of the tokens received
    /// @param deadline     Deadline to receive tokens
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        Route[] calldata routes,
        address to,
        uint256 deadline
    ) external;

    /// @notice Swap ETH for a token supporting fee-on-transfer tokens
    /// @param amountOutMin Minimum amount of desired token received
    /// @param routes       Array of trade routes used in the swap
    /// @param to           Recipient of the tokens received
    /// @param deadline     Deadline to receive tokens
    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint256 amountOutMin,
        Route[] calldata routes,
        address to,
        uint256 deadline
    ) external payable;

    /// @notice Swap a token for WETH (returned as ETH) supporting fee-on-transfer tokens
    /// @param amountIn     Amount of token in
    /// @param amountOutMin Minimum amount of desired ETH
    /// @param routes       Array of trade routes used in the swap
    /// @param to           Recipient of the tokens received
    /// @param deadline     Deadline to receive tokens
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        Route[] calldata routes,
        address to,
        uint256 deadline
    ) external;

    /// @notice Zap a token A into a pool (B, C). (A can be equal to B or C).
    ///         Supports standard ERC20 tokens only (i.e. not fee-on-transfer tokens etc).
    ///         Slippage is required for the initial swap.
    ///         Additional slippage may be required when adding liquidity as the
    ///         price of the token may have changed.
    /// @param tokenIn      Token you are zapping in from (i.e. input token).
    /// @param amountInA    Amount of input token you wish to send down routesA
    /// @param amountInB    Amount of input token you wish to send down routesB
    /// @param zapInPool    Contains zap struct information. See Zap struct.
    /// @param routesA      Route used to convert input token to tokenA
    /// @param routesB      Route used to convert input token to tokenB
    /// @param to           Address you wish to mint liquidity to.
    /// @param stake        Auto-stake liquidity in corresponding gauge.
    /// @return liquidity   Amount of LP tokens created from zapping in.
    function zapIn(
        address tokenIn,
        uint256 amountInA,
        uint256 amountInB,
        Zap calldata zapInPool,
        Route[] calldata routesA,
        Route[] calldata routesB,
        address to,
        bool stake
    ) external payable returns (uint256 liquidity);

    /// @notice Zap out a pool (B, C) into A.
    ///         Supports standard ERC20 tokens only (i.e. not fee-on-transfer tokens etc).
    ///         Slippage is required for the removal of liquidity.
    ///         Additional slippage may be required on the swap as the
    ///         price of the token may have changed.
    /// @param tokenOut     Token you are zapping out to (i.e. output token).
    /// @param liquidity    Amount of liquidity you wish to remove.
    /// @param zapOutPool   Contains zap struct information. See Zap struct.
    /// @param routesA      Route used to convert tokenA into output token.
    /// @param routesB      Route used to convert tokenB into output token.
    function zapOut(
        address tokenOut,
        uint256 liquidity,
        Zap calldata zapOutPool,
        Route[] calldata routesA,
        Route[] calldata routesB
    ) external;

    /// @notice Used to generate params required for zapping in.
    ///         Zap in => remove liquidity then swap.
    ///         Apply slippage to expected swap values to account for changes in reserves in between.
    /// @dev Output token refers to the token you want to zap in from.
    /// @param tokenA           .
    /// @param tokenB           .
    /// @param stable           .
    /// @param _factory         .
    /// @param amountInA        Amount of input token you wish to send down routesA
    /// @param amountInB        Amount of input token you wish to send down routesB
    /// @param routesA          Route used to convert input token to tokenA
    /// @param routesB          Route used to convert input token to tokenB
    /// @return amountOutMinA   Minimum output expected from swapping input token to tokenA.
    /// @return amountOutMinB   Minimum output expected from swapping input token to tokenB.
    /// @return amountAMin      Minimum amount of tokenA expected from depositing liquidity.
    /// @return amountBMin      Minimum amount of tokenB expected from depositing liquidity.
    function generateZapInParams(
        address tokenA,
        address tokenB,
        bool stable,
        address _factory,
        uint256 amountInA,
        uint256 amountInB,
        Route[] calldata routesA,
        Route[] calldata routesB
    ) external view returns (uint256 amountOutMinA, uint256 amountOutMinB, uint256 amountAMin, uint256 amountBMin);

    /// @notice Used to generate params required for zapping out.
    ///         Zap out => swap then add liquidity.
    ///         Apply slippage to expected liquidity values to account for changes in reserves in between.
    /// @dev Output token refers to the token you want to zap out of.
    /// @param tokenA           .
    /// @param tokenB           .
    /// @param stable           .
    /// @param _factory         .
    /// @param liquidity        Amount of liquidity being zapped out of into a given output token.
    /// @param routesA          Route used to convert tokenA into output token.
    /// @param routesB          Route used to convert tokenB into output token.
    /// @return amountOutMinA   Minimum output expected from swapping tokenA into output token.
    /// @return amountOutMinB   Minimum output expected from swapping tokenB into output token.
    /// @return amountAMin      Minimum amount of tokenA expected from withdrawing liquidity.
    /// @return amountBMin      Minimum amount of tokenB expected from withdrawing liquidity.
    function generateZapOutParams(
        address tokenA,
        address tokenB,
        bool stable,
        address _factory,
        uint256 liquidity,
        Route[] calldata routesA,
        Route[] calldata routesB
    ) external view returns (uint256 amountOutMinA, uint256 amountOutMinB, uint256 amountAMin, uint256 amountBMin);

    /// @notice Used by zapper to determine appropriate ratio of A to B to deposit liquidity. Assumes stable pool.
    /// @dev Returns stable liquidity ratio of B to (A + B).
    ///      E.g. if ratio is 0.4, it means there is more of A than there is of B.
    ///      Therefore you should deposit more of token A than B.
    /// @param tokenA   tokenA of stable pool you are zapping into.
    /// @param tokenB   tokenB of stable pool you are zapping into.
    /// @param factory  Factory that created stable pool.
    /// @return ratio   Ratio of token0 to token1 required to deposit into zap.
    function quoteStableLiquidityRatio(
        address tokenA,
        address tokenB,
        address factory
    ) external view returns (uint256 ratio);
}

// contract BaseReflectionBurn_aero_test is Initializable, OwnableUpgradeable, IERC20Upgradeable {

    // /* -------------------------------------------------------------------------- */
    // /*                                   events                                   */
    // /* -------------------------------------------------------------------------- */
    // error InvalidParameters();
    // error ERC20InsufficientAllowance(address, address, uint);
    // error InsuffcientBalance(uint);
    // error InsufficientContractETHBalance(uint /* desired output */, uint /* available balance */);
    // error ExceedingBurnCap(uint /* desired output */, uint /* burn cap */);
    // error CannotBurnYet();
    // error InvalidReferrer();

    // event Reflect(uint256 baseAmountReflected, uint256 totalReflected);
    // event LaunchFee(address user, uint amount);
    // event BurnedAndEarned(address, uint, uint);

    // /* -------------------------------------------------------------------------- */
    // /*                                  constants                                 */
    // /* -------------------------------------------------------------------------- */
    // string constant _name = "BASE Reflection & Burn (base2earn.com)";
    // string constant _symbol = "BRB";

    // // @custom:oz-upgrades-unsafe-allow state-variable-immutable
    // ISolidlyRouter public immutable ROUTER;

    // // --- BSC (Pancake)
    // // IUniswapV2Router02 public constant ROUTER =
    // //     IUniswapV2Router02(0x10ED43C718714eb63d5aA57B78B54704E256024E);

    // // --- Polygon (Quickswap)
    // // IUniswapV2Router02 public constant ROUTER =
    // //     IUniswapV2Router02(0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff);

    // // --- Fantom (Spookyswap)
    // // IUniswapV2Router02 public constant ROUTER =
    // //     IUniswapV2Router02(0xF491e7B69E4244ad4002BC14e878a34207E38c29);

    // // --- Arbitrum (Camelot)
    // // IUniswapV2Router02 public constant ROUTER =
    // //     IUniswapV2Router02(0xc873fEcbd354f5A56E00E710B90EF4201db2448d);

    // // --- Base (Alienbase)
    // // IUniswapV2Router02 public constant ROUTER =
    // //     IUniswapV2Router02(0x8c1A3cF8f83074169FE5D7aD50B978e1cD6b37c7);

    // // --- Ethereum (Uniswap)
    // // IUniswapV2Router02 public constant ROUTER =
    // //     IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);

    // address private constant DEAD = 0x000000000000000000000000000000000000dEaD;
    // address private constant ZERO = 0x0000000000000000000000000000000000000000;

    // uint256 private constant MAX_FEE = 1_000; /* 15% */
    // uint256 private constant MAX_BP = 10_000;
    // uint256 private constant LAUNCH_FEE = 3_000;
    // uint256 private constant REFLECTION_GROWTH_FACTOR = 100;
    // uint256 private constant TOTAL_SUPPLY = 1_428_571_428 ether; /* 30% supply expansion on 1B tokens */

    // uint256 private constant B2E_STATIC_BURN_CAP = 1 ether;
    // uint256 private constant B2E_SUB_CAP_LIMIT = 0.1 ether;
    // uint256 private constant B2E_CAP_DIVISOR = 10;
    // uint256 private constant LAUNCH_FEE_DURATION = 5 days;
    // uint256 private constant BURN_INTERVAL = 2 minutes;

    // uint256 private immutable LAUNCH_TIME;

    // /* -------------------------------------------------------------------------- */
    // /*                                   states                                   */
    // /* -------------------------------------------------------------------------- */

    // struct Fee {
    //     // swap to ETH
    //     uint8 marketing;
    //     uint8 treasury;
    //     uint8 lp;
    //     uint8 buyback;

    //     // do not swap to ETH
    //     uint8 reflection;
    //     uint8 burn;
    //     uint8 b2e;

    //     uint128 total;
    // }

    // bool private liquidityInitialised;

    // uint256 public feesEnabled;
    // uint256 public swapThreshold; // denominated as reflected amount
    // uint256 public totalReflected;
    // uint256 public totalSubLPBalance; // denominated as base amount

    // uint256 private isInSwap;

    // uint256 private lastBurnedTimestamp;
    // uint256 private totalBurnRewards;
    // uint256 private totalBurned;
    // uint256 private b2eETHbalance;

    // address private _uniswapPair;
    // address private marketingFeeReceiver;
    // address private lpFeeReceiver;
    // address private buybackFeeReceiver;
    // address private treasuryReceiver;

    // Fee public buyFee;
    // Fee public sellFee;

    // /* registred pools are excluded from receiving reflections */
    // mapping(address => uint256) public isRegistredPool;
    // mapping(address => uint256) private _baseBalance;

    // mapping(address => mapping(address => uint256)) private _allowances;

    // //@custom:oz-upgrades-unsafe-allow state-variable-immutable
    // constructor(address router) {
    //     ROUTER = ISolidlyRouter(router);
    //     LAUNCH_TIME = block.timestamp;
    // }

    // receive() external payable {}

    // function initialize(
    //     address newMarketingFeeReceiver,
    //     address newLPfeeReceiver,
    //     address newBuyBackFeeReceiver,
    //     address newTreasuryReceiver
    // ) public payable initializer {

    //     // initialise parents
    //     __Ownable_init_unchained();

    //     totalSubLPBalance = TOTAL_SUPPLY;
    //     swapThreshold = TOTAL_SUPPLY * 70 / MAX_BP; /* 0.7% of total supply */

    //     marketingFeeReceiver = newMarketingFeeReceiver;
    //     lpFeeReceiver = newLPfeeReceiver;
    //     buybackFeeReceiver = newBuyBackFeeReceiver;
    //     treasuryReceiver = newTreasuryReceiver;

    //     buyFee = Fee({
    //         reflection: 100,
    //         buyback: 100,
    //         marketing: 100,
    //         lp: 100,
    //         treasury: 100,
    //         burn: 0,
    //         b2e: 100,
    //         total: 600
    //     });
    //     sellFee = Fee({
    //         reflection: 100,
    //         buyback: 100,
    //         marketing: 100,
    //         lp: 100,
    //         treasury: 100,
    //         burn: 0,
    //         b2e: 100,
    //         total: 600
    //     });
    // }

    // function addLiquiditySolidly(
    //     uint tokensForLiquidity
    // ) external payable onlyOwner {
    //     require(TOTAL_SUPPLY  >= tokensForLiquidity);

    //     if (liquidityInitialised) revert();
    //     liquidityInitialised = true;

    //     // fund address(this) with desired amount of liquidity tokens
    //     _baseBalance[address(this)] = tokensForLiquidity;
    //     // baseBalance = reflected balance here
    //     emit Transfer(address(0), address(this), tokensForLiquidity);

    //     // create uniswap pair
    //     _uniswapPair = ISolidlyFactory(ROUTER.defaultFactory()).createPool(address(this), ROUTER.weth(), false);

    //     // set unlimited allowance for uniswap router
    //     _allowances[address(this)][address(ROUTER)] = type(uint256).max;

    //     // add desired amount of liquidity to pair
    //     ROUTER.addLiquidityETH{value: msg.value}(
    //         address(this), // address token,
    //         false,
    //         tokensForLiquidity, // uint amountTokenDesired,
    //         tokensForLiquidity, // uint amountTokenMin,
    //         msg.value, // uint amountETHMin,
    //         treasuryReceiver, // address to,
    //         block.timestamp // uint deadline
    //     );

    //     // mint remainig share to owner, if any
    //     if (tokensForLiquidity < TOTAL_SUPPLY) {
    //         _baseBalance[tx.origin] = TOTAL_SUPPLY - tokensForLiquidity;
    //         emit Transfer(
    //             address(0),
    //             tx.origin,
    //             TOTAL_SUPPLY - tokensForLiquidity
    //         );
    //     }

    //     // register pool as trading pool
    //     isRegistredPool[_uniswapPair] = 1;

    //     // enable fees
    //     feesEnabled = 1;

    //     // update LP balance
    //     totalSubLPBalance = totalSubLPBalance - tokensForLiquidity;
    // }

    // /* -------------------------------------------------------------------------- */
    // /*                             Public functionality                           */
    // /* -------------------------------------------------------------------------- */

    // // msg.sender burns tokens and receive uniswap rate TAX FREE, instead of selling.
    // function burn2Earn(uint256 amount) public {

    //     if(balanceOf(msg.sender) < amount) revert InsuffcientBalance(amount);
    //     if(block.timestamp < BURN_INTERVAL + lastBurnedTimestamp) revert CannotBurnYet();

    //     address[] memory path = new address[](2);
    //     path[0] = address(this);
    //     path[1] = ROUTER.weth();

    //     uint[] memory outputEstimates = ROUTER.getAmountsOut(amount, path);
    //     uint256 tokenOutputEstimate = outputEstimates[outputEstimates.length - 1];

    //     if(b2eETHbalance < tokenOutputEstimate) revert InsufficientContractETHBalance(tokenOutputEstimate, b2eETHbalance);
    //     if(tokenOutputEstimate > _getBurnCapETH()) revert ExceedingBurnCap(tokenOutputEstimate, _getBurnCapETH());

    //     b2eETHbalance = b2eETHbalance - tokenOutputEstimate;
        
    //     // burn
    //     uint baseAmountToBurn = reflectionToBaseAmount(amount, msg.sender);
    //     _baseBalance[msg.sender] = _baseBalance[msg.sender] - baseAmountToBurn;
    //     totalSubLPBalance = totalSubLPBalance - baseAmountToBurn;
    //     emit Transfer(msg.sender, address(0), amount);

    //     // transfer return amount to sender
    //     payable(msg.sender).call{value: tokenOutputEstimate}("");
        
    //     totalBurnRewards = totalBurnRewards + tokenOutputEstimate;
    //     totalBurned = totalBurned + amount;
    //     lastBurnedTimestamp = block.timestamp;

    //     emit BurnedAndEarned(msg.sender, amount, tokenOutputEstimate);
    // }

    // /* -------------------------------------------------------------------------- */
    // /*                                    ERC20                                   */
    // /* -------------------------------------------------------------------------- */

    // function approve(
    //     address spender,
    //     uint256 amount
    // ) public override returns (bool) {
    //     _allowances[msg.sender][spender] = amount;
    //     emit Approval(msg.sender, spender, amount);
    //     return true;
    // }

    // function approveMax(address spender) external returns (bool) {
    //     return approve(spender, type(uint256).max);
    // }

    // function transfer(
    //     address recipient,
    //     uint256 amount
    // ) external override returns (bool) {
    //     return _transferFrom(msg.sender, recipient, amount);
    // }

    // function transferFrom(
    //     address sender,
    //     address recipient,
    //     uint256 amount
    // ) external override returns (bool) {
    //     if (_allowances[sender][msg.sender] != type(uint256).max) {
    //         if (_allowances[sender][msg.sender] < amount)
    //             revert ERC20InsufficientAllowance(
    //                 sender,
    //                 recipient,
    //                 _allowances[sender][msg.sender]
    //             );
    //         _allowances[sender][msg.sender] =
    //             _allowances[sender][msg.sender] -
    //             amount;
    //     }

    //     return _transferFrom(sender, recipient, amount);
    // }

    // /* -------------------------------------------------------------------------- */
    // /*                                    Views                                   */
    // /* -------------------------------------------------------------------------- */

    // function totalSupply() external pure override returns (uint256) {
    //     return TOTAL_SUPPLY;
    // }

    // function decimals() external pure returns (uint8) {
    //     return 18;
    // }

    // function name() external pure returns (string memory) {
    //     return _name;
    // }

    // function symbol() external pure returns (string memory) {
    //     return _symbol;
    // }

    // function balanceOf(address account) public view override returns (uint256) {
    //     return baseToReflectionAmount(_baseBalance[account], account);
    // }

    // function allowance(
    //     address holder,
    //     address spender
    // ) external view override returns (uint256) {
    //     return _allowances[holder][spender];
    // }

    // function baseToReflectionAmount(
    //     uint256 baseAmount,
    //     address account
    // ) public view returns (uint256) {
    //     uint local_totalSubLPBalance = totalSubLPBalance;
    //     if(isRegistredPool[account] != 0) {
    //         return baseAmount;
    //     }else{
    //         uint numerator = baseAmount * local_totalSubLPBalance;
    //         uint denominator = (REFLECTION_GROWTH_FACTOR * totalReflected) + local_totalSubLPBalance;
    //         return 2 * baseAmount - (numerator / denominator);
    //     }
    // }

    // function reflectionToBaseAmount(
    //     uint reflectionAmount, 
    //     address account
    // ) public view returns(uint) {
    //     uint mem_totalSubLPBal = totalSubLPBalance;
    //     if(isRegistredPool[account] != 0) {
    //         return reflectionAmount;
    //     }else{
    //         uint numerator = (REFLECTION_GROWTH_FACTOR * totalReflected) + mem_totalSubLPBal;
    //         uint denominator = (2 * REFLECTION_GROWTH_FACTOR * totalReflected) + mem_totalSubLPBal;
    //         return reflectionAmount * numerator / denominator;
    //     }
    // }

    // // max amount of ETH returned when burning
    // function _getBurnCapETH() internal view returns(uint256) {
    //     uint mem_b2eETHbalance = b2eETHbalance;
    //     return mem_b2eETHbalance <= B2E_STATIC_BURN_CAP
    //         ? B2E_SUB_CAP_LIMIT
    //         : mem_b2eETHbalance / B2E_CAP_DIVISOR;
    // }

    // function getB2Einfo() external view returns(
    //     uint256 _totalBurned, 
    //     uint256 _totalBurnRewards, 
    //     uint256 _b2eETHbalance,
    //     uint256 _timeToNextBurn,
    //     uint256 _maxTokensToBurn,
    //     uint256 _burnCapInEth,
    //     uint256 _maxEthOutput
    // ) {
    //     _totalBurned = totalBurned;
    //     _totalBurnRewards = totalBurnRewards;
    //     _b2eETHbalance = b2eETHbalance;
    //     _timeToNextBurn = 
    //         (block.timestamp - lastBurnedTimestamp >= BURN_INTERVAL)
    //         ? 0 
    //         : BURN_INTERVAL - (block.timestamp - lastBurnedTimestamp);
    //     _burnCapInEth = _getBurnCapETH();

    //     address[] memory path = new address[](2);
    //     path[0] = address(this);
    //     path[1] = ROUTER.weth();
    //     uint[] memory maxInputInTokensArr = ROUTER.getAmountsIn(
    //         _burnCapInEth < _b2eETHbalance
    //             ? _burnCapInEth
    //             : _b2eETHbalance, 
    //         path
    //     );
    //     _maxTokensToBurn = maxInputInTokensArr[0];

    //     uint[] memory outputEstimates = ROUTER.getAmountsOut(_maxTokensToBurn, path);
    //     uint tokenOutputEstimate = outputEstimates[outputEstimates.length - 1];
    //     _maxEthOutput = _burnCapInEth < tokenOutputEstimate ? _burnCapInEth : tokenOutputEstimate;
    // }

    // /* -------------------------------------------------------------------------- */
    // /*                               Access restricted                            */
    // /* -------------------------------------------------------------------------- */

    // function clearStuckBalance() external payable onlyOwner {
    //     (bool success, ) = payable(msg.sender).call{
    //         value: address(this).balance
    //     }("");
    //     require(success);
    // }

    // function clearStuckToken() external payable onlyOwner {
    //     _transferFrom(address(this), msg.sender, balanceOf(address(this)));
    // }

    // function setSwapBackSettings(
    //     uint256 _enabled /* 0 = false, 1 = true */,
    //     uint256 _amount
    // ) external payable onlyOwner {
    //     feesEnabled = _enabled;
    //     swapThreshold = _amount;
    // }

    // function changeFees(
    //     Fee calldata _buyFee,
    //     Fee calldata _sellFee
    // ) external payable onlyOwner {
    //     // can cast all numbers, or just the first to save gas I think, not sure what the saving differences are like
    //     uint128 totalBuyFee = uint128(_buyFee.reflection) +
    //         _buyFee.marketing +
    //         _buyFee.treasury +
    //         _buyFee.lp +
    //         _buyFee.buyback +
    //         _buyFee.burn;

    //     uint128 totalSellFee = uint128(_sellFee.reflection) +
    //         _sellFee.marketing +
    //         _sellFee.treasury +
    //         _sellFee.lp +
    //         _sellFee.buyback +
    //         _sellFee.burn;

    //     if (
    //         totalBuyFee != _buyFee.total ||
    //         totalSellFee != _sellFee.total ||
    //         totalBuyFee > MAX_FEE ||
    //         totalSellFee > MAX_FEE
    //     ) revert InvalidParameters();

    //     buyFee = _buyFee;
    //     sellFee = _sellFee;
    // }

    // function setFeeReceivers(
    //     address newMarketingFeeReceiver,
    //     address newLPfeeReceiver,
    //     address newBuybackFeeReceiver,
    //     address newTreasuryReceiver
    // ) external payable onlyOwner {
    //     marketingFeeReceiver = newMarketingFeeReceiver;
    //     lpFeeReceiver = newLPfeeReceiver;
    //     buybackFeeReceiver = newBuybackFeeReceiver;
    //     treasuryReceiver = newTreasuryReceiver;
    // }

    // function setRegistredPool(
    //     address pool,
    //     uint state
    // ) external payable onlyOwner {
    //     isRegistredPool[pool] = state;
    //     if (state != 0) {
    //         totalSubLPBalance = totalSubLPBalance + _baseBalance[pool];
    //     }
    //     else {
    //         totalSubLPBalance = totalSubLPBalance - _baseBalance[pool];
    //     }
    // }

    // /* -------------------------------------------------------------------------- */
    // /*                                   Internal                                 */
    // /* -------------------------------------------------------------------------- */

    // function _transferFrom(
    //     address sender,
    //     address recipient,
    //     uint256 amount
    // ) internal returns (bool) {
    //     bool senderIsPool = isRegistredPool[sender] != 0; // = buy
    //     bool recipientIsPool = isRegistredPool[recipient] != 0; // = sell

    //     // take launch fee first
    //     uint baseLaunchFeeAmount;
    //     uint local_totalSubLPBalance = totalSubLPBalance;

    //     // take launch fee
    //     if (
    //         feesEnabled != 0 &&
    //         !senderIsPool &&
    //         isInSwap == 0 &&
    //         block.timestamp - LAUNCH_TIME < LAUNCH_FEE_DURATION
    //     ) {
    //         isInSwap = 1;

    //         // swap back
    //         address[] memory path = new address[](2);
    //         path[0] = address(this);
    //         path[1] = ROUTER.WETH();

    //         uint reflectedLaunchFeeAmount =
    //             amount *
    //             LAUNCH_FEE *
    //             (LAUNCH_FEE_DURATION - (block.timestamp - LAUNCH_TIME)) /
    //             LAUNCH_FEE_DURATION /
    //             MAX_BP;

    //         baseLaunchFeeAmount = reflectionToBaseAmount(reflectedLaunchFeeAmount, sender);

    //         _baseBalance[address(this)] = _baseBalance[address(this)] + baseLaunchFeeAmount;
    //         emit Transfer(sender, address(this), reflectedLaunchFeeAmount);
    //         emit LaunchFee(sender, reflectedLaunchFeeAmount);

    //         ROUTER.swapExactTokensForETHSupportingFeeOnTransferTokens(
    //             reflectedLaunchFeeAmount,
    //             0,
    //             path,
    //             treasuryReceiver,
    //             block.timestamp
    //         );

    //         isInSwap = 0;
    //         local_totalSubLPBalance = totalSubLPBalance;
    //     }

    //     // Swap own token balance against pool if conditions are fulfilled
    //     // this has to be done before calculating baseAmount since it shifts
    //     // the balance in the liquidity pool, thus altering the result
    //     {
    //         // wrap into block since it's agnostic to function state
    //         if (
    //             isInSwap == 0 &&
    //             // this only swaps if it's not a buy, amplifying impacts of sells and 
    //             // leaving buys untouched but also shifting gas costs of this to sellers only
    //             isRegistredPool[msg.sender] == 0 &&
    //             feesEnabled != 0 &&
    //             balanceOf(address(this)) >= swapThreshold
    //         ) {
    //             isInSwap = 1;

    //             Fee memory memorySellFee = sellFee;
                
    //             uint256 stack_SwapThreshold = swapThreshold;
    //             uint256 amountToBurn = stack_SwapThreshold * memorySellFee.burn / memorySellFee.total;
    //             uint256 amountToSwap = stack_SwapThreshold - amountToBurn;
                
    //             // burn, no further checks needed here
    //             uint baseAmountToBurn = reflectionToBaseAmount(amountToBurn, address(this));
    //             _baseBalance[address(this)] = _baseBalance[address(this)] - baseAmountToBurn;
    //             _baseBalance[DEAD] = _baseBalance[DEAD] + baseAmountToBurn;

    //             uint preSwapBalance = address(this).balance;

    //             // swap non-burned tokens to ETH
    //             address[] memory path = new address[](2);
    //             path[0] = address(this);
    //             path[1] = ROUTER.WETH();

    //             ROUTER.swapExactTokensForETHSupportingFeeOnTransferTokens(
    //                 amountToSwap,
    //                 0,
    //                 path,
    //                 address(this),
    //                 block.timestamp
    //             );

    //             uint256 swappingProceeds = address(this).balance - preSwapBalance;

    //             // share of fees that were swapped to ETH
    //             uint256 totalSwapShare = memorySellFee.total -/* 6% */
    //                 memorySellFee.reflection - /* 1% */ 
    //                 memorySellFee.burn; /* 0% */

    //             b2eETHbalance = b2eETHbalance + (swappingProceeds * memorySellFee.b2e / totalSwapShare);

    //             /*
    //              * Send proceeds to respective wallets, except for B2E which remains in contract.
    //              *
    //              * We don't need to use return values of low level calls here since we can just manually withdraw
    //              * funds in case of failure; receiver wallets are owner supplied though and should only be EOAs
    //              * anyway.
    //              */

    //             // marketing
    //             payable(marketingFeeReceiver).call{value: (swappingProceeds * memorySellFee.marketing) / totalSwapShare}("");
    //             // LP
    //             payable(lpFeeReceiver).call{value: (swappingProceeds * memorySellFee.lp) / totalSwapShare}("");
    //             // buyback
    //             payable(buybackFeeReceiver).call{value: (swappingProceeds * memorySellFee.buyback) / totalSwapShare}("");
    //             // treasury
    //             payable(treasuryReceiver).call{value: (swappingProceeds * memorySellFee.treasury) / totalSwapShare}("");

    //             isInSwap = 0;
    //             local_totalSubLPBalance = totalSubLPBalance;
    //         }
    //     }

    //     uint256 baseAmount = reflectionToBaseAmount(amount, sender);

    //     if (_baseBalance[sender] < baseAmount)
    //         revert InsuffcientBalance(_baseBalance[sender]);

    //     // perform basic swap
    //     if (isInSwap != 0) {

    //         _baseBalance[sender] = _baseBalance[sender] - baseAmount;
    //         _baseBalance[recipient] = _baseBalance[recipient] + baseAmount;

    //         if (senderIsPool)
    //             totalSubLPBalance = local_totalSubLPBalance + baseAmount;
    //         if (recipientIsPool)
    //             totalSubLPBalance = local_totalSubLPBalance - baseAmount;

    //         emit Transfer(sender, recipient, amount);
    //         return true;
    //     }

    //     /**
    //      * @dev this modifies LP balance and thus also reflection amount that we 
    //      * previously calculated, however the actually transferred amount will
    //      * still be based on the conversion from reflected amount to base amount
    //      * at the time of the transaction initiation and will NOT account for 
    //      * changes made here
    //      */
    //     uint256 baseAmountReceived = feesEnabled != 0
    //         ? _performReflectionAndTakeFees(baseAmount, sender, senderIsPool)
    //         : baseAmount;

    //     _baseBalance[sender] = _baseBalance[sender] - baseAmount;
    //     _baseBalance[recipient] = _baseBalance[recipient] + baseAmountReceived;

    //     if (senderIsPool)
    //         totalSubLPBalance = local_totalSubLPBalance + baseAmount;
    //     if (recipientIsPool)
    //         totalSubLPBalance = local_totalSubLPBalance - baseAmountReceived;

    //     emit Transfer(
    //         sender,
    //         recipient,
    //         baseToReflectionAmount(baseAmountReceived, recipient)
    //     );

    //     return true;
    // }

    // function _performReflectionAndTakeFees(
    //     uint256 baseAmount,
    //     address sender,
    //     bool buying
    // ) internal returns (uint256) {
    //     Fee memory memoryBuyFee = buyFee;
    //     Fee memory memorySellFee = sellFee;

    //     // amount of fees in base amount (non-reflection adjusted)
    //     uint256 baseFeeAmount = buying
    //         ? (baseAmount * memoryBuyFee.total) / MAX_BP
    //         : (baseAmount * memorySellFee.total) / MAX_BP;

    //     // reflect
    //     uint256 baseAmountReflected = buying
    //         ? (baseAmount * memoryBuyFee.reflection) / MAX_BP
    //         : (baseAmount * memorySellFee.reflection) / MAX_BP;

    //     totalReflected = totalReflected + baseAmountReflected;
    //     emit Reflect(baseAmountReflected, totalReflected);

    //     // add entire non-reflected amount to contract balance for later swapping
    //     uint256 baseBalanceToContract = baseFeeAmount - baseAmountReflected;
    //     if (baseBalanceToContract != 0) {
    //         _baseBalance[address(this)] =
    //             _baseBalance[address(this)] +
    //             baseBalanceToContract;
    //         emit Transfer(
    //             sender,
    //             address(this),
    //             baseToReflectionAmount(baseBalanceToContract, address(this))
    //         );
    //     }

    //     return baseAmount - baseFeeAmount;
    // }

// }
