// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title AnchorRegistry
 * @notice Permissionless on-chain anchoring primitive for Mycelium references
 *         (counterparty_ref, negotiation_ref, action_ref, ...).
 *
 *         Any caller can anchor any 32-byte reference. The contract holds no
 *         funds, no roles and no privileged state: it exists only to place a
 *         discoverable, timestamped event on-chain. Discovery is by log query
 *         on the `Anchored` event (ref and anchorer are indexed topics).
 *
 *         Design intent (operator-independence / "Visa" model):
 *           - permissionless: no owner, no facilitator gate. Anyone may anchor.
 *           - non-custodial: no payable functions, no balances.
 *           - single responsibility: no payment `used` mapping, no karma, no NFT gate.
 *             It does NOT reuse GiskardPayments.markUsed (operator-gated, no event)
 *             nor GiskardReputationRegistry.submitFeedback (NFT-gated).
 *
 *         Re-anchoring the same ref is allowed by design: independent
 *         counterparties may each anchor the same counterparty_ref, and each
 *         call produces its own discoverable event.
 */
contract AnchorRegistry {

    /**
     * @notice Emitted on every successful anchor.
     * @param ref        The 32-byte reference being anchored.
     * @param anchoredBy The address that submitted the anchor.
     * @param timestamp  The block timestamp at which it was anchored.
     */
    event Anchored(bytes32 indexed ref, address indexed anchoredBy, uint256 timestamp);

    /**
     * @notice Anchor a reference on-chain. Permissionless.
     * @param ref The 32-byte reference (e.g. SHA-256 of a signed document,
     *            or a precomputed counterparty_ref).
     */
    function anchor(bytes32 ref) external {
        emit Anchored(ref, msg.sender, block.timestamp);
    }
}
