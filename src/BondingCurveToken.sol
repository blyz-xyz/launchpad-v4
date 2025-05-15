// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract BondingCurveToken is ERC20 {
    uint256 public basePrice = 0.001 ether;
    uint256 public slope = 0.0001 ether;
    address public owner;

    constructor() ERC20("CurveToken", "CURVE") {
        owner = msg.sender;
    }

    // Buy tokens
    function buy(uint256 amount) external payable {
        uint256 cost = getPriceForAmount(amount);
        require(msg.value >= cost, "Not enough ETH sent");

        _mint(msg.sender, amount);

        // Refund excess ETH
        if (msg.value > cost) {
            payable(msg.sender).transfer(msg.value - cost);
        }
    }

    // Sell tokens
    function sell(uint256 amount) external {
        require(balanceOf(msg.sender) >= amount, "Insufficient balance");
        uint256 refund = getPriceForAmount(amount); // Symmetric pricing

        _burn(msg.sender, amount);
        payable(msg.sender).transfer(refund);
    }

    // Price formula: P = base + slope * supply
    function getPriceForAmount(uint256 amount) public view returns (uint256 totalPrice) {
        uint256 currentSupply = totalSupply();
        for (uint256 i = 0; i < amount; i++) {
            totalPrice += basePrice + slope * (currentSupply + i);
        }
    }

    // Withdraw contract balance (owner-only)
    function withdraw() external {
        require(msg.sender == owner, "Not owner");
        payable(owner).transfer(address(this).balance);
    }

    receive() external payable {}
}
