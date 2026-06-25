# Stage 25 implementation plan: Part 3: evidence plan

Source: [../cache-handling-phase25-implementation.md](../cache-handling-phase25-implementation.md)

This part specifies the build evidence, test evidence, and
coverage evidence that Stage 25 implementation must capture
before handoff.

## Build evidence (Step 10 + Step 11)

Required commands:

```powershell
cmake --build build-cov --config Release --target test-cache-controller -j 4
cmake --build build-cov --config Release --target llama-server -j 4
.\build-cov\bin\Release\test-cache-controller.exe
git diff --check -- tools/server/server-cache-hybrid.cpp tools/server/server-cache-hybrid.h tools/server/server-context.cpp tests/test-cache-controller.cpp ._design_docs/cache-handling-phase25-implementation.md ._design_docs/document-index.md ._design_docs/cache-handling-stage-tracker.md
```

Record per command:

- exit code (expect 0 for build, 0 for test pack)
- binary mtimes for `test-cache-controller.exe` and
  `llama-server.exe`
- total test count from the binary's printed line (expect
  `Total: 132 tests (...)`)
- per-stage PASS line counts for TP-17, TP-21, TP-22,
  TP-23, TP-24, TP-25
- new diagnostics emitted by `transaction_wait_exceeded`
  during the test pack (expect 0 unless TP-25-UT9 fires)
- any warnings emitted by the build (note location and
  severity)

If `git diff --check` reports any whitespace warning on the
implementation-log files, fix the whitespace before handoff
because the durable-doc convention requires LF-only, no
trailing whitespace, no BOM.

## Regression test evidence (Step 9)

Required PASS lines (count = 132):

| Tier | Test IDs | Count | Required outcome |
| --- | --- | --- | --- |
| Legacy | test_cache_mode_enum and others up to test_boundary_metadata | ~31 | PASS unchanged |
| Stage 5 | test_hybrid_* | ~5 | PASS unchanged |
| Stage 7 | test_stage7_* | ~4 | PASS unchanged |
| Stage 9 | test_stage9_* | ~7 | PASS unchanged |
| Stage 10 | test_stage10_* | ~9 + 3 | PASS unchanged |
| Stage 17 | test_stage17_* | ~15 | PASS unchanged |
| Stage 18 | test_stage18_* | 2 | PASS unchanged |
| Stage 21 | test_stage21_* | 6 | PASS unchanged |
| Stage 22 | test_stage22_* | 15 | PASS unchanged |
| Stage 23 | test_stage23_* | ~9 | PASS unchanged |
| Stage 24 | test_stage24_* | 2 | PASS unchanged |
| Stage 25 | test_stage25_* (TP-25-UT1..UT10) | 10 | NEW PASS |

If any TP-22 row fails, classify per the existing
`developer.md` test-results review gate: the per-row
verdict table is authoritative; the prose summary may
disagree by a counting typo. Report the per-row sum.

## New test coverage (Step 9)

### TP-25-UT1 atomic transaction blocks concurrent writes

Spawn two threads. Thread A enters `tx_save` with a
controlled-failure injected at the eligibility check
(e.g., target_size=0) and a thread-yield before mutation.
Thread B enters `tx_demote_payload` for a known payload
and observes the lock wait.

Assertion: Thread B waits until Thread A exits. The
controller's `n_transaction_wait_exceeded` counter
increments by 1 if Thread B's wait exceeds the threshold
(forced by an artificial 1-second sleep on Thread A).

### TP-25-UT2 demote inline under lock

Drive `tx_demote_payload` for a hot payload. After the
call returns, the descriptor residency is `cold` (not
`demoting`) and `n_demotion_successes` increments by 1.

Assertion: residency transition is `hot -> demoting -> cold`
in one call. No intermediate state observable.

### TP-25-UT3 promote inline under lock

Drive `tx_promote_payload` for a cold payload. After the
call returns, the descriptor residency is `hot` and
`n_promotion_successes` increments by 1.

Assertion: residency transition is `cold -> promoting -> hot`
in one call. The byte record is present in `hot_payloads`.

### TP-25-UT4 save admit evict under lock

Drive `tx_save` with a payload that exceeds the hot
budget. The transaction calls `tx_evict_entry` on the
plan victim first, then admits the new entry. After the
call returns, the cache has the new entry and the victim
entry is evicted.

Assertion: the LRU victim is gone; the new entry is in
`entries`; the resident bytes are within budget.

### TP-25-UT5 restore plan apply split

Drive `tx_restore` with a hot exact blob hit. The
returned plan is `RestorePlan(exact_blob_hot)`. The slot
thread applies the plan outside the lock. Then drive
`tx_apply_restore` with the plan; the second call's
critical section records owner-view sync and increments
`n_apply_restore_owner_view_syncs`.

Assertion: the apply step does not hold the cache-state
lock (verified by inserting a sleep inside the apply stub
and observing that a parallel `tx_demote_payload` from
another thread does not block).

### TP-25-UT6 reentrancy depth limit

Drive `tx_save` from a debug helper that simulates a
reentrant call at depth 5. The reentrant call returns
false and emits a `cache_diag::internal_error`
diagnostic. The state is unchanged.

Assertion: counter at depth 5 fails; counter at depth 4
succeeds for the documented inner-call set.

### TP-25-UT7 no async completion drain

Drive `tx_demote_payload` for a hot payload. Call
`process_completions()` afterward. The call is a no-op
because there are no queued completions.

Assertion: `process_completions()` returns immediately;
`n_demotion_successes` is incremented by exactly 1 from
the `tx_demote_payload` call alone.

### TP-25-UT8 worker thread idle after migration

Inspect the controller's `io_worker` member after the
construction completes. The thread primitive is in a
non-running state.

Assertion: `io_worker.is_running()` returns false on a
controller constructed with a non-empty cold path.

### TP-25-UT9 transaction_wait_exceeded diagnostic

Drive a transaction with a 600 ms artificial sleep
inside the critical section. From a second thread, drive
`tx_update()` and record the elapsed wait time.

Assertion: the diagnostic counter
`n_transaction_wait_exceeded` increments by 1 on the
waiting thread; the waiting thread completes successfully.

### TP-25-UT10 concurrent slot requests N=4 contention

Spawn 4 threads, each entering `tx_save` with a
distinct entry and a 50 ms sleep inside the critical
section. Record the per-thread wait time.

Assertion: the 4 transactions complete in serial order
(each thread's wait time + critical section time
approximately matches serial execution). No thread
crashes; no diagnostic fires because the wait stays
under the 500 ms threshold.

## Coverage evidence (Step 10 + Step 11)

Build a Debug test binary with symbols (per the existing
architecture Part 4 line-coverage procedure):

```powershell
cmake -S . -B build-coverage -DLLAMA_BUILD_TESTS=ON -DBUILD_SHARED_LIBS=OFF
cmake --build build-coverage --config Debug --target test-cache-controller
```

Run OpenCppCoverage focused on the hybrid cache sources
and the test binary:

```powershell
D:\app\OpenCppCoverage\OpenCppCoverage.exe `
  --sources D:\source\llama.cpp-jet\tools\server\server-cache-hybrid.cpp `
  --sources D:\source\llama.cpp-jet\tools\server\server-cache-hybrid.h `
  --sources D:\source\llama.cpp-jet\tools\server\server-cache-controller.cpp `
  --sources D:\source\llama.cpp-jet\tools\server\server-cache-controller.h `
  --sources D:\source\llama.cpp-jet\tests\test-cache-controller.cpp `
  --export_type html:D:\source\llama.cpp-jet\build-coverage\coverage-cache-html `
  --export_type cobertura:D:\source\llama.cpp-jet\build-coverage\coverage-cache.xml `
  -- D:\source\llama.cpp-jet\build-coverage\bin\Debug\test-cache-controller.exe
```

Coverage thresholds (from architecture Part 4):

- T114 product-only line coverage >= 0.80
- T114a hybrid.h per-file line coverage >= 0.70

Record the post-implementation rate and compare against
the Stage 24 baseline. Stage 25 must maintain or improve
the rates (the new `tx_*` methods add new lines that the
TP-25 unit tests cover; the net coverage delta should be
neutral or positive).

If coverage drops below threshold, classify per the
existing test-results review gate as BLOCKED-coverage-setup
(inherited Stage 16 closure exception F-16-TR-03) and
report the actual rate.

## Stage 24 chat S02/S03 rerun evidence (Step 11)

Run the existing `stage24-chat-s02-s03-comparison.ps1`
runner with the same Qwen3.5-4B MTP fixture and the same
hybrid flags used in test-report-20260624-06:

```powershell
& ._design_docs\cache-handling-test-scripts\stage24-chat-s02-s03-comparison.ps1 `
  -RunId stage25-chat-s02-s03-20260625-01 `
  -RowsToRun S02-chat,S03-chat `
  -ModelPath '._test_models\Qwen3.5-4B-MTP-GGUF\Qwen3.5-4B-Q4_K_M.gguf' `
  -RunRoot '._test_output\stage25-chat-s02-s03-20260625-01' `
  -ReportPath '._design_docs\.test_reports\test-report-20260625-01.md' `
  -CacheColdPath 'D:\tmp\cache-cold-stage25' `
  -BasePort 8900 `
  -LegDurationMin 10 `
  -ColdBudgetMiB 512 `
  -LlamaServerPath 'build-cuda\bin\Release\llama-server.exe'
```

Compare against test-report-20260624-06 baseline:

- S02-chat hybrid: expected PASS (Stage 24 PASS) with p50
  latency within +5% and p99 latency within +10%.
- S03-chat hybrid: expected PASS or BLOCKED-structural
  (D-EXEC-24-03 silent crash; out of scope for Stage 25
  per Part 4 risk R-25-04).
- S02/S03 native-legacy: expected PASS unchanged.

Record the comparison in the implementation log.

## Implementation log update evidence (Step 12)

Update `cache-handling-phase25-implementation.md` and
each part file with:

- final state per step (PASS / PARTIAL / BLOCKED)
- changed-file list with exact line ranges
- new test names and per-row verdict
- binary mtimes for both Debug and Release
- coverage delta from the focused OpenCppCoverage run
- Stage 24 chat rerun verdict
- any warnings emitted by the build or tests
- exit codes for the three required commands
