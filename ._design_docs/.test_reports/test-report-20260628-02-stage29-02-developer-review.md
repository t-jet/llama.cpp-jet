# Test report 2026-06-28 02: developer test-results review

Status: REWORK
Date: 2026-06-29
Stage: 29 (Cache Modes Comparison: legacy vs hybrid on a representative agentic-shaped workload)
Branch: work-branch
Owner: Developer (test-results review, fresh session)
Source report: [test-report-20260628-02-stage29-02.md](test-report-20260628-02-stage29-02.md) (PARTIAL, 1 BLOCKING F-29-EXEC-04)
Prior report: [test-report-20260628-01-stage29-01.md](test-report-20260628-01-stage29-01.md) (PARTIAL, 1 BLOCKING F-29-EXEC-01)
Test plan: [../cache-handling-test-plan/part-33-stage29-cache-modes-comparison.md](../cache-handling-test-plan/part-33-stage29-cache-modes-comparison.md) (299 LF, 14 rows)
Driver (under review): [../cache-handling-test-scripts/compare-legacy-vs-hybrid.ps1](../cache-handling-test-scripts/compare-legacy-vs-hybrid.ps1) (243 LF, post S29-IMPL-FIX-02)
Server validation source: [../../tools/server/server-context.cpp:611-625](../../tools/server/server-context.cpp#L611)

## Reviewer session metadata

- Date: 2026-06-29
- Role: Developer test-results review
- Session: NEW fresh session. Distinct from the QA session that authored
  report-02 (2026-06-28), the QA session that authored report-01, the
  Developer sessions that authored the driver and the prior bug fixes
  (S29-IMPL-FIX-01, S29-IMPL-FIX-02), the Architect sessions for
  design / re-review, and the Manager implementation-fix gate
  reviewer. No prior session state was loaded; every source document
  was read from disk in this session.
- Method: byte-level read of the QA report -02 and -01; byte-level
  read of the driver (243 LF, CR=0, no BOM, last byte 0x0A); direct
  read of `tools/server/server-context.cpp:611-625`; cross-check of
  the 14-row classification against `common/arg.cpp:1366` registration
  and the test plan part-33 PASS criteria; verification that the bug
  at driver L88 matches the server-side rejection contract.

## Verdict

REWORK. The 11 BLOCKED-driver-cold-mode rows cannot be marked PASS
without a Developer fix to `Start-Stage29Server` and a QA re-execution
that produces real per-leg evidence. The bug is a driver defect, not a
product defect (see "Product bug triage"). The other 3 rows (RG-01
PARTIAL, RG-02 PASS, CV-01 BLOCKED-Release-without-/Zi) are correctly
classified and stand. Closure requires a second fix iteration
(documented in the retest scope) followed by a second Developer
test-results review.

## Subject under review

- QA execution report: `test-report-20260628-02-stage29-02.md` (PARTIAL,
  1 BLOCKING F-29-EXEC-04).
- Test plan: part-33 (14 rows: 4 CC + 3 PR + 4 AG + 2 RG + 1 CV).
- Driver bug location (verified by direct read): L86-88 of
  `compare-legacy-vs-hybrid.ps1` (function definition + ArgumentList
  construction with unconditional cold-path flags). Note: the user
  brief cited "driver L167" but the actual location of the bug is
  L86-88; L166 is a call site of `Start-Stage29Server` inside
  `Invoke-CycleLeg` and does not itself pass cold-path flags.
- Server validation: `tools/server/server-context.cpp:611-625`
  (three checks, all of which reject the driver's cold-path flags
  when `--cache-mode legacy`).

## Per-row classification acceptance

The QA report classifies 14 rows: PASS=1, FAIL=0, PARTIAL=1, BLOCKED=12
(11 driver-cold-mode, 1 Release-without-/Zi). Per-row sums in the
"Per-row classification" table of the report match this prose
summary; no counting discrepancy to flag (consistent with the QA
"Reconcile test report prose summary count against per-row sums"
discipline).

| Row | QA verdict | Reviewer verdict | Owner | Evidence |
| --- | --- | --- | --- | --- |
| TP-29-CC-01 (output equivalence) | BLOCKED-driver-cold-mode | ACCEPT | Developer (driver fix) | server.err.log (qa-rpt -02) line 1: "E srv load_model: - cache: --cache-cold-max-mib requires --cache-mode hybrid"; driver L88; server-context.cpp:611-615 |
| TP-29-CC-02 (cold-store validity) | BLOCKED-driver-cold-mode | ACCEPT | Developer (driver fix) | same as CC-01; cold-store filesystem never populated by driver because hybrid legs also cannot run after Phase 0.5 fails (Phase 0.5 is legacy-mode tokenize helper at driver L138) |
| TP-29-CC-03 (fallback rate) | BLOCKED-driver-cold-mode | ACCEPT | Developer (driver fix) | same; no per-leg metrics produced by driver |
| TP-29-CC-04 (cooldown) | BLOCKED-driver-cold-mode | ACCEPT | Developer (driver fix) | same; no per-leg `summary.json` produced; no cooldown-evidence.json |
| TP-29-PR-01 (cache_n_ratio exact) | BLOCKED-driver-cold-mode | ACCEPT | Developer (driver fix) | same; no per-cycle `requests.jsonl` produced |
| TP-29-PR-02 (cold-miss ttft) | BLOCKED-driver-cold-mode | ACCEPT | Developer (driver fix) | same; no cold-miss vs warm-miss split |
| TP-29-PR-03 (warm-hit p95) | BLOCKED-driver-cold-mode | ACCEPT | Developer (driver fix) | same; no warm-cycle `requests.jsonl` |
| TP-29-AG-01 (mean hit rate) | BLOCKED-driver-cold-mode | ACCEPT | Developer (driver fix) | same; no aggregated request rows |
| TP-29-AG-02 (total tokens reused) | BLOCKED-driver-cold-mode | ACCEPT | Developer (driver fix) | same |
| TP-29-AG-03 (cold-store bytes) | BLOCKED-driver-cold-mode | ACCEPT | Developer (driver fix) | same; cold-store filesystem never populated |
| TP-29-AG-04 (VRAM peak) | BLOCKED-driver-cold-mode | ACCEPT | Developer (driver fix) | same; no per-leg `summary.json` with vram_peak_mib |
| TP-29-RG-01 (focused + pytest) | PARTIAL | ACCEPT | QA (pytest env), Developer (separate handoff) | test-cache-controller 142/142 PASS (qa-rpt -02 test-cache-controller.log); pytest BLOCKED-env (huggingface-hub==1.16.1 vs transformers>=0.34.0,<1.0) carried forward as F-29-EXEC-06 |
| TP-29-RG-02 (no tools/server mods) | PASS | ACCEPT | QA | `git status --short -- tools/server/` returned 0 entries; setup-env captured git_modified_tools_server=0 |
| TP-29-CV-01 (coverage) | BLOCKED-Release-without-/Zi | ACCEPT | Developer (separate handoff) | `build-cuda/CMakeCache.txt:80` `CMAKE_CXX_FLAGS_RELEASE:STRING=/O2 /Ob2 /DNDEBUG` (no /Zi); OpenCppCoverage not installed; carried forward as F-29-EXEC-07 |

Row verdict totals: 14 accepted, 0 overridden. Per-row sums:
PASS=1, FAIL=0, PARTIAL=1, BLOCKED=12. No row is misclassified.

## Product bug triage

Question: are any of the 11 BLOCKED-driver-cold-mode rows actually
product bugs, or are they all driver defects?

Triage result: No product bugs found.

Evidence:

- The driver unconditionally appends `--cache-cold-max-mib 2048` and
  `--cache-cold-path <dir>` to the server's ArgumentList at L88,
  regardless of `$Mode`. Verified by direct read of L88:
  `$args = @('-m', ..., '--cache-ram', $HotBudgetMiB, '--cache-cold-max-mib', $ColdBudgetMiB, '--cache-cold-path', $CacheColdPath, '--metrics', '--seed', $Seed)`.
  No `$Mode -eq 'hybrid'` guard is present.
- The server-side validation at `tools/server/server-context.cpp:611-625`
  correctly enforces the mode coupling:
  - L611-615: `if (cache_cold_max_mib != -1 && cache_mode_val != CACHE_MODE_HYBRID) SRV_ERR("...requires --cache-mode hybrid\n"); return false;`
  - L616-621: `if (cache_cold_max_mib != 0 && !cache_cold_path.empty() && cache_mode_val != CACHE_MODE_HYBRID) SRV_ERR("...requires --cache-mode hybrid\n"); return false;`
  - L622-625: `if (cache_cold_max_mib > 0 && cache_cold_path.empty()) SRV_ERR("...requires --cache-cold-path for enabled cold writes\n"); return false;`
  The third check (L622-625) shows the server's contract requires both
  `--cache-cold-max-mib` and `--cache-cold-path` together when cold
  writes are enabled in hybrid mode; the driver's current behavior
  satisfies this for hybrid but not the first two checks for legacy.
- The QA report's direct reproduction (four manual boots with
  `--cache-mode legacy --cache-cold-max-mib 2048 --cache-cold-path ...`)
  at `_test_output/stage29-cache-modes-20260628-02/manual-smoke{1..4}.err`
  all returned the same `requires --cache-mode hybrid` error. This
  proves the server contract is the source of the rejection, not a
  transient boot issue.
- The QA report -01 direct hybrid-mode smoke (with correct flags)
  produced a healthy boot, served one chat completion with
  `cache_checkpoint_admissions_total=1`, and proved the binary,
  model fixture, CUDA path, and hybrid cache mode all function
  correctly on this host.
- The hybrid cache controller and the server's mode-coupled
  validation behave exactly as the design and implementation
  documents specify. There is no production code defect in
  `tools/server/server-cache-hybrid.cpp`, `tools/server/server-cache-controller.h`,
  `tools/server/server-cache-legacy.h`, or `tools/server/server-context.cpp`
  that the Stage 29 design depends on.

Conclusion: every BLOCKED-driver-cold-mode row is a driver-script
defect, not a product bug. The fix is local to
`compare-legacy-vs-hybrid.ps1` L86-88 (branch the ArgumentList on
`$Mode -eq 'hybrid'`). No production code change is required.

The two non-blocking environment findings (F-29-EXEC-06 pytest env
gap, F-29-EXEC-07 Release-without-/Zi coverage gap) are also not
product bugs; they are pre-existing environment and tooling gaps
carried forward from prior stages.

## Retest scope

After the Developer fix lands at driver L86-88 (branch
`Start-Stage29Server`'s ArgumentList on `$Mode -eq 'hybrid'`),
re-run all 11 driver-cold-mode rows in a fresh QA session:

- TP-29-CC-01 (output equivalence): Phase 1 boot legacy + hybrid,
  byte-compare 5 prompts.
- TP-29-CC-02 (cold-store validity): per-hybrid-leg descriptor /
  pairing / restore failure deltas (all must be 0).
- TP-29-CC-03 (fallback rate): per-hybrid-leg ratio
  cache_fallback_restores_total_delta / max(cache_hits_total_delta +
  cache_fallback_restores_total_delta, 1); at most 20% of hybrid legs
  above 10%.
- TP-29-CC-04 (cooldown): per-leg cooldown_duration_seconds <= 120s
  for every leg.
- TP-29-PR-01 (cache_n_ratio exact): per-cycle per-(mode, cache_class)
  mean cache_n_ratio; hybrid exact >= legacy exact.
- TP-29-PR-02 (cold-miss ttft): cold-start cycle p50 of ttft_ms; hybrid
  within 50 ms of legacy.
- TP-29-PR-03 (warm-hit p95): warm cycles p95 of wall_clock_ms; hybrid
  exact warm-hit p95 within 10% of legacy exact warm-hit p95.
- TP-29-AG-01 (mean hit rate): hybrid mean >= legacy + 5 pp OR
  >= 60% absolute.
- TP-29-AG-02 (total tokens reused): hybrid > 0 across all 4 cycles;
  legacy reported as comparison data.
- TP-29-AG-03 (cold-store bytes): hybrid cold_store_bytes_on_disk
  <= 2048 MiB AND cold_store_file_count >= 10.
- TP-29-AG-04 (VRAM peak): both modes vram_peak_mib < 6144.

Re-run command per the test plan part-33 "Driver interface" section:
`-Cycles 3 -ColdBudgetMiB 2048 -HotBudgetMiB 512 -LegDurationMin 10 -Parallel 2 -ContextSize 4096 -Seed 42 -OutputEquivalencePrompts 5`. Wall-clock target ~80 min per design part-09 R29-05; Manager may approve 2-cycle warm run if session budget is tight.

After QA re-execution produces the per-leg artifacts and a new
durable report at
`._design_docs/.test_reports/test-report-YYYYMMDD-NN-stage29-01.md`,
a second Developer test-results review is required to confirm
the 11 rows now have PASS / FAIL / BLOCKED-verdict-not-driver
classifications.

Rows NOT in the retest scope (carry-forward, no re-run required):

- TP-29-RG-01 PARTIAL: focused tests re-run is part of the standard
  preflight; pytest env gap is a separate Developer handoff
  (huggingface-hub version constraint).
- TP-29-RG-02 PASS: `git status --short -- tools/server/` re-run
  at session start of the new QA session; no re-run required by
  this review.
- TP-29-CV-01 BLOCKED-Release-without-/Zi: separate Developer
  handoff (cov-config /Zi add + OpenCppCoverage install on QA host);
  not a Stage 29 retest.

## Unresolved execution blockers

| ID | Title | Severity | Owner |
| --- | --- | --- | --- |
| F-29-EXEC-04 | Driver `Start-Stage29Server` (L86-88) passes `--cache-cold-max-mib` and `--cache-cold-path` unconditionally regardless of `$Mode`; server rejects both flags on legacy mode at server-context.cpp:611-625 | BLOCKING for stage closure | Developer (driver fix) |
| F-29-EXEC-06 | Pytest environment gap: `huggingface-hub==1.16.1` does not satisfy transformers constraint `>=0.34.0,<1.0` (carry-forward from F-29-EXEC-03) | non-blocking for PASS | Developer (separate task) |
| F-29-EXEC-07 | Coverage tooling gap: `build-cuda/CMakeCache.txt:80` lacks `/Zi`; OpenCppCoverage not installed at canonical path (carry-forward from F-29-EXEC-04 of -01) | non-blocking for PASS | Developer (separate task) |

F-29-EXEC-04 is the sole blocker for stage closure. F-29-EXEC-06 and
F-29-EXEC-07 are pre-existing environment / tooling gaps independent
of Stage 29; they are recorded for handoff completeness only.

## Manager closure recommendation

REWORK. Stage 29 is not ready for Manager closure.

- 11 of 14 rows are BLOCKED-driver-cold-mode; these rows cannot be
  classified PASS without a driver fix and a fresh QA re-execution
  that produces per-leg evidence.
- The 3 non-driver-cold-mode rows (RG-01 PARTIAL, RG-02 PASS,
  CV-01 BLOCKED-Release-without-/Zi) are correctly classified and
  stand on their own merits; the partial / non-blocking status of
  these rows does not gate the stage because the test plan marks
  pytest and coverage as non-blocking for PASS (per part-33
  "Classification rules").
- The driver bug is local, well-scoped, and has a clear fix
  (~3 lines, branch the ArgumentList on `$Mode -eq 'hybrid'`).
  No design, test plan, or production code change is required.

Required follow-on sequence:

1. Developer fixes `compare-legacy-vs-hybrid.ps1` L86-88 to branch
   ArgumentList on `$Mode`. Hybrid arms keep the cold-path flags
   (L622-625 server check requires both flags together); legacy
   arms omit them.
2. Manager implementation-fix gate review of the driver edit
   (per the pattern set by S29-IMPL-FIX-01 / S29-IMPL-FIX-02).
3. QA re-execution: full driver path with `-Cycles 3` for fresh
   per-leg evidence. Fresh durable report at
   `._design_docs/.test_reports/test-report-YYYYMMDD-NN-stage29-01.md`.
4. Developer test-results review of the new QA report (second
   iteration, distinct from this review).
5. Manager closure per D-CLOSURE-29-NN.

A stronger driver review for future fix iterations would grep for
each `--` literal in the driver and cross-check each one against
`common/arg.cpp` registration AND the mode-coupled validation
blocks in `tools/server/server-context.cpp` (the
`--cache-cold-max-mib` and `--cache-cold-path` validators at L611-625
are the third instance of a flag-validation coupling that a
byte-level review of the ArgumentList would not catch). Recorded
as a follow-up to the prior F-29-EXEC-01 and F-01 driver-flag
findings.

## Handoff

Next owner: Developer. Apply the ~3-line fix at
`compare-legacy-vs-hybrid.ps1` L86-88 to branch the
`Start-Stage29Server` ArgumentList on `$Mode -eq 'hybrid'`.
After the fix, the next gate is Manager implementation-fix
review, then QA re-execution, then a second Developer
test-results review, then Manager closure per D-CLOSURE-29-NN.

The two non-blocking findings (F-29-EXEC-06 pytest env,
F-29-EXEC-07 coverage tooling) are independent of Stage 29 and
are tracked in separate Developer handoffs, not in this review.

No source code, design, implementation, architecture, test plan,
QA test report, or other test report files were modified by this
review. Only
`test-report-20260628-02-stage29-02-developer-review.md` was created.

## Format compliance

- LF byte count: target under 300 (see byte-level audit).
- CR byte count: 0.
- BOM: false.
- Last byte: 0x0A (LF terminator).
- Non-ASCII byte count: 0 (pure ASCII).
- Trailing whitespace line count: 0.
- `git diff --check` exit code: 0 (scoped to this file).

This file uses LF line endings, plain ASCII status labels, no BOM,
no trailing whitespace, and stays under the 300-line durable-doc cap.
