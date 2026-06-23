// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/AnchorRegistry.sol";

/**
 * Deploy AnchorRegistry via CREATE2 (fixed salt) for a single canonical address
 * across every chain. The {salt:} new-expression routes through Foundry's
 * deterministic CREATE2 factory (0x4e59b44847b379578588920cA78FbF26c0B4956C),
 * which exists at the same address on Base and Arbitrum One, so:
 *   address = keccak256(0xff, factory, SALT, keccak256(initCode))[12:]
 * is identical on both. No constructor args -> identical initCode -> same address.
 *
 * Targets (T3, creator-authorized 2026-06-22):
 *   Base mainnet     chainid 8453   --rpc-url https://mainnet.base.org
 *   Arbitrum One     chainid 42161  --rpc-url https://arb1.arbitrum.io/rpc
 *
 * Usage:
 *   forge script script/DeployAnchorRegistry.s.sol:DeployAnchorRegistry \
 *     --rpc-url $RPC --broadcast --private-key $OWNER_PRIVATE_KEY
 */
contract DeployAnchorRegistry is Script {
    // Fixed canonical salt — must stay identical across all chains.
    bytes32 constant SALT = keccak256("mycelium.anchor.registry.v1");

    function run() external {
        vm.startBroadcast();
        AnchorRegistry reg = new AnchorRegistry{salt: SALT}();
        console.log("AnchorRegistry deployed at:", address(reg));
        console.log("chainid:", block.chainid);
        vm.stopBroadcast();
    }
}
