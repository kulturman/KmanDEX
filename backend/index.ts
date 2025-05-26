import express from 'express';
import cors from 'cors';
import { ethers } from 'ethers';
import routerJsonOutput from '../contracts/out/KmanDEXRouter.sol/KmanDEXRouter.json';
import factoryJsonOutput from '../contracts/out/KmanDEXFactory.sol/KmanDEXFactory.json';
import poolJsonOutput from '../contracts/out/KmanDEXPool.sol/KmanDEXPool.json';
import {Pool} from "./pool.model";
import dotenv from 'dotenv';

dotenv.config();

if (!process.env.RPC_URL || !process.env.CONTRACT_ADDRESS) {
    throw new Error('RPC_URL and CONTRACT_ADDRESS environment variables must be set');
}

const provider = new ethers.JsonRpcProvider(process.env.RPC_URL || 'http://localhost:8545');

const app = express();
app.use(cors());
app.use(express.json());

const PORT = process.env.PORT || 3000;

app.get('/pools', async (req, res) => {
    const contractAddress = process.env.CONTRACT_ADDRESS as string;
    const routerContract = new ethers.Contract(contractAddress, routerJsonOutput.abi, provider);

    const factoryContract = new ethers.Contract(await routerContract.factory(), factoryJsonOutput.abi, provider);

    if (!factoryContract) {
        res.status(500).json({ error: 'Factory contract not found' });
    }

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

app.get('/liquidity-providers', async (req, res) => {
    const contractAddress = process.env.CONTRACT_ADDRESS as string;
    const routerContract = new ethers.Contract(contractAddress, routerJsonOutput.abi, provider);

    res.send(await routerContract.getLiquidityProviders());
});

app.listen(PORT, () => {
    console.log(`Server is running on port ${PORT}`);
});

export default app;