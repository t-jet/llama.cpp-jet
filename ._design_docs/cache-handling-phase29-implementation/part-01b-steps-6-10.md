# Stage 29 implementation plan part 1B: ordered steps 6-10

Source: [../cache-handling-phase29-implementation.md](../cache-handling-phase29-implementation.md)
Companion: [part-01a-steps-1-5.md](./part-01a-steps-1-5.md), [part-02-affected-files.md](./part-02-affected-files.md), [part-03-evidence-plan.md](./part-03-evidence-plan.md), [part-04-risks-and-oq-resolutions.md](./part-04-risks-and-oq-resolutions.md)

This part specifies the second half of the 10 ordered implementation
steps for Stage 29. Reading order: part-01a (steps 1-5) followed by
this part (steps 6-10). The order is binding: each step assumes the
prior step's preconditions.

## Step 06: S29-IMPL-06 add Phase 2 cold-start cycle and Phase 3 warm-cycle loop

Description: add the Phase 2 cold-start cycle and the Phase 3
warm-cycle loop per part-03 lines 73-90. Phase 2 boots legacy
empty (cold hot budget, empty cold dir), replays 200 requests,
records cold-start latency for the first 5 requests separately,
shuts down, cools down, then does the same for hybrid. Phase 3
loops 3 cycles (1..3 by default) and for each cycle boots legacy
hot, replays 200 requests, shuts down, cools down, then boots
hybrid hot, replays 200 requests, shuts down, cools down.

Affected files:

- `._design_docs/cache-handling-test-scripts/compare-legacy-vs-hybrid.ps1` (add ~120 lines for Phase 2 and Phase 3)

Pre-conditions: S29-IMPL-05 PASS; `workload.jsonl` exists with
200 requests; both modes can boot and serve the workload within
the leg duration; the cooldown gate (Step 07) is in place.

Post-conditions:

- Per-cycle artifact directories exist:
  `phase-2-cycle-1/legacy/`, `phase-2-cycle-1/hybrid/`,
  `phase-3-cycle-1/legacy/`, ..., `phase-3-cycle-3/hybrid/`.
- Each leg directory contains launch.log, server.out.log,
  server.err.log, metrics-before.txt, metrics-after.txt,
  requests.jsonl, summary.json.
- Per-mode, per-cycle `summary.json` records the empirical
  cache_class counts (re-review C-03).
- Cold-start latency for the first 5 requests is recorded
  separately in `summary.json` per leg.
- The cold dir is wiped between legs of the same mode (per
  R29-09 mitigation).

Evidence to collect:

- Per-leg artifact tree.
- `summary.json` per leg with cache_class counts, cold-start
  latencies, total wall-clock per leg, errors, request count.
- Capture to `._test_output/stage29/<run-id>/phase-2.log` and
  `phase-3.log`.

Estimated wall-clock: 25 minutes of authoring (the actual runtime
is part of the 80-minute execution budget).

## Step 07: S29-IMPL-07 add VRAM cooldown gate

Description: add the VRAM cooldown gate per part-03 lines 95-110:
after each shutdown, sleep 30 seconds, then poll `nvidia-smi
--query-gpu=memory.used --format=csv,noheader` every 5 seconds
for up to 180 seconds (extended per R29-IMPL-02). If VRAM does
not return to baseline within 180 seconds, classify as
`BLOCKED-vram-release` and stop. Record actual cooldown duration
per leg in `summary.json`.

Affected files:

- `._design_docs/cache-handling-test-scripts/compare-legacy-vs-hybrid.ps1` (add ~40 lines for the cooldown gate)

Pre-conditions: S29-IMPL-06 PASS; `nvidia-smi` is callable and
returns a parseable memory.used value.

Post-conditions:

- Every cooldown between legs records
  `cooldown_duration_seconds`, `vram_baseline_mib`,
  `vram_after_sleep_mib`, `vram_after_release_mib` in
  `summary.json`.
- VRAM not back to baseline within 180 seconds classifies the
  run as `BLOCKED-vram-release` with the recorded VRAM values
  preserved.
- The cooldown gate runs between every mode-switch and every
  cycle.

Evidence to collect:

- `summary.json` per leg with cooldown fields.
- `cooldown.log` in each leg directory with the polling history.
- Capture to
  `._test_output/stage29/<run-id>/cooldown-evidence.log`.

Estimated wall-clock: 10 minutes.

## Step 08: S29-IMPL-08 add per-leg metric scraping and ground-truth cross-checks

Description: add the per-leg Prometheus counter scraping (before
and after the leg) plus the filesystem ground-truth cross-checks
per part-04. Capture: 12 counter deltas (4 general + 8
hybrid-only), 4 gauge snapshots, 4 filesystem metrics
(cold_store_bytes_on_disk, cold_store_file_count,
cold_store_drift_ratio, hot_payload_count_proxy), and 4
process/GPU samples (vram_peak_mib, vram_baseline_mib,
cpu_pct_avg, ram_mib_peak). Enforce the post-Stage-26
`llamacpp:cache_X` namespace with a metrics-format grep that
fails any leg emitting `^llamacpp_cache_` (R29-08 mitigation).

Affected files:

- `._design_docs/cache-handling-test-scripts/lib/metric-delta.ps1` (extend with `Get-CounterDelta`)
- `._design_docs/cache-handling-test-scripts/lib/cold-store-drift.ps1` (extend with `Get-ColdStoreDrift`)
- `._design_docs/cache-handling-test-scripts/compare-legacy-vs-hybrid.ps1` (add ~100 lines for scraping and cross-checks)

Pre-conditions: S29-IMPL-07 PASS.

Post-conditions:

- `metrics-before.txt` and `metrics-after.txt` per leg.
- `cold_store_drift_ratio` per leg (hybrid only). Ratio > 1.10
  classifies the leg as `OK-with-drift-warning`; > 5.0
  classifies the leg as `BLOCKED-cold-store-drift`.
- Metrics-format grep runs on each `metrics-after.txt`. Any
  match classifies the leg as
  `FAIL-metric-format-regression`.
- Per-leg `summary.json` includes the 12 counter deltas, 4 gauge
  snapshots, 4 filesystem metrics, 4 process/GPU samples, and
  per-cache-class counts (re-review C-03).

Evidence to collect:

- `metrics-before.txt`, `metrics-after.txt` per leg.
- `cold-store-evidence.json` per leg with bytes, file count,
  drift ratio.
- Metrics-format grep result per leg.
- Capture to
  `._test_output/stage29/<run-id>/metric-scrape-evidence.log`.

Estimated wall-clock: 20 minutes.

## Step 09: S29-IMPL-09 add three-layer report emitter and decision-support section

Description: add the three-layer report emitter per part-05 plus
the five decision-support questions Q1..Q5 with concrete metric
thresholds. Layer 1 (Correctness) runs the three sub-checks
(cold-store validity, output equivalence, fallback restore rate)
and emits PASS/FAIL/BLOCKED with concrete counter values. Layer 2
(Per-request) emits the side-by-side per-request table plus the
distributions (p50, p95, p99 of wall_clock_ms, ttft_ms,
cache_n_ratio per mode per cache_class). Layer 3 (Aggregated)
emits the cross-cycle aggregate. The decision-support section
answers Q1..Q5 with the SHIP/FIX-TARGET/REVERT/ACCEPT-COLD
verdict per question and a final recommendation
(SHIP-HYBRID-AS-DEFAULT, SHIP-HYBRID-AS-OPTIONAL, or
DO-NOT-SHIP).

Affected files:

- `._design_docs/cache-handling-test-scripts/compare-legacy-vs-hybrid.ps1` (add ~150 lines for the report emitter)

Pre-conditions: S29-IMPL-08 PASS.

Post-conditions:

- The durable report file
  `._design_docs/.test_reports/test-report-YYYYMMDD-NN-stage29-01.md`
  exists with all three layers and the decision-support section.
- The report name pattern
  `test-report-YYYYMMDD-NN-stage29-01.md` matches the
  `.test_reports/.gitignore` whitelist (the whitelist allows any
  `test-report-*.md` name; the `-stage29-01` suffix is the QA
  convention for stage-keyed reports).
- Per-question verdict, threshold, and evidence path are recorded
  for each of Q1..Q5.
- Final recommendation cites the per-question verdicts.

Evidence to collect:

- The full report file.
- `aggregate.json` with the cross-cycle aggregate.
- `comparison.json` with per-cycle, per-mode, per-cache-class.
- Capture to
  `._test_output/stage29/<run-id>/report-emit.log`.

Estimated wall-clock: 20 minutes.

## Step 10: S29-IMPL-10 pre-execution self-test

Description: pre-execution self-test that the QA execution gate
will read. Verifies the dry-run path, all required paths exist
(model, binary, cold dir, output dir, port free), CUDA build
proof, nvidia-smi callability, and the wrapper smoke test still
PASSes. Writes
`._test_output/stage29/s29-impl-10-self-test.log` with PASS/FAIL
per check. A FAIL classifies the driver as not-yet-ready-for-QA
and the implementation session fixes the issue before handoff.

Affected files:

- `._design_docs/cache-handling-test-scripts/compare-legacy-vs-hybrid.ps1` (add ~30 lines for the self-test function)

Pre-conditions: S29-IMPL-09 PASS.

Post-conditions:

- `pwsh -NoProfile -File ... -DryRun` exits 0 and prints the
  planned command family.
- All required paths exist; CUDA build proof is in
  `build-cuda/CMakeCache.txt`; nvidia-smi returns a parseable
  memory.used value.
- Wrapper smoke test still PASSes.
- The self-test log lists PASS for every check.

Evidence to collect:

- `._test_output/stage29/s29-impl-10-self-test.log`.
- A copy of `dry-run-plan.json` at the run root.

Estimated wall-clock: 10 minutes.

## Total step wall-clock

S29-IMPL-01: 5 min
S29-IMPL-02: 35 min
S29-IMPL-03: 10 min
S29-IMPL-04: 15 min
S29-IMPL-05: 10 min
S29-IMPL-06: 25 min
S29-IMPL-07: 10 min
S29-IMPL-08: 20 min
S29-IMPL-09: 20 min
S29-IMPL-10: 10 min
Sum: 160 minutes of authoring (1-2 implementation sessions).

The 80-minute execution budget (Phase 0..3 plus cooldowns) is a
runtime budget, not an authoring budget. The implementation
session does not execute the full 80-minute A/B run; that is the
QA execution gate's job.
