# Stage 6 cold layer integration test-plan review

Reviewer: Architect agent
Date: May 30, 2026
Scope: Stage 6 cold layer integration test coverage in the cache handling test plan

## Verdict: PASS

The Stage 6 test plan is complete, correct, and consistent with the approved Stage 6 design and implementation review. The plan covers all exit criteria, addresses all non-blocking findings from the implementation review, uses correct ASCII status labels, and no document exceeds the 300-line limit. The plan is ready for test execution.

## Documents reviewed

| Document | Lines | Assessment |
| --- | --- | --- |
| `cache-handling-test-plan.md` (entry) | 124 | ✅ Within limit, links correct |
| `part-01-implemented-scope-and-exclusions.md` | 113 | ✅ Within limit, Stage 6 scope added |
| `part-02-current-automated-coverage.md` | 54 | ✅ Within limit, Stage 6 coverage listed |
| `part-03-integration-test-matrix.md` | 160 | ✅ Within limit |
| `part-04-edge-and-negative-scenarios.md` | 42 | ✅ Within limit |
| `part-05-runner-and-evidence-format.md` | 148 | ✅ Within limit |
| `part-06-stress-tests-and-acceptance.md` | 143 | ✅ Within limit, Stage 6 rows listed |
| `part-07-test-report-quality-and-templates.md` | 212 | ✅ Within limit |
| `part-08-stage6-cold-layer-integration.md` | 135 | ✅ Within limit, new Stage 6 part |

All documents are within the 300-line mandatory limit.

## Checklist review

### 1. Scope completeness: PASS

The test plan covers all Stage 6 exit criteria from the architecture document (`cache-handling-phase6-design.md` and its part files):

| Exit criterion (Part 6) | Test plan coverage | Assessment |
| --- | --- | --- |
| Payloads can be offloaded to disk and restored on demand | H60, H62, H66 | ✅ Covered |
| Cold I/O happens asynchronously without blocking `server_context` | H64 | ✅ Covered |
| Integrity checks protect against corruption | F01–F08 | ✅ Covered |
| Budgets are configurable and enforced without changing the upstream CLI | C60–C65, R10–R12 | ✅ Covered |
| Startup validation rejects invalid configurations | N30–N35, C62–C65 | ✅ Covered |
| Target/draft pairing preserved across cold transitions | H61, H72–H74 | ✅ Covered |

All design Part 6 fault injection points are covered:

| Fault injection point (Part 6) | Test plan coverage | Assessment |
| --- | --- | --- |
| Checksum corruption | F01 | ✅ |
| Header truncation | F03 | ✅ |
| `payload_id` mismatch | F05 | ✅ |
| `pair_state` mismatch | F06 | ✅ |
| format_version unknown | F04 | ✅ |
| Demotion write failure | F09 | ✅ |
| Queue full at demotion | H65 | ✅ |
| Queue full at promotion | H69 | ✅ |
| Worker thread shutdown race | F10 | ✅ |
| Draft-side promotion failure for `target_and_draft` | F08, H74 | ✅ |

All design Part 5 metrics are covered:

| Metric (Part 5) | Test plan coverage | Assessment |
| --- | --- | --- |
| `cache_payload_demotions_total` | M10, H60 | ✅ |
| `cache_payload_promotions_total` | M10, H66 | ✅ |
| `cache_payload_cold_evictions_total` | M10 (implied by eviction exclusion) | ✅ |
| `cache_cold_restore_latency_seconds` | M15, H70 | ✅ |
| `cache_cold_payload_bytes` | M11 | ✅ |
| `cache_hot_payload_count` | M13 | ✅ |
| `cache_cold_payload_count` | M12 | ✅ |
| `cache_payload_evictions_total` excludes demoted | M14 | ✅ |

All design Part 5 startup validation checks are covered:

| Startup check (Part 5) | Test plan coverage | Assessment |
| --- | --- | --- |
| Cold store root path is provided and non-empty | N30 | ✅ |
| Cold store root path exists as a directory | C64, N32 | ✅ |
| Cold store root directory is writable | C65, N33 | ✅ |
| Worker thread creation succeeds | (implicit in C61) | ✅ |
| `--cache-ram` is positive when hybrid mode is enabled | (inherited from Stage 4) | ✅ |

### 2. Wording quality: PASS

The test plan uses generic, reusable scenario descriptions. Each row specifies the mode, configuration, and expected result without referencing a specific test run, date, or environment. Evidence requirements are stated as conditions, not as past-tense execution records.

### 3. Stale content: PASS

No stale content from previous stages was found. The entry document, Part 1, and Part 2 have been updated to include Stage 6 scope and coverage. Part 6 has been updated to list Stage 6 rows. The Stage 5 closure state is correctly referenced as the prerequisite.

### 4. Evidence format: PASS

The evidence format in Part 5 and Part 8 is consistent. Part 8 adds Stage 6-specific evidence requirements:

- Public HTTP can prove: cold store opt-in, counter changes, gauge changes, eviction exclusion, startup validation, and regression.
- Public HTTP cannot directly prove: residency state transitions, descriptor state after completion, I/O worker queue-full behavior, cold file integrity validation order, hot byte release timing, protected root demotion warning diagnostics, and draft-side promotion failure atomicity.
- The plan correctly marks internal behaviors as requiring focused C++ tests or a stats-capable harness, and instructs reporters to mark rows as `BLOCKED` if the harness is not available.

### 5. Coverage gaps: PASS

No coverage gaps were identified. The plan covers:

- Cold store opt-in (C60–C65)
- Demotion (H60–H65)
- Promotion (H66–H70)
- Startup validation (N30–N35)
- Metrics (M10–M17)
- Fault tolerance (F01–F10)
- Protected root demotion warning (H71)
- Target/draft pair demotion and promotion (H72–H74)
- Stage 4 and Stage 5 regression (R10–R12)

The plan also correctly identifies that cold residency across server restarts is explicitly out of scope (matching the design exclusion in Part 7).

### 6. Non-blocking findings from implementation review: PASS

All four NB findings from the implementation review (Part 13) are addressed in the test plan:

| NB finding | Test plan coverage | Assessment |
| --- | --- | --- |
| NB-1: Single-field `promotion_enqueue_time` | Part 8 "Notes on NB findings" section documents the limitation and instructs evidence to note it | ✅ Addressed |
| NB-2: `n_cold_payload_bytes` underflow guard | Part 8 "Notes on NB findings" section documents the defensive pattern and instructs evidence to verify no underflow in normal operation | ✅ Addressed |
| NB-3: `cold_store_header` byte-offset discrepancy | Part 8 "Notes on NB findings" section documents the self-consistent implementation and notes it should be resolved before external tools read cold files | ✅ Addressed |
| NB-4: Redundant residency check in `demote_payload` | Part 8 "Notes on NB findings" section documents it as dead code that does not affect behavior | ✅ Addressed |

### 7. ASCII status labels: PASS

The entry document explicitly states: "Use plain ASCII status labels in plans, scripts, and reports: `PASS`, `FAIL`, `SKIP`, and `BLOCKED`." All scenario tables use these labels consistently. No non-ASCII status labels were found.

### 8. Document size: PASS

All documents are within the 300-line mandatory limit. The largest is Part 7 at 212 lines. No document needs splitting.

## Findings

### Blocking findings

None.

### Non-blocking findings

#### NB-1: C65 and N33 Windows non-writable check caveat

The test plan states for C65 and N33: "On Windows, this check may be skipped if the POSIX permission model does not apply." This is a correct observation about the implementation, but the test plan should clarify what evidence is expected when the check is skipped. Currently the plan implies the row may be `SKIP` on Windows, which is acceptable, but a note in the evidence format section would make this explicit.

- Affected file: `part-08-stage6-cold-layer-integration.md`, rows C65 and N33
- Recommended correction: Add a note to the evidence requirements section stating that C65 and N33 may be marked `SKIP` on Windows if the implementation does not enforce the non-writable check on that platform, and the skip reason should reference the POSIX permission model limitation.

#### NB-2: M16 and M17 reference controller stats rather than `/metrics`

M16 and M17 reference `n_demotion_failure_write`, `n_demotion_failure_queue_full`, and failure reason counters that are described as "available in controller stats" rather than as Prometheus metrics. The design Part 5 specifies `cache_payload_demotions_total{result="failure"}` and `cache_payload_promotions_total{result="failure",failure_reason=...}` as Prometheus metrics. The test plan should clarify whether these failure-reason counters are exposed in `/metrics` or only accessible through a stats-capable harness.

- Affected file: `part-08-stage6-cold-layer-integration.md`, rows M16 and M17
- Recommended correction: Clarify whether the failure-reason counters are Prometheus metrics in `/metrics` or internal controller stats. If they are internal, mark the failure-reason evidence as requiring a stats-capable harness or focused C++ test, consistent with the evidence requirements section.

#### NB-3: F10 worker shutdown race evidence source

F10 specifies "test hook" as the mode, which correctly identifies that this scenario requires a focused C++ test rather than public HTTP. However, the evidence requirements section lists "I/O worker queue-full behavior" as something public HTTP cannot directly prove, but does not explicitly list "worker shutdown race" as a separate item. The focused C++ test coverage section (Step 11, test 14) covers this, but the evidence requirements section could be more explicit.

- Affected file: `part-08-stage6-cold-layer-integration.md`, evidence requirements section
- Recommended correction: Add "Worker shutdown race behavior" to the list of internal behaviors that public HTTP cannot directly prove, alongside the existing "I/O worker queue-full behavior" item.

## Handoff state

The Stage 6 test plan is **ready for test execution**. The three non-blocking findings are documentation clarifications that do not block any test scenario. They can be addressed in a minor update before or during the first test execution session.

## Task-local edits

- `._design_docs/cache-handling-test-plan/stage-6-test-plan-review-20260530.md` (this file)
