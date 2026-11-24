# MeterSift — Judge Guide

**Status:** Published judge guide for [ShalyX/MeterSift](https://github.com/ShalyX/MeterSift). The validated product-code baseline is `ab44bb937e352292ea2bd59d55a118bb647e7985`; current `main` also includes the documentation-only release reconciliation merged in PR #2 (`02ce0353bd720d61fbc9e0b09b8a8371e681dc5b`). Original MeterSift project code is licensed under MIT; third-party components retain their own terms (see the repository [LICENSE](../LICENSE)). The explorer is run locally from the repository; no public frontend deployment is currently provided. A public frontend URL is optional judge-access convenience.

## The problem

Consider a community energy operator settling payment to a local energy supplier for electricity delivered. The meter profile used to calculate that payment does not reconcile. Paying against questionable data risks overpaying; holding the settlement risks delaying money legitimately owed. Repeating that decision across hundreds of meters becomes difficult to manage consistently.

MeterSift screens daily meter-profile submissions from authorized meter accounts and routes suspicious or uncertain cases to evidence-backed human review. The neural model runs inside Reactive; it does not decide guilt or release funds. An authorized operator controls the separate release or refund.

## What to evaluate

- **Primary user:** community microgrid and peer-to-peer energy settlement operators.
- **Core workflow:** authorized meter-account submission of a profile hash → ten derived features → neural screening inside Reactive → authenticated callback → release-ready or hold-for-review → separate human-controlled settlement action.
- **Differentiator:** Reactive performs the event-triggered inference and callback; a held case requires an authorized human decision and a separate payout.
- **Product boundary:** the Python CLI is the settlement-control surface. The React explorer is a read-only presentation and evidence companion.

## Reactive Meets AI - judging map

Reactive Network's [official buildathon brief](https://blog.reactive.network/reactive-omni-buildathon-thirty-days-to-find-out-what-one-second-buys/) says AI must be part of the running system, not merely a tool used to write the project. MeterSift's neural inference executes in `ReactiveMeterGuard.react()` after the origin event is observed; the result determines the authenticated escrow callback and settlement route.

The organizer lists four equally weighted criteria:

| Criterion | What MeterSift demonstrates | Evidence and boundary |
|---|---|---|
| **Execution** | Two funded testnet paths complete the origin event -> Reactive inference -> authenticated callback -> separate settlement action loop. | The evidence summary links the deployments and transaction sequence. All 22 listed Base Sepolia and Reactive Lasna transaction receipts returned successful status in the 2026-11-24 read-only audit. |
| **Integration** | The neural model is executed by the Reactive contract itself; its output changes escrow state to `RELEASE_READY` or `HOLD_FOR_REVIEW`. | Inspect `src/ReactiveMeterGuard.sol` and `src/SettlementEscrow.sol`. Reactive is not a decorative notification layer or an off-chain model API. |
| **Usefulness** | The workflow gives a community-energy settlement operator a consistent screening and human-review path before funds are released. | This is a prototype use case, not a field-validated utility deployment. The benchmark and funded examples are synthetic/testnet only. |
| **Craft** | Reproducible contracts and feature encoder, explicit model card, linked chain evidence, a read-only explorer and documented limitations. | 29/29 Solidity tests, 6/6 feature tests under Python 3.12.13 and 3.13, clean npm install and production build. Builder-side browser rehearsal is not independent judging. |

**Recommended evaluation order:** inspect the exception path first to see the model-triggered hold and human gate; verify the Reactive inference and callback receipts; inspect the routine path; then review the model card and limitations. Do not infer physical-meter attestation, real-world theft detection, measured end-to-end latency or production utility adoption from this prototype.

## Start the read-only explorer

Requirements: Node.js and npm compatible with the Vite 7 toolchain. No wallet, account, signing key, or API credential is needed for the browser explorer.

From the repository root:

```powershell
cd experience
npm ci
npm run dev -- --host 127.0.0.1 --port 4176
```

Open `http://127.0.0.1:4176/`.

Public repository: https://github.com/ShalyX/MeterSift. Clone the published main branch with recursive submodules: `git clone --recurse-submodules https://github.com/ShalyX/MeterSift.git`. This checks out the pinned Reactive Omni and nested forge-std dependencies required by Foundry.

## Suggested evaluation path

1. **Read the problem and promise** on the home page. The example is an illustrative settlement scenario, not a claimed customer incident.
2. **Open Explore → Exception profile.** The default recorded timeline is historical testnet proof, not a live transaction.
3. **Play or step through the exception path:** the recorded case moves from pending to hold-for-review, then to review-approved, then released through a separate transaction.
4. **Inspect the ten features.** They are derived fixed-point features from synthetic profiles and same-weekday baselines. They are not the original 24-hour meter readings.
5. **Open the evidence drawer and Chain proof.** Inspect the settlement identifiers, contract addresses and transaction references in [the evidence summary](EVIDENCE_SUMMARY.md).
6. **Switch to the routine profile.** It reaches release-ready after the Reactive callback; a separate operator transaction produced the recorded payout.
7. **Optionally query current state.** The explorer's current mode makes a read-only Base Sepolia RPC query. If the RPC is unavailable, it displays `UNAVAILABLE`; it does not present cached history as live state.

## What the explorer does not do

- It does not sign or submit transactions.
- It does not fund settlements or authorize reviewers.
- It does not release or refund escrow.
- Recorded replay is historical; it is not a simulation of a new live transaction.
- Current mode reads the escrow state only. It is not a live meter feed.

No reset is needed. Reload the page, switch cases, or restart recorded playback. These actions do not alter the funded testnet proofs.

## Source-level inspection

Relevant implementation:

- `src/MeterProfileOrigin.sol` — authorized meter-account profile submission.
- `src/ReactiveMeterGuard.sol` — Reactive event handling and callback request.
- `src/MeterSettlementModel.sol` — fixed-point neural screening.
- `src/SettlementEscrow.sol` — principal protection, review and separate release/refund.
- `script/operator_flow.py` — CLI settlement-control workflow.
- `test/SettlementEscrow.t.sol` — local escrow safety tests.
- `docs/model-card.md` — dataset, evaluation and model limitations.

The read-only browser explorer is not a replacement for the CLI control surface. CLI write operations require a properly configured authorized environment and are not part of this walkthrough.

## Evidence and limitations

See [EVIDENCE_SUMMARY.md](EVIDENCE_SUMMARY.md) for the deployed contracts, selected transaction receipts and claim boundaries.

- Both demonstrated profiles are synthetic; both payouts used Base Sepolia test ETH.
- The model benchmark uses synthetic TDD2022 data. It is not field validation.
- Held-out results include an F1 of 85.81%, a 15.93% false-positive rate and 42.80% recall on synthetic Theft6.
- The flagged review record is minimal. Its hash proves commitment matching, not investigative quality or independent corroboration.
- The origin transaction is signed by the configured authorized meter EOA. This authenticates the submitting account, not physical meter hardware or the truth of the underlying readings. The origin contract does not independently recompute the ten features from raw 24-hour readings.
- The deliberate subscription pause was a controlled recovery demonstration, not evidence of an ordinary production outage.
- No production utility integration, field performance, customer adoption, automated payout or mainnet deployment is claimed.

## Evaluation status

The validated product-code baseline `ab44bb937e352292ea2bd59d55a118bb647e7985` was cloned afresh with recursive submodules on 2026-11-24. The subsequent documentation-only release reconciliation was merged to current `main` as PR #2 (`02ce0353bd720d61fbc9e0b09b8a8371e681dc5b`). GitHub Actions run [45502368421](https://github.com/ShalyX/MeterSift/actions/runs/45502368421) passed all steps on that current main commit: Foundry build, Solidity formatting, 29/29 Solidity tests, 6/6 Python feature tests on Python 3.12, npm installation and the Vite production build. A clean local npm ci also reported 0 vulnerabilities.

A builder-side browser judge-path rehearsal against a fresh recursive clone of the validated product-code baseline passed **35/35 checks**. It covered the problem-first landing and payer/payee framing; the Reactive react() and authenticated callback explanation; the funded exception and routine cases; distinct HOLD_FOR_REVIEW, REVIEW_APPROVED and RELEASED states; honest disclosure of the minimal "Approve" review note and account-signature boundary; ten derived features; ten receipt rows with direct Reactscan/Blockscout links; read-only current state; and 390px/360px mobile layouts without horizontal overflow. The point-in-time read-only Base Sepolia query returned RELEASED with 0 wei remaining. No chain writes were performed.

This remains builder-side validation, not an independent external judge review. The public repository is available, but there is no public frontend deployment. The explorer is read-only and runs locally; no wallet or transaction-write access is required.
