# Stage 40 Manager build-blocker rework routing

Date: 2026-08-26
Stage: 40 (Upstream merge cycle)
Trigger: QA test-execution session returned BLOCKED-per-plan; merged tree does not compile.
Manager: self (autonomous session, user unreviewable)

## Situation

The QA test-execution session began the build and surfaced ~30 compile errors
across multiple API changes in the staged merge. The session returned a
truncated message mid-investigation ("This is a large semantic merge conflict -
~30 errors across multiple API changes") and produced no test report on disk
(no `test-report-20260826-*` file, no `_test_output/stage40-*` dir).

A Manager-side focused build (`cmake --build . --config Release --target
llama-server -- /m:4 /clp:ErrorsOnly`) confirmed the tree does NOT compile.

## Root cause

The Manager implementation gate PASS (part-19) was based on a PARTIAL build:
the prior Developer sessions verified only the F1 (result_timings) and F7
(server_prompt_cache_state) scopes by compiling single translation units, and a
full rebuild timed out. The full-tree build in the QA session exposed that the
merge resolution left more upstream/local API incompatibilities than the two
found during review.

This is the same gap identified as NON-BLOCKING finding F2 in the
implementation review: the semantic conflict scan lacked a full cross-file /
full-tree compile check. The gate evidence was therefore not complete.

## Confirmed compile-error categories (from MMA build, llama-server target)

| # | File:line | Error | Likely cause |
|---|-----------|-------|--------------|
| 1 | server-slot.h:224 | C2039 'data' is not a member of 'server_prompt' | local code uses `cur->data` / `prompt.data` removed by upstream |
| 2 | server-slot.h:284,286,676,680 | C3861 'common_context_seq_rm' not found | upstream renamed/removed helper |
| 3 | server-slot.h:677,681 | C3861 'common_context_seq_cp' not found | upstream renamed/removed helper |
| 4 | server-slot.h:391,396 | C3861 'common_speculative_need_embd' / 'common_speculative_need_embd_nextn' not found | upstream renamed/removed speculative helper |
| 5 | server-queue.h:141 | C2064 term is not a function taking 1 args | server_queue::on_new_task callback signature changed upstream |
| 6 | server-context.cpp:46 | C2371 'json' redefinition different basic types | conflicting json include/definition |
| 7 | server-context.cpp:347 | C2011 'server_metrics' struct type redefinition | merged server-metrics header vs local definition |
| 8 | server-context.cpp:494 | C2079 uses undefined struct 'server_metrics' | incomplete type |
| 9 | server-context.cpp:1087 | C2664 on_new_task lambda cannot convert | callback signature mismatch |

## Manager decision

| ID | Decision |
|----|----------|
| D40-BLD-01 | Route the build fix to a fresh Developer session. The Developer is the owner of merge-resolution source fixes (Stage 35 parts 24-27 precedent). |
| D40-BLD-02 | Fix ALL compile errors until `llama-server` and `test-cache-controller` build clean from the staged merge, then run `ctest -R cache`. Do not stop at the two F1/F7 scopes. |
| D40-BLD-03 | Update the implementation review status: the prior PASS stands only for the F1/F7 resolutions; the full-tree compile gate is re-opened and must close before test execution. |
| D40-BLD-04 | After the Developer fixes the build, a fresh Architect session re-reviews the source fixes, THEN QA re-executes the test plan from a clean tree. |

## Next handoff

- Next owner: Developer
- Next gate: Implementation (extended to full-tree compile fix)
- The QA test-execution gate remains BLOCKED until the tree compiles.

## Developer fix outcome

Date: 2026-08-26
Owner: Developer (build-fix session)
Evidence: `._design_docs/.test_reports/test-report-20260826-01-build-fixes.md`

| Check | Result |
| --- | --- |
| `llama-server` build | PASS (exit 0) |
| `test-cache-controller` build | PASS (exit 0) |
| `ctest -C Release -R cache` | PASS 1/1 (test-cache-controller, 53.98 s) |
| `test-cache-controller.exe` direct | PASS, All tests passed successfully |
| MERGE_HEAD intact | `fc35562ba` unchanged |
| Commit / push / PR | none |

All 9 confirmed categories fixed, plus additional errors exposed by the full
build (flat `server_task_result_metrics` members in /metrics + /slots, json
initializer-list conversions, `common_json` numeric conversions, and the local
test file's BASE-struct usage). Fix details and per-error table in the test
report.

Decision D40-BLD-02 is satisfied: both targets build clean and the cache ctest
passes. Next gate per D40-BLD-04: fresh Architect session re-reviews the source
fixes, then QA re-executes the test plan from a clean tree.
