#!/bin/bash

# Define BASE_RPC_URL and ETHERSCAN_API_KEY in a .env file
source .env

# Set the addresses of uniswap pool, premit and positon for base network
poolManagerAddress=0x498581ff718922c3f8e6a244956af099b2652b2b
positionManagerAddress=0x7c5f5a4bbd8fd63184577525326123b519429bdc
permit2Address=0x000000000022D473030F116dDEE9F6B43aC78BA3
universalRouterAddress=0x6fF5693b99212Da76ad316178A184AB56D299b43
platformReserveAddress=0x169Fb46B8da6571b9fFF3026A774FCB9f96A528c
protocolOwnerAddress=0x169Fb46B8da6571b9fFF3026A774FCB9f96A528c
baseTokenURI="ipfs://"

# Set the local solc compiler version
solcVersion="0.8.26+commit.8a97fa7a"

forge create --chain 8453 --rpc-url $BASE_RPC_URL --via-ir --optimizer-runs 100 --compiler-version $solcVersion --interactive --broadcast --verify src/FairLaunchFactoryV2.sol:FairLaunchFactoryV2 \
    --constructor-args $poolManagerAddress $positionManagerAddress $permit2Address $universalRouterAddress $platformReserveAddress $protocolOwnerAddress $baseTokenURI

encodedArgs=$(cast abi-encode \
  "constructor(address,address,address,address,address,address,string)" \
  $poolManagerAddress \
  $positionManagerAddress \
  $permit2Address \
  $universalRouterAddress \
  $platformReserveAddress \
  $protocolOwnerAddress \
  $baseTokenURI)

forge build --via-ir --optimizer-runs 100 --compiler-version $solcVersion \
&& local=$(forge inspect src/FairLaunchFactoryV2.sol:FairLaunchFactoryV2 bytecode | sed 's/^0x//') \
&& args=$(echo "$encodedArgs" | sed 's/^0x//') \
&& echo "local creation-hash: $(echo ${local}${args} | cast keccak)" \
&& echo "0x${local}" > local.hex \
&& remote=$(tr -d '\n' < remote.hex | sed 's/^0x//') \
&& echo "remote creation-hash: $(echo ${remote} | cast keccak)" \
&& if [ "${local}${args}" = "$remote" ]; then \
       echo "Byte‑code matches remote.hex"; \
   else \
       echo "Byte‑code differs from remote.hex"; \
       echo "first 100 differing bytes (index: local | remote)"; \
       diff <(echo ${local}${args} | fold -w2 | nl -ba) <(echo $remote | fold -w2 | nl -ba) | head -100; \
       exit 1; \
   fi

# WARNING: The Etherscan verification step can occasionally fail (e.g., API rate limits?).
#          This **only** verifies an already‑deployed contract.
# deployedContractAddress="0x5Fe424f5982b93676D6d359187A2c5dd251a6c28"
# forge verify-contract \
#     --chain 8453 \
#     --compiler-version $solcVersion \
#     --optimizer-runs 100 \
#     --via-ir \
#     --etherscan-api-key $ETHERSCAN_API_KEY \
#     --constructor-args $encodedArgs \
#     $deployedContractAddress src/FairLaunchFactoryV2.sol:FairLaunchFactoryV2 --watch