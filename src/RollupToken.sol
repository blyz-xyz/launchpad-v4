// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract RollupToken is ERC20, Ownable {
    uint256 public constant TOTAL_SUPPLY = 1_000_000_000 ether; // 1 billion with 18 decimals
    uint256 public mintedSupply = 0 ether;

    constructor(string memory name, string memory symbol) 
        ERC20(name, symbol)
        Ownable(msg.sender)
    {}

    function mint(address to, uint256 amount) external onlyOwner {
        require(to != address(0), "Invalid address");
        require(mintedSupply + amount <= TOTAL_SUPPLY, "Max supply exceeded");

        mintedSupply += amount;
        _mint(to, amount);
    }

    function burnFrom(address from, uint256 amount) external onlyOwner {
        require(from != address(0), "Invalid address");
        _burn(from, amount);
    }

    function remainingSupply() external view returns (uint256) {
        return TOTAL_SUPPLY - mintedSupply;
    }
}
