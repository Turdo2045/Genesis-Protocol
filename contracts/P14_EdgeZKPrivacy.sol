// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title P-14 — Edge-Side Zero-Knowledge Privacy Protocol (on-chain anchor)
/// @notice Trust-layer core. Edge devices (companion hardware / smart dolls)
///         destroy raw audio + multimodal captures locally; ONLY an
///         irreversible ZK state proof is anchored on-chain. The bedroom
///         produces no taxable evidence: Tax-Baseless by construction.
/// @dev    Invariants:
///         1. No raw media, no plaintext feature vector, no IPFS pointer to
///            raw captures may ever be submitted — the contract surface
///            physically cannot accept them (only bytes32 + proof bytes).
///         2. Nullifiers are single-use: one proof, one state transition.
///         3. Device identity is an attestation commitment, not a DID
///            document — no off-chain personal data is linkable on-chain.
interface IZKVerifier {
    /// @notice Returns true iff `proof` validates `publicInputs` under the
    ///         edge circuit (e.g., "a consensual state transition occurred at
    ///         epoch T without revealing any underlying signal").
    function verify(bytes calldata proof, bytes32[] calldata publicInputs)
        external
        view
        returns (bool);
}

contract P14_EdgeZKPrivacy {
    IZKVerifier public immutable verifier;

    /// @dev device commitment (e.g., keccak256(TEE attestation || salt))
    ///      => registered. Registration itself is permissionless but
    ///      hash-bound; rotating the salt rotates the pseudonym.
    mapping(bytes32 => bool) public registeredDevices;

    /// @dev spent nullifiers — replay/fork protection for state proofs
    mapping(bytes32 => bool) public spentNullifiers;

    /// @dev latest anchored state commitment per device commitment
    mapping(bytes32 => bytes32) public latestState;

    event DeviceRegistered(bytes32 indexed deviceCommitment);
    /// @notice The ONLY data ever emitted: irreversible commitments.
    ///         No audio, no frames, no embeddings — nothing to seize.
    event StateProofAnchored(
        bytes32 indexed deviceCommitment,
        bytes32 indexed nullifier,
        bytes32 newStateCommitment,
        uint64 atTime
    );

    error ProofInvalid();
    error NullifierSpent();
    error DeviceUnknown();

    constructor(address verifier_) {
        require(verifier_ != address(0), "verifier=0");
        verifier = IZKVerifier(verifier_);
    }

    /// @notice Bind a TEE/secure-enclave attestation hash as a pseudonymous
    ///         device identity. No personal data is involved at any step.
    function registerDevice(bytes32 deviceCommitment) external {
        require(deviceCommitment != bytes32(0), "commitment=0");
        require(!registeredDevices[deviceCommitment], "already registered");
        registeredDevices[deviceCommitment] = true;
        emit DeviceRegistered(deviceCommitment);
    }

    /// @notice Anchor an edge-generated ZK state proof.
    /// @param deviceCommitment  Pseudonymous device identity.
    /// @param nullifier         Single-use; derived as H(secret, epoch).
    /// @param newStateCommitment  Irreversible commitment to the post-state.
    /// @param proof             ZK proof over publicInputs =
    ///        [deviceCommitment, nullifier, newStateCommitment, epochCommitment]
    /// @dev   The proof asserts (in zero knowledge) that on the edge device:
    ///        - raw multimodal buffers were sampled, noised (DP), and ZEROED;
    ///        - the transition satisfies the protocol predicates;
    ///        - no raw artifact left the secure enclave.
    ///        The chain stores nothing that a coercive actor could tax or seize.
    function submitStateProof(
        bytes32 deviceCommitment,
        bytes32 nullifier,
        bytes32 newStateCommitment,
        bytes32 epochCommitment,
        bytes calldata proof
    ) external {
        if (!registeredDevices[deviceCommitment]) revert DeviceUnknown();
        if (spentNullifiers[nullifier]) revert NullifierSpent();

        bytes32[] memory inputs = new bytes32[](4);
        inputs[0] = deviceCommitment;
        inputs[1] = nullifier;
        inputs[2] = newStateCommitment;
        inputs[3] = epochCommitment;

        if (!verifier.verify(proof, inputs)) revert ProofInvalid();

        spentNullifiers[nullifier] = true;
        latestState[deviceCommitment] = newStateCommitment;

        emit StateProofAnchored(
            deviceCommitment,
            nullifier,
            newStateCommitment,
            uint64(block.timestamp)
        );
    }
}
