import express from 'express';
import cors from 'cors';
import { ethers } from 'ethers';
import routerJsonOutput from '../contracts/out/KmanDEXRouter.sol/KmanDEXRouter.json';
import factoryJsonOutput from '../contracts/out/KmanDEXFactory.sol/KmanDEXFactory.json';
import poolJsonOutput from '../contracts/out/KmanDEXPool.sol/KmanDEXPool.json';
import {Pool} from "./pool.model";

const provider = new ethers.JsonRpcProvider(process.env.RPC_URL || 'http://localhost:8545');
const signer = new ethers.Wallet(process.env.PRIVATE_KEY || '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80', provider);
const contractAddress = process.env.CONTRACT_ADDRESS || '0x3aD2306eDfBe72ce013cdb6b429212d9CdDE4F96';
const routerContract = new ethers.Contract(contractAddress, routerJsonOutput.abi, signer);

const app = express();
app.use(cors());
app.use(express.json());

const PORT = process.env.PORT || 3000;

app.get('/pools', async (req, res) => {
    const factoryContract = new ethers.Contract(await routerContract.factory(), factoryJsonOutput.abi, provider);

    const pools = await factoryContract.getAllPools();
    const returnedPools: Pool[] = [];

    for (let pool of pools) {
        const poolContract = new ethers.Contract(pool, poolJsonOutput.abi, provider);
        const tokenA = await poolContract.tokenA();
        const tokenB = await poolContract.tokenB();
        const tokenAAmount = await poolContract.tokenAAmount();
        const tokenBAmount = await poolContract.tokenBAmount();

        returnedPools.push({
            poolAddress: pool,
            tokenA,
            tokenB,
            tokenAAmount: ethers.formatUnits(tokenAAmount, 18),
            tokenBAmount: ethers.formatUnits(tokenBAmount, 18),
        });
    }

    res.json(returnedPools);
});

app.listen(PORT, () => {
    console.log(`Server is running on port ${PORT}`);
});
