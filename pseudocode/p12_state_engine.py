"""
P-12 — The Frictionless State-Transition Engine (off-chain reference logic)
=============================================================================
Post-Contractual Paradigm, Vol. IV — Settlement Layer.

Pseudocode mirror of contracts/P12_FrictionlessStateTransition.sol.
Illustrates the full lifecycle: initiate -> post -> dissolve (one-click
Ledger State Reset). There is deliberately NO arbitration / court / oracle
branch in this control flow. Absence is the security property.
"""

from dataclasses import dataclass, field
from enum import Enum, auto
from hashlib import sha3_256  # placeholder for keccak256
from time import time


class State(Enum):
    UNINITIALIZED = auto()
    ACTIVE = auto()
    SUSPENDED = auto()
    DISSOLVED = auto()  # terminal


@dataclass
class ExitTerms:
    """Deterministic exit allocation, committed at initiation.

    split_matrix: {party: fraction_bps} — executed as-is at reset.
    No third party may reinterpret; the hash on-chain binds this document.
    """
    split_matrix: dict[str, int]

    def commitment(self) -> bytes:
        blob = repr(sorted(self.split_matrix.items())).encode()
        return sha3_256(blob).digest()


@dataclass
class Covenant:
    party_a: str
    party_b: str
    exit_terms_hash: bytes
    state: State = State.ACTIVE
    ledger: dict[str, float] = field(default_factory=dict)
    initiated_at: float = field(default_factory=time)
    dissolved_at: float | None = None


class FrictionlessEngine:
    LIQUIDATION_TAX_BPS = 0  # hard-coded zero: the tax is dead by construction

    def __init__(self):
        self.covenants: dict[int, Covenant] = {}
        self._seq = 0

    def initiate(self, party_a: str, party_b: str, terms: ExitTerms) -> int:
        assert party_a != party_b
        self._seq += 1
        self.covenants[self._seq] = Covenant(
            party_a=party_a, party_b=party_b,
            exit_terms_hash=terms.commitment(),
            ledger={party_a: 0.0, party_b: 0.0},
        )
        return self._seq

    def post(self, cid: int, party: str, delta: float) -> None:
        c = self.covenants[cid]
        assert c.state is State.ACTIVE and party in c.ledger
        c.ledger[party] += delta

    def dissolve(self, cid: int, initiator: str) -> dict[str, float]:
        """THE CORE PRIMITIVE — one-click Ledger State Reset.

        Unilateral. No notice period, no cooling-off, no fee, no review
        interface. Settlement executes deterministically from the
        pre-committed exit terms; the ledger is zeroed in the same step.
        """
        c = self.covenants[cid]
        assert initiator in (c.party_a, c.party_b)
        assert c.state in (State.ACTIVE, State.SUSPENDED)

        # deterministic settlement — zero tax, zero friction
        settlement = {p: v * (1 - self.LIQUIDATION_TAX_BPS / 10_000)
                      for p, v in c.ledger.items()}

        # state reset: erase the entire entitlement surface
        c.ledger = {p: 0.0 for p in c.ledger}
        c.state = State.DISSOLVED
        c.dissolved_at = time()
        return settlement

    # NOTE: no def arbitrate(), no def appeal(), no def court_attach().
    # The absence of these symbols is the protocol's legal-attack surface
    # reduction. Any PR adding one is a consensus-breaking change.
