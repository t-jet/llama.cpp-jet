# Test plan part 26: Stage 16 chat-path prompt-span boundary (post-closure fix)

Status: PASS
Date: 2026-06-16
Stage: 16
Branch: work-branch
Owner: QA (test planning, fresh session)
Source: [../cache-handling-test-plan.md](../cache-handling-test-plan.md)

## Scope

Stage 16 fixes the chat-path prompt-span boundary gap surfaced by the
2026-06-16 model log analysis. The fix is a 14-line insertion in
`cache_metadata_from_chat_messages` (server-context.cpp:4486-4498) that
emits one `MESSAGE_END` boundary at `[0, n_prompt_tokens]` with
`metadata = "prompt"` when the chat path produced at least one
per-message boundary. The hybrid cache checkpoint path can then attach
the first end-of-prefill checkpoint whose `n_tokens` equals the full
prompt size; the strict validator no longer rejects on missing
boundary metadata.

This part integrates 9 test plan rows (7 operational + 2 unit) for QA
verification. It does not re-plan Stage 15, the B05/B06 fix, or any
closed stage. The post-fix MTP /v1/chat/completions path replaces the
2026-06-13 BLOCKED-structural-not-infra classification.

Inputs (read in order, all durable):

- [Design correction](../../cache-handling-phase15-design/part-09-post-closure-chat-path-prompt-boundary.md) (Option A, surgical)
- [Architecture invariant](../../cache-handling-architecture/part-09-chat-path-prompt-boundary-invariant.md) (three-entry-point model, verification paths)
- [Implementation plan](../../cache-handling-phase16-implementation/part-01-implementation-plan.md) (Tests section, Evidence plan, Manager decisions)
- [Architect design review](../../cache-handling-phase16-design/part-01-design-review-gate-01.md) (PASS, F-16-02 = missing TP-15-UT1/UT2)
- [Architect implementation review](../../cache-handling-phase16-implementation/part-02-architect-implementation-review-gate-01.md) (PASS, F-16-IR-02 = TP-15-UT1/UT2 still missing)
- [Stage 15 V2 baseline](../.test_reports/stage15-benchmark-20260613-03.md) (29/29 restores on separate-draft, baseline for TP-15-PC4)
- [Stage 15 MTP structural probe](../.test_reports/stage15-benchmark-20260613-02.md) (0/30 restores on MTP, pre-fix state)

## Prerequisites and clean-build rule

Build directory: `build-cov` (per Stage 10 closure contract; uses
OpenCppCoverage with `--export_type binary` and per-file aggregation).
Binary: `build-cov/bin/Release/llama-server.exe`.

Clean-build rule (mandatory before every test session):

```powershell
Remove-Item -Recurse -Force build-cov -ErrorAction SilentlyContinue
cmake -S . -B build-cov -DCMAKE_BUILD_TYPE=Release
cmake --build build-cov --config Release --target llama-server -j 4

$Binary = Get-Item build-cov\bin\Release\llama-server.exe
$BuildAge = (Get-Date) - $Binary.LastWriteTime
if ($BuildAge.TotalMinutes -gt 10) {
    throw "llama-server.exe is stale. Run the clean build again."
}
```

Build must exit 0. Recompiles `server-context.cpp` only (the only
file changed by commit `ae2df9657`). A stale or incrementally
rebuilt binary is not test evidence. The fix changes one function
in one file; no other source files require rebuild for the
operational rows. The unit-test rows (TP-15-UT1, TP-15-UT2) require
`test-cache-controller` target rebuilt; record the new target list
in the test report.

## Test plan rows

Nine rows total. Operational rows TP-15-PC1..PC7 are required for
PASS. Unit rows TP-15-UT1, TP-15-UT2 are recommended but
non-blocking for PASS (per Architect design review F-16-02 and
implementation review F-16-IR-02; they lock the contract at the
unit-test level).

| ID | Type | Description | Fixture | Evidence path | Expected outcome | Required | Source |
| --- | --- | --- | --- | --- | --- | --- | --- |
| TP-15-PC1 | operational | `n_checkpoint_payload_descriptors > 0` on `/v1/chat/completions` with MTP fixture after first save; was 0 pre-fix | MTP (Qwen3.6-27B) | `test-report-20260616-01.md` C-pc1 + `metrics-after.txt` | post-fix >= 1; pre-fix = 0 | Yes | design part-09 |
| TP-15-PC2 | operational | `cache_checkpoint_admissions_total{mode="hybrid"} > 0` after first chat-completion save; was 0 pre-fix | MTP | same report C-pc2 | post-fix >= 1 | Yes | design part-09 |
| TP-15-PC3 | operational | `cache_checkpoint_admission_failures_total{mode="hybrid"}` no increase on chat-completion save; was 1/save pre-fix | MTP | same report C-pc3 | delta = 0 across 1 warmup + 29 identical | Yes | design part-09 |
| TP-15-PC4 | operational | hybrid-mode `/v1/chat/completions` MTP fixture produces `cache_n > 0` on subsequent identical requests (29/30 or 30/30 expected, mirrors V2 29/29) | MTP | `stage16-benchmark-20260616-01.md` | 29/30 or 30/30 success; pre-fix 0/30 | Yes | design part-09 |
| TP-15-PC5 | operational | hybrid-mode `/v1/chat/completions` multi-turn messages (system + user + assistant) produces `cache_n > 0` on subsequent identical requests | MTP | same benchmark | 29/30 or 30/30 across multi-turn prompt | Yes | design part-09 |
| TP-15-PC6 | operational | regression: hybrid-mode `/completion` (native) with MTP fixture still produces `cache_n > 0` on subsequent identical requests | MTP | same benchmark, separate sub-run | 29/30 or 30/30 (regression unchanged) | Yes | design part-09 |
| TP-15-PC7 | operational | regression: 5 `n_ctx_seq (140032) < n_ctx_train (262144)` informational warnings per server start are unchanged | MTP | server start log in test report | 5 warnings, line count match pre-fix | Yes | design part-09 |
| TP-15-UT1 | unit | structural: call `cache_metadata_from_chat_messages` with 3-message input (system, user, assistant-prefix), assert metadata has >= 1 `MESSAGE_END` boundary at `[0, n_prompt_tokens]` with `metadata == "prompt"` | none (pure metadata) | `test-report-20260616-01.md` C-ut1 + ctest log | assertion PASS | No (recommended) | architecture part-09 Verification 1 |
| TP-15-UT2 | unit | degenerate: call `cache_metadata_from_chat_messages` with empty `messages` array, assert no prompt-span boundary added (conditional `!messages.empty()` guard) | none | same report C-ut2 | assertion PASS; boundaries count = 0 | No (recommended) | design review degeneracy |

## Test automation scripts

Operational rows TP-15-PC1..PC7 reuse the Stage 15 B05/B06 benchmark
driver with a route swap. The driver at
`._test_output/bench-stage15-20260613-b56-fix/` and the report at
[stage15-benchmark-20260613-03.md](../.test_reports/stage15-benchmark-20260613-03.md)
record the V2 separate-draft driver body. For Stage 16 the driver
body changes from native `/completion` (cache_prompt:true) to
`/v1/chat/completions` (messages array). All other inputs unchanged
(model, port, flags, prompt, n_predict, seed, iterations).

Scripts to be created or reused (test-execution session scope;
this plan defines inputs only, not runs):

| Script | Purpose | Inputs | Output |
| --- | --- | --- | --- |
| `stage16-chat-path-benchmark.ps1` | new wrapper around the V2 driver with route swap to `/v1/chat/completions`; runs TP-15-PC4 | MTP model path, port, prompt, n=30 iterations, n_predict=8, seed=42, hybrid mode | per-request table, metrics-before.txt, metrics-after.txt, server logs |
| `stage16-completion-regression.ps1` | new wrapper that runs the V2 native `/completion` driver unchanged for TP-15-PC6 regression | same as above with native endpoint | per-request table |
| `stage16-multi-turn.ps1` | new wrapper for TP-15-PC5 with 3-message chat input (system, user, assistant-prefix) | messages JSON, port, hybrid mode | per-request table |
| `test-cache-controller` ctest | existing, extended with two new test cases (TP-15-UT1, TP-15-UT2) | `--gtest_filter` not used (custom runner, not gtest; per `qa.md` improvement memory) | per-test PASS/FAIL |
| `run_coverage.ps1` | existing, OpenCppCoverage union on `build-cov` with per-file aggregation, T114/T114a/T115 closure | focused test binaries + HTTP probe | `coverage-merged.xml`, `coverage-report.md` |

The V2 driver body is at `stage15-benchmark-20260613-03.md`
"Per-request results" table. The Stage 16 driver body differs by
endpoint URL and request payload only. Stage 15 sub-sessions
recorded the binary at
`build-cov/bin/Release/llama-server.exe` (27,117,056 bytes,
2026-06-13 21:40:00) before the post-closure follow-up; the
test-execution session must rebuild per the clean-build rule.

## Evidence format

Durable evidence paths under `._design_docs/.test_reports/`:

| Artifact | Path | Notes |
| --- | --- | --- |
| Test report | `test-report-20260616-01.md` | next available suffix; per-row verdict, evidence path, owner |
| Bug-fix loop file | `test-report-20260616-01-fixes.md` | only if a row opens the loop |
| Benchmark report | `stage16-benchmark-20260616-01.md` | per Manager decision C; mirrors stage15-benchmark-20260613-03.md structure; MTP `/v1/chat/completions` |
| Coverage evidence | `coverage-run-20260616/coverage-report.md` + `coverage-merged.xml` | OpenCppCoverage union, per-file aggregation |

Non-durable (`.gitignore`d) under `._test_output/`:

| Artifact | Path |
| --- | --- |
| Per-row HTTP logs | `bench-stage16-20260616/pcNN-<row>/server.out.log`, `server.err.log` |
| Metrics snapshots | `bench-stage16-20260616/pcNN-<row>/metrics-before.txt`, `metrics-after.txt` |
| ctest log | `ctest-20260616-01.log` |
| Coverage raw | `coverage-run-20260616/*.cov` |

Long-running and stress rows are not applicable to Stage 16
(no S/L rows in this test plan; see Exclusions).

## Coverage measurement

Per-file aggregation, OpenCppCoverage, `build-cov` Release. Stage 10
T114/T114a/T115 closure contract continues to apply, plus the new
Stage 16 targets.

Closure contract (Stage 10, unchanged):

- T114 combined rate `>= 0.80` on the reviewed hybrid-mode denominator
- T114a product-only rate `>= 0.70` on the 11 product files
- T115 per-file aggregation (dedup by lowercased full path)
- Aggregation rule: union by (file, line) taking max `hits` per
  duplicate `<class>` block per `qa.md` improvement memory rule
  `dedupe OpenCppCoverage merged Cobertura XML by (file, line)`

Stage 16 specific targets (per user reminder, treat as closure contract):

- **Line coverage on new code path**: 100% on the 14-line insertion
  in `cache_metadata_from_chat_messages`
  (server-context.cpp:4486-4498) and the immediate surrounding code
  (per-message loop closure + `return metadata;`).
- **Branch coverage on new code path**: 100% on the
  `!messages.empty()` conditional (both branches: empty array = no
  boundary; non-empty array = boundary added).
- **Unit test coverage target**: 100% on TP-15-UT1 (3-message input,
  boundary added) and TP-15-UT2 (empty array, no boundary). The
  structural unit tests must cover both branches of the conditional.
- **Regression coverage target**: the 20+ existing tests in
  `tests/test-cache-controller.cpp` continue to pass without
  modification. No new failures allowed.

Coverage failure handling: if the new code path has < 100% line or
branch coverage, the affected test plan row is `FAIL` (not
`BLOCKED`). QA routes `FAIL` rows to the bug-fix loop per Manager
decision in part-25 (max 3 iterations). The coverage file path
follows Stage 10 format (`coverage-report.md` markdown plus
`coverage-merged.xml` Cobertura). The new code path's line and
branch rates are reported as separate sub-rows in the coverage
section of the test report.

Coverage measurement methodology (per Stage 10 closure contract):

- Tool: `OpenCppCoverage.exe` (Windows MSVC profile)
- Build: `build-cov` Release, `CMAKE_CXX_FLAGS_RELEASE` includes
  `/Zi` and `/DEBUG:FULL` per `qa.md` improvement memory
  `distinguish Release-build coverage gap from Start-Process bug`
- Per-test `.cov` files via `--export_type binary:` invocation;
  merged with `--input_coverage` to produce
  `coverage-merged.xml` (Cobertura).
- Per-file aggregation by lowercased full path (T115); no double
  counting of `<class>` duplicates.
- Server HTTP probe included in coverage run when target files
  contain server integration paths (chat path = server-side).

## Report format

Test report `test-report-20260616-01.md` follows the test plan's
test-report-quality rules at
[part-07](./part-07-test-report-quality-and-templates.md):

- Markdown only, no unicode icons, plain ASCII status labels
  (`PASS`, `FAIL`, `BLOCKED`, `SKIP`).
- Per-row verdict table with columns: ID, type, description,
  evidence path, expected, actual, verdict, owner.
- Header: date, owner, stage, build directory, binary timestamp,
  git commit SHA, dirty worktree state, binary path.
- Bug-fix loop file `test-report-20260616-01-fixes.md` follows the
  same shape; opened only if a row returns `FAIL` or `BLOCKED`.
- Benchmark report `stage16-benchmark-20260616-01.md` mirrors
  [stage15-benchmark-20260613-03.md](../.test_reports/stage15-benchmark-20260613-03.md)
  sections (header, environment, build evidence, per-request table,
  per-metric comparison, regression detection, summary, handoff).
- Coverage section reports T114, T114a, T115 rates plus Stage 16
  new-code-path line/branch rates as sub-rows.

## Run evidence per category

For each row the test report records: clean-build evidence (build
command, binary timestamp, git commit SHA), run evidence (server
start log with 5 `n_ctx_seq` warnings for TP-15-PC7, `/metrics`
snapshot before/after for TP-15-PC1..PC3, per-request response body
with `cache_n` for TP-15-PC4..PC6, ctest output for TP-15-UT1/UT2),
expected vs actual numeric values, and per-row verdict.

Pre-fix baseline (MTP /v1/chat/completions path):

- 0/30 successful restores (stage15-benchmark-20260613-02.md,
  BLOCKED-structural-not-infra)
- 10/10 `hybrid cache: checkpoint admission skipped (missing
  checkpoint boundary metadata)` warnings
  (`d:\source\llama.cpp-jet\._analysis\model_log.txt` lines 1-100
  baseline)
- 0 `n_checkpoint_payload_descriptors` in cache stats

Expected post-fix state on the same MTP fixture: 29/30 or 30/30
successful restores; 0 admission_skipped warnings on chat-completion
paths; non-zero `n_checkpoint_payload_descriptors` and
`cache_checkpoint_admissions_total` after first save.

## Pass/fail criteria

- **Operational rows TP-15-PC1..PC7 required for PASS.**
  All 7 must return `PASS`. Any `FAIL` or `BLOCKED` opens the
  bug-fix loop.
- **Unit rows TP-15-UT1, TP-15-UT2 recommended but non-blocking for
  PASS.** If unit-test code is not yet written, the rows return
  `BLOCKED-pending-test-code` and the operational rows still drive
  the verdict. The Manager decision C recommendation accepts this
  state.
- **Coverage 100% on new code path required for PASS.** If line or
  branch coverage on `server-context.cpp:4486-4498` is < 100%, the
  affected row is `FAIL` (not `BLOCKED`). QA routes to the
  bug-fix loop. Per `qa.md` improvement memory
  `classify available fixture no-evidence runs`: a missing-coverage
  row is `FAIL`, not `BLOCKED`.
- **Regression checks (TP-15-PC6, PC7) required for PASS.** A
  regression failure on the native path or on the n_ctx_seq
  warnings count is `FAIL` and routes to the bug-fix loop.
- **Coverage closure T114 >= 0.80, T114a >= 0.70, T115 dedup rule
  met** required for PASS. Coverage setup gaps are
  `BLOCKED-coverage-setup`, not `FAIL` (per
  `distinguish Release-build coverage gap from Start-Process bug`).

## Exclusions

- **Stage 4-9 regression rows** from the test plan matrix (R10..R23,
  H30..H74) are not re-run for Stage 16. They were re-verified at
  Stage 15 closure (2026-06-13) and the post-closure follow-up
  changes one function in one file with no behavioral change to
  other code paths.
- **S01..S08 and L01..L03 stress and long-run rows** are
  DEFERRED-OUT-OF-SCOPE-FOR-SESSION per Stage 15 Manager decision
  2 (2026-06-13). Not re-run for Stage 16.
- **B02/B05/B06 benchmark rows** are NOT-IN-SCOPE for the MTP
  fixture per Stage 15 Manager decision 1 (2026-06-13). The
  reclassification is revisited per Manager decision A in the
  Stage 16 implementation plan, but only AFTER QA verification of
  TP-15-PC1..PC7 confirms the structural root cause is fixed on
  the MTP fixture. The revisit is not part of this test plan.
- **No S/L rows in this test plan.** Long-running and stress
  coverage is deferred per the rules above.
- **No new public API, CLI flag, or metric change.** Out of scope
  for Stage 16.
- **No change to the matching loop, the strict validator, the
  exact-blob path, the public API, the CLI flags, or the metrics.**
  Per design part-09 Exclusions section.

## Handoff

If PASS: next owner is **QA** in a new fresh session for the
test-plan review gate. The test-plan review verifies that the
operational rows are runnable on the current `work-branch` tree
with the MTP fixture available, that the unit-test rows map to
specific test cases in `tests/test-cache-controller.cpp`, that
the coverage measurement is correctly scoped, and that the
evidence and report format match the test plan's quality rules.

If REWORK: next owner is **QA** (this session's owner) in a new
fresh session. REWORK triggers: row set incomplete, coverage
target unclear, evidence path missing, or the clean-build rule
omitted. No source code, design, implementation, or architecture
files are modified by this plan; REWORK is a test-plan concern,
not a product concern.

After test-plan review PASS, the next gate is Manager test-plan
gate, then QA test execution, then Developer test-results review,
then Manager reclassification of B02/B05/B06 per decision A in
the Stage 16 implementation plan. The test-execution session
creates `test-report-20260616-01.md` and
`stage16-benchmark-20260616-01.md` (per Manager decision C
recommendation). The test-results review creates
`test-report-20260616-01-developer-review.md`.
