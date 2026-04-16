// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {GiskardIdentityRegistry} from "../src/GiskardIdentityRegistry.sol";
import {GiskardReputationRegistry} from "../src/GiskardReputationRegistry.sol";

contract ReputationRegistryTest is Test {
    GiskardIdentityRegistry identity;
    GiskardReputationRegistry reputation;

    address alice = address(0xA11CE);
    address bob = address(0xB0B);
    address mallory = address(0xBAD);

    uint256 aliceId;
    uint256 bobId;

    event FeedbackSubmitted(
        uint256 indexed subjectAgentId,
        uint256 indexed attesterAgentId,
        bytes32 indexed attestationHash,
        string feedbackURI,
        int256 karmaDelta
    );
    event FeedbackRevoked(
        uint256 indexed subjectAgentId,
        uint256 indexed attesterAgentId,
        bytes32 indexed attestationHash,
        string reason
    );
    event DisputeLinked(
        bytes32 indexed attestationHash,
        address indexed arbitrable,
        uint256 indexed disputeId
    );

    function setUp() public {
        identity = new GiskardIdentityRegistry();
        reputation = new GiskardReputationRegistry(address(identity));

        vm.prank(alice);
        aliceId = identity.register();
        vm.prank(bob);
        bobId = identity.register();
    }

    function test_submit_feedback() public {
        bytes32 h = keccak256("a1");
        vm.expectEmit(true, true, true, true);
        emit FeedbackSubmitted(bobId, aliceId, h, "ipfs://a1", int256(10));
        vm.prank(alice);
        reputation.submitFeedback(bobId, aliceId, "ipfs://a1", int256(10), h);
        assertTrue(reputation.isAttested(h));
        assertFalse(reputation.isRevoked(h));
    }

    function test_submit_reverts_if_not_attester_owner() public {
        bytes32 h = keccak256("a2");
        vm.prank(mallory);
        vm.expectRevert(bytes("not attester owner"));
        reputation.submitFeedback(bobId, aliceId, "ipfs://a2", int256(5), h);
    }

    function test_submit_reverts_on_duplicate() public {
        bytes32 h = keccak256("a3");
        vm.prank(alice);
        reputation.submitFeedback(bobId, aliceId, "ipfs://a3", int256(5), h);
        vm.prank(alice);
        vm.expectRevert(bytes("already attested"));
        reputation.submitFeedback(bobId, aliceId, "ipfs://a3", int256(5), h);
    }

    function test_revoke_feedback() public {
        bytes32 h = keccak256("a4");
        vm.prank(alice);
        reputation.submitFeedback(bobId, aliceId, "ipfs://a4", int256(5), h);

        vm.expectEmit(true, true, true, true);
        emit FeedbackRevoked(bobId, aliceId, h, "mistake");
        vm.prank(alice);
        reputation.revokeFeedback(bobId, aliceId, h, "mistake");
        assertTrue(reputation.isRevoked(h));
    }

    function test_revoke_reverts_if_not_attested() public {
        bytes32 h = keccak256("a5");
        vm.prank(alice);
        vm.expectRevert(bytes("not attested"));
        reputation.revokeFeedback(bobId, aliceId, h, "x");
    }

    function test_revoke_reverts_if_not_owner() public {
        bytes32 h = keccak256("a6");
        vm.prank(alice);
        reputation.submitFeedback(bobId, aliceId, "ipfs://a6", int256(5), h);
        vm.prank(mallory);
        vm.expectRevert(bytes("not attester owner"));
        reputation.revokeFeedback(bobId, aliceId, h, "x");
    }

    function test_revoke_reverts_on_double() public {
        bytes32 h = keccak256("a7");
        vm.prank(alice);
        reputation.submitFeedback(bobId, aliceId, "ipfs://a7", int256(5), h);
        vm.prank(alice);
        reputation.revokeFeedback(bobId, aliceId, h, "first");
        vm.prank(alice);
        vm.expectRevert(bytes("already revoked"));
        reputation.revokeFeedback(bobId, aliceId, h, "second");
    }

    function test_link_dispute_permissionless() public {
        bytes32 h = keccak256("a8");
        vm.prank(alice);
        reputation.submitFeedback(bobId, aliceId, "ipfs://a8", int256(5), h);

        address arbitrable = address(0xABBA);
        vm.expectEmit(true, true, true, false);
        emit DisputeLinked(h, arbitrable, 42);
        vm.prank(mallory);
        reputation.linkDispute(h, arbitrable, 42);
    }

    function test_link_dispute_reverts_if_not_attested() public {
        bytes32 h = keccak256("a9");
        vm.expectRevert(bytes("not attested"));
        reputation.linkDispute(h, address(0xABBA), 1);
    }
}
