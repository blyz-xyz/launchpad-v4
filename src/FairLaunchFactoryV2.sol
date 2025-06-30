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
import {IV4Router} from "v4-periphery/src/interfaces/IV4Router.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "permit2/src/interfaces/IAllowanceTransfer.sol";
import "universal-router/contracts/libraries/Commands.sol";
import "universal-router/contracts/UniversalRouter.sol";
import "./RollupToken.sol";

contract FairLaunchFactoryV2 is IERC721Receiver, Ownable {
    using SafeERC20 for IERC20;
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error InvalidToken();
    error NoFeesToClaim();
    error Unauthorized();
    error NotUniswapPositionManager();
    error Deprecated();
    error InsufficientLaunchFee();
    error PairTokenNotSupported();

    IPoolManager public immutable poolManager;
    bool public deprecated = false; // if true, the factory is deprecated and no new tokens can be launched
    uint256 public launchFee = 0 ether; // launch fee in ETH, can be set by the protocol owner
    uint256 public launchFeeAccrued = 0 ether; // total launch fees accrued by the factory

    // fee expressed in pips, i.e. 10000 = 1%
    uint24 public constant POOL_FEE = 10_000;
    // 200 tick-spacing = 1% fee, 400 tick-spacing = 2% fee
    int24 public constant TICK_SPACING = 200;
    // if (tick % tickSpacing != 0) revert TickMisaligned(tick, tickSpacing); // custom error 0xd4d8f3e6
    uint256 public constant TOTAL_SUPPLY = 1_000_000_000 ether; // 1 billion with 18 decimals

    // positionManager on Sepolia
    // IPositionManager public immutable positionManager = IPositionManager(address(0x429ba70129df741B2Ca2a85BC3A2a3328e5c09b4));
    IPositionManager public immutable positionManager;
    // Permit2 is deployed to the same address across mainnet, Ethereum, Optimism, Arbitrum, Polygon, and Celo.
    // Note: Permit2 is also deployed to the same address on testnet Sepolia.
    // IAllowanceTransfer public immutable PERMIT2 = IAllowanceTransfer(address(0x000000000022D473030F116dDEE9F6B43aC78BA3));
    IAllowanceTransfer public immutable PERMIT2;

    /// @dev The UniversalRouter contract is used to execute swaps and other actions
    UniversalRouter public immutable router;

    /*//////////////////////////////////////////////////////////////
                              FEE CONFIG
    //////////////////////////////////////////////////////////////*/

    struct FeeConfig {
        // Creator's share of LP fees (in basis points, max 10000)
        uint16 creatorLPFeeBps;
        // Protocol's base fee from initial supply (in basis points)
        uint16 protocolBaseBps;
        // Creator's fee from initial supply (in basis points)
        uint16 creatorBaseBps;
        // Fee Token
        address feeToken;
        // Creator address for this token
        address creator;
    }

    struct UnclaimedFees {
        uint128 unclaimed0;
        uint128 unclaimed1;
    }

    mapping(address => FeeConfig) public tokenFeeConfig;
    mapping(PoolId => address) public poolToToken;
    mapping(address => bool) public pairTokenSupported;

    address public platformReserve;

    string public baseTokenURI;

    /// @dev Default fee configuration
    FeeConfig public defaultFeeConfig = FeeConfig({
        creatorLPFeeBps: uint16(POOL_FEE / 2), // 50% of LP fees to creator (50% implicit Protocol LP fee)
        protocolBaseBps: 100, // 1.00% to protocol
        creatorBaseBps: 100, // 1.00% to creator
        feeToken: address(0),
        creator: address(0)
    });

    /// @dev The mapping from token address to its liquidity position ID
    mapping(address => uint256) public tokenPositionIds;

    /// @dev The mapping from tokenId to creator's unclaimed fees
    mapping(uint256 => UnclaimedFees) public creatorUnclaimedFees;

    /// @dev The mapping from tokenId to protocol's unclaimed fees
    mapping(uint256 => UnclaimedFees) public protocolUnclaimedFees;

    /*//////////////////////////////////////////////////////////////
                                EVENT
    //////////////////////////////////////////////////////////////*/

    event TokenLaunched(address token, address creator, PoolId poolId, uint256 tokenId);

    /// @param tokenId The ID of the NFT Position
    /// @param creatorFee0 The amount of token0 fees for the creator
    /// @param creatorFee1 The amount of token1 fees for the creator
    /// @param protocolFee0 The amount of token0 fees for the protocol
    /// @param protocolFee1 The amount of token1 fees for the protocol
    event FeesCollected(uint256 indexed tokenId, uint256 creatorFee0, uint256 creatorFee1, uint256 protocolFee0, uint256 protocolFee1);

    /// @param recipient The address of the recipient
    /// @param tokenId The ID of the NFT Position
    /// @param amount0 The amount of token0 fees claimed
    /// @param amount1 The amount of token1 fees claimed
    event FeesClaimed(address indexed recipient, uint256 indexed tokenId, uint256 amount0, uint256 amount1);

    /// @notice Emitted when the default pair token is set
    /// @param newPairToken The address of the new default pair token
    /// @param support Whether the pair token is supported or not
    event AddPairToken(address indexed newPairToken, bool support);

    /// @notice Emitted when the base token URI is set
    /// @param newBaseTokenURI The new base token URI
    /// @dev This URI is used to construct the token URI for each token
    /// @dev The token URI is constructed as baseTokenURI + tokenURI
    event SetBaseTokenURI(string newBaseTokenURI);

    /// @notice Emitted when ETH is received by the contract
    event Received(address, uint);

    /// @notice Emitted when the fallback function is called
    event FallbackCalled(address sender, uint amount, bytes data);

    /// @notice Emitted when the factory is deprecated
    event SetDeprecated(bool deprecated);

    /// @notice Emitted when the launch fee is set
    /// @param newLaunchFee The new launch fee in wei
    event SetLaunchFee(uint256 newLaunchFee);

    constructor(
        address _poolManager,
        address _positionManager,
        address _permit2,
        address payable _universalRouter,
        address _platformReserve,
        address _protocolOwner,
        string memory _baseTokenURI
    ) 
        Ownable(_protocolOwner)
    {
        poolManager = IPoolManager(_poolManager);
        positionManager = IPositionManager(_positionManager);
        PERMIT2 = IAllowanceTransfer(_permit2);
        router = UniversalRouter(_universalRouter);
        platformReserve = _platformReserve;
        baseTokenURI = _baseTokenURI;
        // ETH, CurrencyLibrary.ADDRESS_ZERO, is supported by default
        pairTokenSupported[address(0)] = true; // ETH is supported by default
    }


    /// @notice Launch a new token and register a Uniswap v4 pool
    function launchToken(
        string memory name,
        string memory symbol,
        string memory tokenURI,
        int24 initialTick,
        address creator,
        address pairToken, // the token to be used as a pair token
        uint128 amountIn // amount of token 0 to swap for the new token
    ) public payable
        returns (RollupToken newToken)
    {

        if (deprecated) 
            revert Deprecated();

        if (msg.value < launchFee)
            revert InsufficientLaunchFee();

        if (pairTokenSupported[pairToken] == false)
            revert PairTokenNotSupported();

        (uint256 lpSupply, uint256 creatorAmount, uint256 protocolAmount) =
            calculateSupplyAllocation(TOTAL_SUPPLY);

        // string memory tokenURI = string(abi.encodePacked(baseTokenURI, toHex(keccak256(abi.encodePacked(name, symbol, merkleroot)))));

        newToken = new RollupToken(
            name,
            symbol,
            string.concat(baseTokenURI, tokenURI),
            creator,
            creatorAmount,
            platformReserve,
            protocolAmount,
            address(this),
            lpSupply
        );

        // Set FeeConfig
        // Set up fee configuration
        FeeConfig memory config = FeeConfig({
            creatorLPFeeBps: defaultFeeConfig.creatorLPFeeBps,
            protocolBaseBps: defaultFeeConfig.protocolBaseBps,
            creatorBaseBps: defaultFeeConfig.creatorBaseBps,
            feeToken: address(pairToken), // default fee token is ETH
            creator: creator
        });
        tokenFeeConfig[address(newToken)] = config;

        // the default pair token is ETH, CurrencyLibrary.ADDRESS_ZERO
        address token0 = address(pairToken);
        address token1 = address(newToken);    
        uint256 amount0 = 0;
        uint256 amount1 = lpSupply;
        int24 tickLower = TickMath.minUsableTick(TICK_SPACING);
        int24 tickUpper = initialTick;
        uint160 startingPrice = TickMath.getSqrtPriceAtTick(initialTick);

        // Construct pool key
        // PoolKey must have currencies where address(currency0) < address(currency1), otherwise it will revert with CurrenciesOutOfOrderOrEqual error
        if (address(newToken) < address(pairToken)) {
            token0 = address(newToken);
            token1 = address(pairToken);
            amount0 = lpSupply;
            amount1 = 0;
            tickLower = -initialTick; // must be a multiple of tickSpacing
            tickUpper = TickMath.maxUsableTick(TICK_SPACING);
            startingPrice = TickMath.getSqrtPriceAtTick(-initialTick);
        }

        PoolKey memory key = PoolKey({
            currency0: Currency.wrap(token0),
            currency1: Currency.wrap(token1),
            fee: POOL_FEE,
            tickSpacing: TICK_SPACING,
            hooks: IHooks(address(0x0)) // no hooks used
        });

        PoolId poolId = key.toId();
        poolToToken[poolId] = address(newToken);

        uint128 liquidity = LiquidityAmounts.getLiquidityForAmounts(
            startingPrice,
            TickMath.getSqrtPriceAtTick(tickLower),
            TickMath.getSqrtPriceAtTick(tickUpper),
            amount0,
            amount1
        );

        bytes memory hookData = ""; // no hook data
        (bytes memory actions, bytes[] memory mintParams) =
            _mintLiquidityParams(key, tickLower, tickUpper, liquidity, amount0, amount1, address(this), hookData);

        // the parameters provided to multicall()
        bytes[] memory params = new bytes[](2);

        // The first call, params[0], will encode initializePool parameters
        params[0] = abi.encodeWithSelector(
            IPoolInitializer_v4.initializePool.selector,
            key,
            startingPrice // TickMath.getSqrtPriceAtTick(initialTick)
        );

        uint256 deadline = block.timestamp + 60;
        // mint liquidity
        params[1] = abi.encodeWithSelector(
            IPositionManager(positionManager).modifyLiquidities.selector, abi.encode(actions, mintParams), deadline
        );

        // approve the tokens

        // approve the pairToken
        // Note: if the pairToken is ETH, we don't need to approve it
        if (address(pairToken) != address(0)) {
            // if the pairToken is an ERC20 token, we need to approve it
            IERC20(pairToken).approve(address(PERMIT2), type(uint256).max);
            // Approves the spender, positionManager, to use up to amount of the specified token up until the expiration
            PERMIT2.approve(address(pairToken), address(positionManager), type(uint160).max, type(uint48).max);
            // PERMIT2.approve(address(pairToken), address(router), type(uint160).max, type(uint48).max);
        }

        // approve the newToken
        IERC20(newToken).approve(address(PERMIT2), type(uint256).max);
        PERMIT2.approve(address(newToken), address(positionManager), type(uint160).max, type(uint48).max);

        // if the pool is an ETH pair, native tokens are to be transferred
        // uint256 valueToPass = address(pairToken) == address(0) ? msg.value - (amountIn + launchFee) : 0;

        // get the ID that will be used for the next minted liquidity position
        uint256 tokenId = IPositionManager(positionManager).nextTokenId();

        // multicall to atomically create pool & add liquidity
        IPositionManager(positionManager).multicall(params);

        // Store the position ID
        tokenPositionIds[address(newToken)] = tokenId;

        emit TokenLaunched(address(newToken), creator, key.toId(), tokenId);     

        /// @notice Check if to execute creator buy
        if (amountIn == 0)
            return newToken; // no creator buy, just finish the function

        if (address(pairToken) != address(0)) {
            PERMIT2.approve(address(pairToken), address(router), type(uint160).max, type(uint48).max);
        }

        if (address(pairToken) != address(0)) {
            // if the pairToken is an ERC20 token, we need to transfer it to the contract
            bool success = IERC20(pairToken).transferFrom(msg.sender, address(this), amountIn);
            require(success, "Transfer failed");
        } else {
            // if the pairToken is ETH, we assume the amountIn is already sent with the transaction
            require(msg.value == amountIn + launchFee, "ETH sent incorrectly");
        }

        // allow creator to buy the token
        bytes memory commands = abi.encodePacked(uint8(Commands.V4_SWAP));
        // Encode V4Router actions
        bytes memory swapActions = abi.encodePacked(
            uint8(Actions.SWAP_EXACT_IN_SINGLE),
            uint8(Actions.SETTLE),
            uint8(Actions.TAKE_ALL)
        );

        bytes[] memory swapParams = new bytes[](3);

        // First parameter: swap configuration
        swapParams[0] = abi.encode(
            IV4Router.ExactInputSingleParams({
                poolKey: key,
                zeroForOne: address(pairToken) < address(newToken), // true if we're swapping token0 for token1
                amountIn: amountIn, // amount of tokens we're swapping
                amountOutMinimum: 0, // minimum amount we expect to receive
                hookData: bytes("") // no hook data needed
            })
        );

        // Second parameter: specify input tokens for the swap
        // encode SETTLE_ALL parameters
        swapParams[1] = abi.encode(key.currency0, amountIn, true);

        // Third parameter: specify output tokens from the swap
        swapParams[2] = abi.encode(key.currency1, 0);

        if (address(newToken) < address(pairToken)) {
            swapParams[1] = abi.encode(key.currency1, amountIn, true);
            swapParams[2] = abi.encode(key.currency0, 0);
        }

        // execute the swap
        bytes[] memory inputs = new bytes[](1);

        // Combine actions and params into inputs
        inputs[0] = abi.encode(swapActions, swapParams);

        // check the balances of the token and the pairToken before collecting fees
        uint256 tokenBalanceBeforeSwap = IERC20(newToken).balanceOf(address(this));

        // Execute the swap
        router.execute{value: msg.value - launchFee}(commands, inputs, block.timestamp + 60);

        uint256 tokenBalanceAfterSwap = IERC20(newToken).balanceOf(address(this));

        // since the swapped token is received in the contract, we can transfer it to the creator
        uint256 amountReceived = tokenBalanceAfterSwap - tokenBalanceBeforeSwap;
        if (amountReceived > 0) {
            // transfer the received tokens to the creator
            IERC20(newToken).safeTransfer(creator, amountReceived);
        }

        if (launchFee > 0)
            launchFeeAccrued += launchFee; // accumulate the launch fee
    }

    /// @notice Add/remove a pair token for the factory
    /// @param pairToken The address of the pair token
    /// @param support Whether the pair token is supported or not

    function addPairToken(address pairToken, bool support) external onlyOwner {
        pairTokenSupported[pairToken] = support;
        emit AddPairToken(pairToken, support);
    }

    /*//////////////////////////////////////////////////////////////
                             ADMIN CONTROLS
    //////////////////////////////////////////////////////////////*/

    /// @notice Set the new base token URI
    function setBaseTokenURI(string memory newBaseTokenURI) external onlyOwner {
        baseTokenURI = newBaseTokenURI;

        emit SetBaseTokenURI(newBaseTokenURI);
    }


    /// @param token The token address to collect fees for
    function collectFees(
        address token
    ) public {
        uint256 tokenId = tokenPositionIds[token];
        if (tokenId == 0)
            revert InvalidToken();

        FeeConfig memory config = tokenFeeConfig[token];
        address feeToken = config.feeToken;

        // check the balances of the token and the feeToken before collecting fees
        uint256 tokenBalanceBefore = IERC20(token).balanceOf(address(this));
        // check the eth balance of this contract
        uint256 pairTokenBalanceBefore = 0;
        if (address(feeToken) == address(0)) {
            pairTokenBalanceBefore = address(this).balance;
        } else {
            pairTokenBalanceBefore = IERC20(feeToken).balanceOf(address(this));
        }

        bytes memory actions = abi.encodePacked(uint8(Actions.DECREASE_LIQUIDITY), uint8(Actions.TAKE_PAIR));
        bytes[] memory params = new bytes[](2);

        bytes memory hookData = ""; // no hook data
        /// @dev collecting fees is achieved with liquidity=0, the second parameter
        params[0] = abi.encode(tokenId, 0, 0, 0, hookData);

        // we may not need to compare the order of the token and the feeToken
        params[1] = abi.encode(
            Currency.wrap(address(token)),
            Currency.wrap(address(feeToken)),
            address(this) // recipient is set to be this contract
        );

        uint256 deadline = block.timestamp + 60;
        positionManager.modifyLiquidities{value: 0}(
            abi.encode(actions, params),
            deadline
        );

        uint256 tokenBalanceAfter = IERC20(token).balanceOf(address(this));
        uint256 pairTokenBalanceAfter = 0;
        if (address(feeToken) == address(0)) {
            pairTokenBalanceAfter = address(this).balance;
        } else {
            pairTokenBalanceAfter = IERC20(feeToken).balanceOf(address(this));
        }

        // calculate the unclaimed fees
        uint256 totalFee0;
        uint256 totalFee1;

        if (address(token) < address(feeToken)) {
            totalFee0 = tokenBalanceAfter - tokenBalanceBefore;
            totalFee1 = pairTokenBalanceAfter - pairTokenBalanceBefore;
        } else {
            totalFee0 = pairTokenBalanceAfter - pairTokenBalanceBefore;
            totalFee1 = tokenBalanceAfter - tokenBalanceBefore;
        }

        // Split fees according to configuration
        uint256 creatorFee0 = (totalFee0 * config.creatorLPFeeBps) / uint256(POOL_FEE);
        uint256 creatorFee1 = (totalFee1 * config.creatorLPFeeBps) / uint256(POOL_FEE);
        uint256 protocolFee0 = totalFee0 - creatorFee0;
        uint256 protocolFee1 = totalFee1 - creatorFee1;

        // Store unclaimed fees
        creatorUnclaimedFees[tokenId].unclaimed0 += uint128(creatorFee0);
        creatorUnclaimedFees[tokenId].unclaimed1 += uint128(creatorFee1);
        protocolUnclaimedFees[tokenId].unclaimed0 += uint128(protocolFee0);
        protocolUnclaimedFees[tokenId].unclaimed1 += uint128(protocolFee1);

        emit FeesCollected(tokenId, creatorFee0, creatorFee1, protocolFee0, protocolFee1);
    }


    /// @notice Only the creator of this token can claim the fees
    /// @param token The token address to claim fees for
    /// @param recipient The recipient of the fees
    function claimCreatorFees(address token, address recipient) external {
        if (msg.sender != tokenFeeConfig[token].creator) 
            revert Unauthorized();

        uint256 tokenId = tokenPositionIds[token];

        UnclaimedFees memory fees = creatorUnclaimedFees[tokenId];
        if (fees.unclaimed0 == 0 && fees.unclaimed1 == 0) 
            revert NoFeesToClaim();

        // Reset unclaimed fees before transfer
        delete creatorUnclaimedFees[tokenId];

        address feeToken = tokenFeeConfig[token].feeToken;

        // Get token addresses in correct order
        (address token0, address token1) = address(token) < address(feeToken) ? (token, address(feeToken)) : (address(feeToken), token);

        if (address(feeToken) == address(0)) {
            // If the pair token is ETH, we need to transfer ETH
            if (fees.unclaimed0 > 0) {
                (bool success, ) = payable(recipient).call{value: fees.unclaimed0}("");
                require(success, "ETH transfer failed");
            }
            if (fees.unclaimed1 > 0) {
                IERC20(token1).safeTransfer(recipient, fees.unclaimed1);
            }
        } else {
            // Transfer fees
            if (fees.unclaimed0 > 0) {
                IERC20(token0).safeTransfer(recipient, fees.unclaimed0);
            }
            if (fees.unclaimed1 > 0) {
                IERC20(token1).safeTransfer(recipient, fees.unclaimed1);
            }
        }

        emit FeesClaimed(recipient, tokenId, fees.unclaimed0, fees.unclaimed1);
    }

    /// @notice Claims Protocol Fees. Only the protocol owner can call this function.
    /// @param token The token address to claim fees for
    /// @param recipient The recipient of the fees
    function claimProtocolFees(address token, address recipient) external onlyOwner {
        uint256 tokenId = tokenPositionIds[token];

        UnclaimedFees memory fees = protocolUnclaimedFees[tokenId];
        if (fees.unclaimed0 == 0 && fees.unclaimed1 == 0) 
            revert NoFeesToClaim();

        // Reset unclaimed fees before transfer
        delete protocolUnclaimedFees[tokenId];

        // Get token addresses in correct order
        address feeToken = tokenFeeConfig[token].feeToken;

        // Get token addresses in correct order
        (address token0, address token1) = address(token) < address(feeToken) ? (token, address(feeToken)) : (address(feeToken), token);

        if (address(feeToken) == address(0)) {
            // If the default pair token is ETH, we need to transfer ETH
            if (fees.unclaimed0 > 0) {
                (bool success, ) = payable(recipient).call{value: fees.unclaimed0}("");
                require(success, "ETH transfer failed");
            }
            if (fees.unclaimed1 > 0) {
                IERC20(token1).safeTransfer(recipient, fees.unclaimed1);
            }
        } else {
            // Transfer fees
            if (fees.unclaimed0 > 0) {
                IERC20(token0).safeTransfer(recipient, fees.unclaimed0);
            }
            if (fees.unclaimed1 > 0) {
                IERC20(token1).safeTransfer(recipient, fees.unclaimed1);
            }
        }

        emit FeesClaimed(recipient, tokenId, fees.unclaimed0, fees.unclaimed1);
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
    

    /// @dev Calculate the allocation of the total supply to LP, creator, and protocol
    /// @param totalSupply The total supply of the token
    /// @return lpAmount The amount allocated to LP
    /// @return creatorAmount The amount allocated to the creator
    /// @return protocolAmount The amount allocated to the protocol
    function calculateSupplyAllocation(uint256 totalSupply)
        public
        view
        returns (uint256 lpAmount, uint256 creatorAmount, uint256 protocolAmount)
    {
        creatorAmount = (totalSupply * defaultFeeConfig.creatorBaseBps) / 10_000;
        protocolAmount = (totalSupply * defaultFeeConfig.protocolBaseBps) / 10_000;
        lpAmount = totalSupply - creatorAmount - protocolAmount;
    }

    /// @dev This function is called when the contract receives ETH
    receive() external payable {
        emit Received(msg.sender, msg.value);
    }

    /// @dev This function is used to receive ETH when the factory is called with a value
    fallback() external payable {
        emit FallbackCalled(msg.sender, msg.value, msg.data);
    }

    /// @notice Set the deprecated flag for the factory
    /// @param _deprecated The new value for the deprecated flag
    /// @dev If deprecated is set to true, no new tokens can be launched
    /// @dev Only the protocol owner can call this function
    function setDeprecated(bool _deprecated) external onlyOwner {
        deprecated = _deprecated;
        emit SetDeprecated(deprecated);
    }

    /// @notice Set the launch fee for the factory
    /// @param newLaunchFee The new launch fee in wei
    /// @dev The launch fee is the amount of ETH required to launch a new token
    /// @dev Only the protocol owner can call this function
    function setLaunchFee(uint256 newLaunchFee) external onlyOwner {
        launchFee = newLaunchFee;
        emit SetLaunchFee(newLaunchFee);
    }

    /// @notice Withdraws certain amount of ETH (launch fees) from the contract to some recipient by the protocol owner
    /// @dev Only callable by the protocol owner
    function withdrawLaunchFees(address payable recipient) external onlyOwner {
        require(recipient != address(0), "Invalid recipient");
        require(launchFeeAccrued > 0, "No fees to withdraw");
        (bool success, ) = recipient.call{value: launchFeeAccrued}("");
        require(success, "Withdraw failed");
        launchFeeAccrued = 0; // reduce the accrued fees
    }

    /*//////////////////////////////////////////////////////////////
                          POSITION MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    function onERC721Received(address, address, uint256, bytes calldata) external virtual override returns (bytes4) {
        if (msg.sender != address(positionManager)) {
            revert NotUniswapPositionManager();
        }

        return this.onERC721Received.selector;
    }
}
