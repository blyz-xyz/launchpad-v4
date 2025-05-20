import hre from "hardhat";
import { BaseContract, Contract, ContractFactory, Signer } from "ethers";
import { expect } from "chai";
import { RollupToken, FairLaunchFactoryV2 } from "../typechain-types";

describe("FairLaunchFactoryV2", function () {
  let owner: Signer;
  let creator: Signer;
  // Uniswap deployment on Sepolia
  // refs: https://docs.uniswap.org/contracts/v4/deployments#sepolia-11155111
  let poolManagerAddress = "0xE03A1074c86CFeDd5C142C4F04F1a1536e203543";
  let positionManagerAddress = "0x429ba70129df741B2Ca2a85BC3A2a3328e5c09b4";
  let wethAddress = "0xfff9976782d46cc05630d1f6ebab18b2324d6b14";
  let platformReserveAddress = "0x169Fb46B8da6571b9fFF3026A774FCB9f96A528c";
  let permit2Address = "0x000000000022D473030F116dDEE9F6B43aC78BA3";
  let rollupTokenContract: RollupToken;
  let factory: FairLaunchFactoryV2;
  let defaultPairToken: Contract;
  let maxAirdropSupply: number = 100_000_000; // 100 million
  let originalChainId: number = 11155111; // sepolia

  /*
  it("should successfully deploy a rollup chain token", async function ()  {
    const ethers = hre.ethers;
    // const [deployer] = await ethers.getSigners();
    // console.log("Deploying contracts with account:", deployer.address);

    // Get the contract factory
    const rollupTokenFactory = await ethers.getContractFactory("RollupTokenV1");

    // Connect to Sepolia
    const sepoliaProvider = new hre.ethers.JsonRpcProvider(process.env.SEPOLIA_RPC_URL);
    const deployer = new hre.ethers.Wallet(process.env.PRIVATE_KEY, sepoliaProvider);

    const emptyMerkleRoot = ethers.encodeBytes32String("");
    rollupTokenContract = await rollupTokenFactory.connect(deployer).deploy("RollupToken", "RT", "https://glitchd.network/", emptyMerkleRoot, maxAirdropSupply, originalChainId) as RollupTokenV1;
    await rollupTokenContract.waitForDeployment();
    const rollupTokenAddress = await rollupTokenContract.getAddress();
    console.log("RollupToken deployed to:", rollupTokenAddress);
  });
  */

  it("should successfully launch a token", async function () {
    const ethers = hre.ethers;
    // Deploy factory
    const fairLaunchFactory = await hre.ethers.getContractFactory("FairLaunchFactoryV2");

    // Connect to Sepolia
    const sepoliaProvider = new hre.ethers.JsonRpcProvider(process.env.SEPOLIA_RPC_URL);
    const deployer = new hre.ethers.Wallet(process.env.PRIVATE_KEY, sepoliaProvider);    

    factory = await fairLaunchFactory.connect(deployer).deploy(
      poolManagerAddress,
      wethAddress,
      platformReserveAddress
    );

    await factory.waitForDeployment();

    const factoryAddress = await factory.getAddress();
    console.log("FairLaunchFactoryV1 deployed to:", factoryAddress);    

    // Set platform reserve (simplified - we use the deployer)
    // await factory.setNewPairToken(wethAddress);

    /*
    const name = "Rollup Token";
    const symbol = "ROLL";
    const supply = ethers.parseEther("1000000000");
    console.log("supply", supply.toString());
    const emptyMerkleRoot = ethers.encodeBytes32String("");
    const initialTick = 200;
    const salt = ethers.encodeBytes32String("salt");
    const creatorAddr = await deployer.getAddress();

    // call launchToken
    const tx = await factory.launchToken(
      name,
      symbol,
      supply,
      emptyMerkleRoot,
      initialTick,
      salt,
      creatorAddr, {
        gasLimit: 10000000,
        gasPrice: ethers.parseUnits("5", "gwei"),
      }
    );

    const receipt = await tx.wait();
    console.log('transaction events', receipt?.logs);
    */

    /*
    const event = receipt?.events?.find(e => e.event === "TokenCreated");
    expect(event).to.not.be.undefined;
    const tokenAddress = event?.args?.token;
    expect(tokenAddress).to.properAddress;

    // Confirm RollupToken exists
    const RollupToken = await ethers.getContractFactory("RollupTokenV1");
    const newToken = RollupToken.attach(tokenAddress);

    expect(await newToken.name()).to.equal(name);
    expect(await newToken.symbol()).to.equal(symbol);
    expect(await newToken.totalSupply()).to.equal(supply);
    */
  });
});
