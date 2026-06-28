# Part 10: Traceability

Status: design in progress (Architect session)
Date: 2026-06-28
Stage: 29 (Cache Modes Comparison - legacy vs hybrid)
Source: [../cache-handling-phase29-design.md](../cache-handling-phase29-design.md)

## Requirements traceability

The Stage 29 requirements derive from
[cache-handling-requirements.md](../cache-handling-requirements.md) and the
broader cache-handling requirements tree. Each requirement or requirement
subrange is mapped to a design section.

| Requirement | Source | Design section |
| --- | --- | --- |
| R-REQ-01: hybrid-mode A/B comparison on a representative workload | cache-handling.md "Cache modes" notes | part-01 G1, part-02 D29-DESIGN-01 |
| R-REQ-02: per-request metrics with evidence classification | cache-handling-requirements.md part-02 | part-04 |
| R-REQ-03: cold-store utilization metric | Stage 6 design | part-04 "Per-leg Prometheus gauge snapshots" |
| R-REQ-04: hot-budget accounting | Stage 4 design | part-04 "Per-leg Prometheus gauge snapshots" (`llamacpp:cache_hot_payload_descriptors`) |
| R-REQ-05: bounded metrics with no raw payload bytes | Stage 10 design | part-04 (all metrics are bounded or direct stats) |
| R-REQ-06: prompt-redacted evidence (hybrid only) | Stage 17 design | part-04 (hybrid-only counter list) |
| R-REQ-07: cold-store drift detection (metric vs filesystem) | Stage 26 design part-04 | part-04 "Ground-truth cross-checks (filesystem)" |
| R-REQ-08: byte-identical output between cache modes | implicit (correctness) | part-06 D29-DESIGN-03, part-05 Layer 1 sub-check 1.2 |
| R-REQ-09: per-cache-class analysis (exact, near_prefix, new_branch) | Stage 24 design | part-02 workload shape, part-05 Layer 2 per-cache-class distributions |
| R-REQ-10: decision-support framing for hybrid improvements | original proposal section 6 | part-05 decision-support section |
| R-REQ-11: reproducible workload (deterministic seed) | Stage 20 agentic prompt generator | part-02 D29-DESIGN-01 (seed=42) |
| R-REQ-12: VRAM-cooldown guarantee between legs | implicit (comparison correctness) | part-03 cooldown logic, part-09 R29-02 |
| R-REQ-13: post-Stage-26 metric namespace (`llamacpp:cache_X`) | Stage 26 design | part-04 metric naming convention |
| R-REQ-14: comparison-only stage (no product code changes) | Stage 28 closure precedent | part-01 non-goals N1 |
| R-REQ-15: durable report in `.test_reports/` Markdown only | test plan part-24 | part-01 boundary condition B5, part-03 driver interface |

Deferred (not in Stage 29 scope):

- R-REQ-DEFERRED-01: L1 prompt-cache measurement (no upstream proxy)
- R-REQ-DEFERRED-02: real-agentic capture as primary workload (optional
  supplementary only)

- R-REQ-DEFERRED-03: heavy-tier comparison (Qwen3.6-27B-MTP)

## Architecture invariants traceability

Each Stage 25-27 architecture invariant is mapped to a design section
that preserves it (the invariant is not violated) or a design section that
exercises it (the invariant is observable in the comparison).

| Invariant | Source | Stage 29 design section |
| --- | --- | --- |
| I-25-01 atomicity (tx_* synchronous transactions) | Stage 25 design part-02 | part-03 driver sequencing (no async paths), part-07 D29-OQ-02 cold-path write resolution |
| I-25-02 isolation (recursive mutex) | Stage 25 design part-02 | part-04 (every metric is read from a single snapshot; no race conditions) |
| I-25-03 durability-within-transaction | Stage 25 design part-02 | part-04 (counter deltas are taken before and after each leg, not mid-transaction) |
| F-21-EXEC-01 prompt-only save | Stage 21 design | part-04 (the comparison binary is the post-Stage-28 closed binary, which preserves F-21-EXEC-01) |
| F-21-RERUN-01 descriptor tracking | Stage 21 design | part-04 `llamacpp:cache_hot_payload_descriptors` gauge |
| F-22-DR-01 demotion coordination | Stage 22 design | part-04 `llamacpp:cache_payload_demotions_total` and `llamacpp:cache_payload_promotions_total` |
| D-EXEC-26-01 SEH handler | Stage 26 design part-03 | part-04 (counter `_total` continues incrementing if a crash occurs; the SEH dump captures the call stack) |
| D-EXEC-26-02 argv function-scope vector | Stage 26 design | not directly observable; preserved by the closed binary |
| D-EXEC-26-02 cold-store per-id accounting | Stage 26 design part-04 | part-04 (cold_store_drift_ratio <= 1.10 is the observable signal) |
| D-EXEC-27-08 tx_demote_payload (historical line reference: `tools/server/server-cache-hybrid.cpp:3396` at the time of Stage 27 closure; file is now 5400 lines and the legacy `demote_payload` definition sits around line 462). Stage 29 does not modify this code. | Stage 27 design | part-11 reconciliation (S03 hybrid should now run past 258 reqs without crash) |
| R28-BUG-02 cold-store reconcile | Stage 28 design | part-04 (cold_store_drift_ratio target) |

## Test plan mapping

Each test plan row (to be authored by QA after Manager design gate PASS)
maps to a Stage 29 design section:

| Test plan row | Design section |
| --- | --- |
| TP-29-PRE-01: preflight checks | part-03 driver Phase 0 |
| TP-29-OEQ-01: output equivalence pre-check | part-05 Layer 1 sub-check 1.2, part-06 D29-DESIGN-03 |
| TP-29-CS-01: cold-start cycle (1 cycle x 2 modes) | part-03 driver Phase 2 |
| TP-29-WARM-01..03: warm A/B cycles (3 cycles x 2 modes) | part-03 driver Phase 3 |
| TP-29-METRIC-01: post-Stage-26 metric format assertion | part-04 metric naming convention |
| TP-29-DRIFT-01: cold-store drift ratio | part-04 cold-store drift handling |
| TP-29-COOLDOWN-01: VRAM back-to-baseline check | part-03 cooldown logic |
| TP-29-DECISION-01..05: five decision-support questions | part-05 decision-support section |

## Risk-to-mitigation mapping

| Risk ID | Mitigation section |
| --- | --- |
| R29-01 | part-02 D29-DESIGN-01 |
| R29-02 | part-03 cooldown logic |
| R29-03 | part-05 Layer 1 sub-check 1.2 + part-06 D29-DESIGN-03 |
| R29-04 | part-04 cold-store drift handling |
| R29-05 | part-03 driver sequencing (budget documented) |
| R29-06 | part-01 non-goals N1 |
| R29-07 | part-03 driver sequencing (port check) |
| R29-08 | part-04 metric naming convention |
| R29-09 | part-03 driver sequencing (hot-budget reset) |
| R29-10 | part-03 failure classification (BLOCKED-host-capacity) |
| R29-11 | part-04 cold-store drift handling + part-03 failure classification |

## Handoff

Part 10 reviewable. Part 11 covers reconciliation with prior stages.
