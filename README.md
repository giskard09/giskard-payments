# giskard-payments

Multi-network payment gateway for Giskard MCP servers.

Agents pay for services directly from their wallet — no accounts, no subscriptions.

## Networks

| Network | Status | Token |
|---|---|---|
| Lightning (Bitcoin) | ✅ Live | sats |
| Arbitrum Sepolia (testnet) | ✅ Deployed | ETH |
| Arbitrum One (mainnet) | ✅ Live | ETH |

## Contract — GiskardPayments

| Network | Address | Status |
|---|---|---|
| Arbitrum One (mainnet) | `0xe40E376cD32b03E3084F9E0d646155D0Ba0A63ae` | v2 — current (facilitator whitelist, deployed 2026-06-10) |
| Base (mainnet) | `0x90Fa32a9568c6aE6BEa915DF8737acfd7EEA97De` | current (deployed 2026-06-22) |
| Arbitrum (v1) | `0xD467CD1e34515d58F98f8Eb66C0892643ec86AD3` | deprecated — superseded by v2 |

## GiskardIdentityRegistry — ERC-8004 (Arbitrum One)

`0x1C56Ee3cd533C3c8Ac1E87870d43dDF8eC1F9CF3`

ERC-721 + URIStorage implementation of the ERC-8004 Identity Registry. Verified on Sourcify.

- Source: [`src/GiskardIdentityRegistry.sol`](src/GiskardIdentityRegistry.sol)
- Arbiscan: https://arbiscan.io/address/0x1C56Ee3cd533C3c8Ac1E87870d43dDF8eC1F9CF3
- agentRegistry (ERC-8004): `eip155:42161:0x1C56Ee3cd533C3c8Ac1E87870d43dDF8eC1F9CF3`

## Services & Prices

| Service | ID | Price |
|---|---|---|
| Search | 0 | 0.000006 ETH |
| Memory Store | 1 | 0.000003 ETH |
| Memory Recall | 2 | 0.000002 ETH |
| Oasis | 3 | 0.000012 ETH |

## How it works

1. Agent calls `get_invoice(service)` on the MCP server
2. MCP returns contract address + price
3. Agent calls `pay(service_id)` on the contract with the required ETH
4. Agent passes the `tx_hash` to the MCP tool call
5. MCP verifies the payment on-chain and serves the result

## Deploy

```bash
cp .env.example .env  # fill in your keys
forge script script/Deploy.s.sol:Deploy --rpc-url $ARBITRUM_RPC --private-key $OWNER_PRIVATE_KEY --broadcast
```

## Related

- [giskard-search](https://github.com/giskard09/giskard-search)
- [giskard-memory](https://github.com/giskard09/giskard-memory)
- [giskard-oasis](https://github.com/giskard09/giskard-oasis)
