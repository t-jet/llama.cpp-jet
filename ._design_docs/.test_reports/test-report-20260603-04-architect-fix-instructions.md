# Stage 10 bug-fix architectural instructions

Reviewer: Architect agent
Date: 2026-06-04

Source reports:

- `._design_docs/.test_reports/test-report-20260603-04.md` (main QA re-execution report, FAIL on T114/T115, BLOCKED on T121)
- `._design_docs/.test_reports/test-report-20260603-04-fixes.md` (bug-fix handoff with product code audit)
- `._design_docs/.test_reports/test-report-20260603-03.md` (prior run, 73.15% on hybrid-mode denominator)
- `._design_docs/.test_reports/test-report-20260603-03-fixes.md` (T114/T115/T121 row classification)

Stage: 10 (Observability, security review, and hardening). Status: implementation
re-review PASS, QA CLOSED with documented T114/T115/T121 BLOCKED
reclassifications, then REVERTED after the user rejected the BLOCKED-with-
evidence reclassification as a closure contract violation. This document
prescribes the concrete fixes the Developer must apply so QA can re-execute
and the Manager can re-evaluate closure.

---

## 1. T114 - Raise coverage to >= 80%

### Current state

- Combined line rate from `coverage-merged.xml` root attributes:
  `line-rate="0.20685042107930671"`, `lines-covered="35099"`,
  `lines-valid="169683"`. Reported in
  `test-report-20260603-04.md` "Coverage (T114) - FAIL" and in
  `test-report-20260603-04-fixes.md` section 3.
- The 169,683-line denominator includes every source file linked into the 8
  focused test binaries (system headers, STL, etc.) because the prior
  bug-fix loop merged raw .cov files without re-running
  `run_coverage.ps1`. The 2026-06-03 prior run used
  `run_coverage.ps1` and reported the hybrid-mode denominator
  19889/27191 = 73.15% (see
  `test-report-20260603-03.md` section 6 and per-file table).
- The hybrid-mode denominator (the 19 files in `$denomBasenames` in
  `run_coverage.ps1` lines 226-244) is the T114 contract. Raising the
  merged XML root rate is not required; raising the per-file rates of
  these 19 files above 80% is the closure contract.
- Per-file baselines from the 2026-06-03 run
  (`test-report-20260603-03.md` section 6 table):

  | File | Covered | Valid | Rate | Notes |
  | --- | --- | --- | --- | --- |
  | server-cache-hybrid.cpp | 1166 | 1846 | 63.16% | largest gap |
  | server-cache-hybrid.h | 78 | 140 | 55.71% | header debug hooks |
  | server-cache-store-cold.cpp | 174 | 218 | 79.82% | just below 80% |
  | server-cache-store-cold.h | 20 | 27 | 74.07% | include lines |
  | server-cache-controller.cpp | 5 | 6 | 83.33% | already PASS |
  | server-cache-controller.h | 0 | 5 | 0% | 5-line header |
  | server-cache-graph.cpp | 463 | 531 | 87.19% | already PASS |
  | server-cache-graph.h | 19 | 20 | 95.00% | already PASS |
  | server-cache-io-worker.cpp | 130 | 154 | 84.42% | already PASS |
  | server-cache-policy-lru.cpp | 19 | 27 | 70.37% | small surface |
  | server-cache-legacy.h | 0 | 1 | 0% | 1-line header |
  | 8 focused test files | 95-100% | - | >= 95% | already PASS |

- New product code added in the 2026-06-03 bug-fix session
  (`test-report-20260603-04-fixes.md` section 8) increased the
  per-file valid-line counts in `server-cache-store-cold.cpp/h` and
  `server-cache-hybrid.cpp/h`. The coldstore `delete_ids` fix from
  this session added a new test
  `test_cold_store_delete_ids` at
  `tests/test-stage10-cold-store-hardening.cpp:475` and the new
  `test_cold_store_remove_nonexistent` (post-fix). Both PASS but
  cover only a small fraction of the store-cold surface.

### Architectural constraint

`cache-handling-test-plan/part-12-stage10-observability-security-hardening.md`
T114 row: "A coverage run proves at least 80% coverage for the reviewed
hybrid-mode denominator, including observability emission, cold-store
hardening, descriptor validation, hot/cold transitions, branch and Stage 8
paths, checkpoint paths, and target/draft pairing."

`cache-handling-phase10-implementation.md` "B1" correction closed by
`part-04-architect-plan-re-review-gate.md` requires the coverage tool,
command family, branch capability, fallback exception, denominator, and
exclusions to be defined before code work starts. The denominator is the
19 files in `$denomBasenames` of
`._design_docs/cache-handling-test-scripts/run_coverage.ps1` lines 226-244.

`test-report-20260603-04.md` "Final counts" classifies T114 FAIL and the
implementation log "Stage 10 bug-fix loop 2026-06-03" records the user
rejected the BLOCKED-with-evidence reclassification. The 80% threshold
remains a closure contract.

### Fix instructions

Step 1: Re-run `run_coverage.ps1` against the current
`build` directory and capture the current hybrid-mode denominator
rates. This is the baseline the new tests must beat. Save the
resulting `coverage-report.md` to
`._design_docs/.test_reports/test-report-20260603-05-artifacts/coverage/coverage-report.md`
under a fresh `test-report-20260603-05` artifacts tree (do not overwrite
the 04 artifacts). Command:

```powershell
& '._design_docs\cache-handling-test-scripts\run_coverage.ps1' `
    -BuildDir 'build' `
    -Config 'Release' `
    -OutDir '._design_docs\.test_reports\test-report-20260603-05-artifacts\coverage' `
    -Port 8145
```

Step 2: Identify the per-file deltas needed. For each file below the
80% threshold in the new `coverage-report.md`, identify the uncovered
line ranges. The source files are:

- `tools/server/server-cache-hybrid.cpp` (priority 1: largest gap)
- `tools/server/server-cache-hybrid.h`
- `tools/server/server-cache-store-cold.cpp`
- `tools/server/server-cache-store-cold.h`
- `tools/server/server-cache-controller.h` (5 lines, expects 0/5)
- `tools/server/server-cache-policy-lru.cpp`
- `tools/server/server-cache-legacy.h` (1 line, expects 0/1)

For each uncovered line range, classify it as one of:
(a) test-hook code path (exercise via existing `debug_*` helpers or
    new helpers in the same file);
(b) failure-mode branch (exercise via existing fault-injection hooks
    in `server-cache-store-cold.h:154-156`,
    `server-cache-io-worker.h:86-88`, and
    `server-cache-hybrid.h:300-326`);
(c) production flow path (exercise via a new focused test that drives
    the hybrid controller through the path).

Step 3: Add focused tests, using the existing patterns. Do NOT add
production code or new test hooks; use the existing 30+
`debug_*` helpers. Preferred patterns:

- Extend `tests/test-cache-controller.cpp` for hybrid-mode path
  coverage. Existing test names follow
  `test_<feature>_<expected_outcome>` (e.g.,
  `test_hybrid_lru_eviction_by_token_limit`). Add tests that
  exercise the uncovered ranges in
  `server-cache-hybrid.cpp` and `server-cache-hybrid.h`, using
  `debug_add_entry_for_tests`,
  `debug_set_hot_payload_budget_bytes_for_tests`,
  `debug_admit_checkpoint_for_tests`,
  `debug_validate_first_payload_for_tests`,
  `debug_get_compatibility_key_for_tests`, and
  `debug_acquire_first_branch_ref_for_tests` (declared at
  `tools/server/server-cache-hybrid.h:300-326`).
- Extend `tests/test-step10-metrics.cpp` for metric surface paths in
  `server-cache-hybrid.cpp` and `server-context.cpp` get_stats
  emission. Existing pattern at
  `tests/test-step10-metrics.cpp:329-373` (test 9,
  `test_stage10_prometheus_export_dimensions`) shows how to call
  `server_cache_stage10_prometheus_rows_for_tests`.
- Extend `tests/test-stage10-cold-store-hardening.cpp` for cold-store
  surface. Existing pattern at
  `tests/test-stage10-cold-store-hardening.cpp:475` shows the
  `delete_ids` test that was added in this session.
- If a new test file is needed, follow the existing naming
  convention (e.g., `tests/test-stage10-policy-lru.cpp`) and add
  the source to `tests/CMakeLists.txt` next to
  `test-stage10-cold-store-hardening`. The CMake target must be
  compiled with `-DLLAMA_SERVER_CACHE_TESTS=1` so the
  `LLAMA_SERVER_CACHE_TESTS`-gated `debug_*` helpers are visible.

Step 4: Per-file targets after the new tests:

| File | Current | Target | New test functions expected |
| --- | --- | --- | --- |
| server-cache-hybrid.cpp | 63.16% | >= 80% | at least 4 new `test_<feature>_<outcome>` functions covering uncovered lines in admission, eviction, restore ranking, descriptor validation, and namespace key branches |
| server-cache-hybrid.h | 55.71% | >= 80% | header includes and inline helpers covered by the new .cpp tests |
| server-cache-store-cold.cpp | 79.82% | >= 80% | at least 1 new test covering `delete_ids` non-existent-id path and the `path_is_under_root` lexical prefix branch |
| server-cache-store-cold.h | 74.07% | >= 80% | covered by the new .cpp test |
| server-cache-controller.h | 0% | >= 80% | add 1 new test that exercises the inline helper at the 5 lines; 4 of 5 lines are covered by extending `test_hybrid_cache_entry` in `test-cache-controller.cpp` |
| server-cache-policy-lru.cpp | 70.37% | >= 80% | add 1 new test calling `server_cache_policy_lru::plan_evictions` with a protected-root entry and a non-protected entry |
| server-cache-legacy.h | 0% | >= 80% | add 1 new test that constructs a legacy controller and reads the inline constant |

Step 5: Build the new tests and verify they pass. Required build
command:

```powershell
cmake --build build --config Release --target `
    llama-server `
    test-cache-controller `
    test-step10-metrics `
    test-stage10-cold-store-hardening `
    test-step6-demotion-protocol `
    test-step7-promotion-protocol `
    test-step11-test-hooks-fault-injection `
    test-step12-branch-graph `
    test-step13-stage8 `
    test-stage10-policy-lru `
    -j 4
```

Run the focused tests with ctest:

```powershell
ctest --test-dir build -C Release -R `
    "test-(cache-controller|step10-metrics|stage10-cold-store-hardening|stage10-policy-lru|step6-demotion-protocol|step7-promotion-protocol|step11-test-hooks-fault-injection|step12-branch-graph|step13-stage8)" `
    --output-on-failure
```

All tests must PASS. If any FAIL, fix the new test or the underlying
product bug (audit any product change as in
`test-report-20260603-04-fixes.md` section 8 - 0 out-of-scope blocks).

Step 6: Re-run `run_coverage.ps1` and confirm the combined line rate
at the top of `coverage-report.md` is >= 0.80. The per-file table
must show every hybrid-mode file at or above 80%. Save the report
and the `coverage-merged.xml` to the new artifacts tree.

Step 7: Append a new section to
`cache-handling-phase10-implementation.md` under "Stage 10 bug-fix
loop 2026-06-03" titled "Coverage follow-up 2026-06-04". Record:
(a) per-file deltas covered by the new tests; (b) the new combined
rate; (c) the new test source paths and line ranges; (d) the
artifact paths.

### Verification

- `coverage-report.md` combined line rate >= 0.80.
- Every row in the per-file table is >= 0.80.
- New tests are listed in `tests/CMakeLists.txt` and built into the
  Release configuration.
- ctest shows all 9 (or N+1) focused tests PASS in the new
  build.

---

## 2. T115 - Fix run_coverage.ps1 per-file aggregation

### Current state

- The current `coverage-report.md` for the 2026-06-04 run is
  missing entirely. The `coverage/` directory contains
  `coverage-merged.xml`, `merge.stdout`, the 8 per-test .cov files
  in `cov-binary/`, and the `html/` index, but no markdown report.
  This is because the 2026-06-04 bug-fix loop re-ran OpenCppCoverage
  manually and skipped the script.
- The 2026-06-03 run produced a `coverage-report.md` whose per-file
  table listed each file 8 times (one row per focused test run that
  included the file). See
  `test-report-20260603-03.md` section 6, T115 row: "The merged XML
  is the authoritative source. `coverage/coverage-report.md` has a
  per-file aggregation bug: it lists each file 8 times."
- The current `run_coverage.ps1` already contains a dedup pattern
  at the per-class iteration in Phase 4 (around lines 297-302):
  `if ($seenFiles.ContainsKey($basename)) { continue }` and
  `$seenFiles[$basename] = $true`. This dedup was added between
  the 2026-06-03 run and the 2026-06-04 session. The 2026-06-04
  session did NOT re-run the script, so the
  `coverage-report.md` produced by the 2026-06-03 run (with the
  bug) is still the latest report in
  `test-report-20260603-03-artifacts/coverage/`.
- The 2026-06-04 main report classifies T115 FAIL because the
  per-file markdown table is still buggy. The test plan classifies
  T115 as a closure contract.

### Architectural constraint

`cache-handling-test-plan/part-12-stage10-observability-security-hardening.md`
T115 row: "The report lists tool, commands, included files, excluded
files, percentage, branch totals when available, fallback reason if
line coverage is used, and uncovered hybrid paths above risk
threshold."

`run_coverage.ps1` header comment (lines 1-25) and `$denomBasenames`
(lines 226-244) define the hybrid-mode denominator. The script is
the single source of truth for the per-file aggregation.

### Fix instructions

Step 1: Verify the dedup logic in
`._design_docs/cache-handling-test-scripts/run_coverage.ps1`. The
expected pattern is at the start of the per-class loop in Phase 4:

```powershell
$allClasses = $xml.SelectNodes('//class')
foreach ($cls in $allClasses) {
    $filename = $cls.'filename'
    $basename = [System.IO.Path]::GetFileName($filename)
    if ($denomBasenames -notcontains $basename) { continue }
    # OpenCppCoverage emits one <class> per <package> per source file.
    # The merged XML is a union merge, so the <lines> child is
    # identical across duplicates. Skip duplicates by basename so the
    # per-file table lists each file exactly once.
    if ($seenFiles.ContainsKey($basename)) { continue }
    $seenFiles[$basename] = $true
    ...
}
```

If the dedup lines are missing or have been removed, restore them
exactly as shown above. Do NOT change the surrounding logic; the
rest of the script is correct.

Step 2: Strengthen the dedup so a future re-ordering or split
per-class node cannot reintroduce the bug. Replace the
`ContainsKey` check with a normalized-key check that handles path
separator differences and case differences on Windows. The fix
must use `Path.GetFileName` to normalize and a case-insensitive
comparison:

```powershell
$seenFiles = @{}  # Normalized basenames already counted.
$allClasses = $xml.SelectNodes('//class')
foreach ($cls in $allClasses) {
    $filename = $cls.'filename'
    $basename = [System.IO.Path]::GetFileName($filename)
    if ($denomBasenames -notcontains $basename) { continue }
    $key = $basename.ToLowerInvariant()
    if ($seenFiles.ContainsKey($key)) { continue }
    $seenFiles[$key] = $true
    $linesHit   = 0
    $linesTotal = 0
    foreach ($line in $cls.lines.line) {
        $linesTotal++
        if ([int]$line.hits -gt 0) { $linesHit++ }
    }
    if ($linesTotal -eq 0) { continue }
    $rate = [math]::Round($linesHit / $linesTotal, 4)
    $rows.Add([pscustomobject]@{
        File      = $basename
        Rate      = $rate
        Covered   = $linesHit
        Valid     = $linesTotal
    })
    $totalCovered += $linesHit
    $totalValid   += $linesTotal
}
```

Step 3: Re-run the script and verify the per-file table lists each
file exactly once. Save the new artifacts to
`._design_docs/.test_reports/test-report-20260603-05-artifacts/coverage/`:

```powershell
& '._design_docs\cache-handling-test-scripts\run_coverage.ps1' `
    -BuildDir 'build' `
    -Config 'Release' `
    -OutDir '._design_docs\.test_reports\test-report-20260603-05-artifacts\coverage' `
    -Port 8146
```

Step 4: Verify the combined line rate at the top of the new
`coverage-report.md` matches the merged XML root attributes within
0.01. The script computes `$combinedRate` from the
`$totalCovered / $totalValid` of the per-file aggregates. The
merged XML root attributes (`line-rate`, `lines-covered`,
`lines-valid`) reflect the raw merge including all source files
of the 8 test binaries. The script's combined rate reflects the
hybrid-mode denominator. The two will NOT match in absolute terms
because the denominators differ. The per-file table itself must
list each hybrid-mode denominator file exactly once.

Step 5: Confirm with a count: count the number of `| server-cache-`
rows in the new `coverage-report.md`. With the 19-file
denominator, the count must be 19 (or 18 if one tiny file has
zero lines and is excluded by the `$linesTotal -eq 0` guard).
Open the markdown and count the rows; do not rely on the
combined rate alone.

Step 6: Append a T115 follow-up note to
`cache-handling-phase10-implementation.md` under "Stage 10
bug-fix loop 2026-06-03". Record: (a) the exact dedup line
range in the script; (b) the new combined rate; (c) the count
of per-file rows; (d) the artifact paths.

### Verification

- New `coverage-report.md` per-file table lists each hybrid-mode
  file exactly once.
- The combined rate in the markdown is computed from the
  deduplicated per-file aggregates.
- The merged XML root attributes remain authoritative for the
  raw union merge.

---

## 3. T121 - MTP fixture checkpoint admission

### Current state

- The 2026-06-04 MTP probe used the
  `Qwen3.5-4B-MTP-GGUF\Qwen3.5-4B-Q4_K_M.gguf` fixture but
  loaded with cache mode LEGACY and no speculative decoding
  configuration. Evidence: `mtp-server-stdout.log.err` line 32
  ("cache mode: legacy (FIFO, destructive hits)") and line 28
  ("no implementations specified for speculative decoding").
  The server log also shows the warning "speculative decoding
  will use checkpoints" at line 26 - this warning fires from
  the MTP model loader regardless of whether the cache mode is
  hybrid or legacy, so it is NOT proof of checkpoint
  admission.
- The `mtp-metrics-before.txt` and `mtp-metrics-after.txt` files
  are both empty (0 bytes). No `cache_checkpoint_*` rows
  appear in the live `/metrics` output.
- The two completion requests in `mtp-public-probe.ps1` lines
  100-141 returned HTTP 200 with non-empty response bodies
  (1731 bytes and 13749 bytes), so the server processed them,
  but no checkpoint descriptor was admitted.
- The root cause is the MTP probe script:
  `._design_docs/.test_reports/test-report-20260603-04-artifacts/mtp-public-probe.ps1`
  does NOT pass `--cache-mode hybrid`, `--spec-type draft-mtp`,
  or `--cache-ram` to the server start command (lines 70-78).
  The server start command is:

  ```text
  '-m', $Model, '--port', "$Port", '--host', '127.0.0.1',
  '-ngl', '99', '-c', '8192', '-np', '1'
  ```
  Without `--cache-mode hybrid`, the hybrid cache controller
  is never created (see
  `tools/server/server-context.cpp:1335` and `:992`), and
  checkpoint admission cannot occur.
- The focused substitute evidence is in
  `tests/test-cache-controller.cpp`:
  - `test_stage9_checkpoint_admission_transaction` (covers
    `cache_checkpoint_admissions_total` and
    `cache_checkpoint_admission_failures_total` count rows via
    `get_stats()` and `debug_admit_checkpoint_for_tests`)
  - `test_stage9_checkpoint_boundary_metadata` (covers
    descriptor validation paths)
  - `test_stage9_restore_ranking` (covers checkpoint-first
    and exact-first restore ranking)
  - `test_stage9_checkpoint_cold_residency` (covers cold
    checkpoint promotion)
  - `test_stage9_checkpoint_budget_eviction_and_metrics_shape`
    (covers bounded metric label shape)
- `test-report-20260603-03.md` classified T121 BLOCKED with
  the note "Qwen3-0.6B is plain-transformer; no
  checkpoint-capable fixture." That classification was
  upgraded to "BLOCKED" with a fixture search in this
  session's report, but the MTP probe still failed to
  admit a checkpoint because the probe was misconfigured.

### Architectural constraint

`cache-handling-test-plan/part-12-stage10-observability-security-hardening.md`
T121 row: "Stage 9 regression - Workload profile namespace,
checkpoint descriptor validation, checkpoint-first and exact-first
ranking, target/draft checkpoint pairing, cold checkpoint
promotion, public checkpoint metrics, and fixture-dependent public
rows remain valid."

`cache-handling-phase9-design/part-02-checkpoint-payload-lifecycle-and-interfaces.md`
defines the checkpoint descriptor admission contract: admission
requires a `hybrid_cache_controller` instance, a hybrid cache mode
configuration, a speculative type that includes
`COMMON_SPECULATIVE_TYPE_DRAFT_MTP`, and at least one
`/completion` call that exercises the MTP head.

`tools/server/server-cache-hybrid.cpp:3194-3215` defines
`draft_context_mode_id` and `has_speculative_type`. The MTP mode
returns `"mtp-target-model"` when
`is_mtp && !has_separate_draft_model`. The
`admit_latest_checkpoint` at
`tools/server/server-cache-hybrid.cpp:2914` requires
`runtime_has_draft=true` to admit a checkpoint payload.

### Fix instructions

Step 1: Update the MTP probe start command in
`._design_docs/.test_reports/test-report-20260603-04-artifacts/mtp-public-probe.ps1`
(or in a new probe script at
`._design_docs/.test_reports/test-report-20260603-05-artifacts/mtp-public-probe.ps1`).
The new server start command must include:

```powershell
$serverArgs = @(
    '-m', $Model,
    '--port', "$Port",
    '--host', '127.0.0.1',
    '-ngl', '99',
    '-c', '8192',
    '-np', '1',
    '--cache-mode', 'hybrid',     # Required: enables hybrid controller
    '--cache-ram', '512',         # Required: enables hot budget
    '--spec-type', 'draft-mtp',   # Required: enables MTP speculative decoding
    '--temp', '0',
    '--seed', '42',
    '--metrics',
    '--log-verbosity', '3'
)
```

The `--spec-type draft-mtp` value uses the name from
`common/speculative.cpp:1259` (`COMMON_SPECULATIVE_TYPE_DRAFT_MTP`
maps to the string `"draft-mtp"`). When the
`Qwen3.5-4B-Q4_K_M.gguf` fixture is loaded with this spec type,
the MTP head is discovered automatically (per
`common/arg.cpp:465-468`: "when `--spec-type mtp` is set and no
draft model was provided explicitly, fall back to the MTP head
discovered alongside the -hf model").

Step 2: Update the completion request payloads to make
checkpoint admission more likely. The current probes use short
prompts ("The quick brown fox") that may not trigger the
checkpoint path. Use a longer prompt with deterministic
boundaries and a token span that exceeds the MTP head's
default size:

```powershell
$payload = @{
    prompt = "Summarize the following document:`n`nThe llama-server hybrid cache stores exact-blob and checkpoint payloads in a hot byte-budget LRU, demotes to a cold store asynchronously, and pairs target and draft payloads for speculative decoding workloads."
    n_predict = 64
    temperature = 0
    stream = $false
    seed = 42
    cache_prompt = $true
} | ConvertTo-Json -Depth 5
```

Run at least 3 completions: the first is a cache miss that
admits an exact blob; the second and third exercise the
checkpoint restore path with the MTP head active.

Step 3: Verify the live `/metrics` output contains
non-zero `cache_checkpoint_*` rows. The relevant rows are
defined in `tools/server/server-context.cpp:4772-4813`:

```text
cache_checkpoint_restores_total{mode="hybrid",profile="checkpoint_dependent",payload_residency="hot",pair_state="target_and_draft",result="success"} N
cache_checkpoint_hits_total{mode="hybrid",profile="checkpoint_dependent",payload_residency="hot",pair_state="target_and_draft"} N
cache_checkpoint_admissions_total{mode="hybrid"} N
cache_checkpoint_admission_failures_total{mode="hybrid"} N
```

If after Step 1 and Step 2 the `cache_checkpoint_*` rows
remain zero, capture the server stdout and stderr and
diagnose:

- Confirm the server stdout shows "cache mode: hybrid" and
  not "cache mode: legacy".
- Confirm the server stdout shows a non-NONE speculative
  type, e.g. "spec type: draft-mtp".
- Confirm the MTP head was discovered: the server log
  should show "speculative decoding will use checkpoints"
  followed by a non-empty checkpoint configuration
  (token count and head name).
- If the server fails to start with the new flags (e.g.,
  the MTP head is not discoverable from the GGUF
  metadata), capture the full stderr and document the
  failure mode in the implementation log.

Step 4: If the live MTP probe admits a checkpoint
descriptor (the success case), the closure contract for
T121 is met. Save the `mtp-metrics-after.txt`,
`mtp-metrics-before.txt`, the two completion JSON files,
and the server stdout/stderr to
`._design_docs/.test_reports/test-report-20260603-05-artifacts/`.
Add a T121 follow-up section to
`cache-handling-phase10-implementation.md` under "Stage 10
bug-fix loop 2026-06-03". Record: (a) the corrected
server start command; (b) the completion payloads; (c)
the non-zero `cache_checkpoint_*` row values; (d) the
artifact paths.

Step 5: Focused-substitute evidence path (only if Step 4
cannot produce non-zero rows). If the MTP fixture still
does not admit a checkpoint descriptor via public
`/completion` after the corrected start command and
completion payloads, the closure contract cannot be met
by live evidence on this host. In that case, the
Developer must:

- Record the failure mode (server log excerpt, stderr,
  `/metrics` output) in
  `cache-handling-phase10-implementation.md` under a new
  subsection "T121 MTP probe failure mode 2026-06-04".
- Cite the focused substitute evidence that covers the
  public-row check via `get_stats()` and the focused
  exporter test:
  - `tests/test-cache-controller.cpp`
    `test_stage9_checkpoint_admission_transaction`
    (asserts `cache_checkpoint_admissions_total` and
    `cache_checkpoint_admission_failures_total` via
    `get_stats()` JSON)
  - `tests/test-stage10-cold-store-hardening.cpp`
    `test_cold_store_delete_ids` (added in this session)
  - `tests/test-cache-controller.cpp`
    `test_stage9_checkpoint_cold_residency`
  - `tests/test-cache-controller.cpp`
    `test_stage9_checkpoint_budget_eviction_and_metrics_shape`
  - `tests/test-step10-metrics.cpp`
    `test_stage10_prometheus_export_dimensions` (asserts
    the bounded label shape of the `cache_checkpoint_*`
    rows via
    `server_cache_stage10_prometheus_rows_for_tests`)
- Submit a Manager plan-change request via the
  implementation log: the T121 row in
  `cache-handling-test-plan/part-12-stage10-observability-security-hardening.md`
  classifies the row as a "Stage 9 regression" row that
  requires a fixture-dependent public row. If no
  suitable MTP fixture is available on this host, the
  test plan must record the substitute-evidence path
  and a fixture search note in a plan-change record.
- Do NOT mark T121 PASS or BLOCKED. The Developer must
  leave T121 in the "BLOCKED - focused substitute
  evidence cited" state and let the Manager re-evaluate
  after the plan-change is recorded.

### Verification

- Live `cache_checkpoint_*` rows in `/metrics` are
  non-zero (success path), OR
- Focused substitute evidence is cited in the
  implementation log with a Manager plan-change record
  (focused-substitute path).

---

## Handoff state after Developer applies these instructions

- **Owner**: Developer.
- **Next gate**: QA re-execution under a fresh
  `test-report-20260603-05` artifacts tree.
- **Pre-conditions for QA re-execution**:
  1. T114 fix applied; combined line rate >= 0.80
     confirmed in the new `coverage-report.md`.
  2. T115 fix applied; per-file table deduplication
     confirmed (each file listed exactly once).
  3. T121 fix applied; live `cache_checkpoint_*` rows
     non-zero in `/metrics`, OR focused substitute
     evidence cited with a Manager plan-change record.
  4. Implementation log updated with the T114, T115, and
     T121 follow-up sections.
- **Manager re-evaluation**: Manager will re-evaluate
  closure only after QA re-execution produces a fresh
  test report that classifies T114, T115, and T121 per
  the rules in
  `test-plan/stage-10-manager-test-plan-gate-20260602.md`
  and
  `test-plan/part-12-stage10-observability-security-hardening.md`.
  Per
  `test-report-20260603-04-fixes.md` section 2 ("T114
  coverage gap - per-file target"), the closure target
  is 80% hybrid-mode denominator; the per-file deltas
  in this document's T114 step 4 are the new test
  targets.
- **Architect re-review**: After QA passes, the
  Architect will re-review the implementation log
  follow-up sections and update
  `cache-handling-phase10-implementation.md` Part 8 or
  Part 10 (or add a new Part 11) to record the closure
  re-review.
