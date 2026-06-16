# Stage 15 design: long-running tests -- Part 3

Source: [../cache-handling-phase15-design.md](../cache-handling-phase15-design.md)

## Scope of long-running tests

The long-running rows are the Stage 12 design rows S12-L01,
S12-L02, and S12-L03 from
[part-02 of the Stage 12 design](../cache-handling-phase12-design/part-02-stress-scenarios-and-config-matrix.md#long-run-checks).
Stage 15 re-runs them on the current tree, under the same
configuration matrix, and treats the per-row wall-clock and the
counter cleanliness as the entry conditions to the bug-fix loop.

## Per-row time cap

| Row | Source row | Required duration | Cap action when wall-clock exceeds cap |
| --- | --- | --- | --- |
| L01 | S12-L01 production-like hybrid long run | 6 hours | Record the actual wall-clock seconds, mark `BLOCKED-time-budget` if the row did not complete a full 6 hours, and record the partial state in the evidence summary. |
| L02 | S12-L02 reproducibility run | 30 minutes | Same rule. A 30-min cap is short enough that the row should always complete. |
| L03 | S12-L03 legacy control long run | 2 hours | Same rule. |

Cap-exit is recorded as `BLOCKED-time-budget`, not as `FAIL`. A
cap-exit row is not a product bug on its own; the QA records the
reason (e.g., host reboot, fixture fallback, operator stop) and
the row goes to the bug-fix loop only if the cap-exit coincides
with a counter anomaly, a crash, or a public-surface regression.

## 1000 hits+misses threshold rule

Per the manager improvement memory line 188 (`longrun 1000
threshold does not apply structurally`), the 1000 hits-plus-misses
threshold that applies to 30-min stress rows does not apply
structurally to the long-run rows. The QA classifies long-run
rows on intent:

- Cache counters are clean: `evictions >= 0`,
  `restore_failures == 0`,
  `descriptor_validation_failures == 0`, no `pairing_violations`.
- Metric counters are monotonic where expected and never reset
  while the process stays alive.
- Process working set growth after warmup is below 10% across
  the run (L01) or below the recorded equivalent threshold for
  shorter rows.
- Windows handle or file descriptor growth after warmup is below
  5%.
- Cold-store file count after cooldown has no orphan growth
  outside expected resident cold descriptors.
- Latency drift on p95 restore or generation is below 20% after
  warmup without a recorded workload cause.
- Server is alive at the end of the row, with no hang and no
  unhandled exception.

The verdict is `PASS-meets-intent` when all of the above hold, even
if `hits + misses` is well below 1000. The QA records the actual
`hits + misses` value in the per-row evidence summary so future
audits can see the structural reason. A `PASS-meets-intent` row
still satisfies the closure contract; it does not become
`BLOCKED` for the threshold reason.

The 30-min stress rows S01..S08 still use the literal 1000 number
because they are sized for high request rates. A stress row that
ends under 1000 hits+misses is `BLOCKED-stress-low-throughput`,
not `PASS-meets-intent`.

## Driver script and sequential execution

Each long-run row is a single PowerShell script under
`._design_docs/cache-handling-test-scripts/longrun/`:

- `longrun_s12_l01_6h_hybrid_stability.ps1`
- `longrun_s12_l02_30m_legacy_comparison.ps1`
- `longrun_s12_l03_2h_mixed_workload.ps1`

The driver takes the configuration matrix from the Stage 12 design
Part 2. The driver writes its evidence under
`._design_docs/.test_reports/longrun-stage15-YYYYMMDD/` per D5.

The QA runs the rows sequentially, not in parallel, because each
row holds a model file open, reserves memory, and binds a port. A
parallel run would either swap or fail to bind. The wall-clock
total is the sum of the three rows: 8.5 hours in the no-cap
case. The QA is allowed to pause the run overnight, but a paused
row is recorded as `BLOCKED-time-budget` with the actual wall-clock
and a "paused by operator" reason; the row does not
auto-resume on next session.

## Cap-exit reporting

The driver writes three records on cap-exit:

- `cap-exit.json` with `started_at`, `ended_at`, `wall_clock_seconds`,
  `cap_seconds`, `reason` (`time-cap`, `host-reboot`, `operator-stop`,
  `fixture-missing`, `crash`, or `other`), and `partial_state` (a
  one-line description of what the row had completed before cap).
- A line in the evidence summary `summary.md` under the heading
  `cap-exit` so a reader can grep for it without opening the JSON.
- A `BLOCKED-time-budget` verdict in the per-row table of the QA
  report.

A cap-exit that coincides with a counter anomaly, a crash, or a
public-surface regression also opens a product-bug entry. The bug
list is recorded once per category, not once per row. The same
bug may surface in multiple rows; the bug entry names the
canonical row and lists the others as affected rows.

## Pre-existing long-running gap

Stage 12 closed with 9 time-budget rows reclassified as
`BLOCKED-infrastructure-limited` and 2 cap-fix BLOCKED rows. Those
rows are not in scope for Stage 15 unless the user re-opens the
Stage 12 matrix. Stage 15 re-runs the L01..L03 rows only.

## Handoff to the bug-fix loop

A long-running row that ends in `FAIL` or in a product-bug
`BLOCKED-time-budget` enters the bug-fix loop in part-4 with the
counter anomaly or crash description as the symptom and the
configuration matrix as the precondition.
