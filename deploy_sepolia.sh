#!/bin/bash

# Define SEPOLIA_RPC_URL and ETHERSCAN_API_KEY in a .env file
source .env

# Set the addresses for the Sepolia network
poolManagerAddress=0xE03A1074c86CFeDd5C142C4F04F1a1536e203543
platformReserveAddress=0x169Fb46B8da6571b9fFF3026A774FCB9f96A528c
positionManagerAddress=0x429ba70129df741B2Ca2a85BC3A2a3328e5c09b4
permit2Address=0x000000000022D473030F116dDEE9F6B43aC78BA3
protocolOwnerAddress=0x169Fb46B8da6571b9fFF3026A774FCB9f96A528c

# Set the local solc compiler version
solcVersion="0.8.26+commit.8a97fa7a"

forge create --chain sepolia --rpc-url $SEPOLIA_RPC_URL --via-ir --optimizer-runs 100 --compiler-version $solcVersion --interactive --broadcast --verify src/FairLaunchFactoryV2.sol:FairLaunchFactoryV2 \
    --constructor-args $poolManagerAddress $platformReserveAddress $positionManagerAddress $permit2Address $protocolOwnerAddress