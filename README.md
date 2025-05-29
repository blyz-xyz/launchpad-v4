# Rollup Launchpad for Uniswap V4

To compile the project, run the command:

```
forge build --via-ir --optimize --optimizer-runs 100
```

To run tests, run the command:

```
forge test
```

To deploy the contracts, run the command:

```
source .env
forge script --chain sepolia test/script/DeployFactoryV2.t.sol:DeployFactoryV2 --rpc-url $SEPOLIA_RPC_URL --broadcast  --via-ir --sender 0x169Fb46B8da6571b9fFF3026A774FCB9f96A528c --interactives 1 --optimize --optimizer-runs 100
```
