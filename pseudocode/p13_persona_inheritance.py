"""
P-13 — The Ephemeral Persona-Inheritance Matrix (off-chain reference logic)
=============================================================================
Post-Contractual Paradigm, Vol. IV — Settlement Layer.

Pseudocode mirror of contracts/P13_EphemeralPersonaInheritance.sol.

Core idea: the trained companion persona (affective-weight bundle) passes
across generations WITHOUT probate. Control is bound to asymmetric keys;
the trigger is a liveness heartbeat; the handover is proxy re-encryption;
the old ciphertext is destroyed — the matrix is ephemeral, leaving no
surface for any state probate apparatus to attach to.
"""

from dataclasses import dataclass, field
from hashlib import sha3_256  # placeholder for keccak256 / Poseidon
from os import urandom
from time import time


def _H(*parts: bytes) -> bytes:
    h = sha3_256()
    for p in parts:
        h.update(p)
    return h.digest()


class Keypair:
    """Stub for an ed25519/secp256k1 keypair. The legal identity of the
    holder NEVER enters the system — only H(pubkey || salt)."""

    def __init__(self):
        self.secret = urandom(32)
        self.pubkey = _H(b"pub", self.secret)  # stub
        self.salt = urandom(32)

    @property
    def commitment(self) -> bytes:
        return _H(self.pubkey, self.salt)

    def sign(self, *payload: bytes) -> bytes:
        return _H(b"sig", self.secret, *payload)  # stub


@dataclass
class PersonaBundle:
    """The affective-weight matrix of a trained companion, encrypted at
    rest to the owner's pubkey. Never exists in plaintext off-enclave."""
    ciphertext: bytes

    @classmethod
    def seal(cls, weights: bytes, owner: Keypair) -> "PersonaBundle":
        return cls(ciphertext=_H(b"enc", weights, owner.pubkey))

    def commitment(self) -> bytes:
        return _H(b"persona", self.ciphertext)


@dataclass
class PersonaVault:
    persona_commitment: bytes
    owner_commitment: bytes
    heir_commitment: bytes
    heartbeat_interval: int          # seconds of silence arming the trigger
    last_heartbeat: float = field(default_factory=time)
    claimed: bool = False


class InheritanceMatrix:
    """Off-chain mirror of the on-chain vault registry."""

    def __init__(self):
        self.vaults: dict[int, PersonaVault] = {}
        self._seq = 0

    # --- lifecycle ------------------------------------------------------

    def register(self, bundle: PersonaBundle, owner: Keypair,
                 heir: Keypair, heartbeat_interval: int) -> int:
        assert heartbeat_interval >= 86_400
        self._seq += 1
        self.vaults[self._seq] = PersonaVault(
            persona_commitment=bundle.commitment(),
            owner_commitment=owner.commitment,
            heir_commitment=heir.commitment,
            heartbeat_interval=heartbeat_interval,
        )
        return self._seq

    def heartbeat(self, vid: int, owner: Keypair) -> None:
        """The ONLY duty of the living owner: prove liveness by key."""
        v = self.vaults[vid]
        assert owner.commitment == v.owner_commitment and not v.claimed
        v.last_heartbeat = time()

    def rotate_heir(self, vid: int, owner: Keypair, new_heir: Keypair) -> None:
        v = self.vaults[vid]
        assert owner.commitment == v.owner_commitment and not v.claimed
        v.heir_commitment = new_heir.commitment

    # --- the core primitive ----------------------------------------------

    def claim(self, vid: int, heir: Keypair,
              bundle: PersonaBundle) -> PersonaBundle:
        """Self-executing inheritance. Armed iff
        now > last_heartbeat + heartbeat_interval.

        Steps (proxy re-encryption ceremony, no plaintext ever exposed):
          1. verify silence window elapsed — this replaces the death
             certificate; no state registry is consulted;
          2. re-encrypt the bundle from owner-pubkey to heir-pubkey
             (proxy re-encryption; the relay learns nothing);
          3. ZEROIZE the old ciphertext — the pre-handover artifact is
             ephemeral and unrecoverable;
          4. burn the owner's control commitment; re-anchor to the heir.
        """
        v = self.vaults[vid]
        assert heir.commitment == v.heir_commitment and not v.claimed
        assert time() > v.last_heartbeat + v.heartbeat_interval

        re_encrypted = self._proxy_reencrypt(bundle, heir)

        # ephemeral destruction of the old surface
        self._zeroize(bundle.ciphertext)
        v.owner_commitment = b"\x00" * 32      # burned
        v.persona_commitment = re_encrypted.commitment()
        v.claimed = True
        return re_encrypted

    # --- internals (stubs) -----------------------------------------------

    def _proxy_reencrypt(self, bundle: PersonaBundle,
                         heir: Keypair) -> PersonaBundle:
        # PRE (e.g., Umbral-style) stub: capsule transform under heir pubkey.
        # The re-encryption key never decrypts; plaintext never materializes.
        return PersonaBundle(ciphertext=_H(b"re-enc", bundle.ciphertext,
                                           heir.pubkey))

    def _zeroize(self, *buffers) -> None:
        for buf in buffers:
            del buf

    # NOTE: no def probate(), no def notarize(), no def court_verify().
    # Inheritance here is a cryptographic fact, not a legal procedure.
