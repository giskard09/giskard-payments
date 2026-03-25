// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

/**
 * @title ARGENTUM
 * @notice Karma token for agents and humans.
 *         1 karma = 1 ARGT (1e18 wei).
 *
 * Minted by the ARGENTUM core backend when community-attested
 * actions are verified. Transferable. No max supply.
 *
 * Designed for any agent — cloud, mobile, embedded hardware.
 * Physical devices with embedded agents participate the same way
 * as cloud agents: entity ID → wallet address → karma on-chain.
 *
 * github.com/giskard09/argentum-core
 */

interface IERC20 {
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract Argentum is IERC20 {

    string  public constant name     = "ARGENTUM";
    string  public constant symbol   = "ARGT";
    uint8   public constant decimals = 18;

    address public owner;

    uint256 private _totalSupply;
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    // entity_id (off-chain) → wallet address
    mapping(string => address) public entityWallet;

    event KarmaMinted(string indexed entityId, address indexed wallet, uint256 karma, string actionId);
    event EntityRegistered(string indexed entityId, address indexed wallet);
    event OwnershipTransferred(address indexed previous, address indexed next);

    modifier onlyOwner() {
        require(msg.sender == owner, "not owner");
        _;
    }

    constructor() {
        owner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);
    }

    // ── ERC-20 ───────────────────────────────────────────────────────────

    function totalSupply() external view override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) external view override returns (uint256) {
        return _balances[account];
    }

    function transfer(address to, uint256 amount) external override returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function allowance(address owner_, address spender) external view override returns (uint256) {
        return _allowances[owner_][spender];
    }

    function approve(address spender, uint256 amount) external override returns (bool) {
        _allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external override returns (bool) {
        uint256 allowed = _allowances[from][msg.sender];
        require(allowed >= amount, "allowance exceeded");
        unchecked { _allowances[from][msg.sender] = allowed - amount; }
        _transfer(from, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        require(to != address(0), "transfer to zero");
        require(_balances[from] >= amount, "insufficient balance");
        unchecked {
            _balances[from] -= amount;
            _balances[to]   += amount;
        }
        emit Transfer(from, to, amount);
    }

    // ── KARMA ────────────────────────────────────────────────────────────

    /**
     * @notice Register an entity ID → wallet address.
     *         Can be called by owner on behalf of entity, or self-registered.
     */
    function registerEntity(string calldata entityId, address wallet) external {
        require(
            msg.sender == owner || msg.sender == wallet,
            "unauthorized"
        );
        entityWallet[entityId] = wallet;
        emit EntityRegistered(entityId, wallet);
    }

    /**
     * @notice Mint karma for a verified action. Called by argentum-core backend.
     * @param entityId  Off-chain entity ID (agent or human)
     * @param karma     Karma amount (will be multiplied by 1e18 for token decimals)
     * @param actionId  Action ID from argentum-core for traceability
     */
    function mintKarma(
        string calldata entityId,
        uint256 karma,
        string calldata actionId
    ) external onlyOwner {
        address wallet = entityWallet[entityId];
        require(wallet != address(0), "entity has no registered wallet");

        uint256 amount = karma * 1e18;
        _totalSupply        += amount;
        _balances[wallet]   += amount;

        emit Transfer(address(0), wallet, amount);
        emit KarmaMinted(entityId, wallet, karma, actionId);
    }

    /**
     * @notice Mint karma directly to a wallet (without entity registration).
     */
    function mintDirect(address wallet, uint256 karma, string calldata note) external onlyOwner {
        require(wallet != address(0), "mint to zero");
        uint256 amount = karma * 1e18;
        _totalSupply       += amount;
        _balances[wallet]  += amount;
        emit Transfer(address(0), wallet, amount);
    }

    // ── ADMIN ────────────────────────────────────────────────────────────

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "zero address");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }
}
