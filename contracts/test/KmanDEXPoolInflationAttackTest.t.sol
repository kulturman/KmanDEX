// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Test} from "../lib/forge-std/src/Test.sol";
import {KmanDEXPool, IKmanDEXPool} from "../src/KmanDEXPool.sol";
import {KmanDEXRouter} from "../src/KmanDEXRouter.sol";
import {IKmanDEXFactory} from "../src/KmanDEXFactory.sol";
import {ERC20Mock} from "./ERC20Mock.sol";

/// @notice Regression tests for the first-deposit inflation attack mitigation (IMPROVEMENTS.md §1.4).
contract KmanDEXPoolInflationAttackTest is Test {
    KmanDEXPool public pool;
    KmanDEXRouter public router;
    ERC20Mock public tokenA;
    ERC20Mock public tokenB;

    address public attacker = makeAddr("attacker");
    address public victim = makeAddr("victim");

    function setUp() public {
        tokenA = new ERC20Mock("TokenA", "TKA");
        tokenB = new ERC20Mock("TokenB", "TKB");
        router = new KmanDEXRouter();
        pool = KmanDEXPool(IKmanDEXFactory(router.factory()).createPool(address(tokenA), address(tokenB)));

        // ERC20Mock mints 1e8 tokens to deployer. Split a comfortable budget between actors.
        tokenA.transfer(attacker, 10_000_000);
        tokenB.transfer(attacker, 10_000_000);
        tokenA.transfer(victim, 10_000_000);
        tokenB.transfer(victim, 10_000_000);
    }

    /// MINIMUM_LIQUIDITY is locked at address(0) and address(0) has no way to withdraw it.
    /// This is what prevents the attacker from owning 100% of the supply right after the first deposit.
    function testMinimumLiquidityIsLockedAtAddressZero() public {
        vm.startPrank(attacker);
        tokenA.approve(address(router), type(uint256).max);
        tokenB.approve(address(router), type(uint256).max);
        router.investLiquidity(address(tokenA), address(tokenB), 100_000, 100_000, 0);
        vm.stopPrank();

        uint256 minimumLiquidity = pool.MINIMUM_LIQUIDITY();
        uint256 initialShares = pool.INITIAL_SHARES();

        assertEq(pool.shares(address(0)), minimumLiquidity, "MINIMUM_LIQUIDITY must be locked at address(0)");
        assertEq(pool.shares(attacker), initialShares - minimumLiquidity, "Attacker must not own the entire supply");
        assertLt(pool.shares(attacker), pool.totalShares(), "Attacker share < totalShares (locked liquidity exists)");
    }

    /// There is no path in the contract that mutates `shares[address(0)]` after the first deposit,
    /// so the locked MINIMUM_LIQUIDITY can never be reclaimed.
    function testLockedLiquidityIsNeverReducedByLPActivity() public {
        vm.startPrank(attacker);
        tokenA.approve(address(router), type(uint256).max);
        tokenB.approve(address(router), type(uint256).max);
        router.investLiquidity(address(tokenA), address(tokenB), 100_000, 100_000, 0);
        vm.stopPrank();

        uint256 minimumLiquidity = pool.MINIMUM_LIQUIDITY();
        assertEq(pool.shares(address(0)), minimumLiquidity, "Locked shares set on first deposit");

        // A subsequent LP joins.
        vm.startPrank(victim);
        tokenA.approve(address(router), type(uint256).max);
        tokenB.approve(address(router), type(uint256).max);
        router.investLiquidity(address(tokenA), address(tokenB), 50_000, 50_000, 0);
        vm.stopPrank();

        assertEq(pool.shares(address(0)), minimumLiquidity, "Locked shares unchanged after second deposit");

        // Attacker withdraws everything they own.
        vm.startPrank(attacker);
        router.withdrawLiquidity(address(tokenA), address(tokenB), pool.shares(attacker));
        vm.stopPrank();

        assertEq(pool.shares(address(0)), minimumLiquidity, "Locked shares unchanged after attacker exits");
    }

    /// The attacker's classic griefing playbook — deposit a tiny seed, hope the next LP loses out to rounding —
    /// no longer pays off. With INITIAL_SHARES scaled to 1e18, the second LP's shares are essentially
    /// proportional to their contribution, with negligible relative loss to MINIMUM_LIQUIDITY.
    function testSecondDepositIsNotGriefedByTinyFirstDeposit() public {
        // Attacker seeds the pool with a tiny but legal deposit.
        vm.startPrank(attacker);
        tokenA.approve(address(router), type(uint256).max);
        tokenB.approve(address(router), type(uint256).max);
        router.investLiquidity(address(tokenA), address(tokenB), 100_000, 100_000, 0);
        vm.stopPrank();

        // Victim deposits an equal amount and should get an equivalent share of the pool.
        vm.startPrank(victim);
        tokenA.approve(address(router), type(uint256).max);
        tokenB.approve(address(router), type(uint256).max);
        router.investLiquidity(address(tokenA), address(tokenB), 100_000, 100_000, 0);
        vm.stopPrank();

        uint256 attackerShares = pool.shares(attacker);
        uint256 victimShares = pool.shares(victim);

        // Victim ends up with INITIAL_SHARES (proportional to reserves); attacker has INITIAL_SHARES - MINIMUM_LIQUIDITY.
        // The 1e18 scaling makes the MINIMUM_LIQUIDITY gap negligible (~1e-15 relative diff).
        assertGt(victimShares, attackerShares, "Victim should not be griefed by attacker's tiny seed");
        assertApproxEqRel(victimShares, attackerShares, 1e15, "Victim and attacker shares should be within 0.1%");
    }
}
