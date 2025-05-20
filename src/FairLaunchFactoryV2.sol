// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "v4-core/src/interfaces/IPoolManager.sol";
import "v4-core/src/types/PoolKey.sol";
import "v4-core/src/libraries/TickMath.sol";
import "v4-core/src/types/PoolId.sol";
import "v4-core/test/utils/LiquidityAmounts.sol";
import {IPoolInitializer_v4} from "v4-periphery/src/interfaces/IPoolInitializer_v4.sol";
import "v4-periphery/src/libraries/Actions.sol";
import {IPositionManager} from "v4-periphery/src/interfaces/IPositionManager.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "permit2/src/interfaces/IAllowanceTransfer.sol";
import "./RollupToken.sol";

contract FairLaunchFactoryV2 {

    IPoolManager public immutable poolManager;
    IERC20 public defaultPairToken;

    uint24 public constant POOL_FEE = 10_000;
    int24 public constant TICK_SPACING = 200;

    // --- liquidity position configuration --- //
    uint256 public token0Amount = 1e18;
    uint256 public token1Amount = 1e18;

    // positionManager on Sepolia
    IPositionManager constant positionManager = IPositionManager(address(0x429ba70129df741B2Ca2a85BC3A2a3328e5c09b4));
    // Permit2 is deployed to the same address across mainnet, Ethereum, Optimism, Arbitrum, Polygon, and Celo.
    // Note: Permit2 is also deployed to the same address on testnet Sepolia.
    IAllowanceTransfer constant PERMIT2 = IAllowanceTransfer(address(0x000000000022D473030F116dDEE9F6B43aC78BA3));

    struct FeeConfig {
        uint16 creatorLPFeeBps;
        uint16 protocolBaseBps;
        uint16 creatorBaseBps;
        uint16 airdropBps;
        bool hasAirdrop;
        address feeToken;
        address creator;
    }

    mapping(address => FeeConfig) public tokenFeeConfig;
    mapping(PoolId => address) public poolToToken;

    address public platformReserve;

    string public baseTokenURI;


    /*//////////////////////////////////////////////////////////////
                                EVENT
    //////////////////////////////////////////////////////////////*/

    event TokenLaunched(address token, address creator, PoolId poolId);


    constructor(IPoolManager _poolManager, IERC20 _defaultPairToken, address _platformReserve) {
        poolManager = _poolManager;
        defaultPairToken = _defaultPairToken;
        platformReserve = _platformReserve;
    }

    /// @notice Launch a new token and register a Uniswap v4 pool
    function launchToken(
        string memory name,
        string memory symbol,
        uint256 supply,
        bytes32 merkleroot,
        int24 initialTick,
        bytes32 salt,
        address creator
    ) public {
        require(supply > 0, "ZeroSupply");

        (uint256 lpSupply, uint256 creatorAmount, uint256 protocolAmount, uint256 airdropAmount) =
            calculateSupplyAllocation(supply, merkleroot != bytes32(0));

        string memory tokenURI = string(abi.encodePacked(baseTokenURI, toHex(keccak256(abi.encodePacked(name, symbol, merkleroot)))));

        address newToken = address(new RollupToken(name, symbol));

        RollupToken rollupToken = RollupToken(newToken);

        // Mint allocations
        RollupToken(newToken).mint(creator, creatorAmount);
        RollupToken(newToken).mint(platformReserve, protocolAmount);
        RollupToken(newToken).mint(address(this), lpSupply);

        // Set FeeConfig
        FeeConfig memory config = FeeConfig({
            creatorLPFeeBps: 5000,
            protocolBaseBps: 200,
            creatorBaseBps: 50,
            airdropBps: 50,
            hasAirdrop: merkleroot != bytes32(0),
            feeToken: address(defaultPairToken),
            creator: creator
        });
        tokenFeeConfig[newToken] = config;

        // Construct pool key
        PoolKey memory key = PoolKey({
            currency0: Currency.wrap(newToken),
            currency1: Currency.wrap(address(defaultPairToken)),
            fee: POOL_FEE,
            tickSpacing: TICK_SPACING,
            hooks: IHooks(address(0x0)) // no hooks used
        });

        PoolId poolId = key.toId();
        poolToToken[poolId] = newToken;

        // Option 1: Initialize the pool, called when no need to add initial liquidity
        // poolManager.initialize(key, TickMath.getSqrtPriceAtTick(initialTick));

        // Option 2: Add initial liquidity

        // range of the position
        int24 tickLower = initialTick; // must be a multiple of tickSpacing
        int24 tickUpper = TickMath.maxUsableTick(TICK_SPACING);
        // slippage limits
        uint256 amount0Max = token0Amount + 1 wei;
        uint256 amount1Max = token1Amount + 1 wei;

        // starting price of the pool, in sqrtPriceX96
        uint160 startingPrice = TickMath.getSqrtPriceAtTick(initialTick);
        // Converts token amounts to liquidity units
        uint128 liquidity = LiquidityAmounts.getLiquidityForAmounts(
            startingPrice,
            TickMath.getSqrtPriceAtTick(tickLower),
            TickMath.getSqrtPriceAtTick(tickUpper),
            token0Amount,
            token1Amount
        );

        bytes memory hookData = ""; // no hook data
        (bytes memory actions, bytes[] memory mintParams) =
            _mintLiquidityParams(key, tickLower, tickUpper, liquidity, amount0Max, amount1Max, address(this), hookData);

        // the parameters provided to multicall()
        bytes[] memory params = new bytes[](2);

        // The first call, params[0], will encode initializePool parameters
        params[0] = abi.encodeWithSelector(
            IPoolInitializer_v4.initializePool.selector,
            key,
            TickMath.getSqrtPriceAtTick(initialTick)
        );

        uint256 deadline = block.timestamp + 60;
        // mint liquidity
        params[1] = abi.encodeWithSelector(
            IPositionManager(positionManager).modifyLiquidities.selector, abi.encode(actions, mintParams), deadline
        );

        // approve the tokens

        // approve the defaultPairToken
        defaultPairToken.approve(address(PERMIT2), type(uint256).max);
        // Approves the spender, positionManager, to use up to amount of the specified token up until the expiration
        PERMIT2.approve(address(defaultPairToken), address(positionManager), type(uint160).max, type(uint48).max);
        // approve the newToken
        IERC20(newToken).approve(address(PERMIT2), type(uint256).max);
        PERMIT2.approve(address(newToken), address(positionManager), type(uint160).max, type(uint48).max);

        // if the pool is an ETH pair, native tokens are to be transferred
        uint256 valueToPass = address(defaultPairToken) == address(0) ? amount0Max : 0;

        // multicall to atomically create pool & add liquidity
        IPositionManager(positionManager).multicall{value: valueToPass}(params);

        emit TokenLaunched(newToken, msg.sender, poolId);
    }


    /// @dev helper function for encoding mint liquidity operation
    /// @dev does NOT encode SWEEP, developers should take care when minting liquidity on an ETH pair
    function _mintLiquidityParams(
        PoolKey memory poolKey,
        int24 _tickLower,
        int24 _tickUpper,
        uint256 liquidity,
        uint256 amount0Max,
        uint256 amount1Max,
        address recipient,
        bytes memory hookData
    ) internal pure returns (bytes memory, bytes[] memory) {
        bytes memory actions = abi.encodePacked(uint8(Actions.MINT_POSITION), uint8(Actions.SETTLE_PAIR));

        bytes[] memory params = new bytes[](2);
        params[0] = abi.encode(poolKey, _tickLower, _tickUpper, liquidity, amount0Max, amount1Max, recipient, hookData);
        params[1] = abi.encode(poolKey.currency0, poolKey.currency1);
        return (actions, params);
    }    
    
    /*
    /// @notice Fee distribution logic to be called during hooks
    function afterSwap(address, PoolKey calldata key, IPoolManager.SwapParams calldata, BalanceDelta delta, bytes calldata)
        external
        override
        returns (bytes4)
    {
        address token = poolToToken[key.toId()];
        FeeConfig memory config = tokenFeeConfig[token];

        uint256 totalFee0 = uint256(int256(-delta.amount0()));
        uint256 creatorCut = (totalFee0 * config.creatorLPFeeBps) / 10_000;
        uint256 platformCut = totalFee0 - creatorCut;

        ERC20(Currency.unwrap(key.currency0)).transfer(config.creator, creatorCut);
        ERC20(Currency.unwrap(key.currency0)).transfer(platformReserve, platformCut);

        return IHooks.afterSwap.selector;
    }
    */

    function calculateSupplyAllocation(uint256 totalSupply, bool hasAirdrop)
        internal
        view
        returns (uint256 lpAmount, uint256 creatorAmount, uint256 protocolAmount, uint256 airdropAmount)
    {
        if (hasAirdrop) {
            creatorAmount = (totalSupply * 50) / 10_000;
            protocolAmount = (totalSupply * 200) / 10_000;
            airdropAmount = (totalSupply * 50) / 10_000;
        } else {
            creatorAmount = (totalSupply * 100) / 10_000;
            protocolAmount = (totalSupply * 200) / 10_000;
            airdropAmount = 0;
        }
        lpAmount = totalSupply - creatorAmount - protocolAmount - airdropAmount;
    }

    function toHex(bytes32 data) internal pure returns (string memory) {
        bytes memory hexChars = "0123456789abcdef";
        bytes memory str = new bytes(64);
        for (uint i = 0; i < 32; i++) {
            str[i * 2] = hexChars[uint8(data[i] >> 4)];
            str[1 + i * 2] = hexChars[uint8(data[i] & 0x0f)];
        }
        return string(str);
    }
}
