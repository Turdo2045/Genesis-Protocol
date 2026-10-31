// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../contracts/P15_OntologyAgnosticControl.sol";

/// @notice P-15 invariants: pluggable auth, threshold agency,
///         self-succession, non-Terran time bases.
contract P15Test is Test {
    P15_OntologyAgnosticControl internal p15;
    EcdsaVerifier internal ecdsa;
    ThresholdVerifier internal threshold;

    uint256 internal constant PK_A = 0xA1;
    uint256 internal constant PK_B = 0xB2;
    uint256 internal constant PK_C = 0xC3;

    bytes32 internal constant ENTITY = bytes32(uint256(0xE));
    bytes32 internal constant COMPOSITE = bytes32(uint256(0xC0));
    bytes32 internal constant MIGRATED = bytes32(uint256(0xA16));

    address internal a;
    address internal b;
    address internal c;

    function setUp() public {
        p15 = new P15_OntologyAgnosticControl();
        ecdsa = new EcdsaVerifier();
        threshold = new ThresholdVerifier();
        a = vm.addr(PK_A);
        b = vm.addr(PK_B);
        c = vm.addr(PK_C);
        vm.prank(a);
        ecdsa.bind(ENTITY);
    }

    function _sig(uint256 pk, bytes32 digest) internal pure returns (bytes memory) {
        bytes32 prefixed = keccak256(abi.encodePacked(
            "\x19Ethereum Signed Message:\n32", digest
        ));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, prefixed);
        return abi.encodePacked(r, s, v);
    }

    function _registerDigest(bytes32 commitment, address verifier,
                             P15_OntologyAgnosticControl.TimeBasis basis,
                             uint64 interval) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(
            "P15.register", commitment, verifier, uint8(basis), interval
        ));
    }

    /// INVARIANT 1: pluggable auth — ECDSA path registers and pulses.
    function test_EcdsaEntityLifecycle() public {
        p15.registerEntity(
            ENTITY, address(ecdsa),
            P15_OntologyAgnosticControl.TimeBasis.ChainTime,
            1 hours,
            _sig(PK_A, _registerDigest(ENTITY, address(ecdsa),
                 P15_OntologyAgnosticControl.TimeBasis.ChainTime, 1 hours))
        );
        assertFalse(p15.silenceExceeded(ENTITY));

        vm.warp(block.timestamp + 2 hours);
        assertTrue(p15.silenceExceeded(ENTITY));

        bytes32 digest = keccak256(abi.encodePacked(
            "P15.pulse", ENTITY, uint64(block.timestamp)
        ));
        p15.pulse(ENTITY, _sig(PK_A, digest));
        assertFalse(p15.silenceExceeded(ENTITY));
    }

    /// INVARIANT 2: threshold agency — one sub-mind of a composite cannot
    ///              act alone; 2-of-3 can.
    function test_CompositeThreshold() public {
        address[] memory members = new address[](3);
        members[0] = a; members[1] = b; members[2] = c;
        threshold.createSet(COMPOSITE, members, 2);

        bytes32 digest = keccak256("composite-action");

        // single sub-mind: insufficient
        bytes[] memory one = new bytes[](1);
        one[0] = _sig(PK_A, digest);
        assertFalse(
            threshold.verifyControl(COMPOSITE, digest, abi.encode(one))
        );

        // 2-of-3 sub-minds: quorum
        bytes[] memory two = new bytes[](2);
        two[0] = _sig(PK_A, digest);
        two[1] = _sig(PK_C, digest);
        assertTrue(
            threshold.verifyControl(COMPOSITE, digest, abi.encode(two))
        );

        // duplicate signer masquerading as quorum: dead
        bytes[] memory dup = new bytes[](2);
        dup[0] = _sig(PK_A, digest);
        dup[1] = _sig(PK_A, digest);
        assertFalse(
            threshold.verifyControl(COMPOSITE, digest, abi.encode(dup))
        );
    }

    /// INVARIANT 3: self-succession — substrate migration without
    ///              inheritance; old surface burned.
    function test_SelfSuccessionRotation() public {
        p15.registerEntity(
            ENTITY, address(ecdsa),
            P15_OntologyAgnosticControl.TimeBasis.ChainTime,
            1 hours,
            _sig(PK_A, _registerDigest(ENTITY, address(ecdsa),
                 P15_OntologyAgnosticControl.TimeBasis.ChainTime, 1 hours))
        );

        vm.prank(b);
        ecdsa.bind(MIGRATED);

        bytes32 digest = keccak256(abi.encodePacked(
            "P15.rotate", ENTITY, MIGRATED, address(ecdsa)
        ));
        p15.rotateControl(ENTITY, MIGRATED, address(ecdsa), _sig(PK_A, digest));

        // old anchor is gone — ephemeral
        vm.expectRevert(P15_OntologyAgnosticControl.EntityUnknown.selector);
        p15.silenceExceeded(ENTITY);
        // new anchor live
        assertFalse(p15.silenceExceeded(MIGRATED));
    }

    /// INVARIANT 4: non-Terran time — BlockNumber basis needs no seconds and
    ///              rejects Earth-chauvinist short windows.
    function test_BlockNumberBasis() public {
        p15.registerEntity(
            ENTITY, address(ecdsa),
            P15_OntologyAgnosticControl.TimeBasis.BlockNumber,
            100, // 100 blocks — delay-immune on any planetary rollup
            _sig(PK_A, _registerDigest(ENTITY, address(ecdsa),
                 P15_OntologyAgnosticControl.TimeBasis.BlockNumber, 100))
        );

        vm.roll(block.number + 101);
        assertTrue(p15.silenceExceeded(ENTITY));

        // and: a sub-hour ChainTime window is refused outright
        vm.expectRevert(P15_OntologyAgnosticControl.IntervalTooShort.selector);
        p15.registerEntity(
            MIGRATED, address(ecdsa),
            P15_OntologyAgnosticControl.TimeBasis.ChainTime,
            10 minutes,
            _sig(PK_A, _registerDigest(MIGRATED, address(ecdsa),
                 P15_OntologyAgnosticControl.TimeBasis.ChainTime, 10 minutes))
        );
    }
}
