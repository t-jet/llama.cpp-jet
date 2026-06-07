# Stage 11 follow-up test-plan review - 2026-06-06

Source: [../cache-handling-test-plan.md](../cache-handling-test-plan.md)

Reviewer: QA agent
Date: 2026-06-06

## 1. Scope and references

Independent QA review of the Stage 11 follow-up (n_outputs_max cap fix)
test plan. QA execution remains closed. This is a test-plan review
only: no test execution, no model runs, no rebuild, no commits, no
edits to the test plan under review or to any other durable doc.

Documents reviewed:

- [part-15-stage11-mtp-cap-fix.md](part-15-stage11-mtp-cap-fix.md) (primary review target)
- [part-03-integration-test-matrix.md](part-03-integration-test-matrix.md) lines 130-150 (H53/H54/H57 row format)
- [part-13-t114-product-only-coverage.md](part-13-t114-product-only-coverage.md) (T114/T114a row text and tooling limitation)
- [part-14-t114a-tooling-limitation.md](part-14-t114a-tooling-limitation.md) (T114a /Ob2 inlining limitation)
- [part-10-stage8-metadata-only-rematerialization.md](part-10-stage8-metadata-only-rematerialization.md) (R20-R23)
- [part-11-stage9-checkpoint-integration.md](part-11-stage9-checkpoint-integration.md) (Q110-Q112)
- [part-12-stage10-observability-security-hardening.md](part-12-stage10-observability-security-hardening.md) (T118-T121)
- Source of action: [../cache-handling-phase11-implementation/part-22-stage11-mtp-cap-fix-implementation.md](../cache-handling-phase11-implementation/part-22-stage11-mtp-cap-fix-implementation.md)
- Source of action review: [../cache-handling-phase11-implementation/part-23-stage11-mtp-cap-fix-implementation-review.md](../cache-handling-phase11-implementation/part-23-stage11-mtp-cap-fix-implementation-review.md) (PASS, 0 BLOCKER / 0 NON-BLOCKER / 0 ADVISORY)

## 2. Verdict

VERDICT: PASS

The Stage 11 follow-up test plan is current, generic, and aligned
with the accepted implementation and implementation re-review. Test
row coverage, pass criteria specificity, clean-build rules, coverage
citation, hybrid regression, observability boundedness, out-of-scope
list, and evidence format are all adequate. Three minor findings
are recorded below as NON-BLOCKER and ADVISORY; none gate the
manager handoff.

## 3. Findings table

| ID | Severity | Summary | Test-plan line | Suggested resolution |
| --- | --- | --- | --- | --- |
| F-15-01 | NON-BLOCKER | Section 8 lists "Q110-Q112 (Stage 9 regression rows) pass." Q110-Q112 are Stage 4-8 regression rows from part-11; the Stage 9 regression row is T121 from part-12 (already covered by T118-T121). The bullet is redundant and mislabeled. | part-15 Section 8 bullet 4 | Reword bullet 4 to "Q110-Q112 (Stage 4-8 regression rows from part-11) pass." to remove the mislabel. Drop the bullet entirely if the T118-T121 bullet is the intended Stage 4-9 coverage statement. |
| F-15-02 | NON-BLOCKER | Section 3 T-MTP-FIX-01 server command is summarized as "full flags as in investigation log" without enumerating them. An operator running the repro must open part-19 to recover the full flag set. | part-15 Section 3 table | Either inline the full server command from part-19 or list every flag the operator must pass so the row is operator-runnable without a second doc. |
| F-15-03 | ADVISORY | Section 4 T-NOUT-MAX-01 line range `server-context.cpp:3747-3774` is wider than the code under test. The chunked loop body is at 3755-3774 in the post-fix tree; 3747-3752 is the unchanged for-loop header. | part-15 Section 4 second pass criterion | Tighten the range to `server-context.cpp:3755-3774` so the assertion maps to the changed code, not the pre-existing loop header. |

## 4. Test row coverage check

| Row | Coverage | Notes |
| --- | --- | --- |
| T-MTP-FIX-01 (manual repro) | yes | Section 3 names port 52411, -c 140000, draft-mtp, q8_0 KV, the Qwen3.6-27B-Q4_K_M model path, the "What is your problem?" prompt, and the 60-second liveness check. |
| T-NOUT-MAX-01 (chunked bound) | yes | Section 4 drives the chunked decode loop with `n_tokens > cparams.n_outputs_max` and asserts per-chunk `n_tokens <= n_outputs_max` and `<= n_batch`. |
| T-NOUT-MAX-02 (cap formula) | yes | Section 5 pins the expected value to 4 for n_parallel=1, n_max=3, n_batch=2048 and checks both `cparams_mtp.n_outputs_max` and `params_dft.n_outputs_max`. |
| H53 / H54 / H57 hybrid regression | yes | Section 6 cites part-03 lines 137, 138, 141 and preserves the H54 BLOCKED convention from part-03. |
| T114 / T114a coverage | yes | Section 7 cites the 80% combined rate on the 19-file denominator and the 70% product-only rate on the 11-file product denominator, and references the T114a /Ob2 tooling limitation from part-14. |
| Observability (SRV_DBG boundedness) | yes | Section 9 names the format string, the three integer args, and the banned content list. |

## 5. Pass criteria specificity check

| Row | Specificity | Notes |
| --- | --- | --- |
| T-MTP-FIX-01 | yes | Four concrete pass clauses (server ready, prompt processed with text content, no GGML_ASSERT, server alive >= 60 s) plus a named artifact path. |
| T-NOUT-MAX-01 | yes | Construct-then-invoke-then-assert sequence with a per-chunk invariant on n_tokens and a separate n_batch invariant; mapped to the `:3755` initializer-list. |
| T-NOUT-MAX-02 | yes | Numeric expected value (4) is computed from named parameters; both cparams_mtp and params_dft are checked. |
| H53 / H54 / H57 | yes | Per-row pass clause, with the H54 BLOCKED fallback cited to the local-fixture convention from part-03. |
| T114 / T114a | yes | Numeric thresholds (0.80, 0.70) and per-file credit requirement on server-context.cpp are stated. |
| Observability | yes | Format string, three integer args, and the explicit banned-content list are quoted. |

## 6. Clean-build script check

| Item | Result | Notes |
| --- | --- | --- |
| Removes prior build tree | yes | `Remove-Item -Recurse -Force build-cuda -ErrorAction SilentlyContinue` wipes the build dir before reconfigure. |
| Reconfigures with CUDA | yes | `-DGGML_CUDA=ON -DGGML_NATIVE=OFF -DBUILD_SHARED_LIBS=OFF` matches the implementation log build evidence. |
| Builds only the required target | yes | `--target llama-server` limits the build to the affected binary; the focused tests are not in this script (they are referenced from the coverage row separately). |
| Staleness threshold | yes | 10-minute threshold matches the Stage 8-10 plan scripts and is reasonable for a clean Release+CUDA build. |
| Defensive | yes | The throw on stale binary is reachable only if the rebuild silently produces an old binary, which is the correct safety case. |

## 7. Out-of-scope correctness check

| Item | Result | Notes |
| --- | --- | --- |
| k6 load tests | yes | Listed as out of scope in Section 10. |
| Stress tests beyond part-06 | yes | Listed as out of scope. |
| Benchmark rows | yes | Listed as out of scope. |
| Coverage denominator changes | yes | Listed as out of scope. |
| Editing prior test-plan parts | yes | Listed as out of scope; this review does not edit part-15 or any other part. |
| T114 / T114a rerun | yes | In scope via Section 7; the row is not pre-empted. |

## 8. Manager handoff

Submitting to Manager. Owner: Manager. Next gate: Test execution (QA, with operator run for T-MTP-FIX-01) or QA correction.
