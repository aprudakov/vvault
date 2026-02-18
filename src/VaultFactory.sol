// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ISafe} from "../lib/safe-contracts/contracts/interfaces/ISafe.sol";
import {SafeProxyFactory} from "../lib/safe-contracts/contracts/proxies/SafeProxyFactory.sol";
import {Vault, IERC20} from "./Vault.sol";

contract VaultFactory {
    address public safeSingleton;
    address public safeProxyFactory;
    IERC20 public asset;

    event VaultCreated(address indexed vault, address indexed safe, address indexed leader);

    constructor(address _safeSingleton, address _safeProxyFactory, address _asset) {
        require(_safeSingleton != address(0), "INVALID_SAFE_SINGLETON");
        require(_safeProxyFactory != address(0), "INVALID_SAFE_PROXY_FACTORY");
        require(_asset != address(0), "INVALID_ASSET");

        safeSingleton = _safeSingleton;
        safeProxyFactory = _safeProxyFactory;
        asset = IERC20(_asset);
    }

    function createVault(address leader, uint256 saltNonce) external returns (address vault, address safe) {
        require(leader != address(0), "INVALID_LEADER");

        //TODO: Make protocol owner owner
        address[] memory owners = new address[](1);
        owners[0] = leader;
        //TODO: Add safe transaction guards
        bytes memory initializer = abi.encodeWithSelector(
            ISafe.setup.selector, owners, 1, address(0), bytes(""), address(0), address(0), 0, payable(address(0))
        );

        safe = address(SafeProxyFactory(safeProxyFactory).createProxyWithNonce(safeSingleton, initializer, saltNonce));

        Vault newVault = new Vault();
        newVault.initialize(safe, leader, address(asset));
        vault = address(newVault);

        emit VaultCreated(vault, safe, leader);
    }
}
