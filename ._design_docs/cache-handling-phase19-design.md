# Stage 19 design: system-level model warmup crash investigation

Status: authored; pending Architect design review
Date: 2026-06-18
Stage: 19 (System-Level Model Warmup Crash Investigation)
Author: Architect (design, fresh session)
Scope: Stage 19 design only. Not re-review of Stage 17 or 18, not implementation, not test plan, not Stage 20.

## Scope

This design addresses the open question from Manager decision D17-EXEC-02
(stage 17 closure, 2026-06-17): does the system-level model warmup crash
reproduce on the BASELINE path (no cache flags, default config, model
warmup only) in the current system state, and what is the disposition?

The Stage 18 fix (closure 2026-06-18, D18-CLOSURE-01) moved the cache
validation block from `tools/server/server-context.cpp` lines 1381-1427
to lines 1242-1291, placed BEFORE `llama_init = common_init_from_params`
at line 1292. The fix resolved F-18-EXEC-01 and F-18-EXEC-02 by
replacing 8 `throw std::runtime_error` with `return false` and moving
the block to before the model warmup step.

The Stage 18 fix is GATED by `if (params_base.cache_ram_mib != 0)`. The
baseline path (no `--cache-ram-mib`, default 0) does NOT exercise the
validation block. The baseline warmup crash, if it still reproduces, is
NOT addressed by the Stage 18 fix.

## Non-goals

- Not re-review of Stage 17 or Stage 18 implementation.
- Not a code fix; this design documents the investigation plan, not a fix.
- Not a test plan; a separate test plan follows if the investigation
  surfaces actionable rows.
- Not Stage 20 (test infrastructure additions).
- Not changes to other build directories.
- Not a new test framework, fixture, or harness.

## Prerequisites

| Prerequisite | Source | Status |
| --- | --- | --- |
| Stage 18 closed | `cache-handling-phase18-implementation.md` D18-CLOSURE-01, 2026-06-18 | PASS (14 PASS / 0 FAIL in rerun) |
| Stage 17 D17-EXEC-02 baseline crash evidence | `cache-handling-phase17-implementation.md` D17-EXEC-02, 2026-06-17 | Closed (OUT OF SCOPE for F-17-EXEC-01; deferred to Stage 19) |
| Baseline crash details (3/3 trials, fit_params 9933 vs 1466 MiB) | `test-report-20260617-01.md` F-17-EXEC-01 row 14; `cache-handling-phase17-implementation/part-06-architect-bugfix-review-gate-01.md` row 14 | Recorded historical evidence |
| Stage 18 fix: validation block at lines 1242-1291, gated by `cache_ram_mib != 0` | `tools/server/server-context.cpp` (current state); `test-report-20260618-01-rerun.md` FT3 | Verified current state |
| Binary state | `build-cov/bin/Release/llama-server.exe` 13312 bytes, LastWriteTime 2026-06-18 02:17:04 | Fresh from Stage 18 iter 2 |
| Worktree on `work-branch`, uncommitted Stage 18 changes | `git log --oneline -5 -- tools/server/server-context.cpp` HEAD `cb93f3dbd` | Verified |

## Contents

- [Part 1: question, three-branch disposition, reproduction plan](cache-handling-phase19-design/part-01-question-disposition-and-reproduction.md)
- [Part 2: root cause analysis and fix proposal](cache-handling-phase19-design/part-02-root-cause-analysis-and-fix-proposal.md)
- [Part 3: test plan rows, closure criteria, traceability](cache-handling-phase19-design/part-03-test-plan-closure-traceability.md)
- [Part 4: risks, open questions, handoff](cache-handling-phase19-design/part-04-risks-open-questions-handoff.md)

## Handoff (entry doc)

Next owner: Architect for independent design review in a fresh session.
See Part 4 for the full handoff checklist and review subject list.

This file uses LF line endings, plain ASCII status labels, and stays under
the 300-line durable doc cap.
