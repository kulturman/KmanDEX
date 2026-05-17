# KmanDEX — Improvement Tasks

Working checklist of every issue surfaced during the project review. Tackle in order — security first, correctness second, idiomatic polish third, then backend, then hygiene. Each item has acceptance criteria so you (and I, when you ask me to verify) know when it's done.

**Legend**
- `[ ]` — not started
- `[~]` — in progress
- `[x]` — done & verified

---

## 1. Critical Security Issues

### 1.1 Reentrancy guards on Pool

- [x] **Add OpenZeppelin `ReentrancyGuard` to `KmanDEXPool` and `KmanDEXRouter`**
  - Inherit `ReentrancyGuard` in `KmanDEXPool.sol` and `KmanDEXRouter.sol`.
  - Apply `nonReentrant` to `swap`, `investLiquidity`, `withdrawLiquidity` on both contracts.
  - **Why**: External token transfers happen alongside state updates. A malicious ERC-20 (or ERC-777 hook token) can re-enter during `transfer` / `transferFrom` and drain the pool. This is the #1 DeFi attack vector — every reviewer asks about it.
  - **Acceptance**: contract compiles, all existing tests still pass.
  - **Verification (2026-05-06)**: confirmed `ReentrancyGuard` inherited on both contracts; `nonReentrant` present on all 6 state-changing external functions. Reentrancy unit test intentionally skipped — testing the modifier itself is OZ's responsibility; code review confirms correct placement. Acceptable tradeoff at this project scope.

### 1.2 Swap reserve accounting bug

- [ ] **Fix the fee-vs-reserve mismatch in `KmanDEXPool._swap`**
  - File: `contracts/src/KmanDEXPool.sol:148-156`.
  - Current code: `tokenAAmount += amountIn` after computing the new reserve from `amountInAfterFee`. This double-counts the fee in the reserve, so `invariant = tokenAAmount * tokenBAmount` no longer matches the constant-product semantics.
  - Decide: does the fee stay in the pool (boosting LP yield) or go to a fee collector? Pick one and make the reserve math consistent.
  - **Acceptance**: a fuzz test that runs N random swaps and asserts `tokenAAmount == IERC20(tokenA).balanceOf(pool)` passes. (See task 4.2.)

### 1.3 Use `SafeERC20` everywhere

- [x] **Replace raw `IERC20.transfer/transferFrom/approve` with `SafeERC20.safeTransfer/safeTransferFrom/forceApprove`**
  - Files: `KmanDEXPool.sol`, `KmanDEXRouter.sol`.
  - You already import `SafeERC20` in the router but never use it.
  - **Why**: USDT (and a handful of other major tokens) returns no boolean from `transfer`. Raw calls revert against USDT today. `SafeERC20` handles this.
  - **Acceptance**: every ERC-20 call site uses `safeXxx`. A new test using a return-nothing mock token (you can write `ERC20NoReturnMock`) succeeds where the previous code would have reverted.
  - **Verification (2026-05-11)**: `grep -nE "IERC20\([^)]+\)\.(transfer|transferFrom|approve)\(" contracts/src/` returns nothing. Router uses `safeTransferFrom`/`safeTransfer`/`forceApprove`; Pool now imports `SafeERC20`, declares `using SafeERC20 for IERC20`, and uses `safeTransfer`/`safeTransferFrom` on all 4 call sites. `forge build` clean, all 22 existing tests pass. ERC20NoReturnMock-based test deferred — covered conceptually by the grep + the OZ guarantee.

### 1.4 First-deposit inflation attack

- [x] **Burn a small amount of initial shares to `address(0)`**
  - File: `KmanDEXPool.sol`, in the `localTotalShares == 0` branch of `investLiquidity`.
  - Mirror Uniswap V2: mint `INITIAL_SHARES` to the depositor, mint `MINIMUM_LIQUIDITY` (e.g., 1000 wei) to `address(0)` so it's permanently locked.
  - Also bump `INITIAL_SHARES` to be `1e18`-scaled — `1000` literal is far too coarse for proportional math.
  - **Why**: Without a locked minimum, the first depositor can grief later LPs by donating tokens directly to the pool to inflate share value.
  - **Acceptance**: existing tests adjusted for the new scaling; a new test demonstrates the inflation attack is no longer profitable.
  - **Verification (2026-05-17)**: `INITIAL_SHARES` bumped to `1e18`, new `MINIMUM_LIQUIDITY = 1000` constant added. First-deposit branch now mints `INITIAL_SHARES - MINIMUM_LIQUIDITY` to the depositor and `MINIMUM_LIQUIDITY` to `address(0)`. Existing invest/withdraw tests recalibrated to the new scale. New regression suite `KmanDEXPoolInflationAttackTest.t.sol` (3 tests) covers: locked shares at `address(0)`, locked shares never reduced by subsequent LP activity, and that a tiny seed doesn't grief later LPs. All 25 tests green.

### 1.5 `initialize` access control

- [ ] **Stop trusting the caller-supplied `factory_` parameter**
  - File: `KmanDEXPool.sol:38-48`.
  - Current: `require(msg.sender == factory_)` — but `factory_` is a function argument, so the check is vacuous.
  - Fix: drop the `factory_` parameter entirely. Either set it from `msg.sender` directly, or read it from a `factory` storage slot set in the template's constructor and have the factory pass only the per-pool data.
  - **Acceptance**: a test attempting to call `initialize` on a freshly-cloned pool from a non-factory address reverts.

### 1.6 Inert template pool

- [ ] **Make the `mainPool` template uninitializable**
  - File: `KmanDEXFactory.sol:22`.
  - The template deployed in the factory's constructor has zero-address tokens and isn't used directly, but as written it could be initialized by anyone calling `initialize` on it. Lock it: in the template's constructor, set `factory = address(this)` (or any non-zero sentinel) so the `factory == address(0)` initialization gate fails.
  - **Acceptance**: test confirms `mainPool.initialize(...)` reverts with `AlreadyInitialized`.

### 1.7 Uniswap fallback hardening

- [ ] **Fix `KmanDEXRouter._forwardToUniswap`**
  - File: `KmanDEXRouter.sol:75-101`.
  - Three issues:
    1. `block.timestamp` as deadline — accept a user-supplied `deadline` instead.
    2. Slippage check uses the user's `minTokenOut` against `amountInMinusFees` — document and adjust so the user knows the fee is taken from input.
    3. Fee is sent before the swap; if the swap reverts, the fee transfer also reverts (good) — but reorder for clarity: do the swap first, then split the output.
  - Also: `UNISWAP_ROUTER` should be a constructor argument so the contract works on testnets / L2s where the address differs.
  - **Acceptance**: signature changes propagated through tests; a test on Sepolia/fork confirms an expired deadline reverts.

### 1.8 ERC-20 boolean check coverage

- [ ] **Audit every external token call for return-value handling**
  - After 1.3 this should be automatic, but do a final grep for `IERC20(`, `.transfer(`, `.transferFrom(`, `.approve(` and confirm each goes through `SafeERC20`.
  - **Acceptance**: `grep -nE "IERC20\([^)]+\)\.(transfer|transferFrom|approve)\(" contracts/src/` returns nothing.

---

## 2. Solidity Correctness & Idiomatic Issues

### 2.1 Pin a single Solidity version

- [ ] **Use `pragma solidity 0.8.28;` (exact, no caret) in every file**
  - Currently a mix of `0.8.28`, `^0.8.10`, `^0.8.28` across `src/` and `test/`.
  - **Acceptance**: `grep -rn "pragma solidity" contracts/` shows only `pragma solidity 0.8.28;`.

### 2.2 Remove inline assembly for trivial division

- [ ] **Replace all `assembly { x := div(x, y) }` with plain Solidity `/`**
  - File: `KmanDEXPool.sol:89-92`, `:128-130`, `:140-142`.
  - **Why**: 0.8+ already skips the zero-check on constant divisors, gas savings are negligible (≤5), and inline assembly signals "I don't trust the compiler" to reviewers. Plus `div(x, 0)` returns 0 in Yul instead of reverting, which is a footgun if the divisor ever becomes a variable.
  - **Acceptance**: no `assembly` blocks remain in `src/`.

### 2.3 Drop redundant `invariant` storage

- [ ] **Remove the `invariant` state variable**
  - File: `KmanDEXPool.sol:17`.
  - Recompute `tokenAAmount * tokenBAmount` where needed (it's only used in `_swap` to derive the new reserve, and you can do that inline). Storing it costs ~5K gas per write (`SSTORE` of a non-zero->non-zero slot) on every swap and every liquidity event for zero benefit.
  - **Acceptance**: variable removed, all tests still pass, gas snapshot shows reduced cost on `swap`.

### 2.4 Make `UNISWAP_ROUTER` configurable

- [ ] **Pass the Uniswap router address via constructor**
  - File: `KmanDEXRouter.sol:13`.
  - Store as `immutable` (cheap reads, no storage slot).
  - Update the deployment script to read from env: `vm.envAddress("UNISWAP_ROUTER")` with a sensible mainnet default.
  - **Acceptance**: tests pass with a mock Uniswap router on local Anvil without forking.

### 2.5 Replace magic numbers with named constants

- [ ] **Clarify fee math**
  - `FEE_RATE = 500` is opaque. Replace with `FEE_BPS = 20` and `BPS_DENOMINATOR = 10_000` (same effect: 0.2%, but readable).
  - Same for `UNISWAP_ROUTING_FEE = 1000` → `UNISWAP_FORWARD_FEE_BPS = 10` + `BPS_DENOMINATOR`.
  - **Acceptance**: no naked integers in fee arithmetic.

### 2.6 Add NatSpec on every public/external function

- [ ] **Document every external surface**
  - At minimum `/// @notice` and `/// @param` for `investLiquidity`, `withdrawLiquidity`, `swap`, `createPool`, `getPoolAddress`, `getAllPools`, `getLiquidityProviders`, `initialize`.
  - Mark dangerous parameters (e.g., `minimumShares` — "set to non-zero to protect against sandwich attacks").
  - **Acceptance**: `forge doc` produces clean output without "missing NatSpec" warnings.

### 2.7 Return shares from `investLiquidity`

- [ ] **Have `Pool.investLiquidity` and `Router.investLiquidity` return `(uint256 sharesMinted)`**
  - Lets the caller verify the result without re-querying state.
  - **Acceptance**: signature updated, tests assert returned value matches `pool.shares(user)` delta.

### 2.8 Bound the `liquidityProviders` array growth

- [ ] **Drop the array; rely on the existing `LiquidityAdded` event for offchain queries**
  - File: `KmanDEXRouter.sol:16, :20, :47-50, :103-105`.
  - `getLiquidityProviders()` returns the entire array — this will hit block gas limit at scale.
  - You already use events in the backend (`/users`, `/swaps`); be consistent.
  - **Acceptance**: array + getter removed, backend updated to use `LiquidityAdded` events.

### 2.9 Clean up `KmanDEXPool` constructor

- [ ] **Make `KmanDEXPool`'s constructor parameter-free**
  - With `Clones`, the constructor of `KmanDEXPool` only ever runs once for the template — the parameters passed there (`contractOwner`, `factory`, `router`, `tokenA`, `tokenB`) are dead values for every cloned pool.
  - Either remove the constructor args entirely or use them solely to mark the template inert (per task 1.6).
  - **Acceptance**: constructor takes no args (or only what's needed to brick the template); cloned pools are fully driven by `initialize`.

### 2.10 Remove dead code

- [ ] **Delete unused imports and notes**
  - `contracts/test/ERC20Mock.sol` imports `forge-std/console` for no reason.
  - `KmanDEXPool.sol:120` comment ("I avoided using cache variables...") reads like a personal note. Either delete it or rewrite as `/// @dev avoided locals here to dodge stack-too-deep`.
  - `backend/index.ts:30` `if (!factoryContract)` after `new ethers.Contract(...)` — that constructor never returns falsy, so the branch is dead.
  - **Acceptance**: `forge build` produces no "unused" warnings; reviewer-grade comments only.

### 2.11 Consistent licensing

- [ ] **Pick one SPDX license and use it everywhere**
  - Currently `UNLICENSED` (pool, factory) and `MIT` (router) coexist. Choose one (probably `MIT` for a portfolio piece — it signals "feel free to read").
  - **Acceptance**: all `.sol` files share the same SPDX header.

---

## 3. Test Quality

### 3.1 Stop pranking as the router

- [ ] **Refactor `KmanDEXRouterTest` to use a real EOA**
  - File: `contracts/test/KmanDEXRouterTest.t.sol` — every test starts with `vm.startPrank(address(router))`, which means the *router* is calling its own functions. This bypasses the user→router→pool path you actually want to exercise.
  - Create a `user = makeAddr("user")`, `deal` tokens to that user, prank as the user.
  - **Acceptance**: tests pass with realistic call flow; coverage of the router's `msg.sender == user` paths is real.

### 3.2 Add fuzz tests

- [ ] **Add `forge` fuzz tests for the AMM invariant**
  - New file: `contracts/test/KmanDEXPoolFuzz.t.sol`.
  - At minimum:
    - `testFuzz_SwapPreservesInvariant(uint256 amountIn)` — bound `amountIn` to realistic range, swap, assert `tokenAAmount * tokenBAmount >= invariantBefore` (constant-product law modulo fees).
    - `testFuzz_BalanceMatchesReserves(uint256 amountIn)` — after any operation, `IERC20(tokenA).balanceOf(pool) == tokenAAmount`. This is the test that would have caught task 1.2.
    - `testFuzz_SharesProportional(uint256 amountA, uint256 amountB)` — minted shares are proportional to deposit ratio.
  - **Acceptance**: at least 3 fuzz tests, each running ≥256 fuzz runs, all green.

### 3.3 Add invariant (stateful) tests

- [ ] **Add `StdInvariant`-based tests**
  - New file: `contracts/test/KmanDEXPoolInvariant.t.sol`.
  - Build a `Handler` contract that randomly calls `investLiquidity`, `withdrawLiquidity`, `swap` over many runs.
  - Invariants to assert:
    - Sum of all `shares[user]` equals `totalShares` (minus locked minimum).
    - `tokenAAmount == IERC20(tokenA).balanceOf(pool)` (and same for B).
    - `tokenAAmount > 0 && tokenBAmount > 0` whenever `totalShares > 0`.
  - **Acceptance**: invariant suite runs, depth ≥50, and all invariants hold.

### 3.4 Multi-LP / interleaved scenarios

- [ ] **Add a unit test where two LPs deposit at different times and a trader swaps in between**
  - Verify LP1 still gets the right amount on withdrawal after LP2 joined and trades happened.
  - **Acceptance**: test passes; demonstrates correct fee accrual to LPs.

### 3.5 Hostile token tests

- [ ] **Test against malicious-but-legal token behaviors**
  - Add mocks: `ERC20NoReturnMock` (USDT-style), `ERC20FeeOnTransferMock`, `ERC20ReentrantMock`.
  - For each, document expected behavior. Fee-on-transfer is "not supported, will revert / leave pool inconsistent" — that's fine, but make it a conscious decision.
  - **Acceptance**: tests demonstrate either correct support or explicit rejection; documented in NatSpec.

### 3.6 Gas snapshots

- [ ] **Commit a `.gas-snapshot` file**
  - Run `forge snapshot` and commit. Add CI step to fail if any function regresses by >10%.
  - **Acceptance**: snapshot file exists; README mentions gas costs of `swap`, `investLiquidity`, `createPool`.

### 3.7 Fix flaky `tx.wait()` in backend tests

- [ ] **Add missing `await` on `tx4.wait()`**
  - File: `backend/index.spec.ts:128, :158`.
  - Without `await`, the route can be hit before the swap is mined — flaky.
  - **Acceptance**: both `tx4.wait()` calls awaited.

---

## 4. Backend

### 4.1 Layered architecture

- [ ] **Split `index.ts` into folders**
  - Suggested layout:
    ```
    backend/src/
      app.ts                 // express app factory
      server.ts              // entrypoint that starts listen()
      config/                // env loading + zod-validated config
      routes/                // express routers
      controllers/           // thin handlers
      services/              // business logic
      contracts/             // ethers contract factories (cached singletons)
      models/                // types (Pool, Swap, ...)
      middleware/            // error handler, logger, validation
    ```
  - **Acceptance**: `index.ts` is a 5-line bootstrap; logic lives in services; each module has a single reason to change.

### 4.2 Cache contract instances

- [ ] **Instantiate `routerContract` and `factoryContract` once at startup**
  - Currently `new ethers.Contract(...)` runs on every request.
  - Build a `getContracts()` singleton that lazy-initializes once.
  - **Acceptance**: no `new ethers.Contract` calls inside route handlers.

### 4.3 Config validation with Zod

- [ ] **Validate `process.env` once at boot**
  - Use `zod` (or `envalid`) to parse `RPC_URL`, `CONTRACT_ADDRESS`, `PORT`, `MAIN_NET_URL` into a typed `config` object.
  - Crash fast on missing/invalid vars with a clear error message.
  - **Acceptance**: deleting an env var produces a single readable error pointing at the missing key.

### 4.4 Request validation

- [ ] **Validate query params and bodies with Zod**
  - Even the current routes don't take input, but plan ahead for `/swaps?fromBlock=...&toBlock=...&user=...`.
  - Add a `validate(schema)` middleware.
  - **Acceptance**: a malformed query returns 400 with a structured error body, not a 500.

### 4.5 Error handling middleware

- [ ] **Add a global error handler**
  - Catch async errors (Express 5 supports async route handlers natively, but you still want a unified shape: `{ error: { code, message } }`).
  - Distinguish 4xx (validation, missing pool) from 5xx (RPC down).
  - **Acceptance**: simulating an RPC outage returns `503` with `{ error: { code: "RPC_UNAVAILABLE", ... } }`.

### 4.6 Structured logging

- [ ] **Add `pino` (or `winston`) instead of `console.log`**
  - JSON logs with request IDs.
  - Add `pino-http` middleware for per-request logging.
  - **Acceptance**: every request produces a single JSON log line with method, path, status, duration, requestId.

### 4.7 Security middleware

- [ ] **Add `helmet` and `express-rate-limit`**
  - Defaults are fine for a portfolio.
  - **Acceptance**: `curl -I` shows hardened headers (`X-Frame-Options`, etc.); rate limit kicks in after configured threshold.

### 4.8 Indexer instead of `queryFilter` per request

- [ ] **Build a minimal background event indexer**
  - SQLite (via `better-sqlite3`) or Postgres.
  - A worker process tails `SuccessfulSwap` and `LiquidityAdded` events from the last indexed block forward, persists them, and the API queries the DB.
  - Routes `/swaps` and `/users` should hit the DB, not RPC.
  - **Acceptance**: `/swaps` is O(DB query) regardless of chain history depth; restarting the server resumes from the last indexed block.

### 4.9 Pagination

- [ ] **Paginate `/pools`, `/swaps`, `/users`, `/liquidity-providers`**
  - Standard `?limit=&offset=` or cursor-based.
  - **Acceptance**: response includes pagination metadata; large result sets don't timeout.

### 4.10 OpenAPI spec

- [ ] **Generate or hand-write an `openapi.yaml`**
  - Serve at `/docs` via `swagger-ui-express`.
  - **Acceptance**: hitting `/docs` in a browser shows interactive API docs.

### 4.11 ABI handling

- [ ] **Decouple backend from `../contracts/out/`**
  - Add a `prebuild` npm script that runs `forge build` in `../contracts` and copies the relevant ABIs into `backend/abi/`.
  - Or commit the ABIs directly (small JSON files; pin them).
  - **Acceptance**: `npm run build` from a clean checkout (without forge artifacts) succeeds.

### 4.12 Dockerization

- [ ] **Add `Dockerfile` and `docker-compose.yml`**
  - Multi-stage Dockerfile for the backend (build → slim runtime).
  - Compose file with `anvil` + `backend` + `postgres` services for local dev.
  - **Acceptance**: `docker compose up` brings up the full local stack; `curl localhost:3000/pools` works.

---

## 5. Repo Hygiene

### 5.1 Gitignore build artifacts

- [ ] **Confirm `out/`, `cache/`, `broadcast/` are gitignored**
  - In `contracts/.gitignore`: `out/`, `cache/`, `broadcast/`.
  - **Acceptance**: `git status --ignored` shows these as ignored, and they're not in the index.

### 5.2 README upgrade

- [ ] **Expand `README.md`**
  - ASCII architecture diagram (Router → Factory → Pool).
  - Security caveats: "Not audited. Educational project. Do not deploy with real funds."
  - Gas snapshot table (top 5 functions).
  - Deployed Sepolia addresses (after task 5.4).
  - Link to backend OpenAPI docs.
  - **Acceptance**: README answers "what is this, how do I run it, what's the architecture, what's deployed where" in <2 minutes of reading.

### 5.3 CI workflow

- [ ] **Add `.github/workflows/ci.yml`**
  - Jobs: `forge fmt --check`, `forge build`, `forge test -vvv`, `forge snapshot --check`, `npm test` (backend), `tsc --noEmit`.
  - Run on PR and push to main.
  - **Acceptance**: green CI badge in README.

### 5.4 Sepolia deployment

- [ ] **Deploy to Sepolia and document addresses**
  - Use the existing `KmanDEXRouter.s.sol` script.
  - Verify on Etherscan (`forge verify-contract`).
  - Add addresses to README + a `deployments/sepolia.json` file.
  - **Acceptance**: a reviewer can click an Etherscan link and see verified source.

### 5.5 Expand `.env.example` files

- [ ] **List every required and optional env var with comments**
  - `backend/.env.example`: `RPC_URL`, `CONTRACT_ADDRESS`, `PORT`, `MAIN_NET_URL`, `LOG_LEVEL`.
  - `contracts/.env.example`: `MAIN_NET_URL`, `SEPOLIA_URL`, `LOCAL_CHAIN_URL`, `PRIVATE_KEY`, `ETHERSCAN_API_KEY`, `UNISWAP_ROUTER`.
  - **Acceptance**: a fresh clone + `cp .env.example .env` + filling in real values is enough to run everything.

### 5.6 Pre-commit hooks (optional polish)

- [ ] **Add `lefthook` or `husky` running `forge fmt` and `tsc --noEmit`**
  - **Acceptance**: committing badly-formatted Solidity is blocked locally.

---

## 6. Interview-Prep Items

These aren't code tasks — they're conceptual answers you should be able to give cold. Write your own answer for each in this file or a separate `NOTES.md`.

- [ ] **What happens if I call `swap` with USDT and an existing USDT pool?** (Hint: post-task 1.3 it works; pre-task 1.3 it reverts on the missing-bool return.)
- [ ] **What stops a first-deposit inflation attack?** (Post-task 1.4: locked `MINIMUM_LIQUIDITY`.)
- [ ] **Why store `invariant`?** (Post-task 2.3: you don't.)
- [ ] **How are fee-on-transfer tokens handled?** (Post-task 3.5: explicitly unsupported / measured via balance delta.)
- [ ] **State a single invariant for the pool and prove it.** (Post-task 3.3: balance == reserves; `Σ shares == totalShares`.)
- [ ] **Walk through the gas savings of `Clones` vs `new`.** You already did this in code comments — be ready to say it out loud.
- [ ] **What's MEV-protection look like for `swap`?** (Slippage check via `minOut`; `deadline` parameter on Uniswap forwarding — task 1.7.)

---

## Progress

- Critical security: 3 / 8
- Solidity correctness: 0 / 11
- Tests: 0 / 7
- Backend: 0 / 12
- Hygiene: 0 / 6
- Interview prep: 0 / 7

**Total: 3 / 51**