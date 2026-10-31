// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../contracts/P14_EdgeZKPrivacy.sol";

/// @dev Verifier stub: the ZK backend is out of scope for unit tests.
contract MockVerifier is IZKVerifier {
    bool internal ok;

    function setResult(bool ok_) external {
        ok = ok_;
    }

    function verify(bytes calldata, bytes32[] calldata)
        external
        view
        returns (bool)
    {
        return ok;
    }
}

/// @notice P-14 invariants: nullifier single-use, device gating,
///         proof validity gating, commitment-only storage.
contract P14Test is Test {
    P14_EdgeZKPrivacy internal p14;
    MockVerifier internal mock;

    bytes32 internal constant DEVICE = bytes32(uint256(0xD31CE));
    bytes32 internal constant NULLIFIER = bytes32(uint256(0x1));
    bytes32 internal constant STATE_C = bytes32(uint256(0x2));
    bytes32 internal constant EPOCH_C = bytes32(uint256(0x3));

    function setUp() public {
        mock = new MockVerifier();
        p14 = new P14_EdgeZKPrivacy(address(mock));
        p14.registerDevice(DEVICE);
        mock.setResult(true);
    }

    /// INVARIANT 1: a nullifier is single-use — replay is dead.
    function test_NullifierSingleUse() public {
        p14.submitStateProof(DEVICE, NULLIFIER, STATE_C, EPOCH_C, hex"01");

        vm.expectRevert(P14_EdgeZKPrivacy.NullifierSpent.selector);
        p14.submitStateProof(DEVICE, NULLIFIER, bytes32(uint256(0x9)), EPOCH_C, hex"02");
    }

    /// INVARIANT 2: unregistered devices cannot anchor anything.
    function test_UnknownDeviceRejected() public {
        vm.expectRevert(P14_EdgeZKPrivacy.DeviceUnknown.selector);
        p14.submitStateProof(bytes32(uint256(0xBAD)), NULLIFIER, STATE_C, EPOCH_C, hex"01");
    }

    /// INVARIANT 3: invalid proofs never touch state.
    function test_InvalidProofRejected() public {
        mock.setResult(false);
        vm.expectRevert(P14_EdgeZKPrivacy.ProofInvalid.selector);
        p14.submitStateProof(DEVICE, NULLIFIER, STATE_C, EPOCH_C, hex"01");

        // state untouched after rejection
        assertEq(p14.latestState(DEVICE), bytes32(0));
        assertFalse(p14.spentNullifiers(NULLIFIER));
    }

    /// INVARIANT 4: only commitments are stored — nothing else exists to seize.
    function test_OnlyCommitmentsAnchored() public {
        p14.submitStateProof(DEVICE, NULLIFIER, STATE_C, EPOCH_C, hex"01");
        assertEq(p14.latestState(DEVICE), STATE_C);
        assertTrue(p14.spentNullifiers(NULLIFIER));
    }
}
