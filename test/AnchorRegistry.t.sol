// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/AnchorRegistry.sol";

contract AnchorRegistryTest is Test {
    AnchorRegistry registry;

    address alice = address(0xA11CE);
    address bob   = address(0xB0B);

    // Mirror of the event for vm.expectEmit.
    event Anchored(bytes32 indexed ref, address indexed anchoredBy, uint256 timestamp);

    function setUp() public {
        registry = new AnchorRegistry();
    }

    /// Anyone can anchor — no owner, no gate.
    function test_anyoneCanAnchor() public {
        bytes32 ref = keccak256("counterparty_ref");

        vm.prank(alice);
        registry.anchor(ref);

        vm.prank(bob);
        registry.anchor(ref);
        // No revert == permissionless for arbitrary callers.
    }

    /// expectEmit: event shape and indexed args match.
    function test_emitsAnchoredEvent() public {
        bytes32 ref = keccak256("ref-emit");
        uint256 ts = 1_700_000_000;
        vm.warp(ts);

        vm.expectEmit(true, true, false, true);
        emit Anchored(ref, alice, ts);

        vm.prank(alice);
        registry.anchor(ref);
    }

    /// The hard requirement: prove the event actually lands in the tx logs,
    /// and decode topics/data to confirm contents.
    function test_eventIsInLogs() public {
        bytes32 ref = keccak256("ref-in-logs");
        uint256 ts = 1_711_111_111;
        vm.warp(ts);

        vm.recordLogs();
        vm.prank(alice);
        registry.anchor(ref);

        Vm.Log[] memory logs = vm.getRecordedLogs();
        assertEq(logs.length, 1, "exactly one log expected");

        Vm.Log memory entry = logs[0];
        assertEq(entry.emitter, address(registry), "emitter is the registry");

        // topic[0] = keccak256("Anchored(bytes32,address,uint256)")
        assertEq(entry.topics[0], keccak256("Anchored(bytes32,address,uint256)"), "event sig");
        // topic[1] = indexed ref
        assertEq(entry.topics[1], ref, "indexed ref");
        // topic[2] = indexed anchoredBy (address left-padded to 32 bytes)
        assertEq(entry.topics[2], bytes32(uint256(uint160(alice))), "indexed anchoredBy");
        // data = abi-encoded non-indexed timestamp
        uint256 loggedTs = abi.decode(entry.data, (uint256));
        assertEq(loggedTs, ts, "timestamp in data");
    }

    /// Re-anchoring the same ref by different parties is allowed and produces
    /// distinct discoverable events (counterparty independence).
    function test_reanchorAllowed() public {
        bytes32 ref = keccak256("shared-counterparty-ref");

        vm.recordLogs();
        vm.prank(alice);
        registry.anchor(ref);
        vm.prank(bob);
        registry.anchor(ref);

        Vm.Log[] memory logs = vm.getRecordedLogs();
        assertEq(logs.length, 2, "two independent anchors logged");
        assertEq(logs[0].topics[2], bytes32(uint256(uint160(alice))), "first anchorer");
        assertEq(logs[1].topics[2], bytes32(uint256(uint160(bob))), "second anchorer");
    }
}
