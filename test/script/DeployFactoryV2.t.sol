// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./../../src/FairLaunchFactoryV2.sol";
import "./../../src/RollupToken.sol";
import "forge-std/console2.sol";
import "forge-std/Script.sol";

contract DeployFactoryV2 is Script {
    FairLaunchFactoryV2 public factoryV2;

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

        string memory name = "RollupToken1P";
        string memory symbol = "GLT1P";
        address feeToken = address(0);
        string memory tokenURI = "QmT5NvUtoM5nXc6b7z8f4Z9F3d5e5e5e5e5e5e5e5e5e";

        // @Notice: CurrenciesOutOfOrderOrEqual
        (RollupToken token) = factoryV2.launchToken(
            name,
            symbol,
            tokenURI,
            207200,
            creator,
            0 ether
        );

        vm.stopBroadcast();
    }
}