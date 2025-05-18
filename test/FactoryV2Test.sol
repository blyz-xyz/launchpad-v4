// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./../src/FairLaunchFactoryV2.sol";
import "./TestConfig.sol";
import "forge-std/Test.sol";
import "forge-std/Vm.sol";


contract FactoryV2Test is Test, TestConfig {
    FairLaunchFactoryV2 public factoryV2;
    function setUp() public {
        factoryV2 = new FairLaunchFactoryV2();
    }

    function testlaunchToken() public {
        // Access Hevm via the `vm` instance
        vm.startPrank(creator);
    }

    function testCalculateSupplyAllocation() public {
        vm.startPrank(creator);
        uint256 totalSupply = 1_000_000_000 ether;
        bool hasAirdrop = false;
        (uint256 lpAmount, uint256 creatorAmount, uint256 protocolAmount, uint256 airdropAmount) = 
            factoryV2.calculateSupplyAllocation(totalSupply, hasAirdrop);
        assertEq(airdropAmount, 0);
    }
}