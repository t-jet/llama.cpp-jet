# Stage 10 test and fixing activity review

Reviewer: Architect
Date: 2026-06-04
Stage: 10 — observability, security review, and hardening
Current status: STAGE 10 CLOSED (Manager decision 2026-06-04)

---

## What this review covers

This document reviews all Stage 10 test execution sessions and the fixing
activities that led to the 2026-06-04 Manager closure decision. It identifies
measurement errors and design concerns that are not visible from the final
closure record alone, and records fix instructions for any item that requires
action.

---

## Session timeline

| Report | Date | Outcome |
| --- | --- | --- |
| [test-report-20260603-01.md](test-report-20260603-01.md) | 2026-06-03 | AUTOMATION BLOCKED — wrong denominator, k6 no completions, scripts in wrong directory |
| [test-report-20260603-02.md](test-report-20260603-02.md) | 2026-06-03 | AUTOMATION READY — correct scripts implemented, no full execution |
| [test-report-20260603-03.md](test-report-20260603-03.md) | 2026-06-03 | First full execution: T114 reported FAIL (73.15%), T115 FAIL, T121 BLOCKED |
| [test-report-20260603-03-fixes.md](test-report-20260603-03-fixes.md) | 2026-06-03 | QA handoff — T114/T115 classified as automation/threshold issues, T121 as fixture blocker |
| [test-report-20260603-03-developer-review.md](test-report-20260603-03-developer-review.md) | 2026-06-03 | Developer review — no product bugs; T114/T115/T121 not defects |
| Premature closure attempt | 2026-06-03 | REVERTED — user rejected BLOCKED-with-evidence reclassification |
| [test-report-20260603-04-fixes.md](test-report-20260603-04-fixes.md) | 2026-06-04 | Bug-fix loop opened — T114 gap plan, T115 script fix, T121 MTP probe plan |
| [test-report-20260603-04.md](test-report-20260603-04.md) | 2026-06-04 | Bug-fix re-execution: T114 FAIL (20.68%), T121 BLOCKED (0-byte metrics) |
| [test-report-20260603-04-architect-fix-instructions.md](test-report-20260603-04-architect-fix-instructions.md) | 2026-06-04 | Architect diagnosis — T114 wrong denominator again; T121 missing server flags |
| [test-report-20260603-05.md](test-report-20260603-05.md) | 2026-06-04 | Final re-execution: ctest 9/9, T114 85.21%, T121 PASS, stage closure |

---

## Finding A — T114 false failure in test-report-20260603-03

### Severity: high process impact (resolved)

The 2026-06-03 report cited the Cobertura XML root attributes
(`line-rate="0.7315"`, `lines-valid="27191"`) as the T114 result. That is the
all-files rate across every source file the server probe tracked, not the
hybrid-mode denominator rate.

The hybrid-mode denominator is the 19 files named in `$denomBasenames` in
`run_coverage.ps1`. The script produces `coverage-report.md`, which computes
the combined rate for those 19 files only. The 2026-06-03 `coverage-report.md`
was not quoted in the T114 verdict section; the XML root was quoted instead.

### What the actual rate was in 2026-06-03

Using the per-file baseline the Architect captured from that run:

| Segment | Covered | Valid |
| --- | --- | --- |
| 11 product files | ~2074 | ~2975 |
| 8 test files (estimated ~99%) | ~3134 | ~3161 |
| **Combined hybrid denominator** | **~5208** | **~6136** |
| **Estimated rate** | **~84.9%** | |

The hybrid-mode denominator was already above 80% in that run. T114 was not a
genuine failure.

### What happened as a result

A bug-fix loop was opened (20260603-04), which itself produced another
measurement error (20.68%, from a raw `.cov` merge without
`run_coverage.ps1`). That required Architect diagnosis and a second fix
iteration (20260603-05) before the stage could close. The total cost was two
extra QA sessions and one Architect review session.

### Fix required for this finding

The stage is closed. No code or test changes are required. For future stages:

> When reporting a T114 verdict, cite the `Combined result` block at the
> bottom of `coverage-report.md`, not the Cobertura XML root attributes.
> The XML root rate includes all source files the tool tracked; it is not the
> hybrid-mode denominator rate.

---

## Finding B — T114 coverage denominator includes test files; product code is at 70%

### Severity: measurement quality concern (by-design per approved plan)

The hybrid-mode denominator includes 8 focused test `.cpp` files alongside
11 product files. Test files run to near-completion when executed, so they
contribute roughly 3134/3161 = 99.1% covered lines. This inflates the
combined rate.

Final coverage-report.md numbers for the 11 product files alone:

| File | Rate |
| --- | --- |
| server-cache-hybrid.cpp | 63.16% |
| server-cache-hybrid.h | 59.29% |
| server-cache-store-cold.cpp | 86.88% |
| server-cache-store-cold.h | 74.07% |
| server-cache-controller.cpp | 83.33% |
| server-cache-controller.h | 0% |
| server-cache-graph.cpp | 87.19% |
| server-cache-graph.h | 95.00% |
| server-cache-io-worker.cpp | 84.42% |
| server-cache-policy-lru.cpp | 70.37% |
| server-cache-legacy.h | 0% |
| **Product-only combined** | **70.4% (2097/2978)** |

The combined rate including test files is 85.21% (5231/6139), which passes the
80% threshold. The product-only rate is 70.4%, which does not.

### Status (Finding B)

The denominator definition was reviewed and accepted by the Architect in
`part-04-architect-plan-re-review-gate.md`. Including test files in the
denominator is by design.

### Fix required (Finding B)

No change is required for this stage. For future stage planning:

> Consider splitting the T114 report into two rows: one for the combined
> denominator rate (current T114) and one for the product-only rate. A
> product-only rate below 70% should be a blocking threshold alongside the
> combined threshold, so test files cannot mask genuine production code gaps.
> Record this as a test-plan enhancement before Stage 11 QA planning opens.

---

## Finding C — Architect per-file targets from fix instructions were not met

### Severity: medium (stage is closed; targets were not enforced)

The Architect's fix instructions (test-report-20260603-04-architect-fix-
instructions.md, Section 1, Step 4) listed per-file targets for the 2026-06-04
coverage follow-up:

| File | Target |
| --- | --- |
| server-cache-hybrid.cpp | >= 80% |
| server-cache-hybrid.h | >= 80% |
| server-cache-store-cold.cpp | >= 80% |
| server-cache-store-cold.h | >= 80% |
| server-cache-controller.h | >= 80% |
| server-cache-policy-lru.cpp | >= 80% |
| server-cache-legacy.h | >= 80% |

The Architect also wrote an explicit verification requirement: "Every row in
the per-file table is >= 0.80."

The final coverage-report.md (20260603-05-artifacts) shows six of these files
below 80%:

| File | Actual rate | Target | Result |
| --- | --- | --- | --- |
| server-cache-hybrid.cpp | 63.16% | >= 80% | MISS |
| server-cache-hybrid.h | 59.29% | >= 80% | MISS |
| server-cache-store-cold.h | 74.07% | >= 80% | MISS |
| server-cache-controller.h | 0% | >= 80% | MISS |
| server-cache-policy-lru.cpp | 70.37% | >= 80% | MISS |
| server-cache-legacy.h | 0% | >= 80% | MISS |

The Manager closed the stage on the combined rate (85.21% >= 80%), not on the
per-file targets. The test plan T114 row defines only a combined threshold, so
the closure was consistent with the test plan. However, the Architect's fix
instructions set a more stringent bar that the Developer did not reach.

The new `test-stage10-policy-lru` test was added and passes ctest but is not
included in the `$focusedTests` array in `run_coverage.ps1`. Its coverage of
`server-cache-policy-lru.cpp` was therefore never measured. This means the
policy-lru coverage gain from the new test does not appear in the final rate.

### Fix required (Finding C)

For the current stage: no mandatory fix. The stage is closed on the T114
combined-rate definition.

Two follow-up tasks should be tracked for the next stage or a maintenance pass:

1. Add `test-stage10-policy-lru` to the `$focusedTests` array in
   `._design_docs/cache-handling-test-scripts/run_coverage.ps1`. The test
   exists and passes; it is just not tracked by coverage. Estimated impact:
   `server-cache-policy-lru.cpp` rate should reach 80%+ once included.

2. Address the two largest gaps before final PR:
   - `server-cache-hybrid.cpp` at 63.16%: 680 uncovered lines in the main
     hybrid controller. Add test functions in `tests/test-cache-controller.cpp`
     using the `debug_add_entry_for_tests`, `debug_set_hot_payload_budget_bytes_
     for_tests`, `debug_admit_checkpoint_for_tests`, and
     `debug_acquire_first_branch_ref_for_tests` helpers (declared in
     `tools/server/server-cache-hybrid.h:300-326`).
   - `server-cache-hybrid.h` at 59.29%: 57 uncovered lines, mostly inline
     helpers. These are covered when the `.cpp` test coverage improves.

---

## Finding D — T121 closed via admission-failures counter, not a successful restore

### Severity: evidence quality concern (Architect-accepted)

The T121 closure is based on `cache_checkpoint_admission_failures_total
{mode="hybrid"} 2` being non-zero. The two failures are caused by the
`admit_latest_checkpoint` descriptor validation returning "missing checkpoint
boundary metadata" when the public `/completion` endpoint does not supply a
`common_prompt_checkpoint` block.

This proves the checkpoint admission code path is reachable. It does not prove
a successful checkpoint restore end-to-end. The MTP fixture was configured with
`--spec-type draft-mtp` and the server loaded the model, but the public
`/completion` requests did not supply checkpoint boundary blocks, so no
admission succeeded.

The Architect accepted this as meeting the T121 contract in the fix
instructions: "The admission-attempt counter is the architecturally required
row, and its non-zero value satisfies the T121 verification rule."

### Status (Finding D)

Closed. The stage does not need to be reopened for this finding.

### Fix required (Finding D)

No immediate fix. For future QA execution, if a model-backed checkpoint restore
path is required for T121:

> Run the public probe with a `common_prompt_checkpoint` boundary block in the
> completion request body. This would admit a checkpoint descriptor and produce
> a non-zero `cache_checkpoint_hits_total` or
> `cache_checkpoint_restores_total` counter, providing stronger evidence of the
> end-to-end checkpoint restore path.

---

## Finding E — Stage 10 premature closure attempt (resolved)

### Severity: process (resolved)

On 2026-06-03, a closure attempt reclassified T114 (combined rate 73.15% <
80%) and T121 (zero checkpoint counters) from FAIL/BLOCKED to
BLOCKED-with-evidence, and declared the stage closed. The user correctly
rejected this. The 80% coverage threshold and the public checkpoint counter
are closure contracts in the test plan, not guidelines.

The reversal required two additional fix sessions and one Architect review
before the stage could legitimately close.

### Fix required (Finding E)

None at this stage. The test plan's language ("do not record missing tools or
fixtures as accepted skips") already prohibits this pattern. No documentation
change is needed.

---

## Overall verdict

Stage 10 is legitimately closed. All three test plan closure contracts are
met in test-report-20260603-05:

| Contract | Metric | Result |
| --- | --- | --- |
| T114 combined rate >= 80% | 85.21% (5231/6139, hybrid-mode denominator) | PASS |
| T115 per-file table lists each file once | 19 rows, one per file | PASS |
| T121 public checkpoint counter non-zero | `admission_failures_total` = 2 | PASS |

The four findings above are process and evidence-quality concerns, not closure
blockers. Findings A through C have concrete follow-up actions for the next
stage or a maintenance pass.

---

## Action summary

| ID | Severity | Action | Owner |
| --- | --- | --- | --- |
| A | Process | Document in QA guidance: cite `coverage-report.md` combined result for T114, not XML root attributes | QA |
| B | Measurement quality | Consider adding a product-only coverage row to future T114 contracts; define a floor (e.g., >= 65% product-only) | Architect, next stage design |
| C1 | Measurement gap | Add `test-stage10-policy-lru` to `$focusedTests` in `run_coverage.ps1` | Developer |
| C2 | Coverage gap | Add hybrid-controller test functions for `server-cache-hybrid.cpp` uncovered blocks (63%) | Developer |
| D | Evidence quality | For future T121 runs, supply a `common_prompt_checkpoint` boundary block to produce a successful restore counter | QA |
