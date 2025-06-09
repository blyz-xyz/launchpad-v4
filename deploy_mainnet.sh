#!/bin/bash

# Define MAINNET_RPC_URL and ETHERSCAN_API_KEY in a .env file
source .env

# Set the addresses for the Ethereum mainnet
poolManagerAddress=0x000000000004444c5dc75cB358380D2e3dE08A90
platformReserveAddress=0x169Fb46B8da6571b9fFF3026A774FCB9f96A528c
positionManagerAddress=0xbd216513d74c8cf14cf4747e6aaa6420ff64ee9e
permit2Address=0x000000000022D473030F116dDEE9F6B43aC78BA3
protocolOwnerAddress=0x169Fb46B8da6571b9fFF3026A774FCB9f96A528c
baseTokenURI="ipfs://"

# Set the local solc compiler version
solcVersion="0.8.26+commit.8a97fa7a"

forge create --chain mainnet --rpc-url $MAINNET_RPC_URL --via-ir --optimizer-runs 100 --compiler-version $solcVersion --interactive --broadcast --verify src/FairLaunchFactoryV2.sol:FairLaunchFactoryV2 \
    --constructor-args $poolManagerAddress $platformReserveAddress $positionManagerAddress $permit2Address $protocolOwnerAddress $baseTokenURI
