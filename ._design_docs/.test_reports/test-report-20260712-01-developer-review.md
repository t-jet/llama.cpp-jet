# Stage 38 Developer review: QA post-fix retest

Date: 2026-07-12
Owner: Developer
Source report: [test-report-20260712-01.md](test-report-20260712-01.md)
Source fix review:
[test-report-20260711-02-fix-re-review.md](test-report-20260711-02-fix-re-review.md)
Verdict: PASS

## Scope

This review checks the fresh QA post-fix retest against the Stage 38 design,
the Manager test-plan gate, and the fix-loop requirements from report -02.

No code, tests, scripts, build outputs, commits, pushes, staging, or reverts
were performed in this review.

## Freshness

PASS. The QA report is dated 2026-07-12 and follows the Architect fix
re-review PASS for `test-report-20260711-02-fix-re-review.md`.

The report records HEAD `eb3bcb01bf0a89a38469718ab0d0bbf5ec5e58a2`, a dirty
worktree, clean Release configure/build commands, binary timestamps from the
session, direct `test-cache-controller`, `ctest -R cache`, and the live Stage
38 script.

The report includes counts: PASS `11`, FAIL `0`, BLOCKED `0`.

## Artifact spot check

PASS. The cited artifacts below exist on disk:

| Artifact | Path |
| --- | --- |
| Turn 2 response | `._test_output/stage38-prefix-restore-20260712-01/live/turn2.json` |
| Metrics after run | `._test_output/stage38-prefix-restore-20260712-01/live/metrics-post.txt` |
| Live script report | `._test_output/stage38-prefix-restore-20260712-01/live/stage38-script-report.md` |
| Controller log | `._test_output/stage38-prefix-restore-20260712-01/focused/test-cache-controller.log` |
| ctest log | `._test_output/stage38-prefix-restore-20260712-01/focused/ctest-cache.log` |
| Server log | `._test_output/stage38-prefix-restore-20260712-01/live/server.err.log` |

The controller log ends with all tests passed. The ctest log records
`100% tests passed, 0 tests failed out of 1`.

## Evidence checks

PASS. Raw artifact checks match the report:

| Requirement | Result |
| --- | --- |
| `usage.prompt_tokens_details.cached_tokens` | `11` in `turn2.json` |
| `timings.cache_n` | `11` in `turn2.json` |
| Public `usage.prompt_tokens` | `63` in `turn2.json` |
| Hybrid hit delta | `0` to `1`, delta `1` in live script report |
| Accepted prefix metric | `llamacpp:cache_prefix_candidates_total{mode="hybrid",result="accepted",reason="accepted_strict_prefix"} 1` |
| Checkpoint restore metric | `llamacpp:cache_checkpoint_restores_total{mode="hybrid",profile="checkpoint_dependent",payload_residency="hot",pair_state="target_only",result="success"} 1` |
| Checkpoint hit metric | `llamacpp:cache_checkpoint_hits_total{mode="hybrid",profile="checkpoint_dependent",payload_residency="hot",pair_state="target_only"} 1` |
| Cold-budget gauge | `llamacpp:cache_cold_budget_bytes{mode="hybrid"} 2147483648` |
| Cleanup | live script report says port free; QA report records `PORT_FREE=True` |

Server stderr contains `try_restore - successfully restored 11 tokens into
slot 3` and `restore-apply slot=3 restored_tokens=11`.

## Finding classification

| Finding | Classification | Owner | Retest scope |
| --- | --- | --- | --- |
| Original report -01 live prefix failure | Closed QA workload gap | Closed by QA report -02 | None |
| Corrected report -02 checkpoint prefix failure | Closed product bug | Closed by Developer fix and Architect fix re-review PASS | Covered by QA post-fix retest |
| QA report -20260712-01 | PASS | Manager | Closure decision |

No product bug remains. No harness, execution, artifact, cleanup, or stale-build
blocker remains.

## Verdict

PASS. Stage 38 QA post-fix retest satisfies the approved design, Manager
test-plan gate, and fix-loop retest requirements.

Manager may proceed to Stage 38 closure or any additional gate decision.
