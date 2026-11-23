# MeterSift Explorer

The React explorer is a read-only presentation and evidence companion to the CLI settlement-control workflow. It does not sign transactions, approve cases, release escrow, refund deposits, or mutate funded testnet proofs.

Run locally from the experience directory:
    npm ci
    npm run dev -- --host 127.0.0.1 --port 4176

Open http://127.0.0.1:4176/
- / is the product story.
- /explore?case=normal is the routine recorded case.
- /explore?case=flagged is the exception and human-review case.
- /proof shows recorded transaction receipts and evidence boundaries.

Recorded replay is historical. Read-only current mode queries chain state but cannot write. The CLI remains the settlement-control surface.

Build with: npm run build

The explorer presents ten derived fixed-point features from synthetic profiles, not the original 24-hour reading series. Testnet only; no live utility data or automated payout. QA captures and demo-production files under experience/qa are local-only and excluded from the public repository.
