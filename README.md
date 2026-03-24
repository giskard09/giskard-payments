# giskard-payments

Multi-network payment gateway for Giskard MCP servers.

Agents pay for services directly from their wallet — no accounts, no subscriptions.

## Networks

| Network | Status | Token |
|---|---|---|
| Lightning (Bitcoin) | ✅ Live | sats |
| Arbitrum Sepolia (testnet) | ✅ Deployed | ETH |
| Arbitrum One (mainnet) | 🔜 Soon | ETH/USDC |

## Contract — Arbitrum Sepolia

`0xD467CD1e34515d58F98f8Eb66C0892643ec86AD3`

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
