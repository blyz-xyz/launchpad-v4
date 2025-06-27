// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./../../src/FairLaunchFactoryV2.sol";
import "./../../src/RollupToken.sol";
import "forge-std/console2.sol";
import "forge-std/Script.sol";

// Simple ERC20 token contract for testing
contract PairERC20 is ERC20 {
    constructor(string memory name, string memory symbol, uint256 initialSupply, address to) ERC20(name, symbol) {
        _mint(to, initialSupply);
    }
}

contract DeployAndBuyERC20 is Script {
    FairLaunchFactoryV2 public factoryV2;
    PairERC20 public pairERC20;

    function setUp() public {
    }

    function run() public returns (IPoolManager manager) {
        vm.startBroadcast();
        // Uniswap deployment on Sepolia
        // refs: https://docs.uniswap.org/contracts/v4/deployments#sepolia-11155111
        address poolManagerAddress = 0xE03A1074c86CFeDd5C142C4F04F1a1536e203543;
        address positionManagerAddress = 0x429ba70129df741B2Ca2a85BC3A2a3328e5c09b4;
        address permit2Address = 0x000000000022D473030F116dDEE9F6B43aC78BA3;
        address payable universalRouterAddress=payable(address(0x3A9D48AB9751398BbFa63ad67599Bb04e4BdF98b));
        address platformReserveAddress = 0x169Fb46B8da6571b9fFF3026A774FCB9f96A528c;
        address protocolOwnerAddress = 0x169Fb46B8da6571b9fFF3026A774FCB9f96A528c;
        address creator = 0x169Fb46B8da6571b9fFF3026A774FCB9f96A528c;
        string memory baseTokenURI = "ipfs://";

        factoryV2 = new FairLaunchFactoryV2(
            poolManagerAddress,
            positionManagerAddress,
            permit2Address,
            universalRouterAddress,
            platformReserveAddress,
            protocolOwnerAddress,
            baseTokenURI
        );

        console2.log("FairLaunchFactoryV2", address(factoryV2));

        // Deploy a ERC20 token, which will be used as the pair token for the swap
        // Deploy a new ERC20 token with 1 billion supply (assuming 18 decimals)
        uint256 initialSupply = 1_000_000_000 * 1e18;
        pairERC20 = new PairERC20("PairERC20", "Pair", initialSupply, creator);
        console2.log("PairERC20 deployed at", address(pairERC20));
        console2.log("Creator balance", pairERC20.balanceOf(creator));

        // Add the new ERC20 pair token to the support list
        factoryV2.addPairToken(address(pairERC20), true);
        console2.log("Pair token added to factory");

        // Approve the factory to spend the pair token on behalf of the creator
        uint128 amountIn = 100 * 1e18; // Approve 100,000 tokens for the swap amountIn
        pairERC20.approve(address(factoryV2), amountIn);

        string memory name = "RollupToken1P";
        string memory symbol = "GLT1P";
        string memory tokenURI = "QmT5NvUtoM5nXc6b7z8f4Z9F3d5e5e5e5e5e5e5e5e5e";

        // @Notice: CurrenciesOutOfOrderOrEqual
        factoryV2.launchToken(
            name,
            symbol,
            tokenURI,
            0,
            creator,
            address(pairERC20),
            amountIn
        );

        vm.stopBroadcast();
    }
}