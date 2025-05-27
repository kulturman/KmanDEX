import request from 'supertest';
import { ethers } from 'ethers';
import {TestEnvironment} from "./test/setup";
import app from "./index";
import kmanDEXRouterJSON from '../contracts/out/KmanDEXRouter.sol/KmanDEXRouter.json';
import factoryJsonOutput from "../contracts/out/KmanDEXFactory.sol/KmanDEXFactory.json";
import {DecodedError, ErrorDecoder} from 'ethers-decode-error'

const errorDecoder = ErrorDecoder.create()


const erc20ABI = [
    "function approve(address spender, uint256 amount) external returns (bool)",
    "function balanceOf(address account) external view returns (uint256)",
    "function transfer(address to, uint256 amount) external returns (bool)"
];

describe('Smart Contract Integration Tests', () => {
    let testEnv: TestEnvironment;
    let routerContract: any;
    let factoryContract: any;
    let wallet: ethers.Wallet;
    let routerContractAddress: string
    let testWallet: ethers.Wallet;
    let usdcWhaleSigner: ethers.Signer;
    let wethWhaleSigner: ethers.Signer;
    let usdcWithWhale: ethers.Contract;
    let wethWithWhale: ethers.Contract;
    let usdc: ethers.Contract;
    let weth: ethers.Contract;

    beforeEach(async () => {
        testEnv = new TestEnvironment();
        await testEnv.start();

        routerContractAddress = testEnv.getDeployedAddress();

        // Setup wallet and routerContract instance
        testWallet = new ethers.Wallet(
            '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80',
            testEnv.provider!
        );
        
        routerContract = new ethers.Contract(routerContractAddress, kmanDEXRouterJSON.abi, testWallet);
        factoryContract = new ethers.Contract(await routerContract.factory(), factoryJsonOutput.abi, testWallet);

        // Update app environment for this test
        process.env.CONTRACT_ADDRESS = routerContractAddress;
        process.env.RPC_URL = 'http://localhost:8545';

        usdcWhaleSigner = await testEnv.impersonateWhale(testEnv.getUSDCWhale());
        wethWhaleSigner = await testEnv.impersonateWhale(testEnv.getWETHWhale());
        usdcWithWhale = new ethers.Contract('0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48', erc20ABI, usdcWhaleSigner);
        wethWithWhale = new ethers.Contract('0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2', erc20ABI, wethWhaleSigner);

        await usdcWithWhale.transfer(testWallet.address, ethers.parseUnits('100000', 6));
        await wethWithWhale.transfer(testWallet.address, ethers.parseEther('10000')); // 100 WETH

        usdc = new ethers.Contract(testEnv.getUSDCAddress(), erc20ABI, testWallet);
        weth = new ethers.Contract(testEnv.getWETHAddress(), erc20ABI, testWallet);

        routerContract = routerContract.connect(testWallet);
    }, 30000); // 30s timeout for setup

    afterEach(async () => {
        await testEnv.stop();
    });

    it('should fetch all pools', async () => {
        const response = await request(app).get('/pools');
        expect(response.status).toBe(200);
        expect(response.body.length).toBe(1);

        expect(response.body[0]).toMatchObject({
            poolAddress: expect.any(String),
            tokenA: '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48',
            tokenB: '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2',
            tokenAAmount: '0.0',
            tokenBAmount: '0.0'
        });
    }, 10000);

    it('should fetch all liquidity providers', async () => {
        // Approve and wait for confirmations
        const tx1 = await usdc.approve(routerContractAddress, ethers.parseUnits('10000', 6));
        await tx1.wait();

        const tx2 = await weth.approve(routerContractAddress, ethers.parseEther('5000'));
        await tx2.wait();

        // Actually invest liquidity and wait for confirmation
        const tx3 = await routerContract.investLiquidity(
            '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48',
            '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2',
            ethers.parseUnits('1000', 6),
            ethers.parseEther('500'),
            0
        );
        await tx3.wait();

        const response = await request(app).get('/liquidity-providers');
        expect(response.status).toBe(200);

        expect(response.body).toEqual(expect.arrayContaining([
            testWallet.address,
        ]));
    }, 20000);

    it('Should get all swaps number', async () => {
        const tx1 = await usdc.approve(routerContractAddress, ethers.parseUnits('10000', 6));
        await tx1.wait();

        const tx2 = await weth.approve(routerContractAddress, ethers.parseEther('5000'));
        await tx2.wait();

        // Actually invest liquidity and wait for confirmation
        const tx3 = await routerContract.investLiquidity(
            '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48',
            '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2',
            ethers.parseUnits('1000', 6),
            ethers.parseEther('500'),
            0
        );
        await tx3.wait();

        try {
            const tx4 = await routerContract.swap('0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48', '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2', ethers.parseUnits('100', 6), 0);
            tx4.wait();
        } catch (err) {
            const decodedError: DecodedError = await errorDecoder.decode(err)
            console.log(`Revert reason: ${decodedError.reason}`)
        }
        const response = await request(app).get('/swaps');

        expect(response.status).toBe(200);
        expect(response.body.swapNumber).toBe(1);
    }, 20000)

    it('Should get all users of the protocol (addresses)', async () => {
        // Approve and wait for confirmations
        const tx1 = await usdc.approve(routerContractAddress, ethers.parseUnits('10000', 6));
        await tx1.wait();

        const tx2 = await weth.approve(routerContractAddress, ethers.parseEther('5000'));
        await tx2.wait();

        // Actually invest liquidity and wait for confirmation
        const tx3 = await routerContract.investLiquidity(
            '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48',
            '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2',
            ethers.parseUnits('1000', 6),
            ethers.parseEther('500'),
            0
        );
        await tx3.wait();

        const tx4 = await routerContract.swap('0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48', '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2', ethers.parseUnits('100', 6), 0);
        tx4.wait();
        const response = await request(app).get('/users');

        expect(response.status).toBe(200);
        expect(response.body).toContain(testWallet.address);
    }, 20000)
});