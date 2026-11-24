# MeterSift — Public Evidence Summary

**Status:** Sanitized public evidence summary in [ShalyX/MeterSift](https://github.com/ShalyX/MeterSift), main commit `ab44bb937e352292ea2bd59d55a118bb647e7985`. The canonical claim registry and raw proof files remain private.

## Testnet environment

| Network | Chain ID | Role |
|---|---:|---|
| Base Sepolia | 84532 | Authorized profile submission and settlement escrow |
| Reactive Lasna | 5318007 | Event-triggered neural screening and callback request |

### Profile authenticity and feature provenance

The origin-chain transaction is signed by the configured authorized meter EOA. This proves which account submitted the profile commitment and ten fixed-point features; it does **not** prove that physical meter hardware generated the readings. No hardware-backed meter attestation is implemented. The origin contract does not independently recompute the ten features from the original 24-hour readings. The profile hash is a commitment to submitted input, not proof that the source data is truthful. The explorer uses synthetic profiles and displays derived features, not raw household telemetry.

## Deployed contracts

| Contract | Network | Address |
|---|---|---|
| Meter profile origin | Base Sepolia | [`0x2a365F40EA2b11941f5271b4c48B930C162c543D`](https://base-sepolia.blockscout.com/address/0x2a365F40EA2b11941f5271b4c48B930C162c543D) |
| Reactive meter guard | Reactive Lasna | [`0x07B7B5A3C82D0Fe4eA969307083B313a6aa5b89E`](https://lasna.reactscan.net/address/0x07B7B5A3C82D0Fe4eA969307083B313a6aa5b89E) |
| Settlement escrow | Base Sepolia | [`0x139B7fA07BA157e2775BF1D450cd4B0058400133`](https://base-sepolia.blockscout.com/address/0x139B7fA07BA157e2775BF1D450cd4B0058400133) |

## Deployment and configuration receipts

Base Sepolia hashes link to Blockscout; Reactive Lasna hashes link to Reactscan (chain ID 5318007). All 14 Base Sepolia transaction pages, both Base Sepolia contract pages and all 8 Reactive Lasna transaction pages were reachable from the build machine on 2026-11-24.

| Action | Network | Transaction |
|---|---|---|
| Deploy profile origin | Base Sepolia | [`0xac653c1186ac2d6c7da50c46681b6944f1dcd9958af8444c4190929902677b27`](https://base-sepolia.blockscout.com/tx/0xac653c1186ac2d6c7da50c46681b6944f1dcd9958af8444c4190929902677b27) |
| Deploy Reactive guard | Reactive Lasna · 5318007 | [0xd0a15f3dc918629f84e914de98a6f0ffbcc554f2552dc22e9a009b9cbc83f924](https://lasna.reactscan.net/tx/0xd0a15f3dc918629f84e914de98a6f0ffbcc554f2552dc22e9a009b9cbc83f924) |
| Deploy escrow | Base Sepolia | [`0x56bd4f28e8a5f9077a9947c62eaf8b8d2d41b1509f4c951cc49fc74ad23b30c5`](https://base-sepolia.blockscout.com/tx/0x56bd4f28e8a5f9077a9947c62eaf8b8d2d41b1509f4c951cc49fc74ad23b30c5) |
| Authorize meter | Base Sepolia | [`0x32b4b29b3d89c4b2641ca04896f23373ccec73640fc053ff24dc821fce772730`](https://base-sepolia.blockscout.com/tx/0x32b4b29b3d89c4b2641ca04896f23373ccec73640fc053ff24dc821fce772730) |
| Reserve Reactive execution fees | Reactive Lasna · 5318007 | [0x6bbd4d80e352d1ec3a68d378c04518ce0846b911a687eca0588143a8b1101caa](https://lasna.reactscan.net/tx/0x6bbd4d80e352d1ec3a68d378c04518ce0846b911a687eca0588143a8b1101caa) |
| Reserve callback fees | Base Sepolia | [`0xdb0e4c368311f8d96f9bd349baf40d4e6247666d2d85212977de10a2ef67cc43`](https://base-sepolia.blockscout.com/tx/0xdb0e4c368311f8d96f9bd349baf40d4e6247666d2d85212977de10a2ef67cc43) |
| Configure escrow | Reactive Lasna · 5318007 | [0xe8b24023092d2194f0d0ed038acc2179956d932a2c1909d82bcac140dd6e5236](https://lasna.reactscan.net/tx/0xe8b24023092d2194f0d0ed038acc2179956d932a2c1909d82bcac140dd6e5236) |
| Activate subscription | Reactive Lasna · 5318007 | [0xbae1e770a13aa59769365a21ca35715caaeaf1999c497b86e56037f700642400](https://lasna.reactscan.net/tx/0xbae1e770a13aa59769365a21ca35715caaeaf1999c497b86e56037f700642400) |

## Funded normal-profile path

The routine synthetic profile reached `RELEASE_READY`; the model/callback did not pay the meter. A separate operator transaction released 0.00001 test ETH.

| Step | Network | Transaction |
|---|---|---|
| Settlement deposit | Base Sepolia | [`0xf44d78831b9e0d5f53bfa8b414ff94fc321f5c057ab936b107a5c3776dfbf6f9`](https://base-sepolia.blockscout.com/tx/0xf44d78831b9e0d5f53bfa8b414ff94fc321f5c057ab936b107a5c3776dfbf6f9) |
| Authorized meter-account profile submission | Base Sepolia | [`0x41014834dce9fe105082dfbaf758cca3a455b67fd066851401a5eeea3c375bd3`](https://base-sepolia.blockscout.com/tx/0x41014834dce9fe105082dfbaf758cca3a455b67fd066851401a5eeea3c375bd3) |
| Neural screening | Reactive Lasna · 5318007 | [0xc3cc2dce22b8462c2e38483196e35a5f406e97ae42b9448f8a7df8bb2f3fc2dd](https://lasna.reactscan.net/tx/0xc3cc2dce22b8462c2e38483196e35a5f406e97ae42b9448f8a7df8bb2f3fc2dd) |
| Authenticated escrow callback | Base Sepolia | [`0x97c371c7f19b2011b845e2481d1b48211a954b8cda5e9ae462011df216902035`](https://base-sepolia.blockscout.com/tx/0x97c371c7f19b2011b845e2481d1b48211a954b8cda5e9ae462011df216902035) |
| Separate payout | Base Sepolia | [`0xe14438c52da0c1f23354fd22e0c60bd6a744a8f4125d04f14c41c0c03083f49a`](https://base-sepolia.blockscout.com/tx/0xe14438c52da0c1f23354fd22e0c60bd6a744a8f4125d04f14c41c0c03083f49a) |

**Recorded outcome:** `RELEASE_READY → RELEASED`; escrow amount remaining: 0 wei; meter account balance increase: 10,000,000,000,000 wei (0.00001 test ETH).

## Funded exception and recovery path

The flagged synthetic profile was deliberately used to demonstrate recovery from a paused subscription. This was a controlled test, not evidence of an ordinary production outage. The recovered callback routed the settlement to human review. Approval and payout were separate transactions.

| Step | Network | Transaction |
|---|---|---|
| Settlement deposit | Base Sepolia | [`0x40970cd9658fbe6abe10eb513c2996f4baabcd2519e5eb3c0502fd13f9813ac6`](https://base-sepolia.blockscout.com/tx/0x40970cd9658fbe6abe10eb513c2996f4baabcd2519e5eb3c0502fd13f9813ac6) |
| Pause subscription for recovery demo | Reactive Lasna · 5318007 | [0xf35e50c8b4705bb68ed884b57eaae0415fd44000990c6da5441e9e2e3fbf5e4f](https://lasna.reactscan.net/tx/0xf35e50c8b4705bb68ed884b57eaae0415fd44000990c6da5441e9e2e3fbf5e4f) |
| Initial authorized meter-account submission | Base Sepolia | [`0x1b1813af2853ee4bd3111b0556a3222426b5506cfc06a603767ce13d1de70711`](https://base-sepolia.blockscout.com/tx/0x1b1813af2853ee4bd3111b0556a3222426b5506cfc06a603767ce13d1de70711) |
| Resume subscription | Reactive Lasna · 5318007 | [0x40901da84c5c874bdef1e1a9060da699a6a2181af2929257e8a4179cadf8cfba](https://lasna.reactscan.net/tx/0x40901da84c5c874bdef1e1a9060da699a6a2181af2929257e8a4179cadf8cfba) |
| Authorized replay of stored submission | Base Sepolia | [`0xaf75b1256e547cc32f407c2b6772d4d184dff7bb7060635212eac286ad567c89`](https://base-sepolia.blockscout.com/tx/0xaf75b1256e547cc32f407c2b6772d4d184dff7bb7060635212eac286ad567c89) |
| Neural screening | Reactive Lasna · 5318007 | [0xf22d59e6159fab5f27a284bd8bd0aae8475d329adde08dec25204a0ebea72b9e](https://lasna.reactscan.net/tx/0xf22d59e6159fab5f27a284bd8bd0aae8475d329adde08dec25204a0ebea72b9e) |
| Authenticated escrow callback | Base Sepolia | [`0x477e1ee2556a8cc02d51e5ad04385584d5a587d64d9dd7ddfe92cc46322d7000`](https://base-sepolia.blockscout.com/tx/0x477e1ee2556a8cc02d51e5ad04385584d5a587d64d9dd7ddfe92cc46322d7000) |
| Human approval with evidence commitment | Base Sepolia | [`0x3dca5e647beb937179012abf76e2056a2290ca09ba96e48f6e3d87cbb03cba5e`](https://base-sepolia.blockscout.com/tx/0x3dca5e647beb937179012abf76e2056a2290ca09ba96e48f6e3d87cbb03cba5e) |
| Separate payout | Base Sepolia | [`0x094d5cf03a055ae2d020502e5db19db2fd870cd10ba52c65173f8c748f8411a2`](https://base-sepolia.blockscout.com/tx/0x094d5cf03a055ae2d020502e5db19db2fd870cd10ba52c65173f8c748f8411a2) |

**Recorded outcome:** `PENDING → HOLD_FOR_REVIEW → REVIEW_APPROVED → RELEASED`; escrow amount remaining: 0 wei; meter account balance increase: 10,000,000,000,000 wei (0.00001 test ETH).

Evidence commitment: `0x45dfb65e9caabc346b88bb0fdcda4863413ce52f67107a6939455f87cb738b06`.

The committed review record is synthetic and minimal. Its note is only "Approve". The hash proves commitment matching and association with the settlement; it does not prove investigative quality, source-data truth, or independent corroboration. The raw review file is not included in this summary.

## Principal protection evidence

The final clean-clone Foundry run on 2026-11-24 passed 29/29 Solidity tests, including these four escrow-safety tests:

- `testProxyFeesCannotSpendPrincipal`
- `testDecisionCannotTakeFundingFromAnotherMeter`
- `testDuplicateDecisionCannotDowngradeHold`
- `testIndependentSequenceCanArriveOutOfOrder`

This verifies the fee-surplus guard and settlement binding in the local test harness. It is not a separate live testnet fee-drain attack.

## Model evidence and limitations

The model was evaluated on held-out synthetic TDD2022 data:

| Metric | Result |
|---|---:|
| F1 | 85.81% |
| Precision | 81.74% |
| Recall | 90.30% |
| False-positive rate | 15.93% |
| Recall on synthetic Theft6 pattern | 42.80% |

These metrics do not establish field performance or real theft detection. The synthetic dataset is not a representative sample of community microgrids. A model flag is a screening signal, not proof of theft or customer wrongdoing. The current uncertainty margin and feature-range rules are provisional and are not calibrated to an operator's review budget.

## Proof package boundary

The private proof bundle records 25 transaction steps. The browser explorer surfaces ten receipt rows. This public derivative intentionally omits account-funding transactions, wallet details, raw meter profiles, raw review JSON, private logs and local environment files.

Both funded cases are testnet demonstrations using synthetic profiles and test ETH. Both final settlements read `RELEASED`; remaining escrow principal, Reactive debt and callback debt were zero at the recorded verification. No mainnet deployment, production utility integration, live meter feed, customer adoption, field validation or automated payout is claimed.
## Public repository, CI and judge-path verification - 2026-11-24

Public repository: [ShalyX/MeterSift](https://github.com/ShalyX/MeterSift). Verified main commit: `ab44bb937e352292ea2bd59d55a118bb647e7985`. The repository contains the approved public file set and pins Reactive Omni 3ade0dcf1d27e67e5783ef807e73a1b9e0c0cce8 plus nested forge-std 620536fa5277db4e3fd46772d5cbc1ea0696fb43.

GitHub Actions main-branch run [45309492652](https://github.com/ShalyX/MeterSift/actions/runs/45309492652) passed every job step on the verified main commit:
- recursive checkout of both submodules;
- Foundry build and Solidity formatting;
- 29/29 Solidity tests;
- 6/6 Python feature-encoder tests on the workflow's Python 3.12 runtime;
- Node setup, npm install and Vite production build.

A separate fresh recursive clone of the exact public main commit passed a builder-side browser judge-path rehearsal **35/35**. Checks covered the problem-first landing, authorized meter-account framing, Reactive inference and callback explanation, exception and routine paths, distinct review/approval/release states, evidence commitment and minimal-note disclosure, ten feature values, transaction receipt links, read-only current state, and 390px/360px mobile layouts. A point-in-time read-only Base Sepolia query returned RELEASED with 0 wei remaining.

The receipt audit recorded all 14 Base Sepolia and 8 Reactive Lasna transaction hashes in this summary as successful (status 0x1); the browser and CI rehearsals sent no transactions. These results establish reproducibility and builder-side judge-path readiness, not an independent external judge review, customer adoption, field validation, or production performance.

The public repository is available. The explorer is not deployed to a public frontend URL. This summary documents testnet evidence and builder-side reproducibility; it is not an independent external judge review or field validation.
