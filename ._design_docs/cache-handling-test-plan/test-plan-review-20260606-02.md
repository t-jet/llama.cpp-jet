# Stage 11 follow-up test-plan review 2 - 2026-06-06 (fix L translated)

Source: [../cache-handling-test-plan.md](../cache-handling-test-plan.md)

Reviewer: QA agent
Date: 2026-06-06

## 1. Scope and references

Independent QA review of the Stage 11 fix L translated test plan.
No test execution, no model runs, no rebuild, no commits, no edits
to the test plan under review or to any other durable doc. This is
the second test-plan review in the Stage 11 follow-up cycle; the
first test-plan review covered the n_outputs_max cap fix plan
(part-15).

Documents reviewed:

- [part-16-stage11-fix-l-translated.md](part-16-stage11-fix-l-translated.md) (primary review target)
- Source of action: [../cache-handling-phase11-implementation/part-25-stage11-fix-l-translated-implementation.md](../cache-handling-phase11-implementation/part-25-stage11-fix-l-translated-implementation.md) (build exit 0, 19 insertions in `ggml/src/ggml-backend-meta.cpp`)
- Source of action review: [../cache-handling-phase11-implementation/part-26-stage11-fix-l-implementation-review.md](../cache-handling-phase11-implementation/part-26-stage11-fix-l-implementation-review.md) (PASS, 0 BLOCKER / 0 NON-BLOCKER / 3 ADVISORY)
- Adjacent plan: [part-15-stage11-mtp-cap-fix.md](part-15-stage11-mtp-cap-fix.md) (row format conventions, coverage analysis style)
- Coverage denominators: [part-13-t114-product-only-coverage.md](part-13-t114-product-only-coverage.md), [part-14-t114a-tooling-limitation.md](part-14-t114a-tooling-limitation.md), [../cache-handling-test-scripts/run_coverage.ps1](../cache-handling-test-scripts/run_coverage.ps1) lines 76-93 and 302-330
- Current translated function: `ggml/src/ggml-backend-meta.cpp:1467-1494` (verified)
- Current struct: `ggml/src/ggml-backend-meta.cpp:395-431` (verified)
- Prior execution baseline: [../.test_reports/test-report-20260606-01.md](../.test_reports/test-report-20260606-01.md) (Stage 11 n_outputs_max cap fix execution; 85/85 focused tests passed; T114/T114a BLOCKED for coverage setup gap)

## 2. Verdict

VERDICT: PASS

The Stage 11 fix L translated test plan is current, generic, and
aligned with the accepted implementation and the 0/0/3 ADVISORY
implementation review. Test row coverage, pass criteria
specificity, equivalence and idempotence criterion, observability
boundedness, evidence format, and the ggml-excluded-from-coverage
claim are all correct. Five minor findings (0 BLOCKER, 2
NON-BLOCKER, 3 ADVISORY) are recorded below; none gate the manager
handoff.

## 3. Findings table

| ID | Severity | Summary | Test-plan line | Suggested resolution |
| --- | --- | --- | --- | --- |
| F-16-01 | NON-BLOCKER | Section 2 specifies an incremental rebuild (`cmake --build`) rather than a full clean build (Remove-Item + cmake -B + cmake --build). The QA skill mandates a clean build per session; the part-15 cap-fix plan uses a full clean build. The fix is single-file, so an incremental rebuild is acceptable, but the plan should explicitly cite the part-25 build log (exit 0) as the basis for skipping a fresh clean build. | part-16 Section 2 (lines 29-49) | Add one sentence: "The recent implementation build in part-25 (exit 0, ggml-backend-meta.cpp recompiled, llama-server.exe relinked) is the prior clean build this incremental rebuild is anchored to. If the working tree has changed since 2026-06-06 15:53:56, run a full clean build per the part-15 script." |
| F-16-02 | NON-BLOCKER | Section 6 pass criteria say T114 and T114a must "report PASS at the existing 80% / 70% rate" but the prior cap-fix execution (test-report-20260606-01.md Section 7) reported both rows as BLOCKED for coverage setup reasons (Release without `/Zi`, only 1 of 9 focused tests built, no model for HTTP probe). Section 8's "the prior numbers stand" presumes a measurement exists; for T114/T114a the prior number is BLOCKED. The fix L has zero coverage impact (19 lines added to a file not in either denominator), so the BLOCKED status is inherited. The Section 6 pass criterion as written is not achievable on the current build tree. | part-16 Section 6 (lines 117-136) and Section 8 line 150 | Either reclassify the T114/T114a rows in Section 6 as "PASS or setup-inherited BLOCKED" using the same exit-criterion wording as test-report-20260606-01 (BLOCKED for coverage setup gap), or add an explicit "Developer handoff to fix coverage setup (Release+`/Zi` or RelWithDebInfo rebuild with `/Zi /Ob1`)" entry to the test plan's out-of-scope section that the next QA session can cite. |
| F-16-03 | ADVISORY | Section 10 "Out-of-scope correctness" duplicates the topic of Section 8 "Out of scope" with different content. Section 10 is a cross-reference check (parts 1-15 row verdicts unchanged), not an out-of-scope declaration. The heading is misleading. | part-16 Section 10 (lines 187-202) | Rename Section 10 to "Cross-reference check" or "Part 1-15 verdict preservation check" so the heading matches the content. |
| F-16-04 | ADVISORY | Section 8 lists "Re-running the public MTP crash repro from part-15 (T-MTP-FIX-01) is unrelated to fix L" as out of scope. T-MTP-FIX-01 is part-15's row, not part-16's. Part-16 defines no T-MTP-FIX-01 row, so the item is unnecessary. | part-16 Section 8 bullet 6 (line 147) | Drop the T-MTP-FIX-01 re-run bullet. The cap-fix T-MTP-FIX-01 row in part-15 is governed by that plan, not by part-16. |
| F-16-05 | ADVISORY | Section 3 T-FIX-L-01 pass criterion (c) counts `ggml_reset` calls as the sum of non-null `ctxs` across the three `stc_*` containers. The translated function calls `ggml_reset(ctx.get())` on every element of each ctxs vector. The plan already qualifies the count with "non-null", so the criterion is correct, but the fixture requirement (insert only valid `ggml_init()` results) is not stated. | part-16 Section 3 pass criterion (c) (lines 73-76) | Add a fixture requirement bullet: "Each `stc_*` ctxs vector is populated with N non-null `ggml_context_ptr` entries (one per `n_simple` slot); null ctxs are not exercised by the translated body." The `ggml_reset(nullptr)` path is not in scope for this fix. |

## 4. Test row coverage check

| Row | Coverage | Notes |
| --- | --- | --- |
| T-FIX-L-01 (focused reset behavior) | yes | Section 3 names the four sub-assertions (a-d), the fixture shape (N entries in split_state_cache, M entries in each of the three simple_tensors maps, K entries in bufs), and the counting shim for `ggml_reset` and `ggml_backend_buffer_reset`. |
| T-FIX-L-02 (equivalence + idempotence) | yes | Section 4 names the post-reset invariants (all caches empty, all contexts reset, all buffers reset) and the idempotence invariant (second back-to-back call leaves state in the same reference shape). |
| Stage 4-9 regression (H53/H54/H57, R20-R23, Q110-Q112, T118-T121) | yes | Section 5 cites `test-cache-controller.exe` and the 85 focused regression rows. The 85/85 count is current and matches test-report-20260606-01.md Section 6 (85 tests PASSED, exit 0). |
| T114 / T114a coverage | yes (F-16-02 caveat) | Section 6 cites the 80% combined rate on the 19-file denominator and the 70% product-only rate on the 11 product files. F-16-02 flags the BLOCKED-vs-PASS issue, but the coverage check itself is well-formed. |
| Observability (silent fix) | yes | Section 7 names the three-pass observability check (zero added log/assert/metric lines, unchanged server log verbosity, part-25 diff evidence unchanged). |

## 5. Pass criteria specificity check

| Row | Specificity | Notes |
| --- | --- | --- |
| T-FIX-L-01 (a) split_state_cache empty | yes | Single boolean check on the map; the translated body calls `clear()` on the map. |
| T-FIX-L-01 (b) three simple_tensors maps empty | yes | Three boolean checks; the translated body calls `clear()` on all three. |
| T-FIX-L-01 (c) ggml_reset call count | yes (F-16-05 caveat) | Sum of non-null ctxs across the three stc_* containers; the translated body has three for-each loops that call `ggml_reset(ctx.get())` once per element. |
| T-FIX-L-01 (d) ggml_backend_buffer_reset call count | yes | Equals `bufs.size()`; the translated body keeps the existing buffer reset loop. |
| T-FIX-L-02 equivalence | yes | Post-reset state assertion: all cache maps empty, all contexts reset, all buffers reset. Matches the reference behavior from a4303153. |
| T-FIX-L-02 idempotence | yes | Second back-to-back call must leave the same reference shape; this is a real invariant because `std::map::clear()` on an empty map and `ggml_reset` on a reset context are both no-ops that must not throw. |

## 6. Coverage denominator analysis check

| Claim | Verified | Notes |
| --- | --- | --- |
| `ggml/src/ggml-backend-meta.cpp` is NOT in the T114 19-file hybrid-mode denominator | yes | `run_coverage.ps1` lines 76-93 list the 19 files: 11 product files (server-cache-*) and 8 test files (test-*). `ggml-backend-meta.cpp` is not on the list. |
| `ggml/src/ggml-backend-meta.cpp` is NOT in the T114a 11-file product-only denominator | yes | `run_coverage.ps1` lines 320-330 and part-13 list the 11 product files (all server-cache-*). `ggml-backend-meta.cpp` is not on the list. |
| The 19 added lines have no coverage-rate impact on T114 or T114a | yes | Confirmed by file-list inspection. The fix is a pure ggml-internal change; the 19 added lines do not enter either denominator. |
| `ggml/` is in the `$excludePatterns` of run_coverage.ps1 | yes | `run_coverage.ps1` line 99 includes `(Join-Path $SourceRoot 'ggml\')` in `$excludePatterns`. Even if a future denominator expansion added `ggml-backend-meta.cpp`, the exclude pattern would still skip it. |

## 7. Out-of-scope correctness check

| Item | Result | Notes |
| --- | --- | --- |
| k6 load tests | yes | Listed as out of scope in Section 8. |
| Stress tests beyond part-06 | yes | Listed as out of scope. |
| Benchmark rows | yes | Listed as out of scope. |
| New GGML_LOG or SRV_DBG lines | yes | Listed as out of scope. |
| Coverage denominator changes | yes | Listed as out of scope; the 19-file and 11-file lists are frozen for this stage. |
| T-MTP-FIX-01 re-run from part-15 | no (F-16-04) | Listed as out of scope but T-MTP-FIX-01 is part-15's row, not part-16's. The bullet is unnecessary. |
| Editing prior test-plan parts or review files | yes | Listed as out of scope; this review does not edit part-15, part-16, or the prior review. |
| Cap-fix T114/T114a coverage rerun | no (F-16-02) | Listed as out of scope with "the prior numbers stand" justification, but the prior number is BLOCKED for coverage setup reasons. The plan should either acknowledge this or reclassify Section 6. |

## 8. Manager handoff

Submitting to Manager. Owner: Manager. Next gate: Test automation (QA) or QA correction.
