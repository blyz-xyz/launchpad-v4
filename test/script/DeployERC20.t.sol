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

        address creator = 0x169Fb46B8da6571b9fFF3026A774FCB9f96A528c;
        address platformReserveAddress = 0x169Fb46B8da6571b9fFF3026A774FCB9f96A528c;
        address lpAddress = 0x169Fb46B8da6571b9fFF3026A774FCB9f96A528c;

        // deploy an ERC20 token
        RollupToken defaultPairToken = new RollupToken(
            "RollupToken",
            "GLT",
            creator,
            10_000_000 * 10 ** 18, // 10 million tokens for creator
            platformReserveAddress,
            10_000_000 * 10 ** 18, // 10 million tokens for protocol reserve
            lpAddress, // LP address
            980_000_000 * 10 ** 18 // 980 million tokens for LP
        );
        console2.log("defaultPairToken", address(defaultPairToken));

        vm.stopBroadcast();
    }
}
