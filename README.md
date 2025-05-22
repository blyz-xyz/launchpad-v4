# Rollup Launchpad for Uniswap V4

To compile the project, run the command:

```
forge build --via-ir
```

To run tests, run the command:

```
forge test
```

To deploy the contracts, run the command:

```
source .env
forge script --chain sepolia test/script/DeployFactoryV2.t.sol:DeployFactoryV2 --rpc-url $SEPOLIA_RPC_URL --broadcast  --via-ir --sender $YOUR_WALLET_ADDRES --interactives 1
```
