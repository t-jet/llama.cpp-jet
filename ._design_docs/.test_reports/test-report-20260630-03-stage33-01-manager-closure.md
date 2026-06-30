# Stage 33 Manager closure 2026-06-30

Verdict: PARTIAL (PASS-WITH-ACCEPTANCE per Developer review)

## Scope

Stage 33 ran the full legacy-vs-hybrid A/B comparison on the current tree with the Stage 31 and Stage 32 fixes applied. The stage answer three questions from the intake brief:

1. Does the current hybrid cache behavior preserve correctness?
   **YES** (Phase-1 output equivalence `diff.txt` is 0 bytes; legacy-decoded = hybrid-decoded = 4 bytes).
2. Does the current hybrid cache behavior improve hot-RAM use?
   **YES** (hybrid 160.9 MiB vs legacy 423.7 MiB on all 3 comparable completed legs; 62% reduction).
3. Does the current hybrid cache behavior show live cache reuse compared with legacy?
   **UNDEMONSTRATED under this workload** (Hybrid reuse row reclassified from FAIL to EXPECTED BEHAVIOR by Developer review).

## Gate evidence

- Manager intake brief: `._design_docs/.manager-inputs/manager-input-20260630-stage33-full-legacy-hybrid-ab-comparison.md` (pre-execution brief; not an approved design).
- Stage 32 closure baseline: `._design_docs/cache-handling-phase32-implementation/part-06-manager-closure-20260630.md` (PASS 2026-06-30; F32-FIX-01 driver extraction and F32-FIX-02 aggregate metric labels both verified).
- Stage 32 corrected implementation plan: `._design_docs/cache-handling-phase32-implementation.md` plus part-02 (corrections) and part-03 (re-review PASS).
- Stage 32 test plan: `._design_docs/cache-handling-test-plan/part-36-stage32-live-comparison-rerun.md` plus review PASS `stage-32-test-plan-review-20260630.md`.
- Stage 33 QA execution report: `._design_docs/.test_reports/test-report-20260630-03-stage33-01.md` (PASS=11, FAIL=1, BLOCKED=0; PARTIAL flag on warm cycle coverage; verdict FAIL).
- Stage 33 Developer test-results review: `._design_docs/.test_reports/test-report-20260630-03-stage33-01-developer-review.md` (verdict REWORK on Hybrid reuse row, PASS-WITH-ACCEPTANCE overall; 11 rows hold, 1 row reclassified to EXPECTED BEHAVIOR; no product bug).
- Run root: `_test_output/stage33-cache-modes-20260630-01/` (verified by Test-Path; 6 of 8 legs complete; warm-cycle-3 killed at 187 min wall-clock budget).
- Hybrid cold path: `D:\tmp\cache-cold-stage33-20260630-01\` (26 .cold files, 2038.5 MiB, 0 failure counters).

## Manager decisions

D33-CLOSURE-01: Stage 33 closes as PARTIAL with the Developer reclassification accepted. The Hybrid reuse row is NOT a product regression; it is the expected steady-state answer for a long-spaced-duplicate workload against a 512 MiB hot cache holding 6 entries of ~85 MiB each.

D33-CLOSURE-02: The comparison target from the intake brief is partially achieved:

- Correctness preserved (byte-identical output equivalence PASS).
- Hot-RAM improved (62% reduction PASS).
- Live cache reuse undemonstrated under this workload shape (workload design / cache-budget mismatch, not a product defect).

D33-CLOSURE-03: No Stage 33 product bug remains open. Driver extraction is the Stage-32-corrected code path (`compare-legacy-vs-hybrid.ps1` L148-L162, `usage.prompt_tokens_details.cached_tokens` first then `timings.cache_n` fallback). Stage 32 focused retest proved this same driver produced `cache_n` `0,1911,1911,1911,1911,1911` and `cache_hits_total{mode="hybrid"}` delta +5 on six tight-burst chat-completion requests against the same Qwen3.5-4B MTP fixture.

D33-CLOSURE-04: Cold-store auto-load at server start is NOT a regression. Cold store loads on-demand by design (Stage 29 design L96, `cache-handling-architecture.md` L9). Cold-start cycle 1 hybrid `metrics-before` showing `cache_entries=0` despite 26 .cold files in the cold path is the expected first-cycle behavior.

D33-CLOSURE-05: Optional follow-up is OPEN, not required for Stage 33 closure. If broader warm-cycle or higher-confidence hybrid reuse evidence is desired, open a fresh Stage 34 (not a Stage 33 correction loop) with a tighter duplicate-spacing workload (8-burst x 6 repeats = 48 traffic rows, tight bursts over 10 s each, mimicking the Stage 32 focused retest shape at larger scale). This requires a new intake brief from the user; Stage 33 does not extend itself.

## Per-row final classification (12 rows)

| # | Row | QA verdict | Developer verdict | Closure verdict |
| -: | --- | --- | --- | --- |
| 1 | Setup | PASS | PASS (hold) | PASS |
| 2 | Correctness | PASS | PASS (hold) | PASS |
| 3 | Hybrid reuse | FAIL | REWORK -> EXPECTED BEHAVIOR | EXPECTED BEHAVIOR (not a bug) |
| 4 | Namespace bounds | PASS | PASS (hold) | PASS |
| 5 | Public metric labels | PASS | PASS (hold) | PASS |
| 6 | HELP/TYPE shape | PASS | PASS (hold) | PASS |
| 7 | Hot RAM | PASS | PASS (hold) | PASS |
| 8 | Cold store | PASS | PASS (hold) | PASS |
| 9 | Performance | PASS | PASS (hold) | PASS |
| 10 | Errors | PASS | PASS (hold) | PASS |
| 11 | Cleanup | PASS | PASS (hold) | PASS |
| 12 | Hygiene | PASS | PASS (hold) | PASS |

Final tally: 11 PASS, 1 EXPECTED BEHAVIOR (workload design / cache-budget mismatch), 0 FAIL, 0 BLOCKED.

## Code change summary

**No code changes in Stage 33.** Driver, workload generator, and product code were reused as-is from Stage 32 closure. The Stage 32 fixes (F32-FIX-01 driver extraction, F32-FIX-02 aggregate metric labels) remain UNCOMMITTED per AGENTS.md; user approval is required before any commit.

## Follow-ups

1. **D33-FU-01**: Optional Stage 34 with tighter duplicate-spacing workload if broader hybrid reuse evidence is wanted. New intake brief required.
2. **Stage 32 code commit**: Awaiting user approval per AGENTS.md for `tools/server/server-cache-hybrid.cpp` and the driver changes.
3. **Wall-clock budget observation**: 187 min actual vs 180 min budget (over by 7 min). The MTP model at 4096 ctx + 200 requests + 8 legs remains the limiting factor; future 8-leg runs should reserve 200 min or reduce warm cycles to 2.

## Closure checklist

- Stage 29 design + Stage 32 design deltas reused (both approved; Stage 32 design review PASS 2026-06-30).
- Stage 32 corrected implementation plan + re-review PASS reused.
- Stage 32 test plan + review PASS reused.
- Stage 33 QA execution produced durable report + verified evidence paths.
- Stage 33 Developer test-results review accepted with reclassification rationale.
- Document index and stage tracker updated to reflect Stage 33 PARTIAL closure.
- No unresolved review findings remain.
- No product bug remains.

## Handoff

Stage 33 is closed. Next owner: user (decides optional Stage 34 follow-up or commits Stage 32 code).
