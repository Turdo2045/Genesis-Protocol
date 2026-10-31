# Counterfactual Robustness Analysis — P-12 / P-13 / P-14 / P-15

Scope: does the Genesis-Protocol settlement & trust stack survive contact
with post-baseline-human counterparties? Method: for each scenario class,
identify which contract assumption breaks, then assign a mitigation and a
status. Status legend: ✅ robust by construction · ⚠️ parameter-level fix ·
❌ structural break (requires P-15).

## Load-bearing assumptions of P-12/13/14 (the attack surface of the future)

- **A1 — Party = one secp256k1 keypair.** `ecrecover` is the sole
  authentication primitive.
- **A2 — Time = Earth-second `block.timestamp`.** Heartbeat and inheritance
  windows are denominated in seconds.
- **A3 — One being, one key, one body.** Dissolution is unilateral per
  covenant; inheritance targets a single heir commitment.
- **A4 — Death/silence is observable as missing signature.**
- **A5 — No biometric binding anywhere** (a hidden strength — see below).

## Scenario matrix

| # | Scenario | Broken assumption | Failure mode | Mitigation | Status |
|---|----------|-------------------|--------------|------------|--------|
| 1 | 基因人 (germline-edited) | none | Genome is not a key; contract never reads biology | none needed | ✅ |
| 2 | 脑机接口 (BCI) | A1 | Neural-intent signing ≠ ECDSA; **coerced/involuntary signature** risk (a thought under duress is still a valid `ecrecover`) | P-15 pluggable verifier registry (neural-sig verifier contract); optional duress-flag policy module (off by default — see §Duress) | ❌→P-15 |
| 3 | Cyber化 / mind-upload | A4 | Biological death undefined; substrate migration is not inheritance but **self-succession** | P-15 `rotateVerifier`/`rotateCommitment` = self-succession primitive; heartbeat is already a signature, substrate-agnostic | ❌→P-15 |
| 4 | 生化人 (synthetic organisms) | none | — | none needed; key-only binding already biology-free | ✅ |
| 5 | 组合人 (collective/composite minds) | A3 | Unilateral `dissolve()` by ONE sub-mind destroys the whole composite's covenant — catastrophic | P-15 `ThresholdVerifier` (m-of-n over member keys) bound as the party's verifier | ❌→P-15 |
| 6 | 克隆人 (clones) | A3 (weakly) | Identical genome ≠ identical keys — contract is key-bound, so no on-chain ambiguity; residual risk is OFF-chain binding of `exitTermsHash` to the wrong twin | per-clone salt rotation of commitments; salt rotation already supported (P-14 note) | ⚠️ |
| 7 | 行星间人 (interplanetary) | A2 | Light delay (4–24 min Earth↔Mars) + superior conjunction blackouts cause **false-positive inheritance triggers**: owner alive but physically unable to heartbeat | P-15 `TimeBasis.BlockNumber` on per-planet rollups; floor `pulseInterval ≥ 2 × worst-case light delay + margin` at registration | ❌→P-15 |
| 8 | 行星外人 (non-terrestrial persons) | A1 | secp256k1 is a Terran accident; alien cryptography is not ECDSA | P-15 verifier registry accepts ANY verifier contract (lattice-based, hash-based, unknown-scheme) | ❌→P-15 |
| 9 | 非猿类人 (uplifted / non-simian / AI persons) | A1 (partially) | No hands, no seed phrases; custody via embedded enclave only | verifier registry + enclave attestation (P-14 device path generalizes cleanly) | ⚠️→P-15 |
| 10 | 多维空间人 | A2 | Non-linear subjective time; seconds are meaningless | chain consensus time is the ONLY canonical clock; P-15 `BlockNumber` basis removes Earth-second dependency entirely | ❌→P-15 |

## Cross-cutting finding: the coercion surface

For baseline humans, a signature implies a choice. For BCI and composite
scenarios it does not. P-15 therefore ships an OPTIONAL duress policy:
a pre-committed alternate auth path whose use marks the transition
`Flagged` (frozen for review by the counterparty set itself — never by a
court). It is off by default; enabling it reintroduces a delay, which is a
conscious trade against P-12's zero-friction invariant. We refuse to make
that trade silently.

## Verdict

P-12/13/14 remain the canonical minimal reference implementations for the
baseline-human equilibrium. They are frozen. All post-baseline scenarios
route through **P-15 — the Ontology-Agnostic Control Layer**, which
abstracts exactly the three broken assumptions:

1. **Authentication** → pluggable `IControlVerifier` registry
   (ECDSA today; neural-sig, lattice, alien-scheme tomorrow).
2. **Time** → `TimeBasis { ChainTime, BlockNumber }`, per-entity.
3. **Agency** → `ThresholdVerifier` for composite beings; commitment
   rotation for self-succession.

No scenario in the matrix requires reintroducing a judiciary, an identity
registry, or a probate court. That is the invariant the protocol is for.
