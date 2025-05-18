// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Core interface for pools
import 'v3-core/contracts/interfaces/IUniswapV3Pool.sol';
// For swaps
import 'v3-periphery/contracts/interfaces/ISwapRouter.sol';
// For liquidity position management
import 'v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol';
import 'v3-periphery/contracts/interfaces/external/IWETH9.sol';


contract FairLaunchFactoryV1 {

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error ReservedName();
    error ReservedTicker();
    error ZeroSupply();
    error BannedName();
    error BannedTicker();
    error NotUniswapPositionManager();
    error InvalidFeeSplit();
    error InvalidSupplyAllocation();
    error NoFeesToClaim();
    error Unauthorized();
    error IncorrectSalt();
    error InsufficientFunds();
    error InvalidToken();

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @param recipient The address of the recipient
    /// @param token The token address to claim initial fees for
    /// @param amount The amount of tokens claimed
    event PlatformReserveClaimed(address indexed recipient, address indexed token, uint256 amount);

    /// @param token The address of the newly created token
    /// @param owner The address of the creator of the token
    /// @param creator The address of the creator of the token
    event TokenCreated(address indexed token, address indexed owner, address indexed creator, string uri);

    /// @param token The address of the token
    /// @param config The new fee configuration
    event FeeConfigUpdated(address indexed token, FeeConfig config);

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

    /// @param token The address of the new default pair token
    event NewDefaultPairToken(address indexed token);

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
        // Airdrop allocation from initial supply (in basis points)
        uint16 airdropBps;
        // Whether this token has airdrop enabled
        bool hasAirdrop;
        // Fee Token
        address feeToken;
        // Creator address for this token
        address creator;
    }

    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @dev The canonical Uniswap V3 factory contract
    IUniswapV3Factory public immutable uniswapV3Factory;

    /// @dev The canonical WETH token contract
    IWETH9 public immutable WETH;

    /// @dev The default pair token, this should be C98
    ERC20 public defaultPairToken;

    /// @dev The Nonfungible Position Manager contract
    INonfungiblePositionManager public immutable nonfungiblePositionManager;

    /// @dev The Uniswap V3 SwapRouter contract
    ISwapRouter02 public immutable swapRouter;

    /// @dev The base URI for all tokens
    string public baseTokenURI;

    /// @dev The mapping of banned names
    mapping(string => bool) public bannedNames;

    /// @dev The mapping of banned tickers
    mapping(string => bool) public bannedTickers;

    /// @dev The mapping from token address to its fee configuration
    mapping(address => FeeConfig) public tokenFeeConfig;

    /// @dev The mapping from token address to its liquidity position ID
    mapping(address => uint256) public tokenPositionIds;

    /// @dev The mapping from tokenId to creator's unclaimed fees
    mapping(uint256 => UnclaimedFees) public creatorUnclaimedFees;

    /// @dev The mapping from tokenId to protocol's unclaimed fees
    mapping(uint256 => UnclaimedFees) public protocolUnclaimedFees;

    /// @dev platform reserve
    address public platformReserve;

    /// @dev The Uniswap V3 Pool fee
    uint24 public POOL_FEE = 10_000;

    /// @dev The Uniswap V3 Tick spacing
    int24 public TICK_SPACING = 200;    

    /// @dev Default fee configuration
    FeeConfig public defaultFeeConfig = FeeConfig({
        creatorLPFeeBps: 5000, // 50% of LP fees to creator (50% implicit Protocol LP fee)
        protocolBaseBps: 200, // 2.00% to protocol if no airdrop
        creatorBaseBps: 50, // 0.50% to creator with airdrop
        airdropBps: 50, // 0.50% to airdrop
        hasAirdrop: false,
        feeToken: address(WETH),
        creator: address(0)
    });


    /// @notice Sets a new default fee configuration for all tokens made
    /// @param newConfig The new fee configuration to set
    function setDefaultFeeConfig(FeeConfig calldata newConfig) external onlyOwner {
        if (newConfig.creatorLPFeeBps > 10_000) revert InvalidFeeSplit();
        if (newConfig.protocolBaseBps + newConfig.creatorBaseBps + newConfig.airdropBps > 10_000) {
            revert InvalidSupplyAllocation();
        }
        defaultFeeConfig = newConfig;

        // We use address(0) as a default stand in
        emit FeeConfigUpdated(address(0), newConfig);

        if (newConfig.feeToken != address(defaultPairToken)) {
            setNewPairToken(ERC20(newConfig.feeToken));
        }
    }    

    /// @notice Ban a name from being used
    /// @param name The name to ban
    /// @param status The status to set
    function banName(string memory name, bool status) external onlyOwner {
        bannedNames[name] = status;
    }

    /// @notice Ban a ticker from being used
    /// @param ticker The ticker to ban
    /// @param status The status to set
    function banTicker(string memory ticker, bool status) external onlyOwner {
        bannedTickers[ticker] = status;
    }

    /// @notice Set the new pool fee and tick spacing
    /// @param newPoolFee The new pool fee to set
    function setNewTickSpacing(uint24 newPoolFee) external onlyOwner {
        POOL_FEE = newPoolFee;
        TICK_SPACING = uniswapV3Factory.feeAmountTickSpacing(newPoolFee);
    }

    /// @notice Launch a new token
    /// @param name The name of the token
    /// @param symbol The symbol of the token
    /// @param supply The total supply of the token
    /// @param merkleroot The merkle root for airdrop claims
    /// @param initialTick The initial tick for the liquidity position
    /// @param salt The salt for the token deployment
    /// @param creator The address to grant the initial tokens to
    ///
    /// @return newToken The newly created RollupToken
    function launchToken(
        string memory name,
        string memory symbol,
        uint256 supply,
        bytes32 merkleroot,
        int24 initialTick,
        bytes32 salt,
        address creator
    )
        public
        returns (RollupToken newToken)
    {
        if (supply == 0) revert ZeroSupply();

        // Name and ticker checks
        if (bannedNames[name]) revert BannedName();
        if (bannedTickers[symbol]) revert BannedTicker();

        bool hasAirdrop = merkleroot != bytes32(0);

        (uint256 lpSupply, uint256 creatorAmount, uint256 protocolAmount, uint256 airdropAmount) = calculateSupplyAllocation(supply, hasAirdrop);

        uint256 id;
        assembly {
            id := chainid()
        }

        string memory tokenURI = string(toHexString(keccak256(abi.encode(creator, salt, name, symbol, merkleroot, supply)), 32));

        // Create token
        newToken = new RollupToken{ salt: keccak256(abi.encode(creator, salt)) }(
            name, symbol, string.concat(baseTokenURI, tokenURI), merkleroot, airdropAmount, id
        );

        address _pairToken = address(defaultPairToken);

        // to enforce a canonical order of token pairs and prevent duplicate liquidity pools
        if (address(newToken) > address(_pairToken)) {
            revert IncorrectSalt();
        }

        newToken.mint(creator, creatorAmount);

        // Token Supply to platform
        newToken.mint(platformReserve, protocolAmount);

        // Set up fee configuration
        FeeConfig memory config = FeeConfig({
            creatorLPFeeBps: defaultFeeConfig.creatorLPFeeBps,
            protocolBaseBps: defaultFeeConfig.protocolBaseBps,
            creatorBaseBps: defaultFeeConfig.creatorBaseBps,
            airdropBps: defaultFeeConfig.airdropBps,
            hasAirdrop: hasAirdrop,
            feeToken: address(defaultPairToken),
            creator: msg.sender
        });
        tokenFeeConfig[address(newToken)] = config;

        IUniswapV3Pool pool = IUniswapV3Pool(uniswapV3Factory.createPool(address(newToken), address(_pairToken), POOL_FEE));

        uint160 initialSqrtRatio = initialTick.getSqrtRatioAtTick();
        pool.initialize(initialSqrtRatio);

        newToken.mint(address(this), lpSupply);

        // Provide initial liquidity
        INonfungiblePositionManager.MintParams memory params = INonfungiblePositionManager.MintParams({
            token0: address(newToken),
            token1: address(_pairToken),
            fee: POOL_FEE,
            tickLower: initialTick,
            tickUpper: TickRange.maxUsableTick(TICK_SPACING),
            amount0Desired: lpSupply,
            amount1Desired: 0,
            amount0Min: 0,
            amount1Min: 0,
            recipient: address(this),
            deadline: block.timestamp
        });

        newToken.approve(address(nonfungiblePositionManager), lpSupply);
        (uint256 tokenId,,,) = nonfungiblePositionManager.mint(params);

        // Store the position ID
        tokenPositionIds[address(newToken)] = tokenId;

        emit TokenCreated(address(newToken), creator, msg.sender, tokenURI);
    }

    /// @notice Calculate the allocation of supply for LP, creator and airdrop
    /// @param totalSupply The total supply of the token
    /// @param hasAirdrop Whether the token has airdrop enabled
    ///
    /// @return lpAmount The amount of tokens allocated to LP
    /// @return creatorAmount The amount of tokens allocated to the creator
    /// @return protocolAmount The amount of tokens allocated to the platform reserve
    /// @return airdropAmount The amount of tokens allocated to airdrop
    function calculateSupplyAllocation(
        uint256 totalSupply,
        bool hasAirdrop
    )
        internal
        view
        returns (uint256 lpAmount, uint256 creatorAmount, uint256 protocolAmount, uint256 airdropAmount)
    {
        if (hasAirdrop) {
            creatorAmount = (totalSupply * defaultFeeConfig.creatorBaseBps) / 10_000;
            protocolAmount = (totalSupply * defaultFeeConfig.protocolBaseBps) / 10_000;
            airdropAmount = (totalSupply * defaultFeeConfig.airdropBps) / 10_000;
        } else {
            creatorAmount = (totalSupply * defaultFeeConfig.creatorBaseBps) / 10_000;
            protocolAmount = (totalSupply * defaultFeeConfig.protocolBaseBps) / 10_000;
            creatorAmount += (totalSupply * defaultFeeConfig.airdropBps) / 10_000; // Add airdrop amount to creator supply
            airdropAmount = 0;
        }
        lpAmount = totalSupply - creatorAmount - airdropAmount - protocolAmount;
    }
    
}
