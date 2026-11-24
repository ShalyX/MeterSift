# MeterSift

Consider a community energy operator settling payment to a local energy supplier for electricity delivered. The meter profile used to calculate that payment does not reconcile. Paying against questionable data risks overpaying; holding the settlement risks delaying money legitimately owed. Repeating that decision across hundreds of meters becomes difficult to manage consistently.

MeterSift screens daily meter-profile submissions from authorized meter accounts and routes suspicious or uncertain settlements to evidence-backed human review. The neural model runs inside Reactive and returns a decision to the escrow; it does not decide guilt or release funds. An authorized operator controls the separate release or refund.

A model flag is a screening signal, not proof of theft or customer wrongdoing.

## What it demonstrates

- A profile submission from an authorized meter account is evaluated using ten derived fixed-point features.
- Reactive processing on Lasna returns an authenticated decision to the Base Sepolia escrow.
- Routine cases become release-ready; funds move only after a separate operator release.
- Exception cases remain held until an authorized reviewer records a decision; release or refund is a distinct action.
- Two funded testnet cases demonstrate routine and human-review paths.

## Architecture

1. Profile commitment: an authorized meter account submits a profile hash and ten derived features. The transaction signature authenticates the submitting account, not physical meter hardware or the truth of the readings. The origin contract does not independently recompute the features from raw readings. The explorer displays ten derived features from synthetic profiles; it does not reconstruct the original hourly readings.
2. Screening: the fixed-point model runs in the Reactive workflow. The decision routes the case; it does not itself transfer funds.
3. Authenticated callback: Reactive processing returns the decision to the origin escrow.
4. Settlement guard: the escrow tracks the case lifecycle and enforces the operator decision boundary.
5. Explicit action: a separate release or refund settles the testnet deposit.

## Interactive proof explorer

The local React explorer presents signal flow, recorded case replays, derived features and transaction receipts.

    cd experience
    npm ci
    npm run dev -- --host 127.0.0.1 --port 4176

Open http://127.0.0.1:4176/. See experience/README.md for routes and the read-only boundary. The explorer never submits a transaction. Recorded replay is historical; read-only current mode queries state but cannot write.

## Operator CLI boundary

The browser explorer requires no wallet and cannot write to either chain. CLI write and deployment operations require a locally configured Foundry account and contract/RPC settings. Copy .env.example to .env, set FOUNDRY_ACCOUNT to an account alias configured locally in Foundry, and fill the deployed contract addresses before using those commands. Never commit .env. Deployment and proof scripts can broadcast testnet transactions; they are not part of the read-only judge walkthrough.

## Synthetic examples

The examples/ fixtures are derived from the held-out TDD2022 benchmark split and are documented under CC BY 4.0. They are synthetic benchmark examples, not real household meter readings or customer evidence. See examples/README.md and docs/model-card.md.

## Judge evaluation

- [Judge guide](docs/JUDGE_GUIDE.md) — read-only product path, expected behavior and limitations.
- [Evidence summary](docs/EVIDENCE_SUMMARY.md) — deployed contracts, selected Base Sepolia / Reactive Lasna receipts and evidence boundaries.

These are sanitized local drafts. The public repository and publication approval are not configured yet. A public frontend deployment is optional judge-access convenience, not an explicit submission requirement.

## Run tests

    forge test
    python -m pip install -r requirements-dev.txt
    python -m unittest discover -s test -p "test_feature_encoder.py" -v
    cd experience
    npm ci
    npm run build

On 2026-11-23, a temporary clean Git repository was created from the proposed candidate file set, with Reactive Omni represented as the pinned Git submodule. A fresh git clone --recurse-submodules checked out Reactive Omni 3ade0dc and nested forge-std 620536f; the clean clone passed forge build, forge fmt --check, 29/29 Foundry tests, 6/6 Python feature tests under Python 3.12.13 (matching CI) and Python 3.13, clean npm ci (0 reported vulnerabilities), and npm run build. A root .gitattributes rule pins Solidity files to LF, so forge fmt --check also passes on Windows when machine-wide core.autocrlf=true. A separate browser rehearsal against that clean clone passed 31/31 checks across the problem-first landing, exception and routine paths, separate human review/release, evidence and chain proof, read-only current state, and 390px/360px mobile layouts. The read-only query returned RELEASED with 0 wei remaining at query time. The temporary clone used a local bare origin; it is not the actual public GitHub repository. GitHub Actions has not run because no remote is configured. No chain writes were performed.

## Final release-review rehearsal — 2026-11-24

A follow-up release-review candidate was cloned afresh with recursive Reactive Omni and forge-std submodules. From that clone, Foundry build/format passed, all 29 Solidity tests passed, all 6 Python feature tests passed under Python 3.12.13 (matching CI) and Python 3.13, clean npm ci completed with 0 reported vulnerabilities, and the Vite production build passed. On the UI-identical candidate, the updated builder-side browser judge path passed 34/34 checks; the final candidate changes only documentation after that browser run.  including the authorized meter-account wording, the account-signature/physical-meter-attestation boundary, and a direct Reactscan receipt link. The 14 Base Sepolia and 8 Reactive Lasna transaction hashes in the evidence summary all returned successful receipts. This remains a temporary local Git rehearsal, not a public GitHub release; GitHub Actions has not run and no chain writes were sent.

## Model and limitations

The compact fixed-point classifier's current synthetic benchmark reports a 15.9% false-positive rate and 42.8% recall on synthetic pattern 6. These are not production performance claims. No live utility field data or independent operational validation has been completed.

The flagged review note is minimal (the recorded note says "Approve"). Its hash proves commitment matching, not substantive investigation. The explorer labels synthetic profiles and testnet evidence accordingly.

## Scope and safety

- Testnet-only demonstration; no mainnet deployment.
- No automated payout; a separate authorized action is required.
- No claim of theft detection, billing accuracy, or production readiness.
- The browser explorer is a read-only evidence view, not the settlement-control surface.
- Private Operator records, raw proof artifacts, QA captures, local environment files and demo-production assets are excluded from the public source tree.

## Further reading

- docs/model-card.md
- examples/README.md
- experience/README.md
- docs/JUDGE_GUIDE.md
- docs/EVIDENCE_SUMMARY.md

Release status: local-only. No public GitHub push or hackathon submission has been made from this working copy. A public frontend deployment is optional judge-access convenience.
