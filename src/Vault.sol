// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface IERC20 {
    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external returns (bool);
}

contract Vault {
    address public safe;
    address public leader;
    IERC20 public asset;

    event Deposited(address indexed user, uint256 amount);
    event VaultInitialized(
        address indexed safe,
        address indexed leader,
        address indexed asset
    );

    constructor() {}

    function initialize(address _safe, address _leader, address _asset) external {
        require(address(asset) == address(0), "ALREADY_INITIALIZED");
        require(_safe != address(0), "INVALID_SAFE");
        require(_leader != address(0), "INVALID_LEADER");
        require(_asset != address(0), "INVALID_ASSET");

        safe = _safe;
        leader = _leader;
        asset = IERC20(_asset);

        emit VaultInitialized(_safe, _leader, _asset);
    }

    function deposit(uint256 amount) external {
        require(
            asset.transferFrom(msg.sender, safe, amount),
            "TRANSFER_FAILED"
        );
        emit Deposited(msg.sender, amount);
    }
}
