# Stage 35 implementation: upstream merge pre-merge analysis

Status: Closed PASS; corrected upstream_master no-commit merge remains open and uncommitted
Date opened: 2026-07-07
Stage: 35 (Upstream merge cycle)
Owner: Human maintainer
Reviewer: Architect
Manager approver: Manager
Branch: `work-branch`
Source ref: `origin/upstream_master`

## Scope

This implementation log records the Stage 35 pre-merge analysis, merge
execution, retry, source-fix, and focused evidence trail. The current merge is
open and uncommitted. No push, PR, or reviewer response was performed.

Binding sources:

- [Stage 35 design](cache-handling-phase35-design.md)
- [Manager design gate](cache-handling-phase35-design/part-03-manager-design-gate-20260707.md)
- [Upstream merge guide](upstream-merge-guide.md)
- [Guide part 01](upstream-merge-guide/part-01-procedure.md)
- [Guide part 02](upstream-merge-guide/part-02-conflict-patterns.md)
- [Guide part 03](upstream-merge-guide/part-03-coverage-and-evidence.md)
- [Guide part 04](upstream-merge-guide/part-04-edge-cases.md)

## Parts

- [Part 01: pre-merge analysis 2026-07-07](cache-handling-phase35-implementation/part-01-pre-merge-analysis-20260707.md)
- [Part 02: pre-merge analysis review 2026-07-07](cache-handling-phase35-implementation/part-02-pre-merge-analysis-review-20260707.md) - REWORK on stale source ref and stale count.
- [Part 03: Manager pre-merge decisions 2026-07-07](cache-handling-phase35-implementation/part-03-manager-premerge-decisions-20260707.md) - refresh-and-redo selected; merge execution still blocked.
- [Part 04: pre-merge analysis re-review 2026-07-07](cache-handling-phase35-implementation/part-04-pre-merge-analysis-re-review-20260707.md) - PASS on corrected source ref, counts, dirty-worktree planning exception, and rework classification reviewability.
- [Part 05: Manager pre-merge approval 2026-07-07](cache-handling-phase35-implementation/part-05-manager-premerge-approval-20260707.md) - PASS for pre-merge analysis; all 9 REWORK-REQUIRED rows grouped into three rework tracks before merge execution.
- [Part 06: merge/rework implementation plan 2026-07-07](cache-handling-phase35-implementation/part-06-merge-rework-implementation-plan-20260707.md) - planning-only execution plan for source checks, dirty-worktree gate, 67 INTEGRATE rows, 13 NO-OP rows, three rework tracks, conflict scans, durable doc triggers, evidence, stop conditions, and no-commit/no-PR constraints.
- [Part 07: implementation-plan review 2026-07-07](cache-handling-phase35-implementation/part-07-implementation-plan-review-20260707.md) - PASS; 0 blocking, 0 non-blocking, 0 informational findings. Next gate is Manager implementation-plan gate.
- [Part 08: Manager implementation-plan gate 2026-07-07](cache-handling-phase35-implementation/part-08-manager-implementation-plan-gate-20260707.md) - PASS for the plan; implementation is blocked pending explicit user approval for a clean-tree path.
- [Part 09: implementation preflight 2026-07-07](cache-handling-phase35-implementation/part-09-implementation-preflight-20260707.md) - BLOCKED before merge. Clean-tree gate passed, but `origin/upstream_master` no longer matched the approved source tip or actual upstream `master`; no merge, code edit, or test run occurred.
- [Part 10: Manager source-ref decision 2026-07-07](cache-handling-phase35-implementation/part-10-manager-source-ref-decision-20260707.md) - refresh-and-redo selected for the new upstream tip; merge execution still blocked.
- [Part 11: refreshed pre-merge analysis 2026-07-07](cache-handling-phase35-implementation/part-11-refreshed-pre-merge-analysis-20260707.md) - refreshed `origin/upstream_master` to actual upstream `master` at `6c487e2f79de`; refreshed range is 312 commits with 91 filtered rows: 13 NO-OP, 68 INTEGRATE, 10 REWORK-REQUIRED, 0 DEFER, 0 REVERT. Merge execution still blocked.
- [Part 12: refreshed pre-merge analysis review 2026-07-07](cache-handling-phase35-implementation/part-12-refreshed-pre-merge-analysis-review-20260707.md) - PASS; source ref and actual upstream `master` match `6c487e2f79de`, refreshed counts verified, `024c46ae4e37` can join MTP/KV/speculative rework, and `6c487e2f79de` can remain INTEGRATE with focused scans.
- [Part 13: Manager refreshed pre-merge approval 2026-07-07](cache-handling-phase35-implementation/part-13-manager-refreshed-premerge-approval-20260707.md) - PASS for refreshed counts and routing; merge blocked on next clean-tree gate.
- [Part 14: merge/rework implementation blocked 2026-07-07](cache-handling-phase35-implementation/part-14-merge-rework-implementation-blocked-20260707.md) - PARTIAL/BLOCKED; no-commit merge opened at `MERGE_HEAD=6c487e2f79de`, conflicts resolved and staged, semantic scans run, but `origin/upstream_master` and actual upstream `master` advanced before implementation-gate closure.
- [Part 15: Manager source-ref and partial-merge decision 2026-07-07](cache-handling-phase35-implementation/part-15-manager-source-ref-and-partial-merge-decision-20260707.md) - REFRESH AND REDO from actual upstream `master` at `bec4772f6a25`; reject pinned known-gap path, abort the open no-commit merge first, and send Developer back to refreshed pre-merge analysis before any merge execution.
- [Part 16: refreshed pre-merge analysis after abort 2026-07-07](cache-handling-phase35-implementation/part-16-refreshed-pre-merge-analysis-20260707.md) - reviewed by part 17; abort closed the open no-commit merge, `origin/upstream_master` now matches actual upstream `master` at `bec4772f6a25`, refreshed range is 317 commits with 94 filtered rows: 13 NO-OP, 69 INTEGRATE, 12 REWORK-REQUIRED, 0 DEFER, 0 REVERT. Merge execution remains blocked.
- [Part 17: refreshed pre-merge analysis review 2026-07-07](cache-handling-phase35-implementation/part-17-refreshed-pre-merge-analysis-review-20260707.md) - PASS; source ref, absent `MERGE_HEAD`, 317-count range, 5-commit delta, filtered triage, and aggregate counts verified. Next gate is Manager refreshed pre-merge approval.
- [Part 18: Manager refreshed pre-merge approval 2026-07-07](cache-handling-phase35-implementation/part-18-manager-refreshed-premerge-approval-20260707.md) - PASS for part 16 and part 17; approves counts `13/69/12/0/0`, routes `f5525f7e7a7e` and `c198af4dc24f` into MTP/KV/speculative rework, keeps `5eca4e3cabad` INTEGRATE, and blocks merge execution on clean-tree gate.
- [Part 19: Manager clean-tree gate 2026-07-08](cache-handling-phase35-implementation/part-19-manager-clean-tree-gate-20260708.md) - PASS; cleanup commit `e2a3be8553ca` preserves Stage 35 docs, `MERGE_HEAD` is absent, source ref matches actual upstream `master` at `bec4772f6a25`, and Developer merge execution is authorized under the approved no-push/no-PR constraints.
- [Part 20: merge/rework implementation evidence 2026-07-08](cache-handling-phase35-implementation/part-20-merge-rework-implementation-evidence-20260708.md) - PARTIAL/BLOCKED; no-commit merge opened against `MERGE_HEAD=bec4772f6a25`, six textual conflicts resolved and staged, semantic scans passed, focused build attempts timed out with process cleanup, then `origin/upstream_master` resolved to stale `47e1de77aa0f` while actual upstream remained `bec4772f6a25`.
- [Part 21: Manager source-ref correction 2026-07-08](cache-handling-phase35-implementation/part-21-manager-source-ref-restore-decision-20260708.md) - PASS; user corrected the source branch to `upstream_master`, wrong GitHub-`master` merge was aborted, `origin/upstream_master` was force-refreshed to `47e1de77aa0f`, and Developer must restart merge execution against that source.
- [Part 22: merge/rework implementation evidence upstream_master 2026-07-08](cache-handling-phase35-implementation/part-22-merge-rework-implementation-evidence-upstream-master-20260708.md) - PARTIAL/BLOCKED; no-commit merge opened against corrected `MERGE_HEAD=47e1de77aa0f`, five textual conflicts resolved and staged, semantic scans passed, source-ref recheck stayed matched to remote `upstream_master`, and focused build timed out after 608 seconds with process cleanup.
- [Part 23: Manager build retry decision 2026-07-08](cache-handling-phase35-implementation/part-23-manager-build-retry-decision-20260708.md) - PASS; authorizes one longer focused build/test retry on the current open no-commit merge before Architect implementation review.
- [Part 24: focused build retry 2026-07-08](cache-handling-phase35-implementation/part-24-focused-build-retry-20260708.md) - BLOCKED; source refs and unresolved-path checks passed, combined and fallback focused builds failed with `LNK1136` on corrupt `ggml-cuda.dir\Release\argsort.obj`, cleanup passed, and no tests ran.
- [Part 25: clean object-pruned build retry 2026-07-08](cache-handling-phase35-implementation/part-25-clean-build-retry-20260708.md) - BLOCKED; pruned the whole `ggml-cuda.dir` directory, CUDA objects recompiled cleanly (Part 24 `LNK1136` corrupt-object blocker resolved), but the clean build exposed 27 real source-level merge compile errors (`server_state` enum redefinition plus struct field mismatches) in `server-context.cpp` and `server-cache-hybrid.cpp`; `test-cache-controller` not reached, no tests ran.
- [Part 26: Manager source-fix routing 2026-07-08](cache-handling-phase35-implementation/part-26-manager-source-fix-routing-20260708.md) - PASS; routes the open no-commit merge back to Developer for focused merge-resolution source fixes before Architect implementation review.
- [Part 27: source merge fix evidence 2026-07-08](cache-handling-phase35-implementation/part-27-source-merge-fix-evidence-20260708.md) - PASS; source-level merge fixes compile, `llama-server test-cache-controller` builds, direct `test-cache-controller` passes 149 tests, `ctest -C Release -R cache` passes 1/1, and `test_router_props` passes with the built server binary.
- [Part 28: implementation review 2026-07-08](cache-handling-phase35-implementation/part-28-implementation-review-20260708.md) - REWORK; F35-IMPL-01 finds that `set_state_callback` replaces the queue sleep handler instead of composing with `handle_sleeping_state`, so router child sleep/resume lifecycle is not preserved.
- [Part 29: F35-IMPL-01 rework evidence 2026-07-08](cache-handling-phase35-implementation/part-29-f35-impl-01-rework-evidence-20260708.md) - PASS; `set_state_callback` now only stores the router callback, the existing local sleep handler emits router sleeping state after successful local sleep entry, direct `test-cache-controller` passes 150 tests, and `ctest -C Release -R cache` passes 1/1.
- [Part 30: F35-IMPL-01 implementation re-review 2026-07-08](cache-handling-phase35-implementation/part-30-f35-impl-01-implementation-re-review-20260708.md) - PASS; Architect verified the callback composition source, guarded test hooks, Stage 25/34 invariants, focused build, direct cache controller, and `ctest -R cache`.
- [Part 31: Manager implementation gate 2026-07-08](cache-handling-phase35-implementation/part-31-manager-implementation-gate-20260708.md) - PASS; closes implementation review and routes Stage 35 to QA test planning because the shared test plan has no Stage 35 upstream-merge regression part yet.
- [QA report 2026-07-08](.test_reports/test-report-20260708-01.md) - FAIL; TP-35-COV-01 coverage target build failed because `tests/test-step10-metrics.cpp` still calls removed `hybrid_cache_controller::process_completions`.
- [Developer test-results review 2026-07-08](.test_reports/test-report-20260708-01-developer-review.md) - REWORK; classifies F35-QA-01 as test/coverage target drift, not a product runtime bug, and assigns focused coverage-test fix/retest to Developer.
- [F35-QA-01 fix report 2026-07-08](.test_reports/test-report-20260708-01-fixes.md) - updated after Architect fix review; compile drift fixed and deterministic sync metrics assertions added.
- [F35-QA-01 fix review 2026-07-08](.test_reports/test-report-20260708-01-fix-review.md) - historical REWORK; F35-QA-FIX-01 required deterministic Step 10 sync metrics assertions.
- [F35-QA-01 fix re-review 2026-07-08](.test_reports/test-report-20260708-01-fix-re-review.md) - PASS; closes F35-QA-FIX-01 and returns TP-35-COV-01 to QA rerun.
- [Focused TP-35-COV-01 QA rerun 2026-07-08](.test_reports/test-report-20260708-02.md) - FAIL; corrected focused targets build and run under OpenCppCoverage, but markdown coverage is below required floors: combined 0.734 against 0.80 and product-only 0.5856 against 0.70. Direct OpenCppCoverage was used after the wrapper produced no `.cov` files through its Start-Process path.
- [Developer TP-35-COV-01 rerun review 2026-07-08](.test_reports/test-report-20260708-02-developer-review.md) - MANAGER-DECISION; classifies F35-QA-02 as a coverage-contract issue, not a product runtime bug, and assigns the next gate to Manager.
- [Part 32: Manager coverage-contract decision 2026-07-08](cache-handling-phase35-implementation/part-32-manager-coverage-contract-decision-20260708.md) - REWORK; no coverage exception for Stage 35, Developer must add meaningful focused coverage and return for fix review before QA reruns TP-35-COV-01.
- [Part 33: F35-QA-02 coverage fix and review 2026-07-09](cache-handling-phase35-implementation/part-33-f35-qa-02-coverage-fix-review-20260709.md) - PASS; focused test-only coverage rework closes both coverage floors: combined `0.8112`, product-only `0.7026`.
- [Focused TP-35-COV-01 QA rerun 2026-07-09](.test_reports/test-report-20260709-01-stage35-coverage-rerun.md) - PASS; clean focused build and direct OpenCppCoverage evidence produced 10 `.cov` files and passed combined/product-only floors.
- [Developer coverage rerun review 2026-07-09](.test_reports/test-report-20260709-01-stage35-coverage-rerun-developer-review.md) - PASS; no product bug remains from F35-QA-02.
- [Part 34: Manager closure 2026-07-09](cache-handling-phase35-implementation/part-34-manager-closure-20260709.md) - PASS; Stage 35 closed, with the no-commit merge still open and uncommitted.

## Progress log

| Step | Status | Evidence |
| --- | --- | --- |
| Read Stage 35 design and Manager gate | Done | Required docs read on 2026-07-07. |
| Read upstream merge guide parts 01-04 | Done | Required guide parts read on 2026-07-07. |
| Verify upstream ref without fetch | Done | Refreshed `origin/upstream_master` equals `git ls-remote https://github.com/ggml-org/llama.cpp.git master` at `108f186d1701d56133a0239dd6754c8814374cbf`. |
| Apply Stage 35 filters | Done | 89 in-scope commits from 308 upstream commits; new `108f186d1701` SYCL backend/docs commit is excluded by Stage 35 filters. |
| Write pre-merge triage artifact | Done | Part 01 records refreshed source ref, per-commit triage, aggregate summary, expected files, decisions, and open questions. |
| Correct REWORK count mismatch | Done | Entry and part 01 both record 9 REWORK-REQUIRED candidates. |
| Write merge/rework implementation plan | Done | Part 06 records execution phases and evidence matrix; no merge or production code change performed. |
| Review merge/rework implementation plan | Done | Part 07 records Architect PASS with 0 findings; merge execution still blocked. |
| Manager implementation-plan gate | Done | Part 08 approves the plan and blocks implementation on dirty-worktree cleanup approval. |
| Implementation preflight | Blocked | Part 09 records clean worktree but stale source ref: `origin/upstream_master` at `47e1de77aa0f`, actual upstream `master` at `6c487e2f79de`, accepted plan tip `108f186d1701`; merge stopped before track analysis. |
| Manager source-ref decision | Done | Part 10 selects refresh-and-redo pre-merge analysis for actual upstream `master`; planning-only dirty exception applies until merge execution. |
| Refreshed pre-merge analysis | Done | Part 11 records the authorized fetch, source-ref checks, prefix proof, refreshed counts, and two new filtered rows. |
| Refreshed pre-merge analysis review | Done | Part 12 records Architect PASS with 0 findings; Manager approval remains required before merge execution. |
| Manager refreshed pre-merge approval | Done | Part 13 accepts counts `13/68/10/0/0`, routes `024c46ae4e37` into MTP/KV/speculative rework, and keeps `6c487e2f79de` INTEGRATE. |
| Run merge | Partial | Part 14 records no-commit merge preparation against `MERGE_HEAD=6c487e2f79de`; six textual conflicts were resolved and staged. |
| Semantic conflict scans | Partial | Part 14 records clean scoped conflict-marker, stale-symbol, metric-label, and anchor scans. |
| Run regression | Blocked | Focused build attempts timed out, then source ref became stale before implementation-gate closure. |
| Manager source-ref and partial-merge decision | Done | Part 15 rejects the pinned known-gap path and authorizes aborting the open no-commit merge so Developer can redo refreshed pre-merge analysis against actual upstream `master` at `bec4772f6a25`. |
| Abort stale no-commit merge | Done | Part 16 records untracked-file safety checks and `git merge --abort` exit `0`; `MERGE_HEAD` no longer exists. |
| Refresh source ref to actual upstream | Done | Part 16 records direct fetch from `https://github.com/ggml-org/llama.cpp.git` to `refs/remotes/origin/upstream_master`; source ref and actual upstream both equal `bec4772f6a25`. |
| Redo refreshed pre-merge analysis | Done | Part 16 records 317 commits, 94 filtered rows, and counts `13/69/12/0/0`; part 17 review passed. |
| Refreshed pre-merge analysis review | Done | Part 17 records Architect PASS with 0 findings; Manager approval remains required before merge execution. |
| Manager refreshed pre-merge approval | Done | Part 18 accepts part 16 and part 17 and opens the clean-tree gate before merge execution. |
| Manager clean-tree gate | Done | Part 19 records cleanup commit `e2a3be8553ca`, clean status, absent `MERGE_HEAD`, and current source ref `bec4772f6a25`. |
| Run merge after clean-tree gate | Partial | Part 20 records `git merge --no-ff --no-commit origin/upstream_master`; merge opened with `MERGE_HEAD=bec4772f6a25` and six textual conflicts. |
| Resolve conflicts after clean-tree gate | Partial | Part 20 records resolutions for `common/common.cpp`, `common/fit.h`, `tools/server/CMakeLists.txt`, `tools/server/server-common.h`, `tools/server/server-context.cpp`, and `tools/server/server-task.cpp`. |
| Semantic conflict scans after clean-tree gate | Partial | Part 20 records clean scoped conflict-marker and public metric-label scans plus cache transaction, target/draft, checkpoint, route/session/stream, and speculative-helper anchor scans. |
| Focused build/test after clean-tree gate | Blocked | Part 20 records `llama-server test-cache-controller` build timeout after 604 seconds, `test-cache-controller` timeout after 304 seconds, and build-process cleanup. |
| Source-ref recheck after clean-tree gate | Blocked | Part 20 records `origin/upstream_master=47e1de77aa0f`, actual upstream `master=bec4772f6a25`, open `MERGE_HEAD=bec4772f6a25`; implementation-gate closure stopped. |
| Manager source-ref correction | Done | Part 21 records the user correction that `upstream_master` is the source branch, aborts the wrong GitHub-`master` merge, and restores `origin/upstream_master` to `47e1de77aa0f`. |
| Restart merge against upstream_master | Partial | Part 22 records `git merge --no-ff --no-commit origin/upstream_master`; merge opened with `MERGE_HEAD=47e1de77aa0f` and five textual conflicts. |
| Resolve upstream_master conflicts | Partial | Part 22 records resolutions for `common/common.cpp`, `common/fit.h`, `tools/server/CMakeLists.txt`, `tools/server/server-common.h`, and `tools/server/server-context.cpp`. |
| Semantic conflict scans against upstream_master | Partial | Part 22 records clean conflict-marker and public metric-label scans plus cache transaction, target/draft, checkpoint, route/session/stream, and speculative-helper anchor scans. |
| Focused build/test against upstream_master | Blocked | Part 22 records `llama-server test-cache-controller` build timeout after 608 seconds and build-process cleanup. |
| Source-ref recheck against upstream_master | Done | Part 22 records `origin/upstream_master`, remote `refs/heads/upstream_master`, and open `MERGE_HEAD` all equal `47e1de77aa0f`. |
| Manager build retry decision | Done | Part 23 authorizes one longer focused build/test retry before implementation review. |
| Focused build retry after Manager decision | Blocked | Part 24 records source-ref PASS, no unresolved paths, combined build FAIL after 557.9 seconds, fallback `test-cache-controller` build FAIL after 2.0 seconds, both on `LNK1136` corrupt `argsort.obj`, and process cleanup PASS. |
| Clean object-pruned build retry | Blocked | Part 25 records pre-check PASS, whole `ggml-cuda.dir` pruned, CUDA objects recompiled cleanly after 1330.6 seconds (Part 24 `LNK1136` blocker resolved), but clean build FAIL with 27 compile errors in `server-context.cpp` and `server-cache-hybrid.cpp` (`server_state` enum redefinition plus struct field mismatches); `test-cache-controller` not reached, leftover processes cleaned. |
| Manager source-fix routing | Done | Part 26 authorizes Developer to make focused merge-resolution source fixes for the Part 25 compile errors before Architect implementation review. |
| Source-level merge compile fixes | Done | Part 27 records production source fixes in `server-context.cpp`, `server-cache-hybrid.cpp`, `server-common.cpp`, and `server-common.h`; focused build PASS for `llama-server test-cache-controller`; direct `test-cache-controller` PASS 149 tests; `ctest -C Release -R cache` PASS 1/1; `test_router_props` PASS 1/1. |
| Architect implementation review | Rework | Part 28 records F35-IMPL-01: router child `set_state_callback` overwrites the sleep handler that calls `handle_sleeping_state`; Developer source-fix rework required before re-review. |
| F35-IMPL-01 source-fix rework | Done | Part 29 records the composed sleep handler fix, focused build PASS for `llama-server test-cache-controller`, direct `test-cache-controller` PASS 150 tests including the router sleep-state regression, and `ctest -C Release -R cache` PASS 1/1. |
| Architect implementation re-review | Done | Part 30 records PASS for F35-IMPL-01, with local sleep destroy/reload preserved, router sleeping notification ordered after successful local sleep entry, test hooks guarded, and Stage 25/34 invariants still passing focused evidence. |
| Manager implementation gate | Done | Part 31 records implementation PASS and routes Stage 35 to QA test planning because the shared test plan does not yet include Stage 35 upstream-merge regression coverage. |
| F35-QA-02 coverage rework | Done | Part 33 records focused test-only coverage for current synchronous restore, metadata/payload, sync I/O worker, demotion rejection, and coverage contract edge paths. |
| Architect F35-QA-02 fix review | Done | Part 33 records PASS with no blocking findings. |
| QA TP-35-COV-01 rerun | Done | Report `test-report-20260709-01-stage35-coverage-rerun.md` records clean focused build PASS and direct OpenCppCoverage PASS: combined `0.8112`, product-only `0.7026`. |
| Developer QA rerun review | Done | Report `test-report-20260709-01-stage35-coverage-rerun-developer-review.md` records PASS and no remaining product bug. |
| Manager closure | Done | Part 34 records Stage 35 PASS closure. |

## Current handoff

Source-ref verdict: PASS. Part 27 rechecks that `origin/upstream_master`,
remote `refs/heads/upstream_master`, and open `MERGE_HEAD` all equal
`47e1de77aa0f06bf73cfd8c5281d95979f89fcbe`.

Merge state: open no-commit merge against corrected `upstream_master`. Five
textual conflicts are resolved and staged. No merge commit exists.

Build/test state: PASS for focused source-fix and F35-IMPL-01 rework scope.
Part 30 records Architect rerun evidence: `cmake --build build-cuda --config
Release --target llama-server test-cache-controller -j 8` passed, direct
`test-cache-controller` passed 150 tests, and `ctest -C Release -R cache`
passed 1/1. Part 27's `test_router_props` evidence remains the router smoke
check.

Implementation gate verdict: PASS. Part 31 accepts the implementation evidence
and Architect re-review. The CUDA-object blocker, source compile blocker, and
router sleep-state callback rework are closed for the focused scope.

Test execution state: PASS. The 2026-07-09 focused TP-35-COV-01 rerun passed
after a clean focused build. Direct OpenCppCoverage evidence under
`_test_output/stage35-f35-qa-02-dev/coverage-direct-13-clean/` records combined
coverage `0.8112`, `7795 / 9609`, and product-only coverage `0.7026`,
`2833 / 4032`.

Developer review state: PASS. The 2026-07-09 developer review reports no
remaining product bug from F35-QA-02.

Manager decision: PASS. Part 34 closes Stage 35. The merge remains open and
uncommitted. Commit, push, PR, merge abort, and reviewer response remain blocked
unless separately requested.

Next owner: human maintainer.

Next gate: optional human commit decision for the open no-commit merge.
