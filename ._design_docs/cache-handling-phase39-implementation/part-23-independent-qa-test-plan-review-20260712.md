# Part 23: independent QA test-plan review

Date: 2026-07-12
Verdict: REWORK

## Scope

Reviewed test-plan Part 43, the shared test-plan entry, the script README, and
`stage39-two-layer-pressure.ps1` against approved design TP-39-01 through
TP-39-15 and implementation Parts 20-22. This was a static review. No build,
focused test binary, model-backed workload, or full suite was run.

## Result

Part 43 is generic and maps all 15 approved rows without stale session data.
It preserves the clean-build rule, 80% changed-line coverage gate, fixed metric
taxonomy, topology safeguards, exact capacity evidence, and per-session report
boundary. Two automation gaps block test-plan approval.

| ID | Severity | Finding | Required correction |
| --- | --- | --- | --- |
| F39-QAPR-01 | BLOCKING | The Stage 39 driver does not write `metric-delta.txt`, `cold-files-before.csv`, or `state.json`, although Part 43 names them as per-row evidence and requires byte, file, eviction, entry, branch, and pruning reconciliation. Its summary contains only series and file counts. A QA run would need ad hoc reconstruction and cannot verify the required evidence schema from driver output. | Capture the before inventory and a structured before/after state containing the required gauges and counters. Produce a deterministic metric delta artifact, or revise the plan and README to name an equivalent structured artifact that the driver actually writes. |
| F39-QAPR-02 | BLOCKING | The `standard` scenario accepts any Stage 39 decision series and any transaction series. A rollback, error, bypass, or eviction-only run can therefore emit `PASS` without `retained_cold/cold_room` or `retained_cold/cold_room_made`, successful restore, and zero payload-eviction/pruning delta. The README calls this a scenario guard, but the guard does not prove the standard scenario it names. | Make `standard` assert the expected successful decision and committed transaction tuple, perform a restore, and reject forbidden eviction and pruning deltas. If one scenario cannot cover cold-room and cold-room-made deterministically, split them into explicit scenarios. Keep Part 43's row-level manual reconciliation requirement. |

## Coverage assessment

The plan covers positive, negative, fault, restart, concurrency, legacy,
production-path, boundary, enum, and cardinality behavior. TP-39-14 names every
mutation position and restart requirement. TP-39-15 retains both focused enum
mapping and live scrape proof. The clean Release build and changed-line coverage
threshold are explicit. No TP row needs removal or weaker wording.

The script remains a scaffold for live pressure. It need not pass focused fault
rows, but it must produce internally consistent evidence for the live scenario
guards it claims. Missing fixtures or seams remain `BLOCKED`, not `PASS`.

## Static verification

- PowerShell parser: PASS.
- Part 43: 101 lines, LF, ASCII, no run-specific report identity.
- Stage 39 driver: 92 lines, LF, ASCII.
- Stage 39 README section: generic paths and uppercase verdict tokens.
- No dashboard file was reviewed or changed.
- `git diff --check` and final hygiene checks remain required after correction.

## Gate

REWORK. Independent QA test-plan gate stays closed until F39-QAPR-01 and
F39-QAPR-02 are corrected and a fresh QA reviewer records PASS. Do not start the
full Stage 39 execution from this plan revision.
