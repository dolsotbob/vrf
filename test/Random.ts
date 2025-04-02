import { expect } from 'chai';
import { ethers as hre } from 'hardhat';
import Random from '../abis/Random.json';
import dotenv from 'dotenv';
import { ethers } from 'ethers';

dotenv.config();

const { abi, address: ca } = Random;
const privateKey = process.env.PRIVATE_KEY!;
const rpcUrl = process.env.RPC_URL;

const provider = new ethers.JsonRpcProvider(rpcUrl);
const signer = new ethers.Wallet(privateKey, provider);
const random = new ethers.Contract(ca, abi, signer);

describe('Random', function () {
  console.log(provider);

  it('랜덤 요청', async () => {
    const tx = await random.requestRandomWord();
    await tx.wait();

    const requestId = await random.requestId();
    console.log('📦 requestId:', requestId.toString());

    // 아직 fulfillRandomWords는 오지 않았을 수 있음
    const value = await random.randomWord();
    console.log('📭 randomWord:', value.toString()); // 아마도 0
  });
});
