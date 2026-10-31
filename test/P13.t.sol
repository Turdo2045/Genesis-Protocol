// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../contracts/P13_EphemeralPersonaInheritance.sol";

/// @notice P-13 invariants: heartbeat-armed trigger, key-bound control,
///         ephemeral handover (old surface burned), terminality.
contract P13Test is Test {
    P13_EphemeralPersonaInheritance internal matrix;

    uint256 internal constant OWNER_PK = 0x0B1E55;
    uint256 internal constant HEIR_PK = 0xBE1F;

    address internal owner;
    address internal heir;

    bytes32 internal constant PERSONA_C = bytes32(uint256(0x1));
    bytes32 internal constant OWNER_C = bytes32(uint256(0x2));
    bytes32 internal constant HEIR_C = bytes32(uint256(0x3));
    bytes32 internal constant NEW_PERSONA_C = bytes32(uint256(0x4));
    uint64  internal constant INTERVAL = 30 days;

    function setUp() public {
        matrix = new P13_EphemeralPersonaInheritance();
        owner = vm.addr(OWNER_PK);
        heir = vm.addr(HEIR_PK);

        vm.prank(owner);
        matrix.registerVault(PERSONA_C, OWNER_C, HEIR_C, INTERVAL, _sig(OWNER_PK, PERSONA_C, OWNER_C, HEIR_C, INTERVAL));
    }

    function _sig(uint256 pk, bytes32 a, bytes32 b, bytes32 c, uint64 d)
        internal
        pure
        returns (bytes memory)
    {
        bytes32 inner = keccak256(abi.encodePacked(a, b, c, d));
        bytes32 digest = keccak256(abi.encodePacked(
            "\x19Ethereum Signed Message:\n32", inner
        ));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, digest);
        return abi.encodePacked(r, s, v);
    }

    /// INVARIANT 1: the trigger is armed ONLY by silence past the window.
    function test_ClaimBeforeWindowReverts() public {
        vm.warp(block.timestamp + INTERVAL); // exactly at deadline: still alive
        vm.prank(heir);
        vm.expectRevert(P13_EphemeralPersonaInheritance.LivenessActive.selector);
        matrix.claimInheritance(1, NEW_PERSONA_C, _sig(HEIR_PK, PERSONA_C, NEW_PERSONA_C, HEIR_C, uint64(1)));
    }

    /// INVARIANT 2: after silence, the heir — key-bound — claims atomically.
    function test_HeirClaimsAfterSilence() public {
        vm.warp(block.timestamp + INTERVAL + 1);
        vm.prank(heir);
        matrix.claimInheritance(1, NEW_PERSONA_C, _sig(HEIR_PK, PERSONA_C, NEW_PERSONA_C, HEIR_C, uint64(1)));

        (
            bytes32 personaCommitment,
            bytes32 ownerCommitment,
            ,
            ,
            ,
            bool claimed
        ) = matrix.vaults(1);

        assertEq(personaCommitment, NEW_PERSONA_C);
        assertEq(ownerCommitment, HEIR_C);   // heir is now the controller
        assertTrue(claimed);
    }

    /// INVARIANT 3: the handover is ephemeral — the old control surface
    ///              is burned; nothing remains for probate to attach to.
    function test_OldControlBurned() public {
        vm.warp(block.timestamp + INTERVAL + 1);
        vm.prank(heir);
        matrix.claimInheritance(1, NEW_PERSONA_C, _sig(HEIR_PK, PERSONA_C, NEW_PERSONA_C, HEIR_C, uint64(1)));

        assertEq(matrix.controllerOf(OWNER_C), address(0));

        // the former owner can no longer heartbeat or rotate
        vm.prank(owner);
        vm.expectRevert(P13_EphemeralPersonaInheritance.NotController.selector);
        matrix.heartbeat(1);
    }

    /// INVARIANT 4: inheritance is terminal — no double claim.
    function test_NoDoubleClaim() public {
        vm.warp(block.timestamp + INTERVAL + 1);
        vm.prank(heir);
        matrix.claimInheritance(1, NEW_PERSONA_C, _sig(HEIR_PK, PERSONA_C, NEW_PERSONA_C, HEIR_C, uint64(1)));

        vm.prank(heir);
        vm.expectRevert(P13_EphemeralPersonaInheritance.AlreadyClaimed.selector);
        matrix.claimInheritance(1, NEW_PERSONA_C, _sig(HEIR_PK, PERSONA_C, NEW_PERSONA_C, HEIR_C, uint64(1)));
    }

    /// INVARIANT 5: a live heartbeat re-arms nothing — silence is required.
    function test_HeartbeatResetsWindow() public {
        vm.warp(block.timestamp + INTERVAL - 1 hours);
        vm.prank(owner);
        matrix.heartbeat(1);

        vm.warp(block.timestamp + 2 hours); // past old deadline, within new
        vm.prank(heir);
        vm.expectRevert(P13_EphemeralPersonaInheritance.LivenessActive.selector);
        matrix.claimInheritance(1, NEW_PERSONA_C, _sig(HEIR_PK, PERSONA_C, NEW_PERSONA_C, HEIR_C, uint64(1)));
    }
}
