import fs from 'fs';
import path from 'path';
import dotEnvExpand from 'dotenv-expand';
import { config as dotEnvConfig } from 'dotenv';

const NETWORK = process.env.NETWORK || 'hardhat';
const envPath = path.resolve(__dirname, '.env');

// https://github.com/bkeepers/dotenv#what-other-env-files-can-i-use
const dotenvFiles = [`${envPath}.${NETWORK}.local`, `${envPath}.local`, `${envPath}.${NETWORK}`, envPath];

dotenvFiles.forEach((dotenvFile) => {
  if (fs.existsSync(dotenvFile)) {
    dotEnvExpand.expand(
      dotEnvConfig({
        path: dotenvFile,
      }),
    );
  }
});

const {
  PRIVATE_KEY = '',
  SEPOLIA_RPC_URL = '',
} = process.env;

// api keys
export {
  PRIVATE_KEY, 
  SEPOLIA_RPC_URL
};
