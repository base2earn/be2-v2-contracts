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

contract BaseReflectionBurn is Initializable, OwnableUpgradeable, IERC20Upgradeable {

    /* -------------------------------------------------------------------------- */
    /*                                   events                                   */
    /* -------------------------------------------------------------------------- */
    error InvalidParameters();
    error ERC20InsufficientAllowance(address, address, uint);
    error InsuffcientBalance(uint);
    error InsufficientContractETHBalance(uint /* desired output */, uint /* available balance */);
    error ExceedingBurnCap(uint /* desired output */, uint /* burn cap */);
    error CannotBurnYet();
    error InvalidReferrer();
    error MaxWallet();
    error MaxTransaction();

    event Reflect(uint256 baseAmountReflected, uint256 totalReflected);
    event LaunchFee(address user, uint amount);
    event BurnedAndEarned(address, uint, uint);

    /* -------------------------------------------------------------------------- */
    /*                                  constants                                 */
    /* -------------------------------------------------------------------------- */
    string constant _name = "base2earn.com | Base Reflection'n'Burn";
    string constant _symbol = "BRB";

    // @custom:oz-upgrades-unsafe-allow state-variable-immutable
    IUniswapV2Router02 public immutable UNISWAP_V2_ROUTER;

    // --- BSC (Pancake)
    // IUniswapV2Router02 public constant UNISWAP_V2_ROUTER =
    //     IUniswapV2Router02(0x10ED43C718714eb63d5aA57B78B54704E256024E);

    // --- Polygon (Quickswap)
    // IUniswapV2Router02 public constant UNISWAP_V2_ROUTER =
    //     IUniswapV2Router02(0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff);

    // --- Fantom (Spookyswap)
    // IUniswapV2Router02 public constant UNISWAP_V2_ROUTER =
    //     IUniswapV2Router02(0xF491e7B69E4244ad4002BC14e878a34207E38c29);

    // --- Arbitrum (Camelot)
    // IUniswapV2Router02 public constant UNISWAP_V2_ROUTER =
    //     IUniswapV2Router02(0xc873fEcbd354f5A56E00E710B90EF4201db2448d);

    // --- Base (Alienbase)
    // IUniswapV2Router02 public constant UNISWAP_V2_ROUTER =
    //     IUniswapV2Router02(0x8c1A3cF8f83074169FE5D7aD50B978e1cD6b37c7);

    // --- Ethereum (Uniswap)
    // IUniswapV2Router02 public constant UNISWAP_V2_ROUTER =
    //     IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);

    address private constant DEAD = 0x000000000000000000000000000000000000dEaD;
    address private constant ZERO = 0x0000000000000000000000000000000000000000;

    uint256 private constant MAX_FEE = 1_000; /* 15% */
    uint256 private constant MAX_BP = 10_000;
    uint256 private constant LAUNCH_FEE = 3_000;
    uint256 private constant REFLECTION_GROWTH_FACTOR = 100;
    // TODO reconsider supply expansion amount
    uint256 private constant TOTAL_SUPPLY = 1_428_571_428 ether; /* 30% supply expansion on 1B tokens */

    uint256 private constant B2E_STATIC_BURN_CAP = 1 ether;
    uint256 private constant B2E_SUB_CAP_LIMIT = 0.1 ether;
    uint256 private constant B2E_CAP_DIVISOR = 10;
    // TODO reconsider launch fee duration
    uint256 private constant LAUNCH_FEE_DURATION = 5 days;
    uint256 private constant BURN_INTERVAL = 2 minutes;

    uint256 private constant MAX_WALLET = TOTAL_SUPPLY / 5;
    uint256 private constant MAX_TX = TOTAL_SUPPLY / 100;

    uint256 private immutable LAUNCH_TIME;

    /* -------------------------------------------------------------------------- */
    /*                                   states                                   */
    /* -------------------------------------------------------------------------- */

    struct Fee {
        // swap to ETH
        uint8 marketing;
        uint8 treasury;
        uint8 lp;
        uint8 buyback;

        // do not swap to ETH
        uint8 reflection;
        uint8 burn;
        uint8 b2e;

        uint128 total;
    }

    bool private liquidityInitialised;

    uint256 public feesEnabled;
    uint256 public swapThreshold; // denominated as reflected amount
    uint256 public totalReflected;
    uint256 public totalSubLPBalance; // denominated as base amount

    uint256 private isInSwap;

    uint256 private lastBurnedTimestamp;
    uint256 private totalBurnRewards;
    uint256 private totalBurned;
    uint256 private b2eETHbalance;

    address private _uniswapPair;
    address private marketingFeeReceiver;
    address private lpFeeReceiver;
    address private buybackFeeReceiver;
    address private treasuryReceiver;

    Fee public buyFee;
    Fee public sellFee;

    /* registred pools are excluded from receiving reflections */
    mapping(address => uint256) public isRegistredPool;
    mapping(address => uint256) private _baseBalance;
    mapping(address => uint256) private txLimitsExcluded;

    mapping(address => mapping(address => uint256)) private _allowances;

    //@custom:oz-upgrades-unsafe-allow state-variable-immutable
    constructor(address router) {
        UNISWAP_V2_ROUTER = IUniswapV2Router02(router);
        LAUNCH_TIME = block.timestamp;
    }

    receive() external payable {}

    function initialize(
        address newMarketingFeeReceiver,
        address newLPfeeReceiver,
        address newBuyBackFeeReceiver,
        address newTreasuryReceiver
    ) public payable initializer {

        // initialise parents
        __Ownable_init_unchained();

        totalSubLPBalance = TOTAL_SUPPLY;
        swapThreshold = TOTAL_SUPPLY * 70 / MAX_BP; /* 0.7% of total supply */

        marketingFeeReceiver = newMarketingFeeReceiver;
        lpFeeReceiver = newLPfeeReceiver;
        buybackFeeReceiver = newBuyBackFeeReceiver;
        treasuryReceiver = newTreasuryReceiver;

        buyFee = Fee({
            reflection: 100,
            buyback: 100,
            marketing: 100,
            lp: 100,
            treasury: 100,
            burn: 0,
            b2e: 100,
            total: 600
        });
        sellFee = Fee({
            reflection: 100,
            buyback: 100,
            marketing: 100,
            lp: 100,
            treasury: 100,
            burn: 0,
            b2e: 100,
            total: 600
        });
    }

    function addLiquidity(
        uint tokensForLiquidity
    ) external payable onlyOwner {
        require(TOTAL_SUPPLY  >= tokensForLiquidity);

        if (liquidityInitialised) revert();
        liquidityInitialised = true;

        // fund address(this) with desired amount of liquidity tokens
        _baseBalance[address(this)] = tokensForLiquidity;
        // baseBalance = reflected balance here
        emit Transfer(address(0), address(this), tokensForLiquidity);

        // create uniswap pair
        _uniswapPair = IUniswapV2Factory(UNISWAP_V2_ROUTER.factory())
            .createPair(address(this), UNISWAP_V2_ROUTER.WETH());

        // set unlimited allowance for uniswap router
        _allowances[address(this)][address(UNISWAP_V2_ROUTER)] = type(uint256).max;

        txLimitsExcluded[address(this)] = 1;
        txLimitsExcluded[treasuryReceiver] = 1;

        // add desired amount of liquidity to pair
        UNISWAP_V2_ROUTER.addLiquidityETH{value: msg.value}(
            address(this), // address token,
            tokensForLiquidity, // uint amountTokenDesired,
            tokensForLiquidity, // uint amountTokenMin,
            msg.value, // uint amountETHMin,
            treasuryReceiver, // address to,
            block.timestamp // uint deadline
        );

        // register pool as trading pool
        isRegistredPool[_uniswapPair] = 1;

        // mint remainig share to owner, if any
        if (tokensForLiquidity < TOTAL_SUPPLY) {
            _baseBalance[tx.origin] = TOTAL_SUPPLY - tokensForLiquidity;
            emit Transfer(
                address(0),
                treasuryReceiver,
                TOTAL_SUPPLY - tokensForLiquidity
            );
        }

        // enable fees
        feesEnabled = 1;

        // update LP balance
        // totalSubLPBalance = totalSubLPBalance - tokensForLiquidity;
    }

    /* -------------------------------------------------------------------------- */
    /*                             Public functionality                           */
    /* -------------------------------------------------------------------------- */

    // msg.sender burns tokens and receive uniswap rate TAX FREE, instead of selling.
    function burn2Earn(uint256 amount) public {

        if(balanceOf(msg.sender) < amount) revert InsuffcientBalance(amount);
        if(block.timestamp < BURN_INTERVAL + lastBurnedTimestamp) revert CannotBurnYet();

        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = UNISWAP_V2_ROUTER.WETH();

        uint[] memory outputEstimates = UNISWAP_V2_ROUTER.getAmountsOut(amount, path);
        uint256 tokenOutputEstimate = outputEstimates[outputEstimates.length - 1];

        if(b2eETHbalance < tokenOutputEstimate) revert InsufficientContractETHBalance(tokenOutputEstimate, b2eETHbalance);
        if(tokenOutputEstimate > _getBurnCapETH()) revert ExceedingBurnCap(tokenOutputEstimate, _getBurnCapETH());

        b2eETHbalance = b2eETHbalance - tokenOutputEstimate;
        
        // burn
        uint baseAmountToBurn = reflectionToBaseAmount(amount, msg.sender);
        _baseBalance[msg.sender] = _baseBalance[msg.sender] - baseAmountToBurn;
        totalSubLPBalance = totalSubLPBalance - baseAmountToBurn;
        emit Transfer(msg.sender, address(0), amount);

        // transfer return amount to sender
        payable(msg.sender).call{value: tokenOutputEstimate}("");
        
        totalBurnRewards = totalBurnRewards + tokenOutputEstimate;
        totalBurned = totalBurned + amount;
        lastBurnedTimestamp = block.timestamp;

        emit BurnedAndEarned(msg.sender, amount, tokenOutputEstimate);
    }

    /* -------------------------------------------------------------------------- */
    /*                                    ERC20                                   */
    /* -------------------------------------------------------------------------- */

    function approve(
        address spender,
        uint256 amount
    ) public override returns (bool) {
        _allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function approveMax(address spender) external returns (bool) {
        return approve(spender, type(uint256).max);
    }

    function transfer(
        address recipient,
        uint256 amount
    ) external override returns (bool) {
        return _transferFrom(msg.sender, recipient, amount);
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external override returns (bool) {
        if (_allowances[sender][msg.sender] != type(uint256).max) {
            if (_allowances[sender][msg.sender] < amount)
                revert ERC20InsufficientAllowance(
                    sender,
                    recipient,
                    _allowances[sender][msg.sender]
                );
            _allowances[sender][msg.sender] =
                _allowances[sender][msg.sender] -
                amount;
        }

        return _transferFrom(sender, recipient, amount);
    }

    /* -------------------------------------------------------------------------- */
    /*                                    Views                                   */
    /* -------------------------------------------------------------------------- */

    function totalSupply() external pure override returns (uint256) {
        return TOTAL_SUPPLY;
    }

    function decimals() external pure returns (uint8) {
        return 18;
    }

    function name() external pure returns (string memory) {
        return _name;
    }

    function symbol() external pure returns (string memory) {
        return _symbol;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return baseToReflectionAmount(_baseBalance[account], account);
    }

    function allowance(
        address holder,
        address spender
    ) external view override returns (uint256) {
        return _allowances[holder][spender];
    }

    function baseToReflectionAmount(
        uint256 baseAmount,
        address account
    ) public view returns (uint256) {
        uint local_totalSubLPBalance = totalSubLPBalance;
        if(isRegistredPool[account] != 0) {
            return baseAmount;
        }else{
            uint numerator = baseAmount * local_totalSubLPBalance;
            uint denominator = (REFLECTION_GROWTH_FACTOR * totalReflected) + local_totalSubLPBalance;
            return 2 * baseAmount - (numerator / denominator);
        }
    }

    function reflectionToBaseAmount(
        uint reflectionAmount, 
        address account
    ) public view returns(uint) {
        uint mem_totalSubLPBal = totalSubLPBalance;
        if(isRegistredPool[account] != 0) {
            return reflectionAmount;
        }else{
            uint numerator = (REFLECTION_GROWTH_FACTOR * totalReflected) + mem_totalSubLPBal;
            uint denominator = (2 * REFLECTION_GROWTH_FACTOR * totalReflected) + mem_totalSubLPBal;
            return reflectionAmount * numerator / denominator;
        }
    }

    // max amount of ETH returned when burning
    function _getBurnCapETH() internal view returns(uint256) {
        uint mem_b2eETHbalance = b2eETHbalance;
        return mem_b2eETHbalance <= B2E_STATIC_BURN_CAP
            ? B2E_SUB_CAP_LIMIT
            : mem_b2eETHbalance / B2E_CAP_DIVISOR;
    }

    function getB2Einfo() external view returns(
        uint256 _totalBurned, 
        uint256 _totalBurnRewards, 
        uint256 _b2eETHbalance,
        uint256 _timeToNextBurn,
        uint256 _maxTokensToBurn,
        uint256 _burnCapInEth,
        uint256 _maxEthOutput
    ) {
        _totalBurned = totalBurned;
        _totalBurnRewards = totalBurnRewards;
        _b2eETHbalance = b2eETHbalance;
        _timeToNextBurn = 
            (block.timestamp - lastBurnedTimestamp >= BURN_INTERVAL)
            ? 0 
            : BURN_INTERVAL - (block.timestamp - lastBurnedTimestamp);
        _burnCapInEth = _getBurnCapETH();

        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = UNISWAP_V2_ROUTER.WETH();

        if(_b2eETHbalance > 0.000001 ether) {
            uint[] memory maxInputInTokensArr = UNISWAP_V2_ROUTER.getAmountsIn(
                _burnCapInEth < _b2eETHbalance
                    ? _burnCapInEth
                    : _b2eETHbalance, 
                path
            );
            _maxTokensToBurn = maxInputInTokensArr[0];

            uint[] memory outputEstimates = UNISWAP_V2_ROUTER.getAmountsOut(_maxTokensToBurn, path);
            uint tokenOutputEstimate = outputEstimates[outputEstimates.length - 1];
            _maxEthOutput = _burnCapInEth < tokenOutputEstimate ? _burnCapInEth : tokenOutputEstimate;
        }
    }

    function getMaxWalletAndTx() external view returns(uint, uint) {
        return (
            baseToReflectionAmount(MAX_WALLET, address(0)),
            baseToReflectionAmount(MAX_TX, address(0))
        );
    }

    /* -------------------------------------------------------------------------- */
    /*                               Access restricted                            */
    /* -------------------------------------------------------------------------- */

    function clearStuckBalance() external payable onlyOwner {
        (bool success, ) = payable(msg.sender).call{
            value: address(this).balance
        }("");
        require(success);
    }

    function clearStuckToken() external payable onlyOwner {
        _transferFrom(address(this), msg.sender, balanceOf(address(this)));
    }

    function setSwapBackSettings(
        uint256 _enabled /* 0 = false, 1 = true */,
        uint256 _amount
    ) external payable onlyOwner {
        feesEnabled = _enabled;
        swapThreshold = _amount;
    }

    function changeFees(
        Fee calldata _buyFee,
        Fee calldata _sellFee
    ) external payable onlyOwner {
        // can cast all numbers, or just the first to save gas I think, not sure what the saving differences are like
        uint128 totalBuyFee = uint128(_buyFee.reflection) +
            _buyFee.marketing +
            _buyFee.treasury +
            _buyFee.lp +
            _buyFee.buyback +
            _buyFee.burn;

        uint128 totalSellFee = uint128(_sellFee.reflection) +
            _sellFee.marketing +
            _sellFee.treasury +
            _sellFee.lp +
            _sellFee.buyback +
            _sellFee.burn;

        if (
            totalBuyFee != _buyFee.total ||
            totalSellFee != _sellFee.total ||
            totalBuyFee > MAX_FEE ||
            totalSellFee > MAX_FEE
        ) revert InvalidParameters();

        buyFee = _buyFee;
        sellFee = _sellFee;
    }

    function setFeeReceivers(
        address newMarketingFeeReceiver,
        address newLPfeeReceiver,
        address newBuybackFeeReceiver,
        address newTreasuryReceiver
    ) external payable onlyOwner {
        marketingFeeReceiver = newMarketingFeeReceiver;
        lpFeeReceiver = newLPfeeReceiver;
        buybackFeeReceiver = newBuybackFeeReceiver;
        treasuryReceiver = newTreasuryReceiver;
    }

    function setRegistredPool(
        address pool,
        uint state
    ) external payable onlyOwner {
        isRegistredPool[pool] = state;
        if (state != 0) {
            totalSubLPBalance = totalSubLPBalance + _baseBalance[pool];
        }
        else {
            totalSubLPBalance = totalSubLPBalance - _baseBalance[pool];
        }
    }

    /* -------------------------------------------------------------------------- */
    /*                                   Internal                                 */
    /* -------------------------------------------------------------------------- */

    function _transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) internal returns (bool) {

        bool senderIsPool = isRegistredPool[sender] != 0; // = buy
        bool recipientIsPool = isRegistredPool[recipient] != 0; // = sell

        // take launch fee first
        uint baseLaunchFeeAmount;
        uint local_totalSubLPBalance = totalSubLPBalance;

        // take launch fee
        if (
            feesEnabled != 0 &&
            !senderIsPool &&
            isInSwap == 0 &&
            block.timestamp - LAUNCH_TIME < LAUNCH_FEE_DURATION
        ) {
            isInSwap = 1;

            // swap back
            address[] memory path = new address[](2);
            path[0] = address(this);
            path[1] = UNISWAP_V2_ROUTER.WETH();

            uint reflectedLaunchFeeAmount =
                amount *
                LAUNCH_FEE *
                (LAUNCH_FEE_DURATION - (block.timestamp - LAUNCH_TIME)) /
                LAUNCH_FEE_DURATION /
                MAX_BP;

            baseLaunchFeeAmount = reflectionToBaseAmount(reflectedLaunchFeeAmount, sender);

            _baseBalance[address(this)] = _baseBalance[address(this)] + baseLaunchFeeAmount;
            emit Transfer(sender, address(this), reflectedLaunchFeeAmount);
            emit LaunchFee(sender, reflectedLaunchFeeAmount);

            UNISWAP_V2_ROUTER.swapExactTokensForETHSupportingFeeOnTransferTokens(
                reflectedLaunchFeeAmount,
                0,
                path,
                treasuryReceiver,
                block.timestamp
            );

            isInSwap = 0;
            local_totalSubLPBalance = totalSubLPBalance;
        }

        // Swap contract token balance against pool if conditions are fulfilled
        // this has to be done before calculating baseAmount since it shifts
        // the balance in the liquidity pool, thus altering the result
        {
            // wrap into block since it's agnostic to function state
            if (
                isInSwap == 0 &&
                // this only swaps if it's not a buy, amplifying impacts of sells and 
                // leaving buys untouched but also shifting gas costs of this to sellers only
                !senderIsPool &&
                feesEnabled != 0 &&
                balanceOf(address(this)) >= swapThreshold
            ) {
                isInSwap = 1;

                Fee memory memorySellFee = sellFee;
                
                uint256 stack_SwapThreshold = swapThreshold;
                uint256 amountToBurn = stack_SwapThreshold * memorySellFee.burn / memorySellFee.total;
                uint256 amountToSwap = stack_SwapThreshold - amountToBurn;
                
                // burn, no further checks needed here
                uint baseAmountToBurn = reflectionToBaseAmount(amountToBurn, address(this));
                _baseBalance[address(this)] = _baseBalance[address(this)] - baseAmountToBurn;
                _baseBalance[DEAD] = _baseBalance[DEAD] + baseAmountToBurn;

                uint preSwapBalance = address(this).balance;

                // swap non-burned tokens to ETH
                address[] memory path = new address[](2);
                path[0] = address(this);
                path[1] = UNISWAP_V2_ROUTER.WETH();

                UNISWAP_V2_ROUTER.swapExactTokensForETHSupportingFeeOnTransferTokens(
                    amountToSwap,
                    0,
                    path,
                    address(this),
                    block.timestamp
                );

                uint256 swappingProceeds = address(this).balance - preSwapBalance;

                // share of fees that were swapped to ETH
                uint256 totalSwapShare = memorySellFee.total -/* 6% */
                    memorySellFee.reflection - /* 1% */ 
                    memorySellFee.burn; /* 0% */

                b2eETHbalance = b2eETHbalance + (swappingProceeds * memorySellFee.b2e / totalSwapShare);

                /*
                 * Send proceeds to respective wallets, except for B2E which remains in contract.
                 *
                 * We don't need to use return values of low level calls here since we can just manually withdraw
                 * funds in case of failure; receiver wallets are owner supplied though and should only be EOAs
                 * anyway.
                 */

                // marketing
                payable(marketingFeeReceiver).call{value: (swappingProceeds * memorySellFee.marketing) / totalSwapShare}("");
                // LP
                payable(lpFeeReceiver).call{value: (swappingProceeds * memorySellFee.lp) / totalSwapShare}("");
                // buyback
                payable(buybackFeeReceiver).call{value: (swappingProceeds * memorySellFee.buyback) / totalSwapShare}("");
                // treasury
                payable(treasuryReceiver).call{value: (swappingProceeds * memorySellFee.treasury) / totalSwapShare}("");

                isInSwap = 0;
                local_totalSubLPBalance = totalSubLPBalance;
            }
        }

        uint256 baseAmount = reflectionToBaseAmount(amount, sender);

        if (_baseBalance[sender] < baseAmount)
            revert InsuffcientBalance(_baseBalance[sender]);

        // perform basic swap
        if (isInSwap != 0) {

            if(
                !senderIsPool && 
                feesEnabled != 0 && 
                txLimitsExcluded[sender] == 0 && 
                baseAmount > MAX_TX
            )
                revert MaxTransaction();

            if(
                !recipientIsPool && 
                feesEnabled != 0 &&
                txLimitsExcluded[recipient] == 0 &&
                _baseBalance[recipient] + baseAmount > MAX_WALLET
            )
                revert MaxWallet();

            _baseBalance[sender] = _baseBalance[sender] - baseAmount;
            _baseBalance[recipient] = _baseBalance[recipient] + baseAmount;

            if (senderIsPool)
                totalSubLPBalance = local_totalSubLPBalance + baseAmount;
            if (recipientIsPool)
                totalSubLPBalance = local_totalSubLPBalance - baseAmount;

            emit Transfer(sender, recipient, amount);
            return true;
        }

        /**
         * @dev this modifies LP balance and thus also reflection amount that we 
         * previously calculated, however the actually transferred amount will
         * still be based on the conversion from reflected amount to base amount
         * at the time of the transaction initiation and will NOT account for 
         * changes made here
         */
        uint256 baseAmountReceived = feesEnabled != 0
            ? _performReflectionAndTakeFees(baseAmount, sender, senderIsPool)
            : baseAmount;

        if(
            !senderIsPool && 
            feesEnabled != 0 &&
            txLimitsExcluded[sender] == 0 && 
            baseAmount > MAX_TX
        )
            revert MaxTransaction();

        if(
            feesEnabled != 0 &&
            !recipientIsPool &&
            txLimitsExcluded[recipient] == 0 &&
            _baseBalance[recipient] + baseAmountReceived > MAX_WALLET
        )
            revert MaxWallet();

        _baseBalance[sender] = _baseBalance[sender] - baseAmount;
        _baseBalance[recipient] = _baseBalance[recipient] + baseAmountReceived;

        if (senderIsPool)
            totalSubLPBalance = local_totalSubLPBalance + baseAmount;
        if (recipientIsPool)
            totalSubLPBalance = local_totalSubLPBalance - baseAmountReceived;

        emit Transfer(
            sender,
            recipient,
            baseToReflectionAmount(baseAmountReceived, recipient)
        );

        return true;
    }

    function _performReflectionAndTakeFees(
        uint256 baseAmount,
        address sender,
        bool buying
    ) internal returns (uint256) {
        Fee memory memoryBuyFee = buyFee;
        Fee memory memorySellFee = sellFee;

        // amount of fees in base amount (non-reflection adjusted)
        uint256 baseFeeAmount = buying
            ? (baseAmount * memoryBuyFee.total) / MAX_BP
            : (baseAmount * memorySellFee.total) / MAX_BP;

        // reflect
        uint256 baseAmountReflected = buying
            ? (baseAmount * memoryBuyFee.reflection) / MAX_BP
            : (baseAmount * memorySellFee.reflection) / MAX_BP;

        totalReflected = totalReflected + baseAmountReflected;
        emit Reflect(baseAmountReflected, totalReflected);

        // add entire non-reflected amount to contract balance for later swapping
        uint256 baseBalanceToContract = baseFeeAmount - baseAmountReflected;
        if (baseBalanceToContract != 0) {
            _baseBalance[address(this)] =
                _baseBalance[address(this)] +
                baseBalanceToContract;
            emit Transfer(
                sender,
                address(this),
                baseToReflectionAmount(baseBalanceToContract, address(this))
            );
        }

        return baseAmount - baseFeeAmount;
    }

}
