import { expect } from 'chai';
import { ethers as hre } from 'hardhat';
import Random from '../abis/Random.json';
import dotenv from 'dotenv';
import { ethers } from 'ethers';

dotenv.config();

const { abi, address: ca } = Random;
const privateKey = process.env.PRIVATE_KEY!;
const rpcUrl = process.env.RPC_URL!;

const provider = new ethers.JsonRpcProvider(rpcUrl);
const signer = new ethers.Wallet(privateKey, provider);
const random = new ethers.Contract(ca, abi, signer);

describe('Random', function () {
  this.timeout(180_000); // 3분 정도 여유 줘야 함 (VRF 응답 대기)

  const roller = signer.address;

  it('1 ~ 100 난수 구하기', async () => {
    const tx = await random.rollDice(roller);
    await tx.wait();
    console.log('🎲 Dice roll requested');

    let result = 0;
    let fulfilled = false;

    const maxTries = 100;

    for (let i = 0; i < maxTries; i++) {
      await new Promise((res) => setTimeout(res, 1000)); // 1초 대기

      try {
        const res = await random.getResult(roller);
        result = res[0];
        fulfilled = res[1];

        if (fulfilled && Number(result) !== 999) {
          break;
        }

        console.log(`⏳ [${i + 1}/${maxTries}] 아직 응답 대기 중...`);
      } catch (err) {
        continue;
      }
    }

    console.log('✅ 응답 완료! 난수 결과:', result);
    expect(fulfilled).to.be.true;
    expect(result).to.be.within(1, 100);
  });
});
