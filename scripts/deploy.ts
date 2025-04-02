import { ethers } from 'hardhat';
import { makeAbi } from './abiGenerator';
import dotenv from 'dotenv';

dotenv.config();

const privateKey = process.env.PRIVATE_KEY;
const coordinator = process.env.COORDINATOR!;
const keyHash = process.env.KEY_HASH!;
const subscriptionId = process.env.SUBSCRIPTION_ID!;

async function main() {
  const contractName = 'Random';

  console.log(`Deploying contracts`);

  const Contract = await ethers.getContractFactory(contractName);
  const contract = await Contract.deploy(coordinator, keyHash, subscriptionId);

  await contract.waitForDeployment();

  console.log(`Contract deployed at: ${contract.target}`);
  await makeAbi(`${contractName}`, contract.target);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
