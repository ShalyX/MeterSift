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
- [Brand assets](docs/BRAND_ASSETS.md) — primary MeterSift mark, wordmark, favicon, app icon and social avatar.

These judge-facing documents are published in this public repository. Repository: https://github.com/ShalyX/MeterSift. The validated product-code baseline is `ab44bb937e352292ea2bd59d55a118bb647e7985`; current `main` additionally includes the documentation-only release reconciliation merged in PR #2 (`02ce0353bd720d61fbc9e0b09b8a8371e681dc5b`). The latest verified main-branch CI run before this licensing proposal is [45502368421](https://github.com/ShalyX/MeterSift/actions/runs/45502368421), which passed on that main commit. The read-only explorer is source-published but is not currently deployed to a public frontend URL; a frontend deployment is optional judge-access convenience, not an explicit submission requirement.

## Run tests

    forge test
    python -m pip install -r requirements-dev.txt
    python -m unittest discover -s test -p "test_feature_encoder.py" -v
    cd experience
    npm ci
    npm run build

## Public release and reproducibility - 2026-11-25

The public repository is [ShalyX/MeterSift](https://github.com/ShalyX/MeterSift). The validated product-code baseline is `ab44bb937e352292ea2bd59d55a118bb647e7985`; the current `main` branch additionally includes the documentation-only release reconciliation merged in PR #2 (`02ce0353bd720d61fbc9e0b09b8a8371e681dc5b`). A fresh recursive clone checks out the pinned Reactive Omni and nested forge-std submodules. GitHub Actions run [45502368421](https://github.com/ShalyX/MeterSift/actions/runs/45502368421) on current main passed every step: Foundry build, Solidity formatting, 29/29 Solidity tests, 6/6 Python feature tests on Python 3.12, clean npm installation and the Vite production build. The clean local npm install reported 0 vulnerabilities.

A builder-side browser judge-path rehearsal against a fresh recursive clone of the validated product-code baseline passed **35/35 checks** across the problem-first landing, payer/payee clarity, Reactive integration explanation, flagged and routine settlement paths, separate human approval/release, evidence drawer and commitment, ten features, transaction receipts, read-only current state, and 390px/360px mobile layouts. The point-in-time read-only Base Sepolia query returned RELEASED with 0 wei remaining. This is a builder-side simulation, not an independent external judge review. No chain writes were performed during release QA.

## Model and limitations

The compact fixed-point classifier's current synthetic benchmark reports a 15.9% false-positive rate and 42.8% recall on synthetic pattern 6. These are not production performance claims. No live utility field data or independent operational validation has been completed.

The flagged review note is minimal (the recorded note says "Approve"). Its hash proves commitment matching, not substantive investigation. The explorer labels synthetic profiles and testnet evidence accordingly.

## Scope and safety

- Testnet-only demonstration; no mainnet deployment.
- No automated payout; a separate authorized action is required.
- No claim of theft detection, billing accuracy, or production readiness.
- The browser explorer is a read-only evidence view, not the settlement-control surface.
- Private Operator records, raw proof artifacts, QA captures, local environment files and demo-production assets are excluded from the public source tree.

## License and third-party materials

Original MeterSift project code and documentation in this repository are licensed under the MIT License; see [LICENSE](LICENSE). This license does not relicense third-party components. The pinned Reactive Omni submodule and its nested dependencies remain governed by their own license terms. The TDD2022 dataset and the derived example fixtures retain their CC BY 4.0 terms and attribution, as documented in [the model card](docs/model-card.md) and [example notes](examples/README.md).

## Further reading

- docs/model-card.md
- examples/README.md
- experience/README.md
- docs/JUDGE_GUIDE.md
- docs/EVIDENCE_SUMMARY.md

Release status: the public GitHub repository is published at https://github.com/ShalyX/MeterSift. The read-only explorer is not deployed to a public frontend URL; a frontend deployment is optional judge-access convenience.
