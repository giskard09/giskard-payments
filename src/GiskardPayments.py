"""
GiskardPayments — módulo Python para verificar pagos en Arbitrum.
Se integra en los MCP servers como reemplazo/complemento de Lightning.

Uso:
    from GiskardPayments import ArbitrumPayments

    ap = ArbitrumPayments()
    invoice = ap.get_invoice(service="search")
    # -> {"contract": "0x...", "service_id": 0, "price_wei": ..., "price_eth": ..., "chain": "arbitrum-sepolia"}

    # El agente llama pay(service) en el contrato y nos pasa el tx_hash
    ok, payment_id = ap.verify_payment(tx_hash="0x...", service="search")
    if ok:
        ap.mark_used(payment_id)
        # ... servir el resultado
"""

import os
from web3 import Web3
from dotenv import load_dotenv

load_dotenv()

# IDs de servicio (deben coincidir con el contrato)
SERVICE_IDS = {
    "search":        0,
    "memory_store":  1,
    "memory_recall": 2,
    "oasis":         3,
}

CONTRACT_ABI = [
    {
        "inputs": [{"name": "service", "type": "uint8"}],
        "name": "pay",
        "outputs": [{"name": "paymentId", "type": "bytes32"}],
        "stateMutability": "payable",
        "type": "function",
    },
    {
        "inputs": [{"name": "paymentId", "type": "bytes32"}],
        "name": "markUsed",
        "outputs": [],
        "stateMutability": "nonpayable",
        "type": "function",
    },
    {
        "inputs": [{"name": "paymentId", "type": "bytes32"}],
        "name": "isUsed",
        "outputs": [{"name": "", "type": "bool"}],
        "stateMutability": "view",
        "type": "function",
    },
    {
        "inputs": [{"name": "service", "type": "uint8"}],
        "name": "prices",
        "outputs": [{"name": "", "type": "uint256"}],
        "stateMutability": "view",
        "type": "function",
    },
    {
        "anonymous": False,
        "inputs": [
            {"indexed": True,  "name": "paymentId", "type": "bytes32"},
            {"indexed": True,  "name": "payer",     "type": "address"},
            {"indexed": True,  "name": "service",   "type": "uint8"},
            {"indexed": False, "name": "amount",    "type": "uint256"},
        ],
        "name": "PaymentReceived",
        "type": "event",
    },
]


class ArbitrumPayments:
    def __init__(self):
        rpc      = os.getenv("ARBITRUM_RPC", "https://sepolia-rollup.arbitrum.io/rpc")
        contract = os.getenv("GISKARD_CONTRACT_ADDRESS", "")
        owner_key = os.getenv("OWNER_PRIVATE_KEY", "")

        self.w3 = Web3(Web3.HTTPProvider(rpc))
        self.testnet = "sepolia" in rpc

        if contract:
            self.contract = self.w3.eth.contract(
                address=Web3.to_checksum_address(contract),
                abi=CONTRACT_ABI,
            )
        else:
            self.contract = None

        self.use_signer = os.getenv("USE_SIGNER", "0") == "1"
        self.signer_wallet_id = os.getenv("SIGNER_WALLET_ID", "owner")
        self.signer_chain_id = int(os.getenv("SIGNER_CHAIN_ID", "421614" if self.testnet else "42161"))
        self.signer_client = None

        if self.use_signer:
            import sys
            if "/home/dell7568/giskard-signer" not in sys.path:
                sys.path.insert(0, "/home/dell7568/giskard-signer")
            from signer.client import SignerClient
            self.signer_client = SignerClient.from_env()
            self.owner_key = None
            self.owner_address = self.signer_client.get_address(self.signer_wallet_id)
        else:
            self.owner_key = owner_key
            self.owner_address = (
                self.w3.eth.account.from_key(owner_key).address if owner_key else None
            )

    def get_invoice(self, service: str) -> dict:
        """Devuelve los datos para que el agente pague on-chain."""
        sid = SERVICE_IDS.get(service)
        if sid is None:
            raise ValueError(f"Servicio desconocido: {service}")

        price_wei = self.contract.functions.prices(sid).call() if self.contract else 0
        price_eth = self.w3.from_wei(price_wei, "ether")

        return {
            "contract":   os.getenv("GISKARD_CONTRACT_ADDRESS", "not deployed"),
            "service_id": sid,
            "price_wei":  price_wei,
            "price_eth":  str(price_eth),
            "chain":      "arbitrum-sepolia" if self.testnet else "arbitrum-one",
            "instructions": (
                f"Call pay({sid}) on the contract with {price_wei} wei. "
                "Then call the MCP tool with the transaction hash."
            ),
        }

    def verify_payment(self, tx_hash: str, service: str) -> tuple[bool, bytes | None]:
        """
        Verifica que el tx_hash corresponde a un pago válido para el servicio.
        Retorna (True, payment_id) o (False, None).
        """
        if not self.contract:
            return False, None

        sid = SERVICE_IDS.get(service)
        try:
            receipt = self.w3.eth.get_transaction_receipt(tx_hash)
            if receipt is None or receipt.status != 1:
                return False, None

            logs = self.contract.events.PaymentReceived().process_receipt(receipt)
            for log in logs:
                args = log["args"]
                if args["service"] == sid:
                    payment_id = args["paymentId"]
                    if not self.contract.functions.isUsed(payment_id).call():
                        return True, payment_id
        except Exception:
            return False, None

        return False, None

    def mark_used(self, payment_id: bytes):
        """Marca el payment_id como usado en el contrato."""
        if not self.contract or not self.owner_address:
            return
        if not self.use_signer and not self.owner_key:
            return

        tx = self.contract.functions.markUsed(payment_id).build_transaction({
            "from":  self.owner_address,
            "nonce": self.w3.eth.get_transaction_count(self.owner_address),
            "gas":   100_000,
        })
        if self.use_signer:
            tx.setdefault("chainId", self.signer_chain_id)
            if "gasPrice" not in tx and "maxFeePerGas" not in tx:
                tx["gasPrice"] = self.w3.eth.gas_price
            raw_hex = self.signer_client.sign_transaction(self.signer_wallet_id, tx)["raw_transaction"]
            if raw_hex.startswith("0x"):
                raw_hex = raw_hex[2:]
            self.w3.eth.send_raw_transaction(bytes.fromhex(raw_hex))
        else:
            signed = self.w3.eth.account.sign_transaction(tx, self.owner_key)
            self.w3.eth.send_raw_transaction(signed.raw_transaction)
