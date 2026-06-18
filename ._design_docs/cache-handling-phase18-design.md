# Stage 18 design: Stage 17 closure trivial follow-ups

Status: authored; pending Architect design review
Date: 2026-06-18
Stage: 18 (Stage 17 Closure Trivial Follow-ups)
Author: Architect (design, fresh session)
Source: [Stage 17 closure Manager decisions](cache-handling-phase17-implementation.md) D17-EXEC-03 and D17-CLOSURE-02
Scope: Stage 18 design only. Not re-review of Stage 17 or any other stage.
Current gate: Design

## Scope

This design addresses two trivial closure follow-ups recorded in the
Stage 17 closure decisions. Both items are small, low-risk, and rooted in
already-decided Manager closure actions.

Items in scope:

1. Remove the duplicate cold-path-hybrid check at
   `tools/server/server-context.cpp` lines 1554-1557 in the post-slot-init
   block. Source: Manager decision D17-EXEC-03 (Stage 17 closure 2026-06-17).
2. Add `/Zi /DEBUG:FULL` to `CMAKE_CXX_FLAGS_RELEASE` for the `build-cov`
   build configuration so OpenCppCoverage produces coverage data with line
   counts instead of header-only `.cov` files. Source: Manager decision
   D17-CLOSURE-02 / F-16-TR-03 (Stage 17 closure 2026-06-17, inherited from
   Stage 16 closure).

Out of scope:

- D17-EXEC-02 (system-level model warmup crash, STATUS_STACK_BUFFER_OVERRUN).
  Separate stage (Stage 19) per the tracker row.
- Stage 17 test infrastructure additions (agentic prompt generator,
  Qwen3.6-27B-MTP fixture, S/L framework re-invocation). Separate stage
  (Stage 20) per the tracker row.
- Any other closure follow-up not listed above.
- Re-review of Stage 17 implementation or design.
- Changes to other build directories (`build`, `build-cuda`, etc.).

## Contents

- [Part 1: Item 1 design - remove duplicate cold-path-hybrid check](cache-handling-phase18-design/part-01-item1-duplicate-cold-path-hybrid-check.md)
- [Part 2: Item 2 design - add /Zi /DEBUG:FULL to CMAKE_CXX_FLAGS_RELEASE](cache-handling-phase18-design/part-02-item2-cxx-flags-release-debug-info.md)
- [Part 3: Test plan rows, traceability, risks, and handoff](cache-handling-phase18-design/part-03-test-plan-traceability-risks-handoff.md)
- [Part 4: design review gate 01 (Architect, fresh session)](cache-handling-phase18-design/part-04-design-review-gate-01.md)

## Gate status

| Gate | Status |
| --- | --- |
| Stage 18 design authoring | PASS (see entry doc and parts 1-3) |
| Stage 18 design review | PASS (see part 4, 0 BLOCKING, 3 non-blocking, 1 INFO) |
| Stage 18 Manager design gate | PASS (Manager decision 2026-06-18, see below) |
| Stage 18 implementation planning | NOT STARTED |
| Stage 18 implementation | NOT STARTED |
| Stage 18 implementation review | NOT STARTED |
| Stage 18 test planning | NOT STARTED |
| Stage 18 test-plan review | NOT STARTED |
| Stage 18 Manager test-plan gate | NOT STARTED |
| Stage 18 QA execution | NOT STARTED |
| Stage 18 test-results review | NOT STARTED |
| Stage 18 closure | NOT STARTED |

## Manager design gate decision

Date: 2026-06-18
Verdict: PASS

The Stage 18 design is approved. Architect design review (part 4) returned
PASS with 0 BLOCKING, 3 non-blocking, 1 INFO findings. The three
non-blocking findings (F-18-DR-01 duplicate check reachable when
cache_cold_max_mib is 0, F-18-DR-02 test count claim off by 2, F-18-DR-03
byte-identical wording imprecise) and one INFO (F-18-DR-04 CMAKE_BUILD_TYPE
no-op for VS generator) are accepted as Developer verification items and
do not block gate progression.

Both design items correctly map to the source Manager decisions:

- Item 1 (remove duplicate cold-path-hybrid check at server-context.cpp
  lines 1554-1557) maps to D17-EXEC-03.
- Item 2 (add /Zi /DEBUG:FULL to CMAKE_CXX_FLAGS_RELEASE for build-cov)
  maps to D17-CLOSURE-02 / F-16-TR-03.

The design chose Option 1 for Item 2 (cmake configure flag addition,
minimum scope, build-cov only, reversible). Other options were rejected
with documented rationale. The test plan proposes 13 rows (7 focused + 6
integration) covering both items with adequate focused and regression
coverage.

Next gate: implementation planning (Developer, fresh session).

## Prerequisites

- Stage 17 closed on 2026-06-17 per
  [cache-handling-stage-tracker.md](cache-handling-stage-tracker.md) row 17.
- Stage 17 implementation evidence recorded in
  [cache-handling-phase17-implementation.md](cache-handling-phase17-implementation.md).
- Stage 17 bug-fix review (Option B) approved the F-17-EXEC-01 validation
  block move per
  [part-06-architect-bugfix-review-gate-01.md](cache-handling-phase17-implementation/part-06-architect-bugfix-review-gate-01.md).
- The post-slot-init duplicate cold-path-hybrid check at
  server-context.cpp:1554-1557 is the artifact targeted by Item 1.
- The build-cov CMakeCache.txt line 80 (`CMAKE_CXX_FLAGS_RELEASE:STRING=/O2 /Ob2 /DNDEBUG`)
  is the artifact targeted by Item 2.
- Existing test scripts under `._test_output/` and
  `._design_docs/cache-handling-test-scripts/` use `build-cov` as the
  coverage build directory.

## Non-goals

- Modify the F-17-EXEC-01 moved validation block (lines 1384-1428).
- Modify the F-17-EXEC-02 unit test additions in `tests/test-cache-controller.cpp`.
- Modify any other build configuration beyond build-cov's Release flags.
- Modify CMakePresets.json or root CMakeLists.txt for global flag changes.
- Address the system-level model warmup crash (D17-EXEC-02).
- Add new test infrastructure (agentic prompt generator, fixtures, framework
  re-invocation).
- Reopen any closed stage.

## Handoff

Next owner: Architect for design review in a fresh session.

After Architect design review PASS, the design advances to Manager for the
design gate. After Manager design gate PASS, the design advances to
Developer for implementation planning and implementation.

The Stage 17 implementation log, tracker, document-index, and any other
durable doc are NOT modified by this design. This file uses LF line
endings, plain ASCII status labels, and stays under the 300-line durable
doc cap.
