// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./../src/FairLaunchFactoryV2.sol";
import "./../src/RollupToken.sol";
import "./TestConfig.sol";
import "forge-std/Test.sol";
import "forge-std/Vm.sol";


contract FactoryV2Test is Test, TestConfig {
    FairLaunchFactoryV2 public factoryV2;
    address constant poolManagerAddress = 0xE03A1074c86CFeDd5C142C4F04F1a1536e203543;
    address constant positionManagerAddress = 0x429ba70129df741B2Ca2a85BC3A2a3328e5c09b4;
    address constant platformReserveAddress = 0x169Fb46B8da6571b9fFF3026A774FCB9f96A528c;
    address constant permit2Address = 0x000000000022D473030F116dDEE9F6B43aC78BA3;
    address payable universalRouterAddress=payable(address(0x3A9D48AB9751398BbFa63ad67599Bb04e4BdF98b));
    address constant protocolOwnerAddress = 0x169Fb46B8da6571b9fFF3026A774FCB9f96A528c;
    string constant baseTokenURI = "ipfs://";

    function setUp() public {
        factoryV2 = new FairLaunchFactoryV2(
            poolManagerAddress,
            positionManagerAddress,
            permit2Address,
            universalRouterAddress,
            platformReserveAddress,
            protocolOwnerAddress,
            baseTokenURI
        );
    }

    function testCreateFactory() public {
        // Access Hevm via the `vm` instance
        // sets msg.sender for all subsequent calls  
        vm.startPrank(creator);
    }

    function testLaunchToken() public {
        vm.startPrank(creator);
        string memory name = "RollupToken";
        string memory symbol = "GLT";
        string memory tokenURI = "QmT5NvUtoM5nXc6b7z8f4Z9F3d5e5e5e5e5e5e5e5e5e";
        uint256 supply = 1_000_000_000 ether;
        address feeToken = address(0);

        (RollupToken token) = factoryV2.launchToken(
            name,
            symbol,
            tokenURI,
            207200,
            address(0x169Fb46B8da6571b9fFF3026A774FCB9f96A528c),
            feeToken,
            0 ether // 0 ETH for the buy
        );
    }

    function testCalculateSupplyAllocation() public view {
        // vm.startPrank(creator);
        uint256 totalSupply = 1_000_000_000 ether;
        (uint256 lpAmount, uint256 creatorAmount, uint256 protocolAmount) = 
            factoryV2.calculateSupplyAllocation(totalSupply);
        assertEq(creatorAmount, 10_000_000*10e18);
        assertEq(protocolAmount, 10_000_000*10e18);
        assertEq(lpAmount, 980_000_000*10e18);
    }
}
