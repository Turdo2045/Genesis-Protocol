# Genesis Protocol — Section 5 Reference Lock (Vol. IV)

Canonical repository: `https://github.com/Turdo2045/Genesis-Protocol`

All manuscript citations in **Section 5 (Intellectual Property)** of
*The Post-Contractual Paradigm* (Vol. IV) MUST resolve to the following
relative paths. These paths are frozen; any rename is a citation-breaking
change and must be rejected in review.

| Protocol | Component | Repo-relative path | Canonical URL |
|---|---|---|---|
| P-12 | Frictionless State-Transition Engine (Solidity core) | `contracts/P12_FrictionlessStateTransition.sol` | https://github.com/Turdo2045/Genesis-Protocol/blob/main/contracts/P12_FrictionlessStateTransition.sol |
| P-12 | Off-chain reference logic (pseudocode) | `pseudocode/p12_state_engine.py` | https://github.com/Turdo2045/Genesis-Protocol/blob/main/pseudocode/p12_state_engine.py |
| P-13 | Ephemeral Persona-Inheritance Matrix (Solidity core) | `contracts/P13_EphemeralPersonaInheritance.sol` | https://github.com/Turdo2045/Genesis-Protocol/blob/main/contracts/P13_EphemeralPersonaInheritance.sol |
| P-13 | Off-chain reference logic (pseudocode) | `pseudocode/p13_persona_inheritance.py` | https://github.com/Turdo2045/Genesis-Protocol/blob/main/pseudocode/p13_persona_inheritance.py |
| P-14 | Edge-Side ZK Privacy anchor (Solidity core) | `contracts/P14_EdgeZKPrivacy.sol` | https://github.com/Turdo2045/Genesis-Protocol/blob/main/contracts/P14_EdgeZKPrivacy.sol |
| P-14 | Edge pipeline reference logic (pseudocode) | `pseudocode/p14_edge_zk.py` | https://github.com/Turdo2045/Genesis-Protocol/blob/main/pseudocode/p14_edge_zk.py |

## Manuscript citation format (LaTeX)

```latex
The P-12 settlement primitive is released as open-source
protocol\footnote{\url{https://github.com/Turdo2045/Genesis-Protocol/blob/main/contracts/P12_FrictionlessStateTransition.sol}}.

The P-13 persona-inheritance primitive is released as open-source
protocol\footnote{\url{https://github.com/Turdo2045/Genesis-Protocol/blob/main/contracts/P13_EphemeralPersonaInheritance.sol}}.

The P-14 trust-layer anchor is released as open-source
protocol\footnote{\url{https://github.com/Turdo2045/Genesis-Protocol/blob/main/contracts/P14_EdgeZKPrivacy.sol}}.
```

## Deployment sync

From the candidate workspace to the local clone root:

```bash
rsync -a --delete \
  "/Users/andy/Workspaces/20_Company/company/交付/新人类之父/Genesis-Protocol/" \
  "/Users/andy/Soft/kimicode/TurdoAll/Genesis-Protocol/"
cd "/Users/andy/Soft/kimicode/TurdoAll/Genesis-Protocol" \
  && git add -A && git commit -m "P-12/P-14: settlement & trust layer core (Vol. IV Section 5)" \
  && git push origin main
```

License: MIT (SPDX identifier embedded per file).
