# Stage 23 part 10: Architect S03 fix review gate 01

Status: REWORK
Date: 2026-06-21
Owner: Architect
Scope: review of the S03 product fix only. Product code was not edited.

## Inputs

- `cache-handling-phase23-design.md`
- `cache-handling-phase23-implementation.md`
- `cache-handling-phase23-implementation/part-08-manager-test-execution-gate-01.md`
- `cache-handling-phase23-implementation/part-09-s03-product-fix-handoff.md`
- `._design_docs/.test_reports/stage23-sl-matrix-20260621-01.md`
- `._design_docs/.test_reports/stage23-sl-matrix-20260621-01-fixes.md`
- `tools/server/server-cache-hybrid.cpp`
- `tools/server/server-cache-hybrid.h`
- `tools/server/server-context.cpp`
- `tests/test-cache-controller.cpp`

Note: the user-specified root `.test_reports` path is not present in this
worktree. The Stage 23 plan and handoff link the actual durable reports under
`._design_docs/.test_reports/`.

## Verdict

VERDICT: REWORK.

The demotion pressure fix is directionally sound, but the checkpoint-list fix is
not complete enough for S03 review signoff. The code now drops raw checkpoint
lists when checkpoint payload admission is skipped, but still stores the full
raw checkpoint list after one latest checkpoint payload admits. That leaves a
known S03 memory-growth class only partly bounded and not covered by focused
tests.

QA must not rerun S03 for acceptance until the blocking finding below is fixed
or Manager records an explicit contract change.

## Decisions

- Demotion-byte budget guard: accepted. `demote_payload` now rejects another
  demotion when current demoting descriptor bytes plus the next hot payload
  would exceed `limit_size`. This preserves the Stage 21/22 resident-byte rule
  because demoting descriptors keep their resident byte count until completion.
- Immediate eviction fallback: accepted. A `false` return from `demote_payload`
  reaches `mark_payload_kind_evicted`, logs fallback, marks the descriptor
  `evicted`, zeros resident bytes, erases the hot record, clears the entry
  payload id, refreshes accounting, and syncs branch metadata.
- Target/draft invariants: no blocker found in the demotion guard path. The
  byte estimate uses target plus draft bytes, and the existing pair validation
  remains in the demotion path.
- Stage 22 demotion invariant: accepted only under the later Manager-approved
  D22 bug-fix contract, not the older design wording. Current durable Stage 22
  implementation evidence permits exact restore from a demoting descriptor only
  while resident bytes and the hot payload record remain present; cold and
  promoting stay unavailable.
- Cold-store invariants: no new cold-store transition bug found. Cold-budget
  make-room still runs after the hot demotion-pressure guard, and failed
  demotion still falls back to hot eviction without creating partial cold
  residency.
- Metrics and observability: no public metric-name change found. The new guard
  uses existing transition and Stage 10 diagnostic recording. The admitted
  checkpoint-list issue is visible in `size_bytes`, but the hot-payload
  eviction planner uses resident payload bytes, not full entry size, so
  observability does not make the behavior bounded.

## Findings

| ID | Severity | Finding | Required correction |
| --- | --- | --- | --- |
| F-23-S03-AR-01 | BLOCKING | `admit_latest_checkpoint_and_store_metadata` still assigns `entry.checkpoints = checkpoints` after admitting only `checkpoints.back()` (`server-cache-hybrid.cpp`). Each `common_prompt_checkpoint` owns `data_tgt` and `data_dft`, and `hybrid_cache_entry::size()` counts those raw vectors. The S03 fix report identifies full checkpoint-list copying as the second crash source, but the fix only drops the list on skipped admission. If checkpoint admission succeeds, the cache can still retain duplicated raw checkpoint payloads outside descriptor-owned hot-payload eviction pressure, because policy candidates and resident-budget checks use `resident_payload_bytes`, not full entry size. | Store only bounded checkpoint metadata after admission, clear raw `data_tgt`/`data_dft` before retaining the list, or add a documented budget guard that accounts retained checkpoint-list bytes in eviction pressure. Add a focused regression where checkpoint admission succeeds with more than one checkpoint and proves retained raw bytes are bounded. |
| F-23-S03-AR-02 | BLOCKING | Focused tests do not prove the corrected S03 contract across the risky success path. `test_stage23_skipped_checkpoint_admission_does_not_store_checkpoint_list` covers only skipped admission, and `test_stage23_demotion_queue_budget_pressure_falls_back_to_eviction` covers target-only 100-byte payloads. There is no Stage 23 regression for successful checkpoint admission with multiple checkpoint blobs, and no target-and-draft pressure boundary for the new demotion-byte guard. | Add focused tests for successful checkpoint admission with multiple checkpoint entries and for target-and-draft demotion pressure at the budget boundary. The tests should fail if raw checkpoint vectors remain unbounded or if the guard accounts only target bytes. |

## Non-blocking notes

- The demotion guard recomputes demoting bytes for the log after recording the
  diagnostic. That is harmless in this single-threaded controller path, but a
  local variable would make the warning match the branch condition exactly.
- The 1-minute S03 smoke is useful diagnostic evidence. It is not enough to
  replace the required S03 rerun once this review closes.

## Handoff

Gate state: REWORK.

Next owner: Developer. Fix F-23-S03-AR-01 and F-23-S03-AR-02, update the S03
fix report or Stage 23 implementation part with the corrected behavior and
focused evidence, then return for Architect re-review. After Architect PASS,
QA may rerun S03 only with the same CUDA-gated Stage 23 command shape and a
fresh output suffix.

This file uses plain ASCII text and stays under the 300-line durable-doc cap.
