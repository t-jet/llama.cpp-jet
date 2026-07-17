# Stage 39 report 20260713-01 fixes

Date: 2026-07-13
Status: PARTIAL

## Correction implementation

D39-EXEC-02 authorized the guarded live pressure seam and canonical coverage
merge fix. Implementation Part 43 records changed files and focused evidence.

Compile/runtime guards, idle dispatch serialization, exact separate-set
validation, setup-only mutation, one-shot state, normal `tx_update()` handoff,
absolute `whoami.exe` merge tail, and immediate nonzero exit handling are
implemented. ON controller/server builds, the Release controller suite, OFF
server-context build, startup rejection, script parsers, and literal exit-23
fixture pass.

## Open correction

The route contract requires exact payload and owner IDs on its first valid POST,
but no approved pre-mutation source exposes those complete sets. Metrics omit
the IDs, and logs cannot prove completeness. Developer did not add another
route or infer IDs. Route success tests, canonical live TP-39-02 through
TP-39-04 scenarios, and full coverage reruns remain open.

Next gate: fresh Architect implementation review, then Manager design
disposition for identity discovery.

## D39-EXEC-03 guarded discovery rework

Implementation Part 49 records the authorized rework. The guarded route now
supports non-consuming discovery and exact snapshot-bound apply. Production hot
and cold selectors are shared with the seam, mixed checkpoint inventory is
covered, and responses recompute separate before/after sets.

ON controller/server builds, the OFF server-context build, the Release
controller suite, and PowerShell 5/7 parser self-tests pass. Model-backed route
execution, named Python route tests, complete generation mutation-matrix
evidence, and canonical coverage remain open. Status stays PARTIAL.

## Part 50 rework evidence

Implementation Part 51 records the next correction pass. Strict setup arrays,
rollback without generation rewind, the OS CSPRNG, the missing controller
cases, and all 13 named Python route cases are implemented. The ON Release build
passes, the model-backed route suite passes 13 tests, and the immediate final
controller rerun exits zero with its full success footer.

Status remains PARTIAL. Row-specific TP-39-02/03/04 driver assertions, the
guarded driver smoke, canonical PowerShell 5/7 coverage, and fresh Architect
review of complete generation ownership remain open.

## Part 52 open-finding rework

Implementation Part 53 records the F39-GDIR-01/03/04 changes. Generation now
covers the reviewed cleanup, prune, slot-reference, recovery, and rollback
paths. Route tests use real integrity, checkpoint, concurrency, non-loopback,
and terminal post-pressure conditions. Driver assertions now inspect exact
row-specific metrics, logs, victims, files, accounting, topology, and pair
state.

The final retention fix and strengthened assertions have not been rebuilt or
run. Status stays PARTIAL. Coverage remains QA-owned and was not run here.

## Part 58 rework

Implementation Part 59 corrects the cleanup filename, captures pre-mutation
snapshots for all three named generation tests, and records distinct committed
reconstruction and replay-cleanup generations. Controller, route, and
PowerShell 5/7 self-tests pass.

TP-39-04 passes with exact `evicted/oversized_both`, zero transaction delta,
and measured startup/lowered-budget proof. TP-39-03 now enforces its approved
fit-hot, aggregate-hot, cold-occupancy, and zero-victim preconditions. Its one
bounded model run found an eligible cold victim and was rejected with
`invalid_tp39_03_setup`. Status remains PARTIAL pending Manager disposition.

## D39-EXEC-05 TP-39-03 implementation

Implementation Part 64 records guarded checkpoint owner reassignment, mixed-kind
eviction integrity, bounded response evidence, literal MTP driver work, and
focused verification. ON/OFF builds, full controller, 14 route tests, and
PowerShell 5/7 self-tests pass.

Fresh four-request measurement completed in 12 minutes 14 seconds but could not
reach valid discovery. Exact prompts render to 3,631 and 3,632 tokens. Their
7,263-token aggregate exceeds the fixed 4,096-token cache limit, so production
retained one entry and removed the prior cold owner. Discovery returned
`inventory_integrity_error`; no apply was sent. Status remains PARTIAL pending
Architect correction. This blocker is not TP-39-03 PASS.

## D39-EXEC-06 TP-39-03 context execution

Implementation Part 67 records the context-8192 driver correction, PowerShell
5/7 self-test PASS, and fresh seam-ON measurement. The four requests completed
in 360.782 seconds with exact token counts 3,631 and 3,632, total 7,263, margin
929, peak RSS 5,397,516,288 bytes, and real 50.251 MiB checkpoints.

Discovery retained two distinct hot exact owners but returned empty candidate
arrays for both cold sets; the cold root stayed empty. The driver stopped at
`SKIP-preflight-compatible-checkpoint-set` before apply. Canonical execution
was not run. Status remains PARTIAL pending Architect reachability review.
