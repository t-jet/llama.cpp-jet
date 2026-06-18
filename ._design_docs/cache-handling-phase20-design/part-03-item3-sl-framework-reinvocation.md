# Stage 20 design Part 3: Item 3 - S/L framework re-invocation

Source: [../cache-handling-phase20-design.md](../cache-handling-phase20-design.md)

## Overview

Item 3 closes the `BLOCKED-test-session-scope` classification on
Stage 17 stress-longrun-tier rows TP-17-ST1..ST3 by re-invoking the
Stage 12/15 S/L framework with Stage 17 hooks (redacted evidence,
bounded cold budget, prefix classification, branch-forest growth).
The existing framework scripts are present at
`._design_docs/cache-handling-test-scripts/` (verified by
`Get-ChildItem` 2026-06-18):

- 8 stress scripts in `stress/`:
  `stress_s12_s01_budget_exhaustion.ps1`,
  `stress_s12_s02_concurrent_multi_slot.ps1`,
  `stress_s12_s03_large_branch_forests.ps1`,
  `stress_s12_s04_prompt_storms.ps1`,
  `stress_s12_s05_mixed_workload_profiles.ps1`,
  `stress_s12_s06_cold_queue_pressure.ps1`,
  `stress_s12_s07_protected_root_pressure.ps1`,
  `stress_s12_s08_integrity_failure_under_load.ps1`.
- 3 long-run scripts in `longrun/`:
  `longrun_s12_l01_6h_hybrid_stability.ps1`,
  `longrun_s12_l02_30m_legacy_comparison.ps1`,
  `longrun_s12_l03_2h_mixed_workload.ps1`.
- `kickoff-v2-stress-longrun.ps1` drives the 22-row matrix
  (8 stress x 2 jinja + 3 longrun x 2 jinja) with batch size 2 and
  per-row timeouts.

Item 3 is a re-invocation only. The framework scripts themselves
are NOT modified. Stage 17 hooks are added at invocation time via
new wrapper parameters and a new kickoff script
`kickoff-stage20-stress-longrun.ps1` based on the V2 template.

## Why a new kickoff script

The V2 kickoff script targets the Stage 15 closure matrix (20
PENDING rows from the V1 sub-session 1d). It launches the S/L
rows with `--cache-mode hybrid`, the MTP fixture, and per-row
ports starting at 8600. Stage 20 needs:

- Redacted evidence enabled (`--cache-prompt-evidence redacted`
  with `--cache-prompt-evidence-dir <path>`) for all rows.
- Bounded cold budget (`--cache-cold-max-mib <N>`) for rows that
  exercise cold pressure.
- The agentic prompt generator (Item 1) as the prompt source for
  rows that need > 1k tokens per request.
- A separate port range to avoid collision with V2 if both run in
  the same session (V2 uses 8600-8621; Stage 20 uses 8800-8821).
- The `unsafe_prefix_rejected` counter assertion for stress rows
  that mix exact and near-prefix requests.
- The Stage 17 1000 hits+misses threshold for S rows per
  [test plan part-25](../../cache-handling-test-plan/part-25-stage15-full-test-suite-validation.md)
  bug-fix reclassification rules.

A new kickoff script encapsulates these additions without changing
the V2 framework. The new script lives at
`._design_docs/cache-handling-test-scripts/kickoff-stage20-stress-longrun.ps1`
and mirrors the V2 structure (kill old PIDs, define row launch
list, launch in batches of 2, per-batch verification).

## Wrapper parameters

Each S/L script accepts the Stage 17 flags via the wrapper:

- `-CacheColdMaxMib` (int, default `512`): cold budget. `0` to
  disable cold; `-1` for unlimited.
- `-CachePromptEvidence` (string, default `redacted`): one of
  `off`, `redacted`, `raw`.
- `-CachePromptEvidenceDir` (string, required when
  `-CachePromptEvidence` is not `off`): JSONL output directory.
- `-AgenticPromptPath` (string, optional): path to a generated
  prompt JSON file from the Item 1 generator. If unset, the
  row uses its existing deterministic short prompt.
- `-JinjaVariant` (string, default `new`): `original` or `new`.
  Stage 12/15 used both; Stage 20 defaults to `new` to match the
  Stage 16 chat-path boundary invariant.

The wrapper translates these into the existing `--cache-*` flags
the Stage 17 implementation added. The wrapper does NOT modify the
script logic.

## Stress row scope (TP-20-ST1)

TP-20-ST1 reopens TP-17-ST1 (S01..S08 framework with redacted
evidence enabled). The 16-row matrix (8 stress x 2 jinja) runs
under the new kickoff with redacted evidence enabled and the
existing per-row timeouts (30 minutes each, 1000 hits+misses
threshold per [test plan part-25](../../cache-handling-test-plan/part-25-stage15-full-test-suite-validation.md)).

Pass/fail per row:

- One JSONL record per restore lookup at the
  `--cache-prompt-evidence-dir` path.
- Bounded miss reasons (no prompt text or raw paths in the
  reason).
- No crash, no deadlock, no corrupt restore.
- Per-row evidence path:
  `._test_output/stage20-stress-YYYYMMDD-NN/<base>-<jinja>/`.

A row under 1000 hits+misses is `BLOCKED-stress-low-throughput`
per the part-25 rule, not `PASS-meets-intent`.

## Stress row scope (TP-20-ST3)

TP-20-ST3 reopens TP-17-ST3 (branch-forest growth stress with
prefix-classification enabled). This is a subset of TP-20-ST1
covering `stress_s12_s03_large_branch_forests.ps1` (the S03
row) with explicit prefix-mix inputs.

Pass/fail:

- Prefix candidates classified as `unsafe_prefix_rejected` per
  Stage 17 D17-03 (no prefix restore in Stage 17 scope).
- No slot mutation on prefix-only candidates.
- Counters consistent across iterations.
- Per-row evidence path:
  `._test_output/stage20-stress-YYYYMMDD-NN/S03-new/`.

## Longrun row scope (TP-20-ST2)

TP-20-ST2 reopens TP-17-ST2 (L01..L03 framework with bounded
cold budget). The 6-row matrix (3 longrun x 2 jinja) runs under
the new kickoff with `--cache-cold-max-mib 512` and redacted
evidence enabled.

Pass/fail per row:

- Cold bytes stay at or below budget (gauge `cache_cold_bytes`
  does not exceed `cache_cold_budget_bytes`).
- Skipped demotions observed before any filesystem write failure
  (`cache_cold_demotions_skipped_total` increments).
- No host-allocation failure.
- Per-row evidence path:
  `._test_output/stage20-longrun-YYYYMMDD-NN/<base>-<jinja>/`.

Per-row timeouts mirror the V2 caps (L01 2h, L02 30m, L03 2h;
Stage 12 design specifies 6h for L01 and 2h for L03 but the V2
kickoff uses 2h/30m/2h to keep session scope predictable). The
Stage 20 kickoff uses the V2 caps.

## BLOCKED-test-session-scope handling

The Stage 17 closure classified TP-17-ST1..ST3 as
`BLOCKED-test-session-scope` because the framework drivers were
not invoked. Stage 20 invokes them. After invocation:

- A row that runs cleanly is `PASS-meets-intent` (S rows) or
  `PASS-meets-intent` (L rows) per the part-25 rule that L rows
  are classified on intent when hits+misses is below 1000.
- A row that fails is `FAIL` and routes to the bug-fix loop per
  part-25.
- A row that exceeds the per-row cap is `BLOCKED-time-budget`
  with the actual wall-clock seconds recorded per the part-25
  cap-exit parsing rule.

If the test session cannot fit the full 22-row matrix in a single
session (16 stress at 30m each plus 6 longrun at 2h each totals
8h+ wall-clock), the implementation plan proposes splitting the
matrix across two sub-sessions (stress in sub-session A, longrun
in sub-session B). The QA test report records the per-sub-session
boundary.

## Test plan rows proposed

Three stress-longrun-tier rows reopen TP-17-ST1..ST3. Each row
covers one or more framework rows under the new kickoff.

| ID | Type | Fixture | Preconditions | Command or call | Expected outcome | Evidence | Pass/fail criteria |
| --- | --- | --- | --- | --- | --- | --- | --- |
| TP-20-ST1 | stress | Qwen3.5-4B-MTP | redacted evidence enabled, kickoff-stage20-stress-longrun.ps1 | run S01..S08 with redacted evidence and Jnew variant (16 rows total) | one JSONL record per restore lookup; bounded miss reasons; no crash; no corrupt restore | per-row JSONL + server logs + counters | stress rows with redacted evidence PASS; mirrors TP-17-ST1 |
| TP-20-ST2 | longrun | Qwen3.5-4B-MTP | cold budget 512 MiB enabled, redacted evidence enabled | run L01..L03 with bounded cold budget and Jnew variant (6 rows total) | cold bytes at or below budget; skipped demotions before write failure; no host allocation failure | per-row server logs + cold byte gauge + skipped counter | longrun rows respect cold budget; mirrors TP-17-ST2 |
| TP-20-ST3 | stress | Qwen3.5-4B-MTP | prefix-classification enabled, redacted evidence enabled | run S03 large branch forest with mixed exact and near-prefix requests | prefix candidates classified as `unsafe_prefix_rejected`; no slot mutation; counters consistent | server logs + counters | prefix-only candidates rejected, not restored; mirrors TP-17-ST3 |

The three rows are direct reopenings of TP-17-ST1..ST3 with the
new kickoff and Stage 17 hooks. The test plan at Stage 20
test-plan authoring renames them to TP-20-ST1..ST3 and reclassifies
them from `BLOCKED-test-session-scope` to PASS or BLOCKED with a
documented harness/setup reason.

## Evidence capture

Each row's evidence path is:

- `._test_output/stage20-stress-YYYYMMDD-NN/<base>-<jinja>/` for
  stress rows.
- `._test_output/stage20-longrun-YYYYMMDD-NN/<base>-<jinja>/`
  for longrun rows.
- Per-row `server.out.log`, `server.err.log`, `metrics-before.txt`,
  `metrics-after.txt`.
- Redacted JSONL tail at the
  `--cache-prompt-evidence-dir` path.
- Side log at
  `._design_docs/.test_reports/stage20-stress-YYYYMMDD-NN/batch-summary.log.side`
  (for L rows) or
  `._design_docs/.test_reports/stage20-longrun-YYYYMMDD-NN/batch-summary.log.side`
  (for S rows when split).
- `cap-exit.json` per row when the row exits via time cap (per
  part-25 cap-exit parsing rule).

The QA test report cites the per-row evidence path and the
side-log entries.

## Framework constraint compliance

The new kickoff script MUST follow the same patterns as the V2
kickoff per `qa.md` improvement memory:

- Use the full `pwsh.exe` path (not AppExecAlias).
- Per-row launch via `Start-Process` with `-ArgumentList` array.
- Per-batch sleep = 30s.
- Max 2 concurrent `llama-server` instances per batch.
- Side log at the named path under
  `._design_docs/.test_reports/`.

The wrapper parameters MUST be translated into `--cache-*` flags
without changing the underlying script logic.

## Open questions

- OQ-20-05: should the Stage 20 kickoff use the V2 cap (L01 2h,
  L02 30m, L03 2h) or the Stage 12 design cap (L01 6h, L02 30m,
  L03 2h)? The V2 cap is the de facto standard from Stage 15
  closure. The implementation plan proposes V2 cap for
  predictability; the user may revise.
- OQ-20-06: should the agentic prompt generator (Item 1) be used
  for S/L rows, or do the existing short deterministic prompts
  suffice? The Stage 17 part-27 wording suggests the generator is
  reused; the implementation plan decides per-row whether to
  invoke the generator.

## Handoff for Item 3

Implementation plan and implementation are NOT STARTED. The Manager
design gate does not block Item 3 (only Item 2 requires
R-20-DESIGN-MGR-01). Implementation planning for Item 3 can proceed
in parallel with the Manager decision on Item 2.

This file uses LF line endings, plain ASCII status labels, and stays
under the 300-line durable-doc cap.
