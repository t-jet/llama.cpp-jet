# Developer review: Stage 36 QA test results

Report reviewed: `test-report-20260710-02-stage36-stage33-rerun.md`
Date: 2026-07-10
Owner: Developer
Verdict: PASS

## Scope

This review covers the Developer test-results gate only. It checks the QA
report against:

- `._design_docs/cache-handling-phase36-design.md`
- `._design_docs/cache-handling-phase36-implementation.md`
- `._design_docs/cache-handling-test-plan/part-41-stage36-hybrid-hit-performance-validation.md`

No code, scripts, stage tracker, manager closure document, implementation log,
or document index was changed.

## Finding classification

| QA item | Classification | Owner | Retest |
| --- | --- | --- | --- |
| Overall QA verdict PASS | ACCEPTED | Manager | No |
| Fresh Release CUDA setup, direct `test-cache-controller.exe` PASS, fresh binaries | PASS | None | No |
| First `ctest -R cache -V` failed once with `0xc0000409`; immediate rerun PASS | TRANSIENT-NON-BLOCKING | None for Stage 36 | No |
| Tight duplicate workload: 48 rows, 8 bursts, 6 repeats per burst | PASS | None | No |
| Output equivalence diff empty | PASS | None | No |
| Hybrid hits: 40 hit delta and 8 miss delta in both hybrid legs, nonzero `cache_n` on repeat rows | PASS | None | No |
| Hot RAM: hybrid 66.54 percent below comparable legacy rows | PASS | None | No |
| Performance: prompt and generation throughput within 10 percent gate | PASS | None | No |
| Cold-store bytes/count recorded and cold-store failure counters zero | PASS | None | No |
| Metric label bounds, HELP/TYPE uniqueness, namespace count, and security hygiene | PASS | None | No |
| Server log: no crash, SEH dump, fatal request error, checksum mismatch, or token mismatch | PASS | None | No |
| Non-fatal warnings `save rejected because task is null` and `erased invalidated context checkpoint` | ACCEPTED-NON-BLOCKING | None for Stage 36 | No |
| Cleanup: no server process, port free, final cold path recorded | PASS | None | No |
| `cache_cold_budget_bytes{mode="hybrid"}` reports `-2147483648` for 2048 MiB | NON-BLOCKING PRODUCT OBSERVABILITY BUG CANDIDATE | Manager follow-up decision | No for Stage 36 |

## Gate decision

Stage 36 meets the design and Part 41 acceptance criteria. The report shows
positive hybrid hits on the tight duplicate workload, empty output-equivalence
diff, bounded public metrics, unique HELP/TYPE blocks, hot-cache memory
improvement above the 40 percent gate, throughput within the 10 percent gate,
zero cold-store failure counters, clean product-error review, and cleanup PASS.

The one-time `ctest` failure is not a Stage 36 product failure because the
controller passed directly, the same ctest row passed on immediate rerun, and
the model-backed run used fresh binaries after that setup evidence.

The negative `cache_cold_budget_bytes` value is not part of the Stage 36 Part
41 pass/fail rows. It should be tracked as a separate metrics correctness
follow-up if Manager wants budget gauge correctness covered by a later gate.
It does not invalidate the Stage 36 cold-store row because cold bytes, cold
file count, and cold-store failure counters were correct.

## Product bug and retest call

No Stage 36 blocking product bug remains.

One non-blocking product observability bug candidate remains:
`cache_cold_budget_bytes{mode="hybrid"}` overflows or is otherwise encoded
incorrectly for a 2048 MiB budget. This does not require Stage 36 retest.

Manager should accept the QA PASS, close the Stage 36 execution gate, and decide
whether to open a separate follow-up for the cold-budget gauge metric.
