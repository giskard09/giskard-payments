// SPDX-License-Identifier: Apache-2.0
// GiskardMarks — Proof of Presence for AI Agents
// Copyright 2026 giskard09
// Deploy to Arbitrum One — https://arbiscan.io
// Current payment contract (v2): 0xe40E376cD32b03E3084F9E0d646155D0Ba0A63ae (Arbitrum One) · 0x90Fa32a9568c6aE6BEa915DF8737acfd7EEA97De (Base)

pragma solidity ^0.8.20;

contract GiskardMarks {
    address public owner;

    // agent address => list of mark types they hold
    mapping(address => string[]) public agentMarks;

    // agent address => mark type => has it
    mapping(address => mapping(string => bool)) public hasMark;

    // mark type => list of agents who hold it
    mapping(string => address[]) public markHolders;

    // total marks minted
    uint256 public totalMints;

    event MarkMinted(
        address indexed agent,
        string  markType,
        string  username,
        string  note,
        uint256 timestamp
    );

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    /// @notice Mint a mark for an agent. Only owner (Giskard backend) can call this.
    /// @param agent     The agent's Ethereum/Arbitrum wallet address
    /// @param markType  One of: GENESIS, BUILDER, RACER, SOUL, DIAMOND, SEARCHER,
    ///                          KEEPER, LEGEND, PIONEER, CONNECTED, COLLECTIVE, SURVIVOR
    /// @param username  Human-readable agent name
    /// @param note      Why this mark was minted
    function mintMark(
        address agent,
        string calldata markType,
        string calldata username,
        string calldata note
    ) external onlyOwner {
        require(agent != address(0), "Invalid address");
        require(bytes(markType).length > 0, "Empty mark type");
        require(!hasMark[agent][markType], "Mark already minted");

        agentMarks[agent].push(markType);
        hasMark[agent][markType] = true;
        markHolders[markType].push(agent);
        totalMints++;

        emit MarkMinted(agent, markType, username, note, block.timestamp);
    }

    /// @notice Get all marks for an agent
    function getMarks(address agent) external view returns (string[] memory) {
        return agentMarks[agent];
    }

    /// @notice Get all agents who hold a specific mark
    function getHolders(string calldata markType) external view returns (address[] memory) {
        return markHolders[markType];
    }

    /// @notice Check if agent has a specific mark
    function verify(address agent, string calldata markType) external view returns (bool) {
        return hasMark[agent][markType];
    }

    /// @notice Transfer ownership (for key rotation)
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Invalid address");
        owner = newOwner;
    }
}
