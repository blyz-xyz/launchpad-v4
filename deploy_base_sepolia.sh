#!/bin/bash

# Define BASE_RPC_URL and ETHERSCAN_API_KEY in a .env file
source .env

# Set the addresses of uniswap pool, premit and positon for base network
poolManagerAddress=0x05E73354cFDd6745C338b50BcFDfA3Aa6fA03408
positionManagerAddress=0x4b2c77d209d3405f41a037ec6c77f7f5b8e2ca80
permit2Address=0x000000000022D473030F116dDEE9F6B43aC78BA3
universalRouterAddress=0x492e6456d9528771018deb9e87ef7750ef184104
platformReserveAddress=0x169Fb46B8da6571b9fFF3026A774FCB9f96A528c
protocolOwnerAddress=0x169Fb46B8da6571b9fFF3026A774FCB9f96A528c
baseTokenURI="ipfs://"

# Set the local solc compiler version
solcVersion="0.8.26+commit.8a97fa7a"

forge create --chain 84532 --rpc-url $BASE_SEPOLIA_RPC_URL --via-ir --optimizer-runs 100 --compiler-version $solcVersion --interactive --broadcast --verify src/FairLaunchFactoryV2.sol:FairLaunchFactoryV2 \
    --constructor-args $poolManagerAddress $positionManagerAddress $permit2Address $universalRouterAddress $platformReserveAddress $protocolOwnerAddress $baseTokenURI
