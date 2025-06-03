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
    address constant protocolOwnerAddress = 0x169Fb46B8da6571b9fFF3026A774FCB9f96A528c;

    function setUp() public {
        factoryV2 = new FairLaunchFactoryV2(
            poolManagerAddress,
            platformReserveAddress,
            positionManagerAddress,
            permit2Address,
            protocolOwnerAddress
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
        uint256 supply = 1_000_000_000 ether;
        address feeToken = address(0);

        (RollupToken token) = factoryV2.launchToken(
            name,
            symbol,
            207243,
            address(0x169Fb46B8da6571b9fFF3026A774FCB9f96A528c)
        );
    }

    function testCalculateSupplyAllocation() public view {
        // vm.startPrank(creator);
        uint256 totalSupply = 1_000_000_000 ether;
        (uint256 lpAmount, uint256 creatorAmount, uint256 protocolAmount) = 
            factoryV2.calculateSupplyAllocation(totalSupply);
        assertEq(creatorAmount, 10_000_000*10e18);
        assertEq(protocolAmount, 20_000_000*10e18);
        assertEq(lpAmount, 970_000_000*10e18);
    }
}
