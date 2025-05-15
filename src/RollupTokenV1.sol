// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

/// @title RollupToken
/// @author George Qing
/// @notice An implementation of ERC20 extending with IERC7802 to allow for unified use across Superchain.
contract RollupToken is ERC20, Ownable {

    /// @dev The maximum total supply of the token that can be minted
    uint256 public constant TOTAL_SUPPLY = 1_000_000_000 ether; // 1 billion with 18 decimals
    
    /// @dev Tracks the number of tokens we have minted in claims so far
    uint256 public mintedSupply = 0 ether;

    uint256 public maxAirdropSupply = 0 ether;

    uint256 public airdropped = 0 ether;    

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when tokens are claimed
    /// @param to The address that claimed the tokens
    /// @param amount The amount of tokens claimed
    event Claim(address indexed to, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    
    /// @dev The merkle root to be used for claims
    bytes32 public merkleRoot;

    /// @dev Original Chain the token was deployed on
    uint256 public originalChainId;

    /// @param name The name of the token
    /// @param symbol The symbol of the token
    /// @param _tokenURI A Url pointing to the metadata for the token
    /// @param _merkleRoot The merkle root to be used for claims
    constructor(
        string memory name,
        string memory symbol,
        string memory _tokenURI,
        bytes32 _merkleRoot,
        uint256 _maxAirdropSupply,
        uint256 _originalChainId
    )
        ERC20(name, symbol)
        Ownable(msg.sender)
    {
        tokenURI = _tokenURI;
        merkleRoot = _merkleRoot;
        maxAirdropSupply = _maxAirdropSupply;
        originalChainId = _originalChainId;
    }

    modifier onlyOriginalChain() {
        uint256 id;
        assembly {
            id := chainid()
        }
        if (id != originalChainId) revert Unauthorized();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                                MINTING
    //////////////////////////////////////////////////////////////*/

    /// @dev Tracks if a user has claimed their tokens
    mapping(address => bool) public claimed;

    /// @dev Error emitted when the proof supplied is invalid
    error InvalidProof();

    /// @dev Error emitted when a user has already claimed their tokens
    error AlreadyClaimed();

    /// @dev Error emitted when a user tries to claim 0 tokens
    error CannotClaimZero();

    /// @param proof The merkle proof to verify the claim
    /// @param recipient The address to mint the tokens to
    /// @param amount The amount of tokens to mint
    function claim(bytes32[] calldata proof, address recipient, uint256 amount) external onlyOriginalChain {
        if (claimed[recipient]) revert AlreadyClaimed();

        claimed[recipient] = true;

        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(recipient, amount))));
        if (!MerkleProof.verify(proof, merkleRoot, leaf)) {
            revert InvalidProof();
        }

        if (amount + airdropped > maxAirdropSupply) {
            amount = maxAirdropSupply - airdropped;
        }

        if (amount == 0) {
            revert CannotClaimZero();
        }

        mintedSupply += amount;
        airdropped += amount;

        // Mint the points to the recipient
        _mint(recipient, amount);

        emit Transfer(address(0), recipient, amount);
        emit Claim(recipient, amount);
    }

    /// @param to The address to mint the tokens to
    /// @param amount The amount of tokens to mint
    function mint(address to, uint256 amount) external onlyOriginalChain onlyOwner {
        require(to != address(0), "Invalid address");
        require(mintedSupply + amount <= TOTAL_SUPPLY, "Max supply exceeded");

        mintedSupply += amount;
        _mint(to, amount);
    }    

    function remainingSupply() external view returns (uint256) {
        return TOTAL_SUPPLY - mintedSupply;
    }

    /*//////////////////////////////////////////////////////////////
                            METADATA
    //////////////////////////////////////////////////////////////*/

    /// @dev tokenURI The URI for the token metadata.
    string public tokenURI;

    /*//////////////////////////////////////////////////////////////
                          SUPERCHAIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Error emitted for unauthorized access.
    error Unauthorized();

    /// @dev ERC165 Interface Id Compatibility check
    /// @param _interfaceId Interface ID to check for support.
    /// @return True if the contract supports the given interface ID.
    function supportsInterface(bytes4 _interfaceId) public pure returns (bool) {
        return _interfaceId == 0x33331994 // ERC7802 Interface ID
            || _interfaceId == 0x36372b07 // ERC20 Interface ID
            || _interfaceId == 0x01ffc9a7; // ERC165 Interface ID
    }
}
