// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title GiskardPayments
 * @notice Payment gateway for Giskard MCP servers on Arbitrum.
 *         Agents pay ETH to receive a payment ID that unlocks one service call.
 *
 * Services:
 *   0 = Search  (web/news search)
 *   1 = Memory Store
 *   2 = Memory Recall
 *   3 = Oasis
 */
contract GiskardPayments {

    address public owner;

    // Service prices in wei (set at deploy, updatable by owner)
    mapping(uint8 => uint256) public prices;

    // payment_id => used
    mapping(bytes32 => bool) public used;

    // Addresses authorized to call markUsed (integrators, backend nodes)
    mapping(address => bool) public facilitators;

    event PaymentReceived(
        bytes32 indexed paymentId,
        address indexed payer,
        uint8   indexed service,
        uint256 amount
    );

    event PriceUpdated(uint8 service, uint256 newPrice);
    event Withdrawn(address to, uint256 amount);
    event FacilitatorSet(address indexed facilitator, bool authorized);

    modifier onlyOwner() {
        require(msg.sender == owner, "not owner");
        _;
    }

    modifier onlyAuthorized() {
        require(msg.sender == owner || facilitators[msg.sender], "not authorized");
        _;
    }

    constructor() {
        owner = msg.sender;
        // Default prices in wei (~$0.01 USD each at ~$1800 ETH)
        prices[0] = 0.000006 ether;  // Search
        prices[1] = 0.000003 ether;  // Memory Store
        prices[2] = 0.000002 ether;  // Memory Recall
        prices[3] = 0.000012 ether;  // Oasis
    }

    /**
     * @notice Pay for a service. Emits PaymentReceived with a unique payment ID.
     * @param service  0=Search, 1=MemoryStore, 2=MemoryRecall, 3=Oasis
     */
    function pay(uint8 service) external payable returns (bytes32 paymentId) {
        require(service <= 3, "unknown service");
        require(msg.value >= prices[service], "insufficient payment");

        paymentId = keccak256(
            abi.encodePacked(msg.sender, service, block.timestamp, block.prevrandao)
        );

        emit PaymentReceived(paymentId, msg.sender, service, msg.value);
    }

    /**
     * @notice Mark a payment ID as used (called by backend or authorized facilitator).
     */
    function markUsed(bytes32 paymentId) external onlyAuthorized {
        used[paymentId] = true;
    }

    /**
     * @notice Add or remove an authorized facilitator (e.g. integrator backend).
     */
    function setFacilitator(address facilitator, bool authorized) external onlyOwner {
        facilitators[facilitator] = authorized;
        emit FacilitatorSet(facilitator, authorized);
    }

    /**
     * @notice Check if a payment ID was emitted (exists in logs) and is not yet used.
     *         Off-chain verification: check the PaymentReceived event for this paymentId.
     */
    function isUsed(bytes32 paymentId) external view returns (bool) {
        return used[paymentId];
    }

    function setPrice(uint8 service, uint256 price) external onlyOwner {
        prices[service] = price;
        emit PriceUpdated(service, price);
    }

    function withdraw() external onlyOwner {
        uint256 bal = address(this).balance;
        (bool ok, ) = payable(owner).call{value: bal}("");
        require(ok, "transfer failed");
        emit Withdrawn(owner, bal);
    }
}
