// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {GiskardIdentityRegistry} from "../src/GiskardIdentityRegistry.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC721Metadata} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";

contract IdentityRegistryTest is Test {
    GiskardIdentityRegistry registry;

    address alice = address(0xA11CE);
    address bob = address(0xB0B);
    address carol = address(0xCAFE);

    event Registered(uint256 indexed agentId, string agentURI, address indexed owner);
    event URIUpdated(uint256 indexed agentId, string newURI, address indexed updatedBy);
    event MetadataSet(
        uint256 indexed agentId,
        string indexed indexedMetadataKey,
        string metadataKey,
        bytes metadataValue
    );

    function setUp() public {
        registry = new GiskardIdentityRegistry();
    }

    // ---- register() overloads ----

    function test_register_bare() public {
        vm.prank(alice);
        uint256 id = registry.register();
        assertEq(id, 1);
        assertEq(registry.ownerOf(id), alice);
        assertEq(registry.tokenURI(id), "");
        // agentWallet seed == alice
        bytes memory w = registry.getMetadata(id, "agentWallet");
        assertEq(abi.decode(w, (address)), alice);
    }

    function test_register_with_uri() public {
        vm.prank(alice);
        uint256 id = registry.register("ipfs://bafybeigdyrxx");
        assertEq(registry.tokenURI(id), "ipfs://bafybeigdyrxx");
    }

    function test_register_with_metadata() public {
        GiskardIdentityRegistry.MetadataEntry[] memory entries =
            new GiskardIdentityRegistry.MetadataEntry[](2);
        entries[0] = GiskardIdentityRegistry.MetadataEntry("skill", bytes("search"));
        entries[1] = GiskardIdentityRegistry.MetadataEntry("karma", abi.encode(uint256(42)));

        vm.prank(alice);
        uint256 id = registry.register("ipfs://xyz", entries);

        assertEq(registry.getMetadata(id, "skill"), bytes("search"));
        assertEq(abi.decode(registry.getMetadata(id, "karma"), (uint256)), 42);
    }

    function test_register_metadata_rejects_agentWallet_key() public {
        GiskardIdentityRegistry.MetadataEntry[] memory entries =
            new GiskardIdentityRegistry.MetadataEntry[](1);
        entries[0] = GiskardIdentityRegistry.MetadataEntry("agentWallet", abi.encode(bob));

        vm.prank(alice);
        vm.expectRevert(bytes("agentWallet is reserved"));
        registry.register("ipfs://x", entries);
    }

    function test_register_increments_agentId() public {
        vm.prank(alice);
        uint256 id1 = registry.register();
        vm.prank(bob);
        uint256 id2 = registry.register();
        assertEq(id1, 1);
        assertEq(id2, 2);
    }

    // ---- setAgentURI ----

    function test_setAgentURI_by_owner() public {
        vm.prank(alice);
        uint256 id = registry.register("ipfs://v1");
        vm.prank(alice);
        registry.setAgentURI(id, "ipfs://v2");
        assertEq(registry.tokenURI(id), "ipfs://v2");
    }

    function test_setAgentURI_rejects_non_owner() public {
        vm.prank(alice);
        uint256 id = registry.register("ipfs://v1");
        vm.prank(bob);
        vm.expectRevert(bytes("not authorized"));
        registry.setAgentURI(id, "ipfs://hacked");
    }

    function test_setAgentURI_by_approved() public {
        vm.prank(alice);
        uint256 id = registry.register("ipfs://v1");
        vm.prank(alice);
        registry.approve(bob, id);
        vm.prank(bob);
        registry.setAgentURI(id, "ipfs://delegated");
        assertEq(registry.tokenURI(id), "ipfs://delegated");
    }

    // ---- setMetadata ----

    function test_setMetadata_by_owner() public {
        vm.prank(alice);
        uint256 id = registry.register();
        vm.prank(alice);
        registry.setMetadata(id, "color", bytes("blue"));
        assertEq(registry.getMetadata(id, "color"), bytes("blue"));
    }

    function test_setMetadata_rejects_non_owner() public {
        vm.prank(alice);
        uint256 id = registry.register();
        vm.prank(bob);
        vm.expectRevert(bytes("not authorized"));
        registry.setMetadata(id, "color", bytes("red"));
    }

    function test_setMetadata_rejects_agentWallet_key() public {
        vm.prank(alice);
        uint256 id = registry.register();
        vm.prank(alice);
        vm.expectRevert(bytes("agentWallet is reserved"));
        registry.setMetadata(id, "agentWallet", abi.encode(bob));
    }

    // ---- transfer resets agentWallet ----

    function test_transfer_resets_agentWallet() public {
        vm.prank(alice);
        uint256 id = registry.register();
        // agentWallet starts as alice
        assertEq(abi.decode(registry.getMetadata(id, "agentWallet"), (address)), alice);

        vm.prank(alice);
        registry.transferFrom(alice, carol, id);

        // after transfer, agentWallet reset to address(0)
        assertEq(abi.decode(registry.getMetadata(id, "agentWallet"), (address)), address(0));
        assertEq(registry.ownerOf(id), carol);
    }

    // ---- ERC-721 conformance ----

    function test_supportsInterface_ERC721() public view {
        // ERC-721
        assertTrue(registry.supportsInterface(type(IERC721).interfaceId));
        // ERC-721 Metadata
        assertTrue(registry.supportsInterface(type(IERC721Metadata).interfaceId));
    }

    function test_name_symbol() public view {
        assertEq(registry.name(), "Giskard Agent Identity");
        assertEq(registry.symbol(), "GAID");
    }

    // ---- Events ----

    function test_emits_Registered_event() public {
        vm.prank(alice);
        vm.expectEmit(true, true, false, true);
        emit Registered(1, "ipfs://foo", alice);
        registry.register("ipfs://foo");
    }

    function test_emits_URIUpdated_event() public {
        vm.prank(alice);
        uint256 id = registry.register("ipfs://v1");
        vm.prank(alice);
        vm.expectEmit(true, false, true, true);
        emit URIUpdated(id, "ipfs://v2", alice);
        registry.setAgentURI(id, "ipfs://v2");
    }

    // ---- getMetadata on non-existent agent reverts ----

    function test_getMetadata_revert_on_nonexistent() public {
        vm.expectRevert();
        registry.getMetadata(999, "anything");
    }
}
