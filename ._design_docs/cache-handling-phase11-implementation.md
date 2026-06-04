# Stage 11 implementation log: upstream merge integration

Status: STAGE 11 CLOSED. PASS with T114a tooling limitation.
Planning date: 2026-06-04
Closure date: 2026-06-04
Design document: [cache-handling-phase11-design.md](cache-handling-phase11-design.md)
Architecture document: [cache-handling-architecture.md](cache-handling-architecture.md)
Requirements document: [cache-handling-requirements.md](cache-handling-requirements.md)

## Scope

This log records the Stage 11 implementation plan for upstream merge
integration. Stage 11 re-syncs the fork with `upstream_master` and reworks
prior stages when upstream cache, checkpoint, or speculative decoding
changes invalidate them. The scope is fixed by the architecture and is
carried into the design verbatim. This plan adds the ordered steps,
prerequisites, evidence, and risks the merge and rework activity needs.

This planning pass does not approve the upstream merge, code work, test
execution, coverage execution, k6, commits, PR text, or reviewer
responses.

## Manager plan-change decisions

- 2026-06-04: The Manager overrode design decision 1 (single primary
  `upstream` remote, `master` ref). The upstream reference is the
  local `upstream_master` tracking branch. The Developer verifies the
  branch is current before the merge. The design will be updated in a
  future Architect correction gate.
- 2026-06-04: Closure plan change. The Manager overrode the test
  plan T114a 70% floor closure contract and accepted the T114a row
  as a known MSVC `/Ob2` inlining tooling limitation. The T114a
  FAIL row is not reclassified to PASS. The 70% floor and the
  11-file product-only denominator are unchanged in the test
  plan. The closure record documents the tooling limitation and a
  follow-up plan to disable `/Ob2` for the test target (or add
  `__declspec(noinline)`) in a future stage and rerun coverage to
  verify the rate can be lifted. The closure status is PASS with
  the T114a row in FAIL. The full closure record is in
  [part-09-stage11-closure.md](cache-handling-phase11-implementation/part-09-stage11-closure.md)
  and the T114a tooling limitation addendum is in
  [part-14-t114a-tooling-limitation.md](cache-handling-test-plan/part-14-t114a-tooling-limitation.md).

## Manager decisions log

The Manager records the per-decision outcome here. The Developer
records the chosen path in the merge log "Cover and metadata"
section when Step 3 opens.

- 2026-06-04: D1 (fork point SHA) approved. Fork point is
  `40d5358d3c730b81729ba81cd5c44ed596d02510`. The Developer proceeds
  with Step 3 merge execution against this fork point. A change to
  the fork point after the pre-merge analysis closes reopens the
  pre-merge analysis per design Part 6.
- 2026-06-04: D6 (stale `upstream_master` 5-commit gap) resolved.
  The Developer proceeds with the current 5-commit gap and re-syncs
  `upstream_master` from `https://github.com/ggml-org/llama.cpp.git`
  `master` after the merge closes. The 5 missing upstream commits
  (`e3ba22d6`, `7ac5a422`, `00664040`, `4d742877`, `45864798`) are
  recorded as a known gap in the merge log. The 5-commit gap does
  not invalidate a prior-stage contract from design Part 1 because
  3 of the 5 touch only mtmd, cmake, or xcframework paths outside
  the file-glob groups in design Part 2, and 2 add
  `#include <unordered_map>` to `tools/server/server-http.h` with
  null functional impact (the include was already available
  transitively).

## Contents

- [Part 1: Implementation plan, prerequisites, and gates](cache-handling-phase11-implementation/part-01-implementation-plan.md)
- [Part 2: Evidence plan, risks, and open decisions](cache-handling-phase11-implementation/part-02-evidence-plan-and-risks.md)
- [Part 3: Open decisions for Manager](cache-handling-phase11-implementation/part-03-known-decisions.md)
- [Part 4: Prerequisites: run_coverage.ps1 T114a change and upstream reference verification](cache-handling-phase11-implementation/part-04-prerequisites.md)
- [Pre-merge report 2026-06-04-01](cache-handling-phase11-implementation/pre-merge-report-20260604-01.md)
- [Architect pre-merge review gate 01](cache-handling-phase11-implementation/part-07-architect-pre-merge-review-gate-01.md)
- [Merge log 2026-06-04-01](cache-handling-phase11-implementation/merge-log-20260604-01.md)
- [Part 9: Stage 11 closure (2026-06-04)](cache-handling-phase11-implementation/part-09-stage11-closure.md)
- [Test report 2026-06-04-04 and fixes handoff](.test_reports/test-report-20260604-04.md)

## Current gate

The accepted design baseline is
[cache-handling-phase11-design.md](cache-handling-phase11-design.md), Parts
01 through 06, plus the Architect design review in
[part-07-design-review-gate-01.md](cache-handling-phase11-design/part-07-design-review-gate-01.md)
(verdict PASS, 7 of 7 author decisions accepted). The Manager design-gate
decision is PASS, dated 2026-06-04.

The `run_coverage.ps1` T114a prerequisite gate closed PASS on 2026-06-04
after the Architect review recorded in
[part-06-architect-prereq-script-review-gate-01.md](cache-handling-phase11-implementation/part-06-architect-prereq-script-review-gate-01.md).

Step 1 of the implementation plan, the pre-merge analysis, closed on
2026-06-04 with the pre-merge report on disk at
[pre-merge-report-20260604-01.md](cache-handling-phase11-implementation/pre-merge-report-20260604-01.md).

Step 2, the Manager review of the pre-merge analysis, closed on
2026-06-04 with the Architect pre-merge review verdict PASS in
[part-07-architect-pre-merge-review-gate-01.md](cache-handling-phase11-implementation/part-07-architect-pre-merge-review-gate-01.md).
The Manager D1 (fork point SHA) and D6 (5-commit staleness gap)
decisions are recorded in the "Manager decisions log" section above
and in the pre-merge report "D6 outcome" section.

Step 3 (merge execution) closed on 2026-06-04 with merge commit
`72cfbcd44` on branch `cache-optimization-stage11-merge`. The merge
integrated 225 upstream commits from the local `upstream_master`
tracking branch (5 commits behind actual upstream `master`; D6
known gap). The merge surfaced 4 conflicts, all resolved per the
design Part 3 hybrid-and-legacy preservation and
local-first-for-hybrid-mode policy. The full per-conflict table is
in the merge log.

Step 4 (per-rework planning) closed on 2026-06-04 with 0 rework
candidates. The pre-merge triage recorded 0 REWORK-REQUIRED
commits. The merge did not surface any new contract-breaking
change that the pre-merge triage missed. The local's
`split_state_cache.clear()` defensive intent in
`ggml_backend_meta_buffer_reset` is documented in a code comment
as a follow-up item for a future Stage 11 cycle.

Step 5 (regression test scope) closed on 2026-06-04. The minimum
regression scope per the Architect pre-merge review ran: build
(PASS), ctest (PARTIAL, 1 pre-existing test failure), focused
ctest (PARTIAL, 1 pre-existing test failure), HTTP probe T121
(PASS, `cache_checkpoint_admission_failures_total{mode="hybrid"}`
is non-zero), coverage T114 (FAIL, 0/0 lines from a script merge
failure), coverage T114a (FAIL, 0/0 lines from the same script
failure). The two FAIL rows are pre-existing local issues that
the merge surfaced but did not introduce. The full per-row
verdicts and artifact citations are in the test report at
[test-report-20260604-04.md](.test_reports/test-report-20260604-04.md).

Step 6 (merge log and Stage 11 closure) closed on 2026-06-04 with
the merge log on disk at
[merge-log-20260604-01.md](cache-handling-phase11-implementation/merge-log-20260604-01.md).
The Stage 11 closure status is PASS with the T114a tooling
limitation recorded in the new "Stage 11 closure (2026-06-04)"
section below. The T114 and T121 closure contracts are met. The
T114a row is FAIL by 0.0026 (0.6974 vs 0.70) and is closed as a
known tooling limitation rather than a product gap. The Manager
closure decision is recorded in the entry doc "Manager
decisions log" section above. The Manager D1 and D6 decisions
remain as recorded earlier.

## Advisory findings from design review

| ID | Finding | Plan resolution |
| --- | --- | --- |
| -- | -- | -- |

The Architect's design review recorded zero blocking findings and zero
advisory findings. The seven decisions the design author flagged for
Manager confirmation are accepted as written in the review verdict. No
design rework is required before implementation planning.

## Stage gate

| Gate | Status |
| --- | --- |
| Stage 10 closure prerequisite | PASS |
| Stage 11 design authoring | PASS |
| Stage 11 independent design review | PASS |
| Stage 11 manager design gate | PASS |
| Stage 11 implementation planning | PASS, 2026-06-04 |
| Stage 11 run_coverage.ps1 T114a prerequisite | PASS, 2026-06-04 |
| Stage 11 pre-merge analysis (Step 1) | PASS, 2026-06-04 |
| Stage 11 Manager review of pre-merge analysis (Step 2) | PASS, 2026-06-04 |
| Stage 11 merge execution (Step 3) | PASS, 2026-06-04 |
| Stage 11 per-rework planning (Step 4) | PASS, 2026-06-04 (0 reworks) |
| Stage 11 regression test scope (Step 5) | PASS with 2 FAIL rows, 2026-06-04 (routed to fixes handoff) |
| Stage 11 merge log and closure (Step 6) | PASS with T114a tooling limitation, 2026-06-04 |
| Stage 11 QA execution | NOT STARTED |

## Handoff

This implementation log records the Stage 11 implementation
plan and execution. The merge commit is `72cfbcd44` on branch
`cache-optimization-stage11-merge`. The merge log is on disk
at
[merge-log-20260604-01.md](cache-handling-phase11-implementation/merge-log-20260604-01.md).
The executed test report and rerun evidence are at
[test-report-20260604-04.md](.test_reports/test-report-20260604-04.md),
[test-report-20260604-04-rerun.md](.test_reports/test-report-20260604-04-rerun.md),
[test-report-20260604-04-fixes.md](.test_reports/test-report-20260604-04-fixes.md),
and
[test-report-20260604-04-rerun-fixes.md](.test_reports/test-report-20260604-04-rerun-fixes.md).
The Stage 11 closure status is PASS with the T114a tooling
limitation. The next gate is Stage 12 (per the architecture
doc, the next stage is Stress Testing and Benchmarking). The
next owner is the Stage 12 Architect (or the next Architect
activity if a different sequence is chosen).

## Stage 11 closure (2026-06-04)

The Stage 11 closure record, including the Manager closure
decision, final test counts, T114a tooling limitation,
follow-up plan, commit list, Manager D1 and D6 decisions,
evidence pointers, and closure rationale, is recorded in
[part-09-stage11-closure.md](cache-handling-phase11-implementation/part-09-stage11-closure.md).
The T114 and T121 closure contracts are met. The T114a
product-only row is FAIL by 0.0026 and is closed as a
known MSVC `/Ob2` inlining tooling limitation with a
follow-up plan.
