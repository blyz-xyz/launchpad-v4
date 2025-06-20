#!/bin/bash

# Define MAINNET_RPC_URL and ETHERSCAN_API_KEY in a .env file
source .env

# Set the addresses for the Ethereum mainnet
poolManagerAddress=0x000000000004444c5dc75cB358380D2e3dE08A90
positionManagerAddress=0xbd216513d74c8cf14cf4747e6aaa6420ff64ee9e
permit2Address=0x000000000022D473030F116dDEE9F6B43aC78BA3
universalRouterAddress=0x3a9d48ab9751398bbfa63ad67599bb04e4bdf98b
platformReserveAddress=0x169Fb46B8da6571b9fFF3026A774FCB9f96A528c
protocolOwnerAddress=0x169Fb46B8da6571b9fFF3026A774FCB9f96A528c
baseTokenURI="ipfs://"

# Set the local solc compiler version
solcVersion="0.8.26+commit.8a97fa7a"

forge create --chain mainnet --rpc-url $MAINNET_RPC_URL --via-ir --optimizer-runs 100 --compiler-version $solcVersion --interactive --broadcast --verify src/FairLaunchFactoryV2.sol:FairLaunchFactoryV2 \
    --constructor-args $poolManagerAddress $positionManagerAddress $permit2Address $universalRouterAddress $platformReserveAddress $protocolOwnerAddress $baseTokenURI

# WARNING: The Etherscan verification step can occasionally fail (e.g., API rate limits?).
#          This **only** verifies an already‑deployed contract.
# deployedContractAddress="0x8D69805a5264Dd82894ED25Ea11Cca2719BD2C37"
# encodedArgs=$(cast abi-encode \
#   "constructor(address,address,address,address,address,string)" \
#   $poolManagerAddress \
#   $platformReserveAddress \
#   $positionManagerAddress \
#   $permit2Address \
#   $protocolOwnerAddress \
#   $baseTokenURI)
# forge verify-contract \
#     --chain mainnet \
#     --compiler-version $solcVersion \
#     --optimizer-runs 100 \
#     --via-ir \
#     --etherscan-api-key $ETHERSCAN_API_KEY \
#     --constructor-args $encodedArgs \
#     $deployedContractAddress src/FairLaunchFactoryV2.sol:FairLaunchFactoryV2 --watch