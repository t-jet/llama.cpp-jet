# Part 143: TP-39-03 driver review rework

Date: 2026-07-17
Status: READY FOR ARCHITECT RE-REVIEW
Scope: Part 142 findings F142-01 through F142-03

## Result

The canonical driver now uses the guarded proof contract twice. A bootstrap
proof expands the discovered exact row through its current owner links. The
driver validates that result, derives the checkpoint ID from its ordered rows,
then sends both exact and checkpoint IDs in the binding proof request.

After successful apply, the driver validates the returned terminal proof,
including session/run identity, ordered production records, generation chain,
terminal exact-cold/checkpoint-evicted state, retained topology, and consumed
apply. It retrieves the proof with the terminal HMAC and requires identical
JSON bytes. Saved apply and retrieval artifacts redact the terminal HMAC; log
checks cover snapshot, proof, and terminal authentication values.

The second-owner negative now adds a distinct eligible exact row with another
nonzero payload and owner, plus its matching empty cold set.

## Evidence

PowerShell parser validation passed with zero errors. The preflight-free
`MetricValidationSelfTest` passed under PowerShell 7 and Windows PowerShell 5.
No model, build, coverage, product, fixture, seam, test-plan, or threshold work
ran.

## Next gate

Fresh Architect re-review of Part 142 findings. Canonical TP-39-03 and coverage
remain blocked until that review passes.
