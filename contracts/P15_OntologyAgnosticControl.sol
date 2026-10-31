// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title P-15 — The Ontology-Agnostic Control Layer
/// @notice Generalization layer for post-baseline-human counterparties
///         (BCI, uploads, composites, clones, interplanetary,
///         non-terrestrial, non-simian, trans-dimensional). P-12/13/14 stay
///         frozen as minimal baseline references; P-15 abstracts their three
///         brittle assumptions: secp256k1-only auth, Earth-second time, and
///         single-mind agency.
/// @dev    Design invariants (same family as P-12/13/14):
///         1. No identity registry: an entity is a pseudonymous commitment.
///         2. No judiciary: verification is delegated to code, never to law.
///         3. No Earth chauvinism: time is chain consensus, denominated in
///            either seconds or block numbers, per entity.

/// @notice Pluggable authentication. Any signature scheme — ECDSA,
///         neural-intent, lattice-based, or one not yet invented on this
///         planet — is admissible if a contract can decide it.
interface IControlVerifier {
    function verifyControl(
        bytes32 commitment,
        bytes32 digest,
        bytes calldata authData
    ) external view returns (bool);
}

/// @notice Reference verifier: secp256k1 (baseline-human default).
contract EcdsaVerifier is IControlVerifier {
    mapping(bytes32 => address) public bound;

    function bind(bytes32 commitment) external {
        require(commitment != bytes32(0), "commitment=0");
        bound[commitment] = msg.sender;
    }

    function verifyControl(bytes32 commitment, bytes32 digest, bytes calldata authData)
        external
        view
        returns (bool)
    {
        if (authData.length != 65) return false;
        bytes32 r; bytes32 s; uint8 v;
        assembly {
            r := calldataload(authData.offset)
            s := calldataload(add(authData.offset, 32))
            v := byte(0, calldataload(add(authData.offset, 64)))
        }
        bytes32 prefixed = keccak256(abi.encodePacked(
            "\x19Ethereum Signed Message:\n32", digest
        ));
        return ecrecover(prefixed, v, r, s) == bound[commitment];
    }
}

/// @notice m-of-n threshold verifier for composite beings: no single
///         sub-mind may unilaterally act for the collective.
contract ThresholdVerifier is IControlVerifier {
    struct MemberSet {
        uint8 threshold;
        uint8 memberCount;
        bool exists;
    }

    mapping(bytes32 => MemberSet) public sets;          // commitment => config
    mapping(bytes32 => mapping(address => bool)) public isMember;

    function createSet(bytes32 commitment, address[] calldata members, uint8 threshold)
        external
    {
        require(!sets[commitment].exists, "set exists");
        require(threshold >= 2 && threshold <= members.length, "bad threshold");
        require(members.length <= 255, "too many");
        MemberSet storage ms = sets[commitment];
        ms.threshold = threshold;
        ms.memberCount = uint8(members.length);
        ms.exists = true;
        for (uint256 i = 0; i < members.length; ++i) {
            require(members[i] != address(0), "member=0");
            require(!isMember[commitment][members[i]], "dup member");
            isMember[commitment][members[i]] = true;
        }
    }

    /// @dev authData = abi.encode(bytes[] sigs) where each sig is 65-byte
    ///      (r,s,v) over `digest`; distinct members, count >= threshold.
    function verifyControl(bytes32 commitment, bytes32 digest, bytes calldata authData)
        external
        view
        returns (bool)
    {
        MemberSet storage ms = sets[commitment];
        if (!ms.exists) return false;

        bytes[] memory sigs = abi.decode(authData, (bytes[]));
        if (sigs.length < ms.threshold) return false;

        bytes32 prefixed = keccak256(abi.encodePacked(
            "\x19Ethereum Signed Message:\n32", digest
        ));
        address[] memory seen = new address[](sigs.length);
        uint256 valid = 0;

        for (uint256 i = 0; i < sigs.length; ++i) {
            if (sigs[i].length != 65) return false;
            bytes32 r; bytes32 s; uint8 v;
            bytes memory sig = sigs[i];
            assembly {
                r := mload(add(sig, 32))
                s := mload(add(sig, 64))
                v := byte(0, mload(add(sig, 96)))
            }
            address recovered = ecrecover(prefixed, v, r, s);
            if (!isMember[commitment][recovered]) return false;
            for (uint256 j = 0; j < valid; ++j) {
                if (seen[j] == recovered) return false; // duplicate signer
            }
            seen[valid] = recovered;
            ++valid;
        }
        return valid >= ms.threshold;
    }
}

contract P15_OntologyAgnosticControl {
    enum TimeBasis { ChainTime, BlockNumber }

    struct Entity {
        address verifier;      // IControlVerifier — any scheme, any species
        bytes32 commitment;    // pseudonymous existence anchor
        TimeBasis timeBasis;   // seconds (Terran) or blocks (canonical)
        uint64  lastPulse;
        uint64  pulseInterval; // in the unit of timeBasis
        bool    exists;
    }

    mapping(bytes32 => Entity) public entities;

    event EntityRegistered(bytes32 indexed commitment, address verifier, TimeBasis basis);
    event Pulse(bytes32 indexed commitment, uint64 atTime);
    /// @notice Substrate migration = self-succession: the SAME entity moves
    ///         to a new key/scheme without triggering inheritance semantics.
    event ControlRotated(bytes32 indexed oldCommitment, bytes32 indexed newCommitment);

    error EntityExists();
    error EntityUnknown();
    error Unauthorized();
    error IntervalTooShort();

    /// @dev Floor for pulse intervals expressed in seconds: two-way worst-case
    ///      Earth↔Mars light delay (~44 min) plus margin, rounded to 1 hour.
    ///      Block-number basis is delay-immune by construction.
    uint64 public constant MIN_CHAIN_TIME_INTERVAL = 1 hours;

    function registerEntity(
        bytes32 commitment,
        address verifier,
        TimeBasis timeBasis,
        uint64 pulseInterval,
        bytes calldata authData
    ) external {
        if (entities[commitment].exists) revert EntityExists();
        require(verifier != address(0), "verifier=0");
        if (timeBasis == TimeBasis.ChainTime && pulseInterval < MIN_CHAIN_TIME_INTERVAL) {
            revert IntervalTooShort();
        }
        bytes32 digest = keccak256(abi.encodePacked(
            "P15.register", commitment, verifier, uint8(timeBasis), pulseInterval
        ));
        if (!IControlVerifier(verifier).verifyControl(commitment, digest, authData)) {
            revert Unauthorized();
        }

        entities[commitment] = Entity({
            verifier: verifier,
            commitment: commitment,
            timeBasis: timeBasis,
            lastPulse: _now(timeBasis),
            pulseInterval: pulseInterval,
            exists: true
        });
        emit EntityRegistered(commitment, verifier, timeBasis);
    }

    /// @notice Liveness pulse — a signature, not a heartbeat. Substrate-free.
    function pulse(bytes32 commitment, bytes calldata authData) external {
        Entity storage e = entities[commitment];
        if (!e.exists) revert EntityUnknown();
        bytes32 digest = keccak256(abi.encodePacked(
            "P15.pulse", commitment, _now(e.timeBasis)
        ));
        if (!IControlVerifier(e.verifier).verifyControl(commitment, digest, authData)) {
            revert Unauthorized();
        }
        e.lastPulse = _now(e.timeBasis);
        emit Pulse(commitment, e.lastPulse);
    }

    /// @notice Self-succession: rotate to a new commitment + verifier under
    ///         the CURRENT control. Covers mind-upload migration and clone
    ///         salt rotation without invoking inheritance at all.
    function rotateControl(
        bytes32 oldCommitment,
        bytes32 newCommitment,
        address newVerifier,
        bytes calldata authData
    ) external {
        Entity storage e = entities[oldCommitment];
        if (!e.exists) revert EntityUnknown();
        if (entities[newCommitment].exists) revert EntityExists();
        bytes32 digest = keccak256(abi.encodePacked(
            "P15.rotate", oldCommitment, newCommitment, newVerifier
        ));
        if (!IControlVerifier(e.verifier).verifyControl(oldCommitment, digest, authData)) {
            revert Unauthorized();
        }

        entities[newCommitment] = Entity({
            verifier: newVerifier,
            commitment: newCommitment,
            timeBasis: e.timeBasis,
            lastPulse: _now(e.timeBasis),
            pulseInterval: e.pulseInterval,
            exists: true
        });
        delete entities[oldCommitment]; // ephemeral: old surface burned
        emit ControlRotated(oldCommitment, newCommitment);
    }

    /// @notice Silence check in the entity's OWN time basis — safe for
    ///         interplanetary and trans-dimensional counterparties.
    function silenceExceeded(bytes32 commitment) external view returns (bool) {
        Entity storage e = entities[commitment];
        if (!e.exists) revert EntityUnknown();
        return _now(e.timeBasis) > e.lastPulse + e.pulseInterval;
    }

    function _now(TimeBasis basis) internal view returns (uint64) {
        return basis == TimeBasis.ChainTime
            ? uint64(block.timestamp)
            : uint64(block.number);
    }
}
