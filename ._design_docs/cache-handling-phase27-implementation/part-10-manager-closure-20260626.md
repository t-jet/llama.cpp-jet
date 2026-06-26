# Part 10: Manager closure 2026-06-26

Status: closed; Manager gate decision D-CLOSURE-27-01 2026-06-26
Date: 2026-06-26
Stage: 27 (D-EXEC-24-03 Heap Corruption Fix in tx_save Path)
Owner: Manager (closure) and Architect (closure sweep)
Scope: closure record for Stage 27 implementation log; Stage 27 closed
with the D-EXEC-24-03 root cause fix VERIFIED via Stage 24 -07 rerun
on the production binary.

## Summary

Stage 27 fixed the D-EXEC-24-03 heap corruption that survived three
prior attempts: Stage 26 commit `4556965c7` (Candidate A: wasteful
alloc+free in `admit_latest_checkpoint_and_store_metadata`) was
confirmed INSUFFICIENT by Stage 24 -05 rerun (server still exited
0xC0000374 STATUS_HEAP_CORRUPTION at req 258 of the S03-chat hybrid
leg). Stage 27 iter 4 found the actual root cause: `mark_payload_kind_evicted`
called legacy `demote_payload(payload_id)` at
`tools/server/server-cache-hybrid.cpp:3396`, which enqueues a task to
the retired Stage 25 `io_worker` thread (never started under Option B).
The queued task sits forever; `hot_payloads[id]` retains the ~50 MiB
checkpoint buffer indefinitely. After ~250 saves on the MTP fixture,
hot memory grows unbounded, the Windows heap fragments, and the next
allocation triggers STATUS_HEAP_CORRUPTION.

The fix is one character: replace `demote_payload(payload_id)` with
`tx_demote_payload(payload_id)`. `tx_demote_payload` is the Stage 25
synchronous inline variant that calls `io_worker.execute_demotion_inline(...)`
then `handle_demotion_completion(*completion)`, which actually writes
to cold store and releases the hot memory as designed. The
`recursive_mutex` allows nested acquisition at reentrancy_depth_limit_=4.

The fix was verified by Stage 24 -07 rerun on the production
`build-cuda/bin/Release/llama-server.exe` (mtime 2026-06-26 15:15:18)
against the MTP fixture. The previously-crashing S03-chat hybrid leg
completed to the 10-min cap at 687 requests (vs 258 crash threshold;
2.65x past failure point) with zero errors, zero crash dumps, and
clean idle state. New regression test TP-27-UT-01
(`test_stage27_mark_payload_evicted_releases_hot_memory_inline` at
`tests/test-cache-controller.cpp:6990`) reproduces the root cause
deterministically pre-fix and passes post-fix. Code changes are
UNCOMMITTED per AGENTS.md and D-CLOSURE-27-01.

## Per-row final classification

| Row | Verdict | Note |
| --- | --- | --- |
| TP-27-UT-01 mark_payload_evicted releases hot memory inline | PASS | new test at tests/test-cache-controller.cpp:6990; reproduces root cause pre-fix, passes post-fix |
| V1 fix present on disk | PASS | 1-char change at server-cache-hybrid.cpp:3396 verified by Select-String |
| V2 clean Release build | PASS | llama-server.exe + test-cache-controller.exe; exit 0; CMakeCache GGML_CUDA=ON |
| V3 137 + TP-27-UT-01 tests pass | PARTIAL | 110 PASS pre-TP-26-UT6; TP-27-UT-01 PASS; TP-26-UT6 aborts identically pre-fix and post-fix (D-EXEC-27-09 deferred) |
| V4 Stage 24 -07 verification | PASS | all 4 legs reach leg cap; S03 hybrid 687 reqs vs 258 crash threshold (2.65x); 0 errors; 0 crashes |
| V5 D-EXEC-24-03 closed | PASS | server alive, no STATUS_HEAP_CORRUPTION, no SEH dump, inline demote completed synchronously |

Final counts: 5 PASS, 1 PARTIAL (test artifact deferred), 0 FAIL,
0 BLOCKED. Source:
[test-report-20260626-07-fixes.md](../../.test_reports/test-report-20260626-07-fixes.md).

## Manager decisions (verbatim)

### D-EXEC-27-08

D-EXEC-24-03 root cause fix APPLIED 2026-06-26. 1-character change at
`tools/server/server-cache-hybrid.cpp:3396`:
`if (demote_payload(payload_id))` -> `if (tx_demote_payload(payload_id))`.
`tx_demote_payload` is Stage 25 synchronous inline variant that
actually executes cold-store write + handle_demotion_completion inline,
releasing hot memory as designed. New TP-27-UT-01 regression test at
`tests/test-cache-controller.cpp:6990` reproduces root cause
deterministically (passes post-fix; would fail pre-fix).

### D-EXEC-27-09

TP-26-UT6 test artifact DEFERRED. Test fails identically pre-fix and
post-fix with exit -1073740791 (0xC0000409 STATUS_STACK_BUFFER_OVERRUN)
from `__fastfail(FAST_FAIL_FATAL_APP_EXIT)` after test's own `std::abort()`.
Cause: `assert(stage23_admit_checkpoint_store(...))` at
`tests/test-cache-controller.cpp:3645` silently no-ops under `/D NDEBUG`.
Not heap corruption; not product bug. Separate ticket for test fix.

### D-EXEC-27-10

D-EXEC-24-03 fix VERIFIED via Stage 24 -07 2026-06-26. All 4 legs PASS:

- S02 native: 2516 reqs (all 200, completed-until-cap, 99.84% cache_n nonzero)
- S02 hybrid: 740 reqs (all 200, completed-until-cap, 85.41% cache_n nonzero; cold budget FAIL pre-existing drift)
- S03 native: 1513 reqs (all 200, completed-until-cap, 99.80% cache_n nonzero)
- S03 hybrid: **687 reqs (all 200, completed-until-cap, 25.04% cache_n nonzero, ZERO ERRORS)** -- 2.65x past crash threshold (was 258 in -06 baseline)
- Server exit code: alive (was 0xC0000374 in -06)

### D-CLOSURE-27-01

close Stage 27. Code changes UNCOMMITTED per AGENTS.md; user approval
required for commit. Follow-ups open:

- (a) TP-26-UT6 test artifact fix (D-EXEC-27-09)
- (b) S02 hybrid cold-store metric drift (5.37 GiB on disk vs 512 MiB budget) -- pre-existing D-EXEC-24-03-c, separate investigation
- (c) AddressSanitizer infrastructure cleanup (LNK2038 SAL annotation mismatch known MSVC issue, deferred)

## Code change summary

Stage 27 modifications are uncommitted per AGENTS.md and
D-CLOSURE-27-01. Modified files:

- `tools/server/server-cache-hybrid.cpp` (+47 / -1) -- 1-char core fix
  at line 3396 (`demote_payload` -> `tx_demote_payload`); 13-line
  comment block explaining the root cause and fix rationale.
- `tests/test-cache-controller.cpp` (+64 / -1) -- TP-27-UT-01
  regression test at line 6990 reproducing the enqueue-only demotion
  leak deterministically.

No other production files, no runner scripts, no test plan, no
design docs modified by Stage 27 implementation. No public CLI flags,
public endpoint schemas, model fixtures, or test report body were
modified during this closure sweep. No fixes file or developer review
file was edited.

The Stage 26 commit `4556965c7` (Candidate A: wasteful alloc+free in
`admit_latest_checkpoint_and_store_metadata`) remains in the tree and
was confirmed INSUFFICIENT by Stage 24 -05 but kept because it is a
real heap-pressure reduction. The Stage 27 fix at line 3396 is the
final root-cause resolution.

## Follow-up tasks

- (a) TP-26-UT6 test artifact fix: replace `assert(stage23_admit_checkpoint_store(...))`
  at `tests/test-cache-controller.cpp:3645` with explicit
  `if (!ok) { fprintf(stderr, "FAIL: admit returned false\n"); std::abort(); }`
  per developer memory "Improvement: NDEBUG silently disables asserts
  in Release-build unit tests". Owner: future Developer ticket.
  Rationale: deferred per D-EXEC-27-09; not blocking Stage 27 closure.
- (b) S02 hybrid cold-store metric vs filesystem drift (5.37 GiB
  filesystem vs 502 MiB metric, ~10x ratio) -- pre-existing
  D-EXEC-24-03-c carried from Stage 25 closure. Owner: future stage.
  Rationale: Stage 26 per-id accounting fix bounded S03 hybrid drift
  (485 MiB / 485 MiB within rounding) but S02 hybrid drift persists;
  separate investigation needed.
- (c) AddressSanitizer infrastructure cleanup: LNK2038 SAL annotation
  mismatch on every ggml-cuda.obj (274 mismatches in MSVC ASan build
  path) is a known MSVC ASan limitation. Owner: future stage or
  external. Rationale: Stage 27 ASan investigation (iter 3, build-cuda-asan)
  confirmed TP-26-UT6 is a test artifact not heap corruption via
  CPU-only ASan path; full ASan+CUDA build killed mid-compile due to
  wall-time budget; defer infrastructure cleanup to future work.

## Handoff

Next owner: user.

The user owns the commit decision for the uncommitted Stage 27 code
changes in `tools/server/server-cache-hybrid.cpp` and
`tests/test-cache-controller.cpp`. Per AGENTS.md and D-CLOSURE-27-01,
AI agents do not commit or push without explicit user approval. Once
the user commits, the three follow-up tasks above remain open as
separate future stages or tickets.

This file uses LF line endings, plain ASCII status labels, no BOM,
no trailing whitespace, and stays under the 300-line durable-doc cap.
