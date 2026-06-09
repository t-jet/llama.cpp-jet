# Stage 12 test plan review

- Review ID: part-20-stage12-test-plan-review
- Date: 2026-06-07
- Reviewer: QA agent (fresh session)
- Source plan: ._design_docs/cache-handling-test-plan/part-18, part-18a, part-19
- Source impl: cache-handling-phase12-implementation/part-01, part-03, part-05, part-06
- Source entry: ._design_docs/cache-handling-test-plan.md

## 1. Scope

Review covers Stage 12 test plan parts 18, 18a, and 19, the
test-plan entry document, and the related implementation parts
01, 03, 05, and 06. No edits to product code, harness scripts,
self-improvement assets, prior doc/skill mods, or coverage run
dirs. Review is read-only; this file records findings and
verdict for Manager handoff.

## 2. Scenario coverage

| Scenario | Plan section | Status |
| --- | --- | --- |
| S12-S01..S08 (8 stress) | part-18 section 3 table | covered |
| S12-B01..B08 (8 bench) | part-18 section 4 table | covered |
| S12-L01..L03 (3 long-run) | part-18 section 5 table, part-18a section 8 | covered |
| S12-B05-NL, S12-B08-NL (2 nearest-legacy, S12-PLAN-01) | part-18a section 13 | covered |
| 8 preflight focused tests | part-18a section 10 | covered |

Total: 29 rows. Coverage matrix matches impl part-01 stress map,
bench map, long-run table, and preflight ctest list.

## 3. Pass/fail criteria check

| Scenario | Criteria summary | Status |
| --- | --- | --- |
| S12-S01 budget exhaustion | requests complete, payload bytes bounded, eviction counters increase, no crash, no corrupt restore | covered (part-18 table) |
| S12-S05 mixed workload | namespace separation holds, profile strategy follows Stage 9 rules, unsupported shapes fail or fall back | covered (part-18 table) |
| S12-B01 exact hit | hybrid records measurable exact hits, no correctness regression | covered (part-18 table) |
| S12-B05 restore latency | p50/p95/p99 by payload kind and residency, no unbounded tail growth, correctness evidence | covered (part-18 table) |
| S12-L01 6h stability | working set < 10% growth, handle < 5%, monotonic counters, p95 drift < 20%, no crash or unbounded log/label growth | covered (part-18a section 8 thresholds) |

## 4. Configuration matrix check

part-18 section 2 clean-build block matches the cap-fix closure
baseline from impl part-29: build-cov with BUILD_SHARED_LIBS=OFF,
/Zi /Ob1 /O2 /EHsc, /DEBUG:FULL, GGML_CUDA=OFF, Release only.
VS18 2026 generator matches the locked build-cov cache. Binary
freshness check is the 10-minute rule. Section 6 matrix lists
all 10 design dimensions with required values. match: PASS.

## 5. Evidence format check

part-18 section 7 evidence format matches impl part-01 evidence
section field-for-field: stress and benchmark dir templates,
baseline JSON shape (commit SHA, build type, binary timestamp,
host hardware, model fixture, slot count, context length, draft
mode, server flags, prompt generator seed, warmup window,
measurement window, request count, throughput, p50/p95/p99
latency, exact-hit rate, checkpoint-hit rate, restore latency by
payload kind, demotion and promotion counts, eviction count,
working set and handle samples, correctness_verdict), and
seven-section tuning report skeleton. match: PASS.

## 6. BLOCKED rules check

- MTP-capable Qwen3.5-4B held out per cap-fix closure: part-18a
  section 11 confirms; H53/H54 carry-forward blocked.
- test-stage10-policy-lru pre-existing bug out of scope: part-18a
  section 11 confirms; LRU bug is in server-cache-policy-lru.cpp
  and needs separate session.
- S12-S02 parallel 8 host-dependent: part-18 table BLOCKED rule
  matches impl part-01 risk; condition is host cannot start at
  the requested slot count.
- S12-S05/B07 checkpoint Qwen3-8B dependent: part-18 table and
  part-19 STUB triggers both reference Qwen3-8B failing to admit
  a checkpoint at in-scope --ctx-size.

match: PASS.

## 7. Out-of-scope discipline

Part-18/18a/19 use only YYYYMMDD-NN placeholders for evidence
dir paths. No specific test run dates, report numbers, or
previous baseline values cited. Generic posture is correct.
Cosmetic and cleanup follow-ups (S02 dry-run port print, dry-run
evidence dir residue) are flagged in part-19 section 8 as known
items, not defects.

## 8. Verdict

PASS.

All 29 rows are covered. Pass/fail criteria, BLOCKED rules,
config matrix, and evidence format match the implementation
plan and the cap-fix closure baseline. Test plan is generic.
No blocking gaps remain.

## 9. Manager handoff

| Field | Value |
| --- | --- |
| Verdict | PASS |
| Open findings | none blocking |
| Cosmetic follow-ups (not blocking) | S02 dry-run port print; dry-run evidence dir residue; checkpoint-dependent rows may BLOCK on first live run if Qwen3-8B does not admit a checkpoint at in-scope --ctx-size |
| git diff --check | exit 0 on entry doc (tracked, pre-existing M) and on part-18, part-18a, part-19 (untracked). Raw byte check: CR=0, LF-only, no UTF-8 BOM in all three untracked part files |
| Entry doc Contents | part-18, part-18a, part-19 all linked |
| Next gate | QA execution session opens a fresh test-report-YYYYMMDD-NN.md and consumes the plan; tuning thresholds from part-18a section 8 may be tuned before first run with final values recorded in the report |

Ready for QA execution.
