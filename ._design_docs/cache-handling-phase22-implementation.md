# Stage 22 implementation: demotion coordination refactor

Status: Closed - Manager closure PASS
Date: 2026-06-18
Stage: 22 (Demotion Coordination Refactor)
Author: Developer (implementation planning)
Source design: [cache-handling-phase22-design.md](cache-handling-phase22-design.md)
Manager gate: D22-DESIGN-01 and D22-DESIGN-02
Current gate: Stage closed; Stage 21 resume open

## Contents

- [Part 1: Architect implementation review gate 01](cache-handling-phase22-implementation/part-01-architect-implementation-review-gate-01.md)
- [Part 2: Architect implementation re-review gate 01](cache-handling-phase22-implementation/part-02-architect-implementation-re-review-gate-01.md)
- [Part 3: Manager gates and implementation evidence](cache-handling-phase22-implementation/part-03-manager-gates-and-implementation-evidence.md)
- [Part 4: Manager gates after QA rerun 03](cache-handling-phase22-implementation/part-04-manager-gates-after-qa-rerun-03.md)
- [Part 5: Manager gates after QA rerun 07](cache-handling-phase22-implementation/part-05-manager-gates-after-qa-rerun-07.md)
- [Part 6: Bug-fix and closure evidence summary](cache-handling-phase22-implementation/part-06-bugfix-and-closure-evidence-summary.md)
- [D22-EXEC-01 fix report](.test_reports/stage22-heavy-20260619-01-fixes.md)
- [D22-RERUN-01 fix report](.test_reports/stage22-heavy-20260619-02-fixes.md)
- [D22-RERUN-03-F1 fix report](.test_reports/stage22-heavy-20260619-03-fixes.md)
- [D22-RERUN-05-F1 fix report](.test_reports/stage22-heavy-20260619-05-fixes.md)
- [D22-RERUN-06 fix report](.test_reports/stage22-heavy-20260619-06-fixes.md)
- [D22-RERUN-07 fix report](.test_reports/stage22-heavy-20260620-07-fixes.md)
- [D22-RERUN-07 fix report](.test_reports/stage22-heavy-20260620-07-fixes.md)

## Approved baseline

Stage 22 starts from the corrected design:

- [Stage 22 design](cache-handling-phase22-design.md): Architect re-review PASS and Manager design gate PASS.
- D22-DESIGN-01: corrected design accepted after F-22-DR-01 and F-22-DR-02 closed.
- D22-DESIGN-02: implementation planning is open, but production refactor work waits for implementation-plan review and Manager gate.
- Stage 21 remains paused for Stage 22, not closed.

Binding inherited fixes:

| Source | Invariant to preserve |
| --- | --- |
| F-21-EXEC-01 | Prompt-only save/lookup keeps exact repeats as exact hits, not unsafe prefix candidates. TP-21-UT1..UT3 stay unchanged. |
| F-21-RERUN-01 | Demoting payloads count against hot budget until hot bytes are released. TP-21-UT4..UT6 stay unchanged. |
| Stage 5 | Target/draft payloads move as one descriptor-owned unit. |
| Stage 6 | Cold I/O writes asynchronously; controller owns descriptor transition. |
| Stage 8 | Payload eviction and branch pruning stay separate; metadata-only nodes are valid only after descriptor ownership is clear. |
| Stage 17 | Cold-budget rejection leaves descriptor hot and does not create partial cold residency. |

## Affected files

Planned implementation edits after plan gates:

| Path | Planned action | Reason |
| --- | --- | --- |
| `tools/server/server-cache-hybrid.cpp` | Refactor demotion ownership helpers and completion handling. | Fix F-21-RERUN-02 and centralize descriptor/hot-map/entry/branch synchronization. |
| `tests/test-cache-controller.cpp` | Add TP-22-UT1..UT8 and any narrow test hook calls. | Prove idempotent completion, failure paths, target/draft pairing, and Stage 21 invariants. |
| `._design_docs/cache-handling-phase22-implementation.md` | Update after each implementation step. | Keep the durable implementation log current. |
| `._design_docs/.test_reports/stage22-*.md` | Create only for later bug-fix or QA execution evidence if needed. | Keep test evidence durable without mixing it into production docs. |

No public CLI flags, endpoint schemas, public metric names, model fixtures, runner scripts, or CMake files are planned.

## Helper and API plan

Implement a small private helper set in `server-cache-hybrid.cpp`. Names may vary, but behavior is binding:

| Helper | Contract |
| --- | --- |
| `sync_payload_owner_views(payload_id)` | For every entry referencing the payload id, refresh payload accounting and sync the branch node from the entry. |
| `release_hot_payload_after_success(descriptor)` | Erase the hot payload record for the descriptor payload id after successful demotion only. It must not run before worker success. |
| `complete_demoted_payload(descriptor, ref)` | Set cold ref/residency, add cold counters once, release hot bytes, refresh/sync owner views, and record success. |
| Optional `demotion_completion_*` local helpers | Keep success, duplicate success, stale success, and failure branches readable without changing public APIs. |

Test-only hooks may be added only if existing hooks cannot inject completion states or inspect results. Any hook must be private to tests, minimal, and documented here after implementation.

## Ordered implementation steps

1. Baseline verification.
   - Record `git status --short`.
   - Confirm current code still has `demote_payload` generic non-hot rejection before the demoting-specific rejection.
   - Confirm existing TP-21-UT1..UT6 names and 97-test baseline are present.

2. Add helper scaffolding.
   - Add owner-view sync and hot-release helpers.
   - Replace repeated loops in demotion completion with helper calls.
   - Do not change behavior yet except through equivalent refactoring.

3. Fix `demote_payload` validation order.
   - Check descriptor exists.
   - Check `demoting` before generic non-hot rejection.
   - Keep cold-store, hot-record, pair-state, cold-budget, enqueue, and queue-full behavior unchanged.
   - Preserve resident bytes and hot map while state is `demoting`.

4. Refactor `mark_payload_kind_evicted`.
   - If cold store is configured and descriptor is hot, call `demote_payload`.
   - On successful enqueue, refresh owner views while bytes are still resident, keep payload id attached, and return.
   - Fall through to immediate eviction only when demotion is unavailable or failed before enqueue.

5. Refactor `handle_demotion_completion`.
   - Missing descriptor: diagnostic and return.
   - Success + `demoting`: one transition to cold, cold counters increment once, hot bytes released, owner views synced.
   - Success + already `cold`: duplicate/stale success, no double count, no product warning, ensure hot record absent.
   - Success + `evicted`: bounded stale-success diagnostic, no ownership recreation.
   - Failure + `demoting` + hot record: revert to hot and sync owner views.
   - Failure + `demoting` + no hot record: mark evicted, zero resident bytes, sync owner views.
   - Failure + already `cold`: stale failure, leave cold.

6. Add TP-22 unit tests.
   - Add tests incrementally near Stage 21 tests.
   - Register every test in `main()` and update the summary count.
   - Keep TP-21-UT1..UT6 unchanged unless a compile-only signature update is required.

7. Build and focused test run.
   - Build `test-cache-controller` and `llama-server`.
   - Run `test-cache-controller.exe`.
   - Confirm all existing 97 tests plus TP-22-UT1..UT8 pass.

8. Evidence and doc update.
   - Update this implementation log with exact changed files, helper names, test names, commands, exit codes, binary mtimes, and warning/counter observations.
   - Run `git diff --check` on touched files.

9. Handoff.
   - Send to Architect for implementation review.
   - After review PASS and Manager gate, QA reruns Stage 21 HV-chat-feasible with the Stage 22 binary.

## Exact unit test plan

| ID | Test name draft | Required assertions |
| --- | --- | --- |
| TP-22-UT1 | `test_stage22_demotion_success_transitions_once` | Demoting completion success changes state to cold, releases hot bytes, removes hot record, updates resident bytes, and syncs branch node. |
| TP-22-UT2 | `test_stage22_duplicate_success_idempotent` | Second success completion leaves state cold, does not increment cold bytes/count twice, and does not take the "not in demoting state" warning path. |
| TP-22-UT3 | `test_stage22_stale_success_after_evicted` | Success after immediate eviction does not crash, does not recreate ownership, and leaves descriptor/entry evicted or metadata-only. |
| TP-22-UT4 | `test_stage22_demotion_failure_with_hot_bytes_reverts` | Failure while hot record exists returns descriptor to hot and keeps resident bytes counted. |
| TP-22-UT5 | `test_stage22_demotion_failure_without_hot_bytes_evicts` | Failure with no hot record marks evicted, zeroes resident bytes, and syncs branch node/accounting. |
| TP-22-UT6 | Direct TP-21-UT1..UT6 registrations | Existing TP-21-UT1..UT6 still pass unchanged in the full binary run; no duplicate wrapper is registered. |
| TP-22-UT7 | `test_stage22_target_draft_completion_idempotent` | Target/draft demotion success and duplicate success keep pair state, target bytes, draft bytes, cold counters, and owner views coherent. |
| TP-22-UT8 | `test_stage22_demote_already_demoting_in_progress` | Calling demote on a demoting descriptor returns the in-flight diagnostic path before generic non-hot rejection. |

## TP-21 invariant checks

The implementation session must capture visible PASS lines for:

- `test_stage21_exact_repeat_restore_with_prompt_only_save`
- `test_stage21_exact_repeat_prefix_boundary`
- `test_stage21_near_prefix_still_rejected`
- `test_stage21_demoting_payload_counted_in_budget`
- `test_stage21_descriptor_resident_bytes_preserved_during_demotion`
- `test_stage21_entry_eviction_during_demotion_does_not_crash`

Failure of any TP-21 row blocks Stage 22 handoff.

## Build and run evidence plan

Required commands for implementation evidence:

```powershell
cmake --build build-cov --config Release --target test-cache-controller -j 4
cmake --build build-cov --config Release --target llama-server -j 4
.\build-cov\bin\Release\test-cache-controller.exe
git diff --check -- tools/server/server-cache-hybrid.cpp tests/test-cache-controller.cpp ._design_docs/cache-handling-phase22-implementation.md ._design_docs/document-index.md ._design_docs/cache-handling-stage-tracker.md
```

Record exit codes, binary mtimes, total test count, Stage 21 PASS lines, Stage 22 PASS lines, and any diagnostics emitted by new duplicate/stale branches.

## QA rerun evidence plan

After implementation review and Manager gate, QA reruns Stage 21 HV-chat-feasible:

- Use the same Qwen3.6-27B-MTP fixture and Stage 21 runner contract.
- Verify zero `descriptor not found for payload_id` warnings.
- Verify zero product warnings for `payload_id X is not in demoting state (residency=4)`.
- Verify req-008, req-009, and req-010 find exact matching entries.
- PASS requires `cache_n > 0` for exact repeats, or a Manager-approved bounded result if cold promotion latency still needs an extra retry row.
- Confirm prompt evidence JSONL remains redacted and bounded.
- Confirm public metric names remain unchanged.

## Documentation plan

- Keep this file current after each completed implementation step.
- Update `document-index.md` only if scope or status changes.
- Update `cache-handling-stage-tracker.md` when Manager gate status changes.
- If helper semantics become durable architecture, add an architecture note only after review asks for it.
- Keep every durable doc under 300 lines, LF-only, UTF-8 without BOM, and plain ASCII unless existing file content requires otherwise.

## Risks

| ID | Risk | Mitigation |
| --- | --- | --- |
| R-22-01 | Duplicate success path double counts cold bytes. | TP-22-UT2 and TP-22-UT7 assert counter stability. |
| R-22-02 | Failure paths leave entries or branch nodes with stale payload state. | Central owner-view helper plus TP-22-UT4/UT5. |
| R-22-03 | Target/draft pair loses draft ownership on completion. | TP-22-UT7 covers pair state and byte counters. |
| R-22-04 | New hooks overfit tests to internals. | Add only smallest hook needed for completion injection and state inspection. |
| R-22-05 | Stage 21 exact-repeat fix regresses while demotion code changes. | TP-21-UT1..UT6 stay binding and visible in evidence. |

## Rollback

Rollback is file-scoped:

- Revert only Stage 22 edits in `tools/server/server-cache-hybrid.cpp`.
- Revert only Stage 22 tests and hooks in `tests/test-cache-controller.cpp`.
- Keep F-21-EXEC-01 prompt-only save behavior.
- Keep F-21-RERUN-01 demoting-budget behavior.
- Leave Stage 21 paused unless Manager explicitly changes the gate.

If rollback happens, record which TP-22 row failed and whether any TP-21 invariant regressed.

## Review handoff

Next owner: Architect for implementation-plan review.

Developer implementation must not start until implementation-plan review PASS and Manager implementation-plan gate PASS.

## Gate and evidence history

Implementation-plan review, Manager implementation-plan gate, Developer
implementation evidence, Manager implementation gate, and Manager QA execution
gate are recorded in
[Part 3](cache-handling-phase22-implementation/part-03-manager-gates-and-implementation-evidence.md).

Bug-fix and closure evidence is summarized in
[Part 6](cache-handling-phase22-implementation/part-06-bugfix-and-closure-evidence-summary.md).
