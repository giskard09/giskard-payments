// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

/**
 * @title ArgentumArbitrable
 * @notice Kleros dispute resolution layer for ARGENTUM karma actions.
 *
 * Implements the IArbitrable interface so Kleros Court can rule on disputed actions.
 * When a ruling is issued, it emits DisputeResolved — the argentum-core backend
 * listens for this event and calls POST /kleros/ruling to execute the slash or clear.
 *
 * Rulings:
 *   0 — refused to arbitrate → action restored to verified
 *   1 — reporter wins        → slash poster + attestors
 *   2 — poster wins          → action restored to verified
 *
 * Minimum karma to open a dispute: enforced off-chain in argentum-core.
 * Deploy: after coordination with Kleros team (Petchevere).
 * Arbitrator: Kleros Court v2 on Arbitrum One (address set at deploy time).
 *
 * github.com/giskard09/argentum-core
 */

interface IArbitrator {
    function createDispute(uint256 _choices, bytes calldata _extraData)
        external payable returns (uint256 disputeID);
    function arbitrationCost(bytes calldata _extraData)
        external view returns (uint256 cost);
}

interface IArbitrable {
    /**
     * @dev Emitted when a ruling is given.
     * @param _arbitrator  The arbitrator that gave the ruling.
     * @param _disputeID   The identifier of the dispute in the arbitrator.
     * @param _ruling      The ruling (0 = refuse, 1 = slash, 2 = clear).
     */
    event Ruling(IArbitrator indexed _arbitrator, uint256 indexed _disputeID, uint256 _ruling);

    /**
     * @dev Called by the arbitrator to give a ruling.
     */
    function rule(uint256 _disputeID, uint256 _ruling) external;
}

contract ArgentumArbitrable is IArbitrable {

    address     public owner;
    IArbitrator public arbitrator;

    uint256 public constant DISPUTE_CHOICES = 2; // 1 = slash, 2 = clear

    struct Dispute {
        string  actionId;    // ARGENTUM off-chain action ID
        address requester;   // who opened the dispute
        uint8   status;      // 0 = pending, 1 = ruled
        uint256 ruling;
    }

    // kleros disputeID → our Dispute
    mapping(uint256 => Dispute) public disputes;
    // actionId → kleros disputeID (0 if no dispute)
    mapping(string  => uint256) public actionDisputeId;

    event DisputeOpened(
        string  indexed actionId,
        address indexed requester,
        uint256         disputeID
    );

    event DisputeResolved(
        string  indexed actionId,
        uint256         disputeID,
        uint256         ruling
    );

    event ArbitratorUpdated(address indexed previous, address indexed next);
    event OwnershipTransferred(address indexed previous, address indexed next);

    modifier onlyOwner()      { require(msg.sender == owner,               "not owner");       _; }
    modifier onlyArbitrator() { require(msg.sender == address(arbitrator), "not arbitrator");  _; }

    constructor(address _arbitrator) {
        owner       = msg.sender;
        arbitrator  = IArbitrator(_arbitrator);
        emit OwnershipTransferred(address(0), msg.sender);
    }

    // ── DISPUTE ──────────────────────────────────────────────────────────────

    /**
     * @notice Open a Kleros dispute for an ARGENTUM action.
     * @param actionId   Off-chain action ID from argentum-core.
     * @param extraData  Kleros subcourt + min jurors (encoded by client).
     *                   See: https://kleros.gitbook.io/docs/developer/arbitration-development
     *
     * Caller must send msg.value >= arbitrationCost(extraData).
     * Excess ETH is returned (or left for gas — caller should calculate precisely).
     *
     * Karma gate (>= 10) is enforced off-chain before this call.
     */
    function disputeAction(
        string  calldata actionId,
        bytes   calldata extraData
    ) external payable {
        require(actionDisputeId[actionId] == 0, "already disputed");

        uint256 cost = arbitrator.arbitrationCost(extraData);
        require(msg.value >= cost, "insufficient arbitration fee");

        uint256 disputeID = arbitrator.createDispute{value: cost}(DISPUTE_CHOICES, extraData);

        disputes[disputeID] = Dispute({
            actionId:  actionId,
            requester: msg.sender,
            status:    0,
            ruling:    0
        });
        actionDisputeId[actionId] = disputeID;

        // Refund excess
        uint256 excess = msg.value - cost;
        if (excess > 0) {
            payable(msg.sender).transfer(excess);
        }

        emit DisputeOpened(actionId, msg.sender, disputeID);
    }

    // ── IARBITRABLE CALLBACK ──────────────────────────────────────────────────

    /**
     * @notice Called by Kleros arbitrator with the final ruling.
     *         Emits DisputeResolved — argentum-core backend listens and executes.
     */
    function rule(uint256 _disputeID, uint256 _ruling) external override onlyArbitrator {
        Dispute storage d = disputes[_disputeID];
        require(d.status == 0, "already ruled");

        d.status = 1;
        d.ruling = _ruling;

        emit Ruling(arbitrator, _disputeID, _ruling);
        emit DisputeResolved(d.actionId, _disputeID, _ruling);
    }

    // ── VIEWS ─────────────────────────────────────────────────────────────────

    function getDispute(string calldata actionId)
        external view
        returns (uint256 disputeID, uint8 status, uint256 ruling, address requester)
    {
        disputeID = actionDisputeId[actionId];
        if (disputeID > 0) {
            Dispute memory d = disputes[disputeID];
            return (disputeID, d.status, d.ruling, d.requester);
        }
        return (0, 0, 0, address(0));
    }

    function arbitrationCost(bytes calldata extraData) external view returns (uint256) {
        return arbitrator.arbitrationCost(extraData);
    }

    // ── ADMIN ─────────────────────────────────────────────────────────────────

    function setArbitrator(address _arbitrator) external onlyOwner {
        emit ArbitratorUpdated(address(arbitrator), _arbitrator);
        arbitrator = IArbitrator(_arbitrator);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "zero address");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function withdraw() external onlyOwner {
        payable(owner).transfer(address(this).balance);
    }
}
