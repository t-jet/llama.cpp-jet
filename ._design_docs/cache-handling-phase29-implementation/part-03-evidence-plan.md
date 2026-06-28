# Stage 29 implementation plan part 3: evidence plan

Source: [../cache-handling-phase29-implementation.md](../cache-handling-phase29-implementation.md)
Companion: [part-01a-steps-1-5.md](./part-01a-steps-1-5.md), [part-01b-steps-6-10.md](./part-01b-steps-6-10.md), [part-02-affected-files.md](./part-02-affected-files.md), [part-04-risks-and-oq-resolutions.md](./part-04-risks-and-oq-resolutions.md)

This part specifies, per implementation step, the artifact paths,
the per-step pass criteria, and the wall-clock breakdown for the
QA execution gate. The implementation session verifies each step
against its evidence plan before starting the next step.

## Evidence file convention

Per the test plan part-24 folder convention:

- Durable report (committed):
  `._design_docs/.test_reports/test-report-YYYYMMDD-NN-stage29-01.md`
  (the `-stage29-01` suffix follows the QA convention for
  stage-keyed reports; the name pattern matches the
  `.test_reports/.gitignore` whitelist which allows any
  `test-report-*.md`).
- Per-leg artifacts (non-durable, ignored):
  `._test_output/stage29/<run-id>/phase-N-cycle-M/<mode>/...`
- Per-step log (non-durable, ignored):
  `._test_output/stage29/s29-impl-NN-<slug>.log`

The implementation session does not commit the non-durable
artifacts. The durable report is committed by the implementation
session at close.

## Per-step evidence plan

### Step 01 evidence (S29-IMPL-01)

Pass criteria:

- `Get-Command New-ComparisonWorkload` returns the function after
  dot-sourcing the wrapper.
- `Get-Command New-AgenticChatPrompt` returns the function after
  dot-sourcing the Stage 20 lib.
- All four expected throws fire (RequestCount=0, MaxTokens=0,
  Distribution sum != 1.0, missing key 'exact').

Artifact: `._test_output/stage29/s29-impl-01-wrapper-smoke.log`.

### Step 02 evidence (S29-IMPL-02)

Pass criteria:

- All five new files exist on disk.
- Byte-level audit of the five new files: LF=line count, CR=0,
  no BOM, no non-ASCII, no trailing whitespace, last byte LF.
- `pwsh -NoProfile -File compare-legacy-vs-hybrid.ps1 -DryRun`
  exits 0 and prints the planned command family.

Artifact: `._test_output/stage29/s29-impl-02-scaffold.log`.

### Step 03 evidence (S29-IMPL-03)

Pass criteria:

- `dry-run-plan.json` exists at the run root.
- Per-check log lines in
  `._test_output/stage29/<run-id>/phase-0-preflight.log`
  for all seven sub-checks: clean build, fixture, port, disk,
  CUDA proof, git hash, nvidia-smi.

Artifact: `dry-run-plan.json` (per-run, non-durable).

### Step 04 evidence (S29-IMPL-04)

Pass criteria:

- `workload.jsonl` exists with 200 requests.
- `equivalence-prompts.jsonl` exists with 5 prompts.
- Empirical cache_class counts in workload.jsonl are within
  +/- 5 of the 80/60/60 expected split (re-review C-01).
- All 6 per-request fields present
  (request_id, cache_class, messages, max_tokens, temperature, seed).

Artifact: `._test_output/stage29/<run-id>/phase-0-5-workload-build.log`.

### Step 05 evidence (S29-IMPL-05)

Pass criteria:

- `phase-1-output-equivalence/legacy-decoded.txt` and
  `hybrid-decoded.txt` exist with 5 lines each.
- `phase-1-output-equivalence/diff.txt` is empty on PASS.
- Per-prompt HTTP status and per-prompt ttft_ms recorded in
  `phase-1-output-equivalence/requests.jsonl`.

Artifact: `._test_output/stage29/<run-id>/phase-1-output-equivalence.log`.

### Step 06 evidence (S29-IMPL-06)

Pass criteria:

- Per-cycle artifact directories exist for Phase 2 and Phase 3.
- Each leg directory contains launch.log, server.out.log,
  server.err.log, metrics-before.txt, metrics-after.txt,
  requests.jsonl, summary.json.
- Per-mode, per-cycle summary.json records the empirical
  cache_class counts (re-review C-03).
- Cold-start latency for the first 5 requests is recorded
  separately in summary.json per leg.

Artifact: `._test_output/stage29/<run-id>/phase-2.log` and `phase-3.log`.

### Step 07 evidence (S29-IMPL-07)

Pass criteria:

- Every cooldown between legs records cooldown_duration_seconds,
  vram_baseline_mib, vram_after_sleep_mib, vram_after_release_mib
  in summary.json.
- VRAM returns to baseline within 180 seconds for every cooldown
  in normal conditions; > 180 seconds classifies as
  BLOCKED-vram-release.

Artifact: `._test_output/stage29/<run-id>/cooldown-evidence.log`.

### Step 08 evidence (S29-IMPL-08)

Pass criteria:

- metrics-before.txt and metrics-after.txt per leg.
- cold_store_drift_ratio per leg (hybrid only) recorded in
  cold-store-evidence.json.
- Metrics-format grep returns zero matches on each
  metrics-after.txt (no `^llamacpp_cache_` lines).
- Per-leg summary.json includes the 12 counter deltas, 4 gauge
  snapshots, 4 filesystem metrics, 4 process/GPU samples, and
  per-cache-class counts.

Artifact: `._test_output/stage29/<run-id>/metric-scrape-evidence.log`.

### Step 09 evidence (S29-IMPL-09)

Pass criteria:

- The durable report file
  `._design_docs/.test_reports/test-report-YYYYMMDD-NN-stage29-01.md`
  exists with all three layers and the decision-support section.
- Per-question verdict, threshold, and evidence path are recorded
  for each of Q1..Q5.
- Final recommendation cites the per-question verdicts.
- aggregate.json and comparison.json exist at the run root.

Artifact: the durable report file plus
`._test_output/stage29/<run-id>/report-emit.log`.

### Step 10 evidence (S29-IMPL-10)

Pass criteria:

- `pwsh -NoProfile -File ... -DryRun` exits 0 and prints the
  planned command family.
- All required paths exist; CUDA build proof is in
  `build-cuda/CMakeCache.txt`; nvidia-smi returns a parseable
  memory.used value.
- Wrapper smoke test still PASSes (Step 01 evidence re-runs).
- The self-test log lists PASS for every check.

Artifact: `._test_output/stage29/s29-impl-10-self-test.log`.

## Wall-clock breakdown for QA execution gate

The implementation session does not run the QA execution gate. The
QA execution gate consumes the driver and the test plan and runs
the 80-minute A/B execution budget. The breakdown:

| Phase | Description | Est. minutes |
| --- | --- | ---: |
| Phase 0 | Preflight | 2 |
| Phase 0.5 | Tokenize helper + workload build | 3 |
| Phase 1 | Output equivalence pre-check (5 prompts x 2 modes) | 5 |
| Phase 2 | Cold-start cycle (1 cycle x 2 modes x 200 reqs) | 20 |
| Phase 3 | Warm cycles (3 cycles x 2 modes x 200 reqs) | 50 |
| Cooldowns | 8 cooldowns at 30s + nvidia-smi gate | 4 |
| Subtotal | execution | 84 |
| Report emit | Three-layer report + decision-support | 2 |
| Total | QA execution gate | 86 |

Manager may approve a reduced 2-cycle warm run (drops Phase 3 to 2
cycles, ~30 minutes) for a total of ~64 minutes if session budget
is tight (per part-09 R29-05).

## Per-row pass/fail criteria for QA

The QA execution gate classifies each row of the test plan (per
part-10 test plan mapping):

| Test plan row | Pass criterion | Fail criterion | Block criterion |
| --- | --- | --- | --- |
| TP-29-PRE-01 | All 7 preflight sub-checks PASS | any sub-check FAIL | any sub-check BLOCKED |
| TP-29-OEQ-01 | diff.txt is empty (byte-identical) | diff.txt non-empty (silent cache-blob substitution) | pre-workload gate failure |
| TP-29-CS-01 | Both modes complete 200 reqs in cold-start cycle | valid-setup product crash; repeated HTTP 500 | VRAM not back to baseline; cold-store write failure |
| TP-29-WARM-01..03 | All 3 warm cycles complete for both modes | any valid-setup product crash | VRAM not back to baseline; cold-store write failure |
| TP-29-METRIC-01 | metrics-format grep returns 0 matches on every leg | any underscore-form metric line | not applicable |
| TP-29-DRIFT-01 | cold_store_drift_ratio <= 1.10 on every hybrid leg | ratio > 5.0 (BLOCKED-cold-store-drift) | ratio > 1.10 (OK-with-drift-warning, not blocking) |
| TP-29-COOLDOWN-01 | VRAM back to baseline within 180s for every cooldown | not applicable | VRAM not back to baseline within 180s (BLOCKED-vram-release) |
| TP-29-DECISION-01..05 | each Q1..Q5 verdict and final recommendation recorded | not applicable | not applicable |

The implementation session verifies that the driver supports each
test plan row by the S29-IMPL-10 self-test. The QA execution gate
classifies the actual run per these criteria.
