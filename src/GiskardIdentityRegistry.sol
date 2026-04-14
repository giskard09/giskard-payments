// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

// ERC-8004 Identity Registry — minimal compliant implementation.
// Spec: https://eips.ethereum.org/EIPS/eip-8004
//
// Scope (v1):
//   - ERC-721 + URIStorage for agent identity (agentId = tokenId, agentURI = tokenURI)
//   - register(), register(agentURI), register(agentURI, metadata[])
//   - setAgentURI(), getMetadata/setMetadata (with reserved agentWallet key)
//   - Events: Registered, URIUpdated, MetadataSet
//
// Deferred to v2 (documented, not yet implemented):
//   - setAgentWallet EIP-712 / ERC-1271 signature verification
//   - unsetAgentWallet, getAgentWallet accessors
//   - Automatic agentWallet reset on transfer
// These are OPTIONAL in the spec beyond discovery; v1 covers the mandatory
// registration surface. v2 adds payment-wallet proof-of-control.

import {ERC721URIStorage, ERC721} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

contract GiskardIdentityRegistry is ERC721URIStorage {
    uint256 private _nextAgentId = 1;

    // agentId => metadataKey => metadataValue
    mapping(uint256 => mapping(string => bytes)) private _metadata;

    string private constant AGENT_WALLET_KEY = "agentWallet";

    struct MetadataEntry {
        string metadataKey;
        bytes metadataValue;
    }

    event Registered(uint256 indexed agentId, string agentURI, address indexed owner);
    event URIUpdated(uint256 indexed agentId, string newURI, address indexed updatedBy);
    event MetadataSet(
        uint256 indexed agentId,
        string indexed indexedMetadataKey,
        string metadataKey,
        bytes metadataValue
    );

    constructor() ERC721("Giskard Agent Identity", "GAID") {}

    // ------------------------------------------------------------------
    // Registration
    // ------------------------------------------------------------------

    function register() external returns (uint256 agentId) {
        return _register(msg.sender, "", new MetadataEntry[](0));
    }

    function register(string calldata agentURI) external returns (uint256 agentId) {
        return _register(msg.sender, agentURI, new MetadataEntry[](0));
    }

    function register(string calldata agentURI, MetadataEntry[] calldata metadata)
        external
        returns (uint256 agentId)
    {
        return _register(msg.sender, agentURI, metadata);
    }

    function _register(address to, string memory agentURI, MetadataEntry[] memory metadata)
        internal
        returns (uint256 agentId)
    {
        agentId = _nextAgentId++;
        _safeMint(to, agentId);
        if (bytes(agentURI).length != 0) {
            _setTokenURI(agentId, agentURI);
        }

        // Reserved agentWallet metadata — initially set to owner address.
        bytes memory walletBytes = abi.encode(to);
        _metadata[agentId][AGENT_WALLET_KEY] = walletBytes;
        emit MetadataSet(agentId, AGENT_WALLET_KEY, AGENT_WALLET_KEY, walletBytes);

        for (uint256 i = 0; i < metadata.length; i++) {
            require(
                keccak256(bytes(metadata[i].metadataKey)) != keccak256(bytes(AGENT_WALLET_KEY)),
                "agentWallet is reserved"
            );
            _metadata[agentId][metadata[i].metadataKey] = metadata[i].metadataValue;
            emit MetadataSet(
                agentId,
                metadata[i].metadataKey,
                metadata[i].metadataKey,
                metadata[i].metadataValue
            );
        }

        emit Registered(agentId, agentURI, to);
    }

    // ------------------------------------------------------------------
    // agentURI update
    // ------------------------------------------------------------------

    function setAgentURI(uint256 agentId, string calldata newURI) external {
        require(_isAuthorized(ownerOf(agentId), msg.sender, agentId), "not authorized");
        _setTokenURI(agentId, newURI);
        emit URIUpdated(agentId, newURI, msg.sender);
    }

    // ------------------------------------------------------------------
    // Metadata
    // ------------------------------------------------------------------

    function getMetadata(uint256 agentId, string calldata metadataKey)
        external
        view
        returns (bytes memory)
    {
        _requireOwned(agentId);
        return _metadata[agentId][metadataKey];
    }

    function setMetadata(uint256 agentId, string calldata metadataKey, bytes calldata metadataValue)
        external
    {
        require(_isAuthorized(ownerOf(agentId), msg.sender, agentId), "not authorized");
        require(
            keccak256(bytes(metadataKey)) != keccak256(bytes(AGENT_WALLET_KEY)),
            "agentWallet is reserved"
        );
        _metadata[agentId][metadataKey] = metadataValue;
        emit MetadataSet(agentId, metadataKey, metadataKey, metadataValue);
    }

    // ------------------------------------------------------------------
    // Transfer hook — clear agentWallet per spec
    // ------------------------------------------------------------------

    function _update(address to, uint256 tokenId, address auth)
        internal
        override
        returns (address)
    {
        address from = _ownerOf(tokenId);
        address prev = super._update(to, tokenId, auth);
        // On transfer (not mint), reset agentWallet to zero-address encoded.
        if (from != address(0) && from != to) {
            bytes memory zero = abi.encode(address(0));
            _metadata[tokenId][AGENT_WALLET_KEY] = zero;
            emit MetadataSet(tokenId, AGENT_WALLET_KEY, AGENT_WALLET_KEY, zero);
        }
        return prev;
    }
}
