#!/bin/bash

# Define SEPOLIA_RPC_URL and ETHERSCAN_API_KEY in a .env file
source .env

# Set the addresses for the Sepolia network
poolManagerAddress=0x000000000004444c5dc75cb358380d2e3de08a90
platformReserveAddress=0x022Ca046a4452cCc4C578eb430A60C660ba1b74d
positionManagerAddress=0xbd216513d74c8cf14cf4747e6aaa6420ff64ee9e
permit2Address=0x000000000022D473030F116dDEE9F6B43aC78BA3
protocolOwnerAddress=0x022Ca046a4452cCc4C578eb430A60C660ba1b74d

# Set the local solc compiler version
solcVersion="0.8.26+commit.8a97fa7a"

forge create --chain sepolia --rpc-url $SEPOLIA_RPC_URL --via-ir --optimizer-runs 100 --compiler-version $solcVersion --interactive --broadcast --verify src/FairLaunchFactoryV2.sol:FairLaunchFactoryV2 \
    --constructor-args $poolManagerAddress $platformReserveAddress $positionManagerAddress $permit2Address $protocolOwnerAddress