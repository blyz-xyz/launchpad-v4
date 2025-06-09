// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

// import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/utils/Nonces.sol";

contract RollupToken is ERC20Permit, ERC20Votes {
    uint256 public constant TOTAL_SUPPLY = 1_000_000_000 ether; // 1 billion with 18 decimals
    /// @dev tokenURI The URI for the token metadata.
    string public tokenURI;

    constructor(
        string memory name,
        string memory symbol,
        string memory _tokenURI,
        address creator,
        uint256 creatorAmount,
        address platformReserve,
        uint256 protocolAmount,
        address lpAddress,
        uint256 lpAmount
    )
        ERC20(name, symbol)
        ERC20Permit(name)
        ERC20Votes()
    {
        require(creatorAmount + protocolAmount + lpAmount <= TOTAL_SUPPLY, "RollupToken: Total supply exceeded");

        tokenURI = _tokenURI;

        _mint(creator, creatorAmount);
        _mint(platformReserve, protocolAmount);
        _mint(lpAddress, lpAmount);
    }

    function _update(address from, address to, uint256 amount) internal override(ERC20, ERC20Votes) {
        super._update(from, to, amount);
    }

    function nonces(address owner) public view virtual override(ERC20Permit, Nonces) returns (uint256) {
        return super.nonces(owner);
    }
}
