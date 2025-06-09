// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./../src/FairLaunchFactoryV2.sol";
import "./../src/RollupToken.sol";
import "./TestConfig.sol";
import "forge-std/Test.sol";
import "forge-std/Vm.sol";


contract FactoryV2Test is Test, TestConfig {
    FairLaunchFactoryV2 public factoryV2;
    address constant poolManagerAddress = 0x000000000004444c5dc75cb358380d2e3de08a90;
    address constant positionManagerAddress = 0xbd216513d74c8cf14cf4747e6aaa6420ff64ee9e;
    address constant platformReserveAddress = 0x022Ca046a4452cCc4C578eb430A60C660ba1b74d;
    address constant permit2Address = 0x000000000022D473030F116dDEE9F6B43aC78BA3;
    address constant protocolOwnerAddress = 0x022Ca046a4452cCc4C578eb430A60C660ba1b74d;

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
            207200,
            address(0x022Ca046a4452cCc4C578eb430A60C660ba1b74d)
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
