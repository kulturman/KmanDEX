# KmanDEX

KmanDEX is a minimal decentralized exchange composed of Solidity smart contracts and a small TypeScript backend API.

## Repository layout

- **contracts/** – Foundry project containing the `KmanDEX` smart contracts and tests.
- **backend/** – Express server exposing an HTTP API that interacts with the deployed contracts via `ethers.js`.

## Prerequisites

- Node.js and npm
- [Foundry](https://book.getfoundry.sh/) for compiling and testing contracts

## Setup

Install Node dependencies in the `backend` directory:

```bash
cd backend
npm install
```

Environment variables are read from `.env` files. Examples can be found in `backend/.env.example` and `contracts/.env.example`.
At minimum the backend requires:

- `RPC_URL` – JSON-RPC endpoint
- `CONTRACT_ADDRESS` – address of `KmanDEXRouter`

For contract tests, `MAIN_NET_URL` should be set to an Ethereum mainnet RPC endpoint.

## Running the backend

```bash
npm run build   # transpile TypeScript
npm start       # run the compiled server
```

During development you can use

```bash
npm run dev
```

which runs the API using `ts-node`.

## Testing

### Contracts

From the `contracts` directory, run:

```bash
forge test
```

which executes the Solidity tests with Foundry.

### Backend

```bash
npm test
```

The backend tests spin up a local Anvil node and deploy the contracts using Foundry. Ensure `anvil` and `forge` are installed and available in `$PATH`.

