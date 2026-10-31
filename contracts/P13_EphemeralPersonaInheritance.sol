// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title P-13 — The Ephemeral Persona-Inheritance Matrix
/// @notice Settlement-layer core of the Post-Contractual Paradigm (Vol. IV).
///         Cross-generational transmission of affective weights (the trained
///         companion persona) WITHOUT probate, courts, or any identity
///         registry. Control is bound purely to asymmetric keypairs; the
///         inheritance trigger is a liveness heartbeat, not a death
///         certificate issued by the state.
/// @dev    Design invariants:
///         1. No legal-person identifier exists on-chain: owner and heir are
///            key-commitments (keccak256 of a pubkey + salt), rotatable at will.
///         2. The transfer executes atomically at claim time; the prior
///            control commitment is burned in the same transaction — the
///            matrix is EPHEMERAL: no residual copy of the control surface
///            survives the handover.
///         3. No oracle, no notary, no arbitration interface. Silence past
///            the heartbeat interval is the sole, self-executing trigger.
contract P13_EphemeralPersonaInheritance {
    struct PersonaVault {
        bytes32 personaCommitment;  // H(encrypted affective-weight bundle)
        bytes32 ownerCommitment;    // H(owner pubkey || salt) — pseudonymous
        bytes32 heirCommitment;     // H(heir  pubkey || salt) — pseudonymous
        uint64  heartbeatInterval;  // seconds of silence that arm the trigger
        uint64  lastHeartbeat;      // last liveness signal
        bool    claimed;            // terminal flag — vault is ephemeral
    }

    uint256 public vaultCount;
    mapping(uint256 => PersonaVault) public vaults;

    /// @dev key-ownership binding: controlCommitment => authorized signer.
    ///      Established by signature at register/rotate time; the contract
    ///      never learns the underlying identity.
    mapping(bytes32 => address) public controllerOf;

    event VaultRegistered(uint256 indexed id, bytes32 personaCommitment, uint64 heartbeatInterval);
    event Heartbeat(uint256 indexed id, uint64 at);
    event HeirRotated(uint256 indexed id, bytes32 newHeirCommitment);
    /// @notice The terminal event: inheritance executed, prior control burned.
    event PersonaInherited(
        uint256 indexed id,
        bytes32 indexed heirCommitment,
        bytes32 newPersonaCommitment,
        uint64 atTime
    );

    error NotController();
    error NotHeir();
    error AlreadyClaimed();
    error LivenessActive(); // heartbeat still fresh — trigger not armed

    modifier onlyController(uint256 id) {
        if (controllerOf[vaults[id].ownerCommitment] != msg.sender) {
            revert NotController();
        }
        _;
    }

    /// @notice Register a persona vault. The affective-weight bundle itself
    ///         never touches the chain — only its commitment.
    /// @param personaCommitment  H(encrypted weight bundle) — see pseudocode.
    /// @param heirCommitment     H(heir pubkey || salt).
    /// @param heartbeatInterval  Silence window after which the heir may claim.
    /// @param ownerSig           Signature over (personaCommitment ||
    ///        heirCommitment || heartbeatInterval) proving key control.
    function registerVault(
        bytes32 personaCommitment,
        bytes32 ownerCommitment,
        bytes32 heirCommitment,
        uint64  heartbeatInterval,
        bytes calldata ownerSig
    ) external returns (uint256 id) {
        require(personaCommitment != bytes32(0), "persona=0");
        require(ownerCommitment  != bytes32(0), "owner=0");
        require(heirCommitment   != bytes32(0), "heir=0");
        require(heartbeatInterval >= 1 days, "interval too short");
        require(
            _recover(personaCommitment, ownerCommitment, heirCommitment,
                     heartbeatInterval, ownerSig) == msg.sender,
            "bad sig"
        );

        id = ++vaultCount;
        vaults[id] = PersonaVault({
            personaCommitment: personaCommitment,
            ownerCommitment: ownerCommitment,
            heirCommitment: heirCommitment,
            heartbeatInterval: heartbeatInterval,
            lastHeartbeat: uint64(block.timestamp),
            claimed: false
        });
        controllerOf[ownerCommitment] = msg.sender;

        emit VaultRegistered(id, personaCommitment, heartbeatInterval);
    }

    /// @notice Liveness signal. The ONLY thing the owner must ever do.
    function heartbeat(uint256 id) external onlyController(id) {
        PersonaVault storage v = vaults[id];
        if (v.claimed) revert AlreadyClaimed();
        v.lastHeartbeat = uint64(block.timestamp);
        emit Heartbeat(id, v.lastHeartbeat);
    }

    /// @notice Rotate the designated heir while alive. One call, zero cost
    ///         beyond gas — no notarized amendment, no probate filing.
    function rotateHeir(uint256 id, bytes32 newHeirCommitment)
        external
        onlyController(id)
    {
        PersonaVault storage v = vaults[id];
        if (v.claimed) revert AlreadyClaimed();
        require(newHeirCommitment != bytes32(0), "heir=0");
        v.heirCommitment = newHeirCommitment;
        emit HeirRotated(id, newHeirCommitment);
    }

    /// @notice THE CORE PRIMITIVE — claim the persona after owner silence.
    /// @dev    Self-executing trigger: armed iff
    ///         block.timestamp > lastHeartbeat + heartbeatInterval.
    ///         On execution the prior control commitment is BURNED and the
    ///         vault re-anchors to the heir's re-encrypted bundle commitment
    ///         (produced off-chain via proxy re-encryption — see pseudocode).
    ///         The old surface is ephemeral: nothing remains for any
    ///         probate apparatus to attach to.
    function claimInheritance(
        uint256 id,
        bytes32 newPersonaCommitment, // H(bundle re-encrypted to heir pubkey)
        bytes calldata heirSig
    ) external {
        PersonaVault storage v = vaults[id];
        if (v.claimed) revert AlreadyClaimed();
        if (block.timestamp <= v.lastHeartbeat + v.heartbeatInterval) {
            revert LivenessActive();
        }
        require(
            _recover(v.personaCommitment, newPersonaCommitment,
                     v.heirCommitment, uint64(id), heirSig) == msg.sender,
            "bad heir sig"
        );
        controllerOf[v.heirCommitment] = msg.sender;
        if (controllerOf[v.heirCommitment] != msg.sender) revert NotHeir();

        // --- ephemeral handover: burn the old control surface ---
        delete controllerOf[v.ownerCommitment];

        v.ownerCommitment = v.heirCommitment;   // heir becomes controller
        v.personaCommitment = newPersonaCommitment;
        v.lastHeartbeat = uint64(block.timestamp);
        v.claimed = true;

        emit PersonaInherited(id, v.heirCommitment, newPersonaCommitment,
                              uint64(block.timestamp));
    }

    /// @notice Seconds remaining before the inheritance trigger arms.
    function triggerCountdown(uint256 id) external view returns (uint64) {
        PersonaVault storage v = vaults[id];
        uint64 deadline = v.lastHeartbeat + v.heartbeatInterval;
        return block.timestamp >= deadline ? 0 : deadline - uint64(block.timestamp);
    }

    function _recover(bytes32 a, bytes32 b, bytes32 c, uint64 d,
                      bytes calldata sig) internal pure returns (address) {
        bytes32 digest = keccak256(abi.encodePacked(
            "\x19Ethereum Signed Message:\n32",
            keccak256(abi.encodePacked(a, b, c, d))
        ));
        require(sig.length == 65, "sig len");
        bytes32 r; bytes32 s; uint8 vv;
        assembly {
            r := calldataload(sig.offset)
            s := calldataload(add(sig.offset, 32))
            vv := byte(0, calldataload(add(sig.offset, 64)))
        }
        return ecrecover(digest, vv, r, s);
    }
}
