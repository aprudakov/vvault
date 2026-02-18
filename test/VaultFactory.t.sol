// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {VaultFactory} from "../src/VaultFactory.sol";
import {Vault} from "../src/Vault.sol";
import {ISafe} from "../lib/safe-contracts/contracts/interfaces/ISafe.sol";
import {Safe} from "../lib/safe-contracts/contracts/Safe.sol";
import {SafeProxyFactory} from "../lib/safe-contracts/contracts/proxies/SafeProxyFactory.sol";

contract MockUSDCe {
    mapping(address => uint256) internal balances;
    mapping(address => mapping(address => uint256)) internal allowances;

    function mint(address to, uint256 amount) external {
        balances[to] += amount;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowances[msg.sender][spender] = amount;
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool) {
        uint256 allowed = allowances[from][msg.sender];
        require(allowed >= amount, "INSUFFICIENT_ALLOWANCE");
        require(balances[from] >= amount, "INSUFFICIENT_BALANCE");

        allowances[from][msg.sender] = allowed - amount;
        balances[from] -= amount;
        balances[to] += amount;
        return true;
    }

    function balanceOf(address account) external view returns (uint256) {
        return balances[account];
    }
}

contract VaultFactoryTest is Test {
    VaultFactory internal vaultFactory;
    Safe internal safeSingleton;
    SafeProxyFactory internal safeProxyFactory;
    MockUSDCe internal usdcE;

    address internal leader;

    function setUp() public {
        leader = makeAddr("leader");
        usdcE = new MockUSDCe();

        safeSingleton = new Safe();
        safeProxyFactory = new SafeProxyFactory();
        vaultFactory = new VaultFactory(
            address(safeSingleton),
            address(safeProxyFactory),
            address(usdcE)
        );
    }

    function test_CreateVault_InitializesVaultAndSafe() public {
        uint256 saltNonce = 1;

        (address vaultAddress, address safeAddress) = vaultFactory.createVault(
            leader,
            saltNonce
        );

        Vault vault = Vault(vaultAddress);
        ISafe safe = ISafe(payable(safeAddress));

        assertEq(vault.safe(), safeAddress, "vault.safe mismatch");
        assertEq(vault.leader(), leader, "vault.leader mismatch");

        address[] memory owners = safe.getOwners();
        assertEq(owners.length, 1, "unexpected owner count");
        assertEq(owners[0], leader, "leader is not owner");
        assertTrue(safe.isOwner(leader), "isOwner(leader) should be true");
        assertEq(safe.getThreshold(), 1, "unexpected threshold");
    }

    function test_Deposit_SendsFundsToSafe() public {
        uint256 saltNonce = 2;
        uint256 amount = 250e6;
        address depositor = makeAddr("depositor");

        (address vaultAddress, address safeAddress) = vaultFactory.createVault(
            leader,
            saltNonce
        );
        Vault vault = Vault(vaultAddress);

        usdcE.mint(depositor, amount);
        uint256 safeBalanceBefore = usdcE.balanceOf(safeAddress);
        uint256 vaultBalanceBefore = usdcE.balanceOf(vaultAddress);

        vm.startPrank(depositor);
        usdcE.approve(vaultAddress, amount);
        vault.deposit(amount);
        vm.stopPrank();

        uint256 safeBalanceAfter = usdcE.balanceOf(safeAddress);
        uint256 vaultBalanceAfter = usdcE.balanceOf(vaultAddress);

        assertEq(
            safeBalanceAfter,
            safeBalanceBefore + amount,
            "safe did not receive deposited funds"
        );
        assertEq(
            vaultBalanceAfter,
            vaultBalanceBefore,
            "vault custody changed unexpectedly"
        );
        assertEq(vaultBalanceAfter, 0, "vault should not retain asset custody");
    }
}
