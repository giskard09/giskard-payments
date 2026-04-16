// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

// ERC-8004 Reputation Registry — SKELETON v0 (2026-04-15)
//
// Minimal reputation surface for agents registered in GiskardIdentityRegistry.
// Follows the ERC-8004 discovery-and-reputation pattern: attestations are
// on-chain events that index reputation content stored off-chain (argentum-core).
//
// Design notes:
//   - No on-chain karma math. argentum-core (off-chain) owns the weighted sum.
//     This contract is an event-sourced anchor: it commits attestation hashes
//     so anyone can verify off-chain karma was not rewritten.
//   - feedbackAuthID = agentId of the attester (ERC-8004 identity registry).
//   - feedbackURI points to signed attestation JSON (Ed25519 over SHA256).
//   - revoke emits an event; off-chain consumer recomputes.
//
// Deferred to v1:
//   - signature verification on-chain (ERC-1271 compatible)
//   - integration with ArgentumArbitrable for Kleros-ruled slashing
//   - karma-weight commitment (merkle root per epoch)

interface IGiskardIdentityRegistry {
    function ownerOf(uint256 agentId) external view returns (address);
}

contract GiskardReputationRegistry {
    IGiskardIdentityRegistry public immutable identityRegistry;

    // attestation hash => exists
    mapping(bytes32 => bool) private _attested;
    // attestation hash => revoked
    mapping(bytes32 => bool) private _revoked;

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

    constructor(address _identityRegistry) {
        identityRegistry = IGiskardIdentityRegistry(_identityRegistry);
    }

    function submitFeedback(
        uint256 subjectAgentId,
        uint256 attesterAgentId,
        string calldata feedbackURI,
        int256 karmaDelta,
        bytes32 attestationHash
    ) external {
        require(
            identityRegistry.ownerOf(attesterAgentId) == msg.sender,
            "not attester owner"
        );
        require(!_attested[attestationHash], "already attested");
        _attested[attestationHash] = true;
        emit FeedbackSubmitted(
            subjectAgentId,
            attesterAgentId,
            attestationHash,
            feedbackURI,
            karmaDelta
        );
    }

    function revokeFeedback(
        uint256 subjectAgentId,
        uint256 attesterAgentId,
        bytes32 attestationHash,
        string calldata reason
    ) external {
        require(
            identityRegistry.ownerOf(attesterAgentId) == msg.sender,
            "not attester owner"
        );
        require(_attested[attestationHash], "not attested");
        require(!_revoked[attestationHash], "already revoked");
        _revoked[attestationHash] = true;
        emit FeedbackRevoked(subjectAgentId, attesterAgentId, attestationHash, reason);
    }

    function linkDispute(
        bytes32 attestationHash,
        address arbitrable,
        uint256 disputeId
    ) external {
        // Permissionless by design — Kleros Arbitrable contract calls this
        // to anchor a dispute reference on-chain. Verification of the
        // arbitrable contract's legitimacy is off-chain for now.
        require(_attested[attestationHash], "not attested");
        emit DisputeLinked(attestationHash, arbitrable, disputeId);
    }

    function isAttested(bytes32 attestationHash) external view returns (bool) {
        return _attested[attestationHash];
    }

    function isRevoked(bytes32 attestationHash) external view returns (bool) {
        return _revoked[attestationHash];
    }
}
