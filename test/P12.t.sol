// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../contracts/P12_FrictionlessStateTransition.sol";

/// @notice P-12 invariants: unilateral dissolution, total ledger reset,
///         zero third-party surface, terminality.
contract P12Test is Test {
    P12_FrictionlessStateTransition internal engine;

    address internal constant A = address(0xA);
    address internal constant B = address(0xB);
    address internal constant STRANGER = address(0xDEAD);

    function setUp() public {
        engine = new P12_FrictionlessStateTransition();
        vm.prank(A);
        engine.initiate(B, keccak256("exit-terms"));
    }

    function _state(uint256 id)
        internal
        view
        returns (P12_FrictionlessStateTransition.State)
    {
        (, , , , , P12_FrictionlessStateTransition.State s) =
            engine.covenants(id);
        return s;
    }

    /// INVARIANT 1: either party — not only the initiator — can dissolve.
    function test_UnilateralDissolveByCounterparty() public {
        vm.prank(B);
        engine.dissolve(1);
        assertEq(
            uint256(_state(1)),
            uint256(P12_FrictionlessStateTransition.State.Dissolved)
        );
    }

    /// INVARIANT 2: reset erases the entire entitlement surface.
    function test_LedgerZeroedOnReset() public {
        vm.prank(A);
        engine.post(1, A, 100 ether);
        vm.prank(B);
        engine.post(1, B, -40 ether);

        vm.prank(B);
        engine.dissolve(1);

        assertEq(engine.entitlementOf(1, A), 0);
        assertEq(engine.entitlementOf(1, B), 0);
    }

    /// INVARIANT 3: no third-party interface — strangers cannot attach.
    function test_NoThirdPartySurface() public {
        vm.prank(STRANGER);
        vm.expectRevert(P12_FrictionlessStateTransition.NotParty.selector);
        engine.dissolve(1);

        vm.prank(STRANGER);
        vm.expectRevert(P12_FrictionlessStateTransition.NotParty.selector);
        engine.post(1, A, 1);
    }

    /// INVARIANT 4: dissolution is terminal — no appeal, no reopen.
    function test_DissolveIsTerminal() public {
        vm.prank(A);
        engine.dissolve(1);

        vm.prank(A);
        vm.expectRevert(); // BadState — already Dissolved
        engine.dissolve(1);

        vm.prank(A);
        vm.expectRevert(); // posting on a dissolved covenant is dead
        engine.post(1, A, 1);
    }
}
