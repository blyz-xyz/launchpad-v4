// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./RollupToken.sol";

contract RollupLaunchFactory {
    address public immutable platformFeeRecipient;
    address public immutable coin98; // C98 token address
    address public immutable uniswapV4PoolManager;
    uint256 public constant TOTAL_SUPPLY = 1_000_000_000 ether; // 1 billion with 18 decimals

    event TokenDeployed(address indexed deployer, address token, uint256 userAmount, uint256 platformAmount);

    constructor(address _platformFeeRecipient, address _coin98, address _poolManager) {
        require(_platformFeeRecipient != address(0), "Invalid platform address");
        platformFeeRecipient = _platformFeeRecipient;
        coin98 = _coin98;
        uniswapV4PoolManager = _poolManager;
    }

    function deployToken(string memory name, string memory symbol) external {
        uint256 platformShare = (TOTAL_SUPPLY * 2) / 100;
        uint256 userShare = TOTAL_SUPPLY - platformShare;

        // Deploy token and mint 100% to this contract
        RollupToken token = new RollupToken(name, symbol);

        // Distribute tokens
        token.transfer(msg.sender, userShare);
        token.transfer(platformFeeRecipient, platformShare);

        emit TokenDeployed(msg.sender, address(token), userShare, platformShare);
    }
}
