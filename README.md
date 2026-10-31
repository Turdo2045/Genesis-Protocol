# Genesis-Protocol

[![invariant-tests](https://github.com/Turdo2045/Genesis-Protocol/actions/workflows/ci.yml/badge.svg)](https://github.com/Turdo2045/Genesis-Protocol/actions/workflows/ci.yml)

Open standards-track protocol cores for *The Post-Contractual Paradigm*
(Volume IV, §5). Settlement and trust layers released as permanent
defensive publications — un-patentable by design, un-enclosable by
construction.

## Protocol cores

| Slot | Name | Core | Invariant tests |
|---|---|---|---|
| P-12 | Frictionless State-Transition Engine | `contracts/P12_FrictionlessStateTransition.sol` | `test/P12.t.sol` |
| P-13 | Ephemeral Persona-Inheritance Matrix | `contracts/P13_EphemeralPersonaInheritance.sol` | `test/P13.t.sol` |
| P-14 | Edge-Side Zero-Knowledge Privacy | `contracts/P14_EdgeZKPrivacy.sol` | `test/P14.t.sol` |
| P-15 | Ontology-Agnostic Control Layer | `contracts/P15_OntologyAgnosticControl.sol` | `test/P15.t.sol` |

Reference logic (pseudocode mirrors) lives in `pseudocode/`; the
counterfactual robustness analysis (post-baseline-human scenarios) lives
in `docs/COUNTERFACTUAL_ROBUSTNESS.md`. Citation paths are frozen in
`SECTION5_REFERENCE_LOCK.md`.

## Verify

```bash
forge install foundry-rs/forge-std --no-commit
forge test -vv   # 17 invariants, all green
```

License: MIT.
