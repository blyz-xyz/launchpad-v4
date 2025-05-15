// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./RollupToken.sol";
import "v4-core/src/PoolManager.sol";
import "v4-periphery/src/PositionManager.sol";
import 'v4-core/src/libraries/Hooks.sol';

contract FairLaunchSale {
    using Address for address payable;

    enum SaleStatus { Active, Successful, Failed }

    uint256 public constant TOTAL_SALE_TOKENS = 700_000_000 * 1e18;
    uint256 public constant TOTAL_SUPPLY = 1_000_000_000 * 1e18;
    uint256 public constant HARD_CAP = 35 ether;
    uint256 public constant LIQUIDITY_ETH = 20 ether;
    uint256 public constant LIQUIDITY_TOKENS = 280_000_000 * 1e18;

    RollupToken public token;
    PoolManager public poolManager;
    PositionManager public positionManager;

    address public immutable platformReserve;
    address public immutable weth;
    address public owner;

    uint256 public endTime;
    uint256 public totalContributed;
    SaleStatus public status;

    mapping(address => uint256) public contributions;

    event Contributed(address indexed user, uint256 amount);
    event SaleFinalized(bool success);
    event Refunded(address indexed user, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor(
        address _poolManager,
        address _positionManager,
        address _platformReserve,
        uint256 _saleDuration,
        string memory name,
        string memory symbol
    ) {
        require(_platformReserve != address(0), "Invalid reserve address");

        poolManager = PoolManager(_poolManager);
        positionManager = PositionManager(_positionManager);

        token = new RollupToken(name, symbol);
        owner = msg.sender;
        platformReserve = _platformReserve;
        endTime = block.timestamp + _saleDuration;
        weth = uniswapRouter.WETH();

        // Pre-mint 500M for the sale
        token.mint(address(this), TOTAL_SALE_TOKENS);
    }

    function createPool(address token, uint24 fee, uint160 sqrtPriceX96) external {
        positionManager.createAndInitializePoolIfNecessary(token, address(WETH), fee, sqrtPriceX96);
    }

    function addLiquidity(address token, uint256 amountTokenDesired, uint256 amountETHDesired) external payable {
        IERC20(token).approve(address(positionManager), amountTokenDesired);
        positionManager.mint{value: amountETHDesired}(
            PositionManager.MintParams({
                token0: token,
                token1: address(WETH),
                fee: fee,
                tickLower: tickLower,
                tickUpper: tickUpper,
                amount0Desired: amountTokenDesired,
                amount1Desired: amountETHDesired,
                amount0Min: 0,
                amount1Min: 0,
                recipient: msg.sender,
                deadline: block.timestamp
            })
        );
    }

    receive() external payable {
        contribute();
    }

    function contribute() public payable {
        require(block.timestamp < endTime, "Sale ended");
        require(status == SaleStatus.Active, "Sale closed");
        require(msg.value > 0, "No ETH sent");
        require(totalContributed + msg.value <= HARD_CAP, "Exceeds hard cap");

        uint256 tokensToSend = (msg.value * TOTAL_SALE_TOKENS) / HARD_CAP;
        require(tokensToSend > 0, "Zero tokens");

        contributions[msg.sender] += msg.value;
        totalContributed += msg.value;

        token.transfer(msg.sender, tokensToSend);

        emit Contributed(msg.sender, msg.value);

        if (totalContributed == HARD_CAP) {
            _finalizeSale(true);
        }
    }

    function finalizeIfExpired() external {
        require(block.timestamp >= endTime, "Too early");
        if (status == SaleStatus.Active) {
            _finalizeSale(totalContributed == HARD_CAP);
        }
    }

    function _finalizeSale(bool success) internal {
        if (success) {
            status = SaleStatus.Successful;

            // Mint rest of tokens for liquidity & reserve (500M not used)
            token.mint(address(this), TOTAL_SUPPLY - TOTAL_SALE_TOKENS);

            // Approve tokens
            token.approve(address(uniswapRouter), LIQUIDITY_TOKENS);

            // Add liquidity
            uniswapRouter.addLiquidityETH{value: LIQUIDITY_ETH}(
                address(token),
                LIQUIDITY_TOKENS,
                0,
                0,
                address(0xdead), // lock liquidity forever
                block.timestamp
            );

            // Send 15 ETH to reserve
            uint256 reserveAmount = (totalContributed * 15) / 35;
            payable(platformReserve).sendValue(reserveAmount);

            // Remainder stays in contract or can be claimed
        } else {
            status = SaleStatus.Failed;
        }

        emit SaleFinalized(success);
    }

    function claimRefund() external {
        require(status == SaleStatus.Failed, "Not refundable");
        uint256 contributed = contributions[msg.sender];
        require(contributed > 0, "No contribution");

        uint256 tokensToBurn = (contributed * TOTAL_SALE_TOKENS) / HARD_CAP;
        contributions[msg.sender] = 0;

        token.burnFrom(msg.sender, tokensToBurn);
        payable(msg.sender).sendValue(contributed);

        emit Refunded(msg.sender, contributed);
    }
}
