import { HardhatUserConfig } from 'hardhat/types';

import "@nomicfoundation/hardhat-ethers";
import '@typechain/hardhat';
import 'hardhat-deploy';
import "@openzeppelin/hardhat-upgrades";

import {
  PRIVATE_KEY,
} from './env';

const config: HardhatUserConfig = {
  solidity: {
    compilers: [{ 
      version: '0.8.29',
      settings: {
        optimizer: {
          enabled: true,
          runs: 1000,
        },
        viaIR: true,
      } }],
  },
  networks: {
    hardhat: {},
    localhost: {},
  },
  namedAccounts: {
    deployer: 0,
  },  
};

export default config;
