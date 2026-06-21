# Stage 23 design: Full S/L Matrix Execution

Status: design review PASS; Manager design gate PASS; execution planning open
Date: 2026-06-20
Stage: 23 (Full S/L Matrix Execution)
Owner: Architect
Source: Stage 20 D20-CLOSURE-01 deferred full S/L matrix scope; Stage 17 test plan part 27 TP-17-ST1..ST3; Stage 21 and Stage 22 closure state
Scope: design authoring only. No code, test, runner, or product behavior changes.
Current gate: execution planning open

## Contents

- [Part 1: design review gate 01](cache-handling-phase23-design/part-01-design-review-gate-01.md)

This document is under the 300-line cap. Review history is kept in part files.

## Scope

Stage 23 runs the full stress and longrun matrix that Stage 20 deferred as
`BLOCKED-test-session-scope` because the matrix needs an 8+ hour run window.

In scope:

- Stress rows S01..S08 with Stage 17 hooks enabled.
- Longrun rows L01..L03 with Stage 17 hooks enabled.
- One durable execution report for the full matrix.
- Per-row evidence, row verdicts, retry/resume rules, cleanup rules, and
  cold-budget checks.
- Stage 21/22 closure context: current cache behavior includes the Stage 22
  demotion coordination fix and Stage 21 heavy closure evidence.

Out of scope:

- Production code changes unless a later test-results bug-fix loop finds a
  product defect.
- Public endpoint schema, public metric-name, or CLI flag changes.
- Broad Stage 20 infrastructure changes. Only review-blocking runner issues may
  be corrected later, and such corrections need their own review record.
- Reopening Stage 21 or Stage 22. Their closure state is prerequisite context.
- Re-running synthetic TP-20-SY1..SY5 or heavy TP-21-HV1/HV2 rows.

## Prerequisites

Required before execution opens:

- Current build of `build-cov/bin/Release/llama-server.exe`; clean build
  evidence or binary freshness must be recorded in the report.
- Qwen3.5-4B-MTP fixture available for S/L scripts:
  `._test_models/Qwen3.5-4B-MTP-GGUF/`.
- Stage 20 wrapper exists and passes dry-run:
  `._design_docs/cache-handling-test-scripts/kickoff-stage20-stress-longrun.ps1`.
- Stress scripts exist:
  S01 `stress_s12_s01_budget_exhaustion.ps1`,
  S02 `stress_s12_s02_concurrent_multi_slot.ps1`,
  S03 `stress_s12_s03_large_branch_forests.ps1`,
  S04 `stress_s12_s04_prompt_storms.ps1`,
  S05 `stress_s12_s05_mixed_workload_profiles.ps1`,
  S06 `stress_s12_s06_cold_queue_pressure.ps1`,
  S07 `stress_s12_s07_protected_root_pressure.ps1`,
  S08 `stress_s12_s08_integrity_failure_under_load.ps1`.
- Longrun scripts exist:
  L01 `longrun_s12_l01_6h_hybrid_stability.ps1`,
  L02 `longrun_s12_l02_30m_legacy_comparison.ps1`,
  L03 `longrun_s12_l03_2h_mixed_workload.ps1`.
- Disk headroom: at least 30 GiB free on the output volume and at least 10 GiB
  free on the cold-path volume before each batch.
- Port range 8800-8821 is free or Manager assigns a replacement range before
  execution.
- Cold path root is empty at row start unless a retry explicitly resumes the
  same row from a preserved evidence directory.
- No public surface changes are required or allowed for Stage 23 design.

## Stage 21/22 closure context

Stage 21 is closed. Its heavy rerun passed after Stage 22 fixes: req-008,
req-009, and req-010 restored with `cache_n=26`, forbidden warnings were zero,
redacted evidence was present, and after-metrics were available.

Stage 22 is closed. The current cache behavior includes descriptor-owned
demotion coordination, idempotent demotion completion, and target/draft
completion coverage. Stage 23 uses that behavior as the current baseline. It
does not reopen Stage 21/22 findings or retry their heavy workload.

Non-blocking follow-ups from Stage 21/22, including the negative cache-byte
gauge and restore/promote cleanup advisory, remain non-blocking for Stage 23
unless a Stage 23 row produces a new FAIL tied to those items.

## Prompt source decision

Stage 23 uses existing deterministic S/L prompts by default. The Stage 20
agentic prompt generator is not a broad input replacement for this matrix.

Generated prompts may be used only when a row explicitly supports a prompt file
path or the Manager approves a focused rerun to diagnose prompt-size behavior.
If used, the report must capture:

- generator command and seed
- target token count and measured token count
- prompt class
- SHA256 checksum
- generated prompt file path under non-durable output
- redacted evidence JSONL record showing lookup outcome

Durable reports must not include raw prompt text. Redacted evidence may include
request labels, row id, token count, checksum, bounded miss reason, namespace
hash, `cache_n`, and prompt evidence counters. Raw mode is out of scope.

## Matrix rows

Stress rows run with 30 minute per-row caps and the Stage 15 1000
hits+misses threshold. A stress row below 1000 hits+misses is
`BLOCKED-stress-low-throughput` unless the Manager pre-approves a different
row-specific intent threshold.

| Row | Script | Cap | Required behavior |
| --- | --- | ---: | --- |
| S01 | budget exhaustion | 30m | bounded cold pressure; no corrupt restore |
| S02 | concurrent multi-slot | 30m | no crash or slot ownership leak |
| S03 | large branch forests | 30m | near-prefix candidates remain `unsafe_prefix_rejected` |
| S04 | prompt storms | 30m | bounded miss reasons and redacted evidence under load |
| S05 | mixed workload profiles | 30m | exact and non-exact outcomes classified cleanly |
| S06 | cold queue pressure | 30m | cold demotions skip or evict before write failure |
| S07 | protected root pressure | 30m | protected roots remain protected under pressure |
| S08 | integrity failure under load | 30m | integrity failures stay bounded; no corrupt restore |

Longrun rows use the V2 caps adopted by Stage 20: L01 2h, L02 30m, L03 2h.
Longrun rows are judged on stated intent when total hits+misses is below 1000,
matching the Stage 15/20 rule.

| Row | Script | Cap | Required behavior |
| --- | --- | ---: | --- |
| L01 | 6h hybrid stability script, V2 cap | 2h | stable run, bounded cold budget, no host allocation failure |
| L02 | 30m legacy comparison | 30m | comparison completes or blocks with clear environment cause |
| L03 | 2h mixed workload | 2h | mixed workload remains bounded over time |

## Execution management

The execution owner runs rows in batches of at most two concurrent processes.
Recommended order is S01..S08, then L01..L03. Manager may split execution into
two sub-sessions, stress first and longrun second, without changing the stage
scope.

Before every batch:

- stop stale `llama-server` processes from prior Stage 23 rows
- verify the assigned ports are free
- verify cold path root and evidence root are writable
- record free disk space for output and cold path
- run or cite wrapper dry-run evidence for selected rows

Resume and retry rules:

- If a row finishes with complete evidence, do not rerun it unless Manager asks
  for confirmation of a suspected harness issue.
- If a row is interrupted before server startup or before first request, retry
  once with a clean cold path and a new row attempt suffix.
- If a row reaches its cap with complete cap-exit evidence, classify it; do not
  extend the cap inside the same attempt.
- If a row fails because of port collision, stale process, missing fixture, or
  missing evidence directory, fix the setup and rerun once.
- If a row fails twice with the same product symptom, stop retries and open the
  bug-fix loop.

Process cleanup after every row:

- terminate child PowerShell process and `llama-server` for the row
- wait for process exit and record exit code
- capture final metrics before termination when the server is responsive
- leave the row evidence directory intact
- clear the cold path unless the row is being resumed from the same attempt

## Evidence and report naming

Durable report:

`._design_docs/.test_reports/stage23-sl-matrix-YYYYMMDD-NN.md`

Non-durable row output:

- `._test_output/stage23-stress-YYYYMMDD-NN/S01-Jnew/` through `S08-Jnew/`
- `._test_output/stage23-longrun-YYYYMMDD-NN/L01-Jnew/` through `L03-Jnew/`

Required per-row files:

- `launch.log` and `launch.err`
- `server.out.log` and `server.err.log`
- `metrics-before.txt` and `metrics-after.txt`
- prompt evidence JSONL tail or an explicit `BLOCKED-evidence-missing` note
- cold-path byte summary before and after
- row summary JSON with row id, cap, wall time, exit code, request count,
  hits+misses, `cache_n` summary, warning counts, and verdict
- `cap-exit.json` when the row exits by time cap

The durable report must include one table for stress rows and one table for
longrun rows. Each row needs: verdict, cap, wall time, output path, cold budget
status, prompt evidence status, key metrics, warnings, retry count, and next
action.

## Metrics and checks

Required metric checks when exposed:

- `cache_restore_misses_total`
- `cache_prefix_candidates_total`
- `cache_prompt_evidence_records_total`
- `cache_cold_bytes`
- `cache_cold_budget_bytes`
- `cache_cold_demotions_skipped_total`
- `cache_cold_evictions_total`
- `cache_checkpoint_admissions_by_shape_total`

The report must not invent metric values. If a metric family is unavailable,
state `BLOCKED-metric-unavailable` for that evidence item and cite substitute
logs or JSONL only when they prove the same contract.

Cold-budget checks:

- `cache_cold_bytes` must not exceed `cache_cold_budget_bytes` after row
  completion unless the row is explicitly running unlimited cold budget.
- cold demotion pressure must produce bounded skip, bounded eviction, or a
  documented block before any filesystem write failure.
- no row may hide a host allocation failure as PASS.

## Verdict criteria

PASS per row requires complete evidence, no crash, no corrupt restore, bounded
diagnostics, redacted prompt evidence without prompt text, and the row-specific
behavior listed in the matrix.

FAIL per row applies to product symptoms: crash, corrupt restore, unsafe prefix
restore, repeated HTTP 500, raw prompt text leak in redacted mode, cold write
failure without bounded handling, or exact-repeat regression with matching
identity evidence.

BLOCKED per row applies to setup or session limits: missing fixture, stale
binary, port collision after one setup retry, disk shortage, cap exit before
required evidence, unavailable metric with no substitute, or runner contract
failure.

Stage 23 PASS requires all 11 rows PASS or have Manager-accepted BLOCKED
classifications with complete evidence and no product defect. Any FAIL opens a
bug-fix loop before closure.

## Handoff

## Manager design gate

VERDICT: PASS
Date: 2026-06-20
Owner: Manager

Decision D23-DESIGN-01: accept Stage 23 design and design review PASS. Stage 23
scope is limited to full S/L matrix execution for S01..S08 and L01..L03 using
the current Stage 20 wrapper contract.

Decision D23-DESIGN-02: execution planning is open. The next owner must prepare
the run plan and verify wrapper readiness before any multi-hour execution.
Product code, public surface, public metric names, and runner behavior remain
unchanged unless a later reviewed bug-fix loop requires otherwise.

Decision D23-DESIGN-03: deterministic S/L prompts are the default. Generated
agentic prompts require explicit row support or a focused Manager-approved
rerun with redacted evidence rules recorded.

Handoff: Developer/QA owns execution planning. Manager review follows before
the full matrix starts.

This file uses LF line endings, plain ASCII status labels, and stays under the
300-line durable-doc cap.
