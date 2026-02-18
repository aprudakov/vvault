// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {VaultFactory} from "../src/VaultFactory.sol";
import {Vault} from "../src/Vault.sol";
import {ISafe} from "../lib/safe-contracts/contracts/interfaces/ISafe.sol";
import {Safe} from "../lib/safe-contracts/contracts/Safe.sol";
import {SafeProxyFactory} from "../lib/safe-contracts/contracts/proxies/SafeProxyFactory.sol";

contract VaultFactoryTest is Test {
    VaultFactory internal vaultFactory;
    Safe internal safeSingleton;
    SafeProxyFactory internal safeProxyFactory;

    address internal leader;
    address internal asset;

    function setUp() public {
        leader = makeAddr("leader");
        asset = makeAddr("asset");

        safeSingleton = new Safe();
        safeProxyFactory = new SafeProxyFactory();
        vaultFactory = new VaultFactory(
            address(safeSingleton),
            address(safeProxyFactory),
            asset
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
}
