# MeterSift — Judge Guide

**Status:** Local draft. The public repository and deployed application URL are not configured; this guide has not been published or allowlisted.

## The problem

Consider a community energy operator settling payment to a local energy supplier for electricity delivered. The meter profile used to calculate that payment does not reconcile. Paying against questionable data risks overpaying; holding the settlement risks delaying money legitimately owed. Repeating that decision across hundreds of meters becomes difficult to manage consistently.

MeterSift screens signed daily meter profiles and routes suspicious or uncertain cases to evidence-backed human review. The neural model runs inside Reactive; it does not decide guilt or release funds. An authorized operator controls the separate release or refund.

## What to evaluate

- **Primary user:** community microgrid and peer-to-peer energy settlement operators.
- **Core workflow:** signed profile → ten derived features → neural screening inside Reactive → authenticated callback → release-ready or hold-for-review → separate human-controlled settlement action.
- **Differentiator:** Reactive performs the event-triggered inference and callback; a held case requires an authorized human decision and a separate payout.
- **Product boundary:** the Python CLI is the settlement-control surface. The React explorer is a read-only presentation and evidence companion.

## Start the read-only explorer

Requirements: Node.js and npm compatible with the Vite 7 toolchain. No wallet, account, signing key, or API credential is needed for the browser explorer.

From the repository root:

```powershell
cd experience
npm ci
npm run dev -- --host 127.0.0.1 --port 4176
```

Open `http://127.0.0.1:4176/`.

The public repository URL is not yet configured. Once a repository is published, clone it with its submodules enabled; the Foundry tests depend on the Reactive library submodule.

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

- `src/MeterProfileOrigin.sol` — signed profile submission.
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
- The deliberate subscription pause was a controlled recovery demonstration, not evidence of an ordinary production outage.
- No production utility integration, field performance, customer adoption, automated payout or mainnet deployment is claimed.

## Evaluation status

On 2026-11-23, the builder-side end-to-end browser rehearsal was repeated from a fresh temporary Git clone with recursive Reactive Omni and forge-std submodules and passed 30/30 checks. It covered the problem-first landing, flagged and routine paths, separate hold/approval/release stages, ten derived features, the evidence drawer, ten transaction receipt rows, read-only current-state RPC and 390px/360px mobile layouts. The read-only Base Sepolia query returned RELEASED with 0 wei remaining at query time. This remains a builder-side simulation, not an independent external judge review. The temporary clone used a local bare origin; the actual application remains local-only, no public repository or deployment is configured, GitHub Actions has not run, and the demo film remains paused. This guide is a prepared draft, not a claim that MeterSift is submission-ready.
