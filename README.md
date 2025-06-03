# Rollup Launchpad for Uniswap V4

To compile the project, run the command:

```
forge build --via-ir --optimize --optimizer-runs 100
```

### Test the smart contracts

To run tests, run the command:
```
forge test
```

To run the test scripts, run the command:

```
source .env
forge script --chain sepolia test/script/DeployFactoryV2.t.sol:DeployFactoryV2 --rpc-url $SEPOLIA_RPC_URL --broadcast  --via-ir --sender 0x169Fb46B8da6571b9fFF3026A774FCB9f96A528c --interactives 1 --optimize --optimizer-runs 100
```

### Deploy the smart contracts

To deploy the contracts to sepolia testnet using shell script, you need to first add a .env file and set `SEPOLIA_RPC_URL` and `ETHERSCAN_API_KEY` accordingly.

After that, you can run the deploy command. You might also need to add the executable permission to the file `deploy_sepolia.sh`.

```
./deploy_sepolia.sh
```
