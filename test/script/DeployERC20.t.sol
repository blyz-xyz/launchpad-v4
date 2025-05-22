// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./../../src/RollupToken.sol";
import "forge-std/console2.sol";
import "forge-std/Script.sol";

contract DeployERC20 is Script {

    function setUp() public {
    }

    function run() public {
        vm.startBroadcast();

        // deploy an ERC20 token
        RollupToken defaultPairToken = new RollupToken("Angel", "AGL");
        console2.log("defaultPairToken", address(defaultPairToken));

        vm.stopBroadcast();
    }
}