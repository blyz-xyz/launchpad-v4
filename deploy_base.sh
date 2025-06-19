#!/bin/bash

# Define BASE_RPC_URL and ETHERSCAN_API_KEY in a .env file
source .env

# Set the addresses of uniswap pool, premit and positon for base network
poolManagerAddress=0x498581ff718922c3f8e6a244956af099b2652b2b
positionManagerAddress=0x7c5f5a4bbd8fd63184577525326123b519429bdc
permit2Address=0x000000000022D473030F116dDEE9F6B43aC78BA3

protocolOwnerAddress=0x022Ca046a4452cCc4C578eb430A60C660ba1b74d
platformReserveAddress=0x022Ca046a4452cCc4C578eb430A60C660ba1b74d

baseTokenURI="ipfs://"

# Set the local solc compiler version
solcVersion="0.8.26+commit.8a97fa7a"

forge create --chain 8453 --rpc-url $BASE_RPC_URL --via-ir --optimizer-runs 100 --compiler-version $solcVersion --interactive --broadcast --verify src/FairLaunchFactoryV2.sol:FairLaunchFactoryV2 \
    --constructor-args $poolManagerAddress $platformReserveAddress $positionManagerAddress $permit2Address $protocolOwnerAddress $baseTokenURI
