// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title P-12 — The Frictionless State-Transition Engine
/// @notice Settlement-layer core of the Post-Contractual Paradigm (Vol. IV).
///         A bilateral covenant ledger whose termination is a unilateral,
///         one-transaction state reset. Zero liquidation tax, zero temporal
///         friction, and — by construction — NO judicial/arbitration interface.
/// @dev    Design invariants:
///         1. No oracle, no arbitrator role, no court hook, no appeal window.
///         2. Exit allocation is pre-committed at initiation (exitTermsHash)
///            and executed deterministically at reset —清算税 == 0 by code.
///         3. Termination is final and irreversible on-chain; the ledger
///            returns to the null state in exactly one block.
contract P12_FrictionlessStateTransition {
    enum State {
        Uninitialized, // 0 — null ledger
        Active,        // 1 — covenant in force
        Suspended,     // 2 — frozen by mutual signal, resumable
        Dissolved      // 3 — terminal; ledger reset executed
    }

    struct Covenant {
        address partyA;
        address partyB;
        bytes32 exitTermsHash; // commitment to deterministic exit allocation
        uint64  initiatedAt;
        uint64  dissolvedAt;
        State   state;
    }

    uint256 public covenantCount;
    mapping(uint256 => Covenant) public covenants;

    // Per-covenant ledger: net entitlements recorded while Active.
    // Cleared (state reset) upon dissolution — no residual tax base.
    mapping(uint256 => mapping(address => int256)) private _ledger;

    event CovenantInitiated(uint256 indexed id, address partyA, address partyB, bytes32 exitTermsHash);
    event CovenantSuspended(uint256 indexed id);
    event CovenantResumed(uint256 indexed id);
    event LedgerPosted(uint256 indexed id, address indexed party, int256 delta);
    /// @notice The single terminal event: full state reset, one block, zero fee.
    event LedgerStateReset(uint256 indexed id, address indexed initiator, uint64 at);

    error NotParty();
    error BadState(State required, State actual);
    error ZeroAddress();
    error SelfCovenant();

    modifier onlyParty(uint256 id) {
        Covenant storage c = covenants[id];
        if (msg.sender != c.partyA && msg.sender != c.partyB) revert NotParty();
        _;
    }

    /// @notice Initiate a bilateral covenant with a pre-committed exit schedule.
    /// @param counterparty  The other party.
    /// @param exitTermsHash keccak256 of the off-chain deterministic exit
    ///        allocation (asset split matrix). Executed as-is at reset; no
    ///        third party may reinterpret it.
    function initiate(address counterparty, bytes32 exitTermsHash)
        external
        returns (uint256 id)
    {
        if (counterparty == address(0)) revert ZeroAddress();
        if (counterparty == msg.sender) revert SelfCovenant();

        id = ++covenantCount;
        Covenant storage c = covenants[id];
        c.partyA = msg.sender;
        c.partyB = counterparty;
        c.exitTermsHash = exitTermsHash;
        c.initiatedAt = uint64(block.timestamp);
        c.state = State.Active;

        emit CovenantInitiated(id, msg.sender, counterparty, exitTermsHash);
    }

    /// @notice Post a net entitlement delta while Active (mutual-callable).
    function post(uint256 id, address party, int256 delta)
        external
        onlyParty(id)
    {
        Covenant storage c = covenants[id];
        if (c.state != State.Active) revert BadState(State.Active, c.state);
        if (party != c.partyA && party != c.partyB) revert NotParty();
        _ledger[id][party] += delta;
        emit LedgerPosted(id, party, delta);
    }

    /// @notice Mutual freeze. Resumable by mutual signal. No external arbiter.
    function suspend(uint256 id) external onlyParty(id) {
        Covenant storage c = covenants[id];
        if (c.state != State.Active) revert BadState(State.Active, c.state);
        c.state = State.Suspended;
        emit CovenantSuspended(id);
    }

    function resume(uint256 id) external onlyParty(id) {
        Covenant storage c = covenants[id];
        if (c.state != State.Suspended) revert BadState(State.Suspended, c.state);
        c.state = State.Active;
        emit CovenantResumed(id);
    }

    /// @notice THE CORE PRIMITIVE — one-click Ledger State Reset.
    /// @dev    Unilateral by design: either party may dissolve. There is no
    ///         notice period, no cooling-off hook, no fee, no slashing, and
    ///         no interface by which any external jurisdiction can attach a
    ///         claim. The ledger is zeroed; the exit allocation bound to
    ///         exitTermsHash executes off-chain deterministically.
    function dissolve(uint256 id) external onlyParty(id) {
        Covenant storage c = covenants[id];
        if (c.state == State.Dissolved) revert BadState(State.Active, c.state);
        if (c.state == State.Uninitialized) revert BadState(State.Active, c.state);

        // --- Ledger State Reset: erase the entire entitlement surface ---
        _ledger[id][c.partyA] = 0;
        _ledger[id][c.partyB] = 0;

        c.state = State.Dissolved;
        c.dissolvedAt = uint64(block.timestamp);

        emit LedgerStateReset(id, msg.sender, c.dissolvedAt);
    }

    /// @notice Read the current net entitlement of a party (pre-reset only).
    function entitlementOf(uint256 id, address party) external view returns (int256) {
        return _ledger[id][party];
    }
}
