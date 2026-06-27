# Stage 28 design entry: Technical Debt Removal + Open Bug Fixes

Status: closed; Manager gate decision D-CLOSURE-28-01 2026-06-27
Date: 2026-06-26
Stage: 28 (Technical Debt Removal + Open Bug Fixes)
Owner: Architect (design); Developer (implementation); Manager (closure)
Source design: parts 01..05 in this directory
Scope: per user direction 2026-06-26 "remove all technical debt and fix
all known open bugs including the one related to drift." Includes three
known open bugs carried from Stage 27 closure plus a tech-debt inventory
across Stages 24-27.

## Goal

Remove every known technical debt item and fix every known open bug
discovered during Stages 24-27. This stage is the consolidation stage:
it does not introduce new architecture, it does not change CLI flags, it
does not change runner contracts. It fixes what is broken and cleans what
is stale, so the next substantive stage starts from a clean baseline.

Scope inputs:

- Stage 27 closure follow-ups: TP-26-UT6 test artifact (D-EXEC-27-09),
  S02 hybrid cold-store metric vs filesystem drift (D-EXEC-24-03-c),
  AddressSanitizer infrastructure LNK2038 mismatch (D-EXEC-27-09 carry).
- Stages 24-27 tech debt inventory (this design carries the catalog).
- User direction "Close the current stage and open a next one dedicated
  to bugfixing" (2026-06-26).

## Constraints (binding from D28-DESIGN-01)

- DESIGN ONLY in this session. NO production code, test code, runner, or
  test plan modifications by the Architect. The Developer owns code
  changes after Manager gate PASS.
- Preserve all Stage 24-27 invariants:
  - F-21-EXEC-01 (prompt-only save).
  - F-21-RERUN-01 (descriptor tracking).
  - F-22-DR-01 (demotion coordination).
  - I-25-01 (atomicity), I-25-02 (isolation), I-25-03 (durability-within-transaction).
  - D-EXEC-26-01 (SEH handler), D-EXEC-26-02 (argv function-scope vector),
    D-EXEC-26-02 cold-store per-id accounting.
  - D-EXEC-27-08 (tx_demote_payload at line 3396).
- ASCII only, LF line endings, no BOM, no trailing whitespace.
- Each part under 300 lines.
- `git diff --check` clean on every file at close.

## Architecture invariants preserved

All Stage 25-27 invariants listed above are preserved. No public CLI
flags, public endpoint schemas, public metric names, or test fixtures
will change. Runner script receives no Stage 28 modifications beyond a
potential one-line fix for the `leak_scan` property error documented in
[cache-handling-phase27-implementation/part-10-manager-closure-20260626.md](cache-handling-phase27-implementation/part-10-manager-closure-20260626.md)
(classified BLOCKED-runner-cleanup, NOT a product bug; deferred to
Stage 28 follow-up R28-TD-04 below).

## Known open bugs (binding from Stage 27 closure)

1. **TP-26-UT6 test artifact (D-EXEC-27-09)**:
   `tests/test-cache-controller.cpp` line 3707 `assert(stage23_admit_checkpoint_store(...))`
   uses `assert()` which is conditionally disabled by `NDEBUG`. The test
   file undefines `NDEBUG` at line 22 so asserts are active in this TU,
   but the Stage 27 closure deferred the fix because the test exits via
   explicit `std::abort()` raising `__fastfail(FAST_FAIL_FATAL_APP_EXIT)`
   (exit code -1073740791 / 0xC0000409). Root cause is the inconsistent
   abort pattern: prior asserts pass silently while new asserts plus
   `fprintf + std::abort()` raise the fast-fail. Fix scope: replace all
   `assert(condition)` in this file with explicit abort-on-fail pattern
   when the test infrastructure depends on Release-build assertions
   firing reliably.

2. **S02 hybrid cold-store metric vs filesystem drift (D-EXEC-24-03-c)**:
   5.37 GiB on disk vs 502 MiB metric in S02 hybrid leg of Stage 24 -07.
   Per-file size is uniform 52,691,612 bytes (50.25 MiB); 102 files on
   disk, but `cold_payload_bytes_by_id_` map sums to 502 MiB (10 entries).
   So ~92 cold files are NOT tracked in the per-id map. Root cause is an
   orphan-file path: when `cold_store.remove()` fails (Windows file lock,
   AV scan, race) the per-id map entry stays, but the more common orphan
   path is `cold_budget_make_room` early-`continue` (line 641) when
   `cold_store.remove()` returns false on a still-tracked id. Need a
   focused diagnosis step before the fix shape is final.

3. **AddressSanitizer LNK2038 mismatch**: 274 link errors when building
   llama-server with ASan+CUDA via the CMakeLists side-channel. MSVC
   `annotate_string`/`annotate_vector` SAL annotations differ between
   `ggml-cuda.lib` (built without `/fsanitize`) and `llama-server-impl.lib`
   (built with `/fsanitize`). Root cause is the per-target ASan flag set
   in the side-channel build that does not propagate to the ggml-cuda
   static library target. Fix: rebuild ggml-cuda with the same `/fsanitize`
   flags or build the server executable in a single translation unit.

## Tech debt inventory (binding, see part-01)

22 items inventoried across Stages 24-27 plus the async worker code
inventory added 2026-06-26. Severity breakdown:

- HIGH: 4 (the three known bugs above plus R28-BUG-04 async worker
  code retention: 2 production paths still call the legacy async API
  and silently hang because the worker thread is never started).
- MEDIUM: 7 (stale doc references, missing regression tests, async
  worker thread infrastructure deletion post-deprecation).
- LOW: 11 (cosmetic prose, redundant comments, metric name drift).

The HIGH items are the binding scope. The MEDIUM items are in-scope for
iteration 2. The LOW items are out-of-scope unless they share a commit
with a HIGH or MEDIUM fix.

## Amendment record

- 2026-06-26 (user direction): added R28-BUG-04 async worker code
  retention after inventory of `io_worker` class, `enqueue_demotion`,
  `enqueue_promotion`, `process_completions`, `handle_demotion_completion`,
  worker thread, and the 41+ test refs to `debug_*_io_worker_for_tests`.
  Inventory surfaced 2 broken production paths (`load_slot` line 4929,
  `stage23_admit_checkpoint_store` line 1875-1899). Promoted R28-TD-05
  from deferred-to-Stage-29 to iteration 2 MEDIUM, conditional on
  R28-BUG-04 Phase B deprecation landing first. No new design files;
  amended part-01, part-03, part-05 in place.

## Contents

| Part | Title | Status |
| --- | --- | --- |
| [part-01](./cache-handling-phase28-design/part-01-tech-debt-inventory.md) | Tech debt inventory across Stages 24-27 with severity and fix estimates | this draft |
| [part-02](./cache-handling-phase28-design/part-02-known-bug-fixes.md) | Fix design for the four known open bugs (TP-26-UT6, cold-store drift, ASan LNK2038, async worker retention) | this draft |
| [part-03](./cache-handling-phase28-design/part-03-prioritized-fix-order.md) | Iteration plan: HIGH first, then MEDIUM, then LOW | this draft |
| [part-04](./cache-handling-phase28-design/part-04-verification-plan.md) | Verification plan per fix, plus regression of existing 138-test pack | this draft |
| [part-05](./cache-handling-phase28-design/part-05-risks.md) | Risks, coupling between fixes, what could break | this draft |

## Hard constraints (binding)

- DO NOT modify production code, test code, runner, test plan, or
  tracker in this design session.
- ASCII only, LF line endings, no BOM, no trailing whitespace.
- Each part file under 300 lines.
- `git diff --check` clean on every file at close.
- Preserve all Stage 24-27 invariants listed above.

## Handoff

Next owner: Manager (design gate review). After Manager gate PASS:
Developer (implementation). After Developer implementation PASS:
QA (regression + focused rerun). After QA PASS: Manager (closure per
D-CLOSURE-28-01, conditional on user commit approval per AGENTS.md).

This file uses LF line endings, plain ASCII status labels, no BOM,
no trailing whitespace, and stays under the 300-line durable-doc cap.
