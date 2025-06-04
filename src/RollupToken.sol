// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract RollupToken is ERC20 {
    uint256 public constant TOTAL_SUPPLY = 1_000_000_000 ether; // 1 billion with 18 decimals
    uint256 public mintedSupply = 0 ether;

    constructor(
        string memory name,
        string memory symbol,
        address creator,
        uint256 creatorAmount,
        address platformReserve,
        uint256 protocolAmount,
        address lpAddress,
        uint256 lpAmount
    )
        ERC20(name, symbol)
    {   
        require(creatorAmount + protocolAmount + lpAmount <= TOTAL_SUPPLY, "RollupToken: Total supply exceeded");

        _mint(creator, creatorAmount);
        _mint(platformReserve, protocolAmount);
        _mint(lpAddress, lpAmount);
    }
}
