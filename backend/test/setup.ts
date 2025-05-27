import { spawn, ChildProcess } from 'child_process';
import { ethers } from 'ethers';
import { readFileSync, existsSync } from 'fs';
import { join, resolve } from 'path';
import dotenv from 'dotenv';

dotenv.config();

interface DeploymentTransaction {
    transactionType: string;
    contractAddress: string;
}

interface BroadcastArtifact {
    transactions: DeploymentTransaction[];
}

export class TestEnvironment {
    private anvilProcess: ChildProcess | null = null;
    public provider: ethers.JsonRpcProvider | null = null;
    private readonly contractsDir: string;
    // Known whale addresses with large balances
    private readonly USDC_WHALE = "0x47ac0Fb4F2D84898e4D9E7b4DaB3C24507a6D503"; // Binance wallet
    private readonly WETH_WHALE = "0x8EB8a3b98659Cce290402893d0123abb75E3ab28"; // Avalanche bridge

    // Token addresses on mainnet
    private readonly USDC_ADDRESS = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48";
    private readonly WETH_ADDRESS = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";


    constructor() {
        // Path to contracts directory from backend
        this.contractsDir = resolve(__dirname, '../../contracts');
    }

    async start(): Promise<void> {
        // Start Anvil
        this.anvilProcess = spawn('anvil', [
            '--port', '8545',
            '--fork-url', process.env.MAIN_NET_URL as string,
            '--fork-block-number', '22476889',
        ]);
        await new Promise(resolve => setTimeout(resolve, 2000));

        this.provider = new ethers.JsonRpcProvider('http://localhost:8545');

        // Deploy contracts using forge from contracts directory
        await this.deployContracts();
    }

    private async deployContracts(): Promise<void> {
        console.log(process.env.MAIN_NET_URL);
        return new Promise((resolve, reject) => {
            const deployProcess = spawn('forge', [
                'script',
                'script/KmanDEXRouter.s.sol',
                '--rpc-url', 'http://localhost:8545',
                '--broadcast'
            ], {
                cwd: this.contractsDir // Run forge from contracts directory
            });

            deployProcess.stdout?.on('data', (data) => {
                console.log(`Deploy: ${data}`);
            });

            deployProcess.stderr?.on('data', (data) => {
                console.error(`Deploy Error: ${data}`);
            });

            deployProcess.on('close', (code) => {
                code === 0 ? resolve() : reject(new Error(`Deployment failed with code ${code}`));
            });
        });
    }

    async stop(): Promise<void> {
        if (this.anvilProcess) {
            this.anvilProcess.kill();
            this.anvilProcess = null;
        }
    }

    getDeployedAddress(): string {
        // Look for broadcast artifacts in contracts directory
        const broadcastDir = join(this.contractsDir, 'broadcast');
        const runLatest = join(broadcastDir, 'KmanDEXRouter.s.sol/1/run-latest.json');

        if (!existsSync(runLatest)) {
            throw new Error(`Contract deployment artifacts not found at: ${runLatest}`);
        }

        const broadcast: BroadcastArtifact = JSON.parse(readFileSync(runLatest, 'utf8'));
        const createTx = broadcast.transactions.find(tx => tx.transactionType === 'CREATE');

        if (!createTx) {
            throw new Error('CREATE transaction not found in deployment');
        }

        return createTx.contractAddress;
    }

    getContractABI(contractName: string): any[] {
        // Get ABI from contracts/out directory
        const abiPath = join(this.contractsDir, `out/${contractName}.sol/${contractName}.json`);

        if (!existsSync(abiPath)) {
            throw new Error(`Contract ABI not found at: ${abiPath}`);
        }

        const artifact = JSON.parse(readFileSync(abiPath, 'utf8'));
        return artifact.abi;
    }

    async impersonateWhale(whaleAddress: string): Promise<ethers.Signer> {
        // Impersonate the whale account
        await this.provider!.send("anvil_impersonateAccount", [whaleAddress]);

        // Fund the whale with ETH for gas
        await this.provider!.send("anvil_setBalance", [
            whaleAddress,
            "0x56BC75E2D630E000" // 100 ETH in hex
        ]);

        return this.provider!.getSigner(whaleAddress);
    }

    getUSDCWhale(): string { return this.USDC_WHALE; }
    getWETHWhale(): string { return this.WETH_WHALE; }
    getUSDCAddress(): string { return this.USDC_ADDRESS; }
    getWETHAddress(): string { return this.WETH_ADDRESS; }
}