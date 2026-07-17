# Stage 39 D39-QA-04 fixes

Date: 2026-07-17
Status: ARCHITECT REVIEW PASS
Source: `test-report-20260717-04-developer-review.md`

## Plan

1. Serialize terminal topology deltas as signed values.
2. Accept source hot-LRU removal while retaining its entry, branch, owner, and
   exact cold descriptor.
3. Account for the remaining resident bytes through one referenced entry that
   production excludes from pressure.
4. Add controller and pure regressions, then run only the focused controller
   target and PowerShell parser/self-tests.

## Correction

`stage39_finalize_prepared_locked()` now computes entry, node, LRU, and pruning
deltas as `int64_t`. The valid source transition is encoded as membership `0`
and delta `-1`, not `UINT64_MAX`.

The terminal seam also reports resident accounting. It lists entries with live
slot references and resident bytes, the total resident bytes, and the applied
hot budget. `Assert-Tp3903TerminalProofS39` requires one referenced entry with
a different owner from the released source. Its bytes must equal the complete
remaining resident total, and that total must exceed the lowered budget.

The driver still requires the source entry and branch, exact owner links, one
exact cold descriptor and file, matching descriptor/file byte maps, zero
entry/node/pruning delta, an evicted checkpoint tombstone, and no staging or
quarantine bytes. Pure negatives reject membership `1`, delta `0`, the wrapped
unsigned value, a source-owned referenced row, and unexplained resident bytes.

## Evidence

| Check | Result |
| --- | --- |
| Focused seam-ON `test-cache-controller` build | PASS, exit 0 |
| `test-cache-controller.exe` | PASS, including `test_stage39_live_pressure_tp39_03_signed_lru_delta` |
| PowerShell 7 parser API | PASS, zero errors |
| Windows PowerShell 5 parser API | PASS, zero errors |
| PowerShell 7 pure self-test | PASS, exit 0 |
| Windows PowerShell 5 pure self-test | PASS, exit 0 |

No model, coverage, fixture, plan, threshold, production eviction-policy, or
product-retention behavior changed. Architect Part 162 records PASS. A
canonical TP-39-03 rerun still requires a fresh Manager gate, and coverage
remains closed until that node passes.

## Architect review

Part 162 verifies signed JSON delta semantics, hot-LRU membership `0/-1`,
retained source topology and cold evidence, active-reference resident-byte
reconciliation, negative tests, and seam-only scope. Verdict: PASS.
