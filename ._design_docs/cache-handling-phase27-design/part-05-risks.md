# Part 5: Risks and open questions

Status: design approved; Manager gate closed per D-CLOSURE-27-01 2026-06-26
Date: 2026-06-26
Scope: explicit risks for Stage 27 verification and the open questions that may require Manager resolution.
Historical note: Risk R1 (Stage 26 fix insufficient) materialized in Stage 24 -05; managed via Stage 27 iter 4 root cause discovery and 1-char fix. Risk R2 (ASan not available on MSVC) materialized; managed via side-channel build-cuda-asan path with CPU-only ASan for test-cache-controller. See implementation log [part-10](../cache-handling-phase27-implementation/part-10-manager-closure-20260626.md) for follow-ups and decisions.

## Risks

### Risk R1: Stage 26 fix is insufficient

| Trigger | Stage 24 rerun -05 still crashes at request 258 |
| --- | --- |
| Impact | Stage 27 does not close D-EXEC-24-03; one additional fix iteration required |
| Likelihood | Low (Stage 26 commit comment explicitly cites this as the D-EXEC-24-03 fix) |
| Mitigation | Step 2 of part-02 fix design adds try/catch hardening in `attach_payload` as the next-priority candidate |
| Detection | V4 S03-chat hybrid FAIL |

### Risk R2: ASan not available on MSVC build path

| Trigger | The TP-27-UT-01 test passes the post-condition invariants but heap corruption is still present in production |
| --- | --- |
| Impact | Test is a false-positive PASS; the live failure mode is not caught by the unit test |
| Likelihood | Medium (ASan is not wired on MSVC; the focused test relies on bounded post-conditions, not heap poisoning) |
| Mitigation | V4 Stage 24 rerun -05 with the MTP fixture exercises the same code path under realistic load |
| Detection | V4 S03-chat hybrid FAIL despite TP-27-UT-01 PASS |

### Risk R3: Stage 24 rerun takes ~40-50 minutes

| Trigger | V4 requires a full 4-leg Stage 24 run with the MTP fixture on RTX 5060 Ti x 2 |
| --- | --- |
| Impact | Total verification wall-time is ~50 minutes; one rerun iteration adds ~50 minutes |
| Likelihood | Certain (the S03 hybrid leg is bounded by the 10-min cap from Stage 23) |
| Mitigation | Run only the S03-chat hybrid-stage24 leg if V1-V3 pass; defer the other 3 legs to a final verification run |
| Detection | Wall-clock measured by the runner log timestamps |

### Risk R4: Step 2 fix (try/catch in `attach_payload`) introduces new behavior

| Trigger | Wrapping `hot_payloads[record.payload_id] = std::move(record)` in try/catch and erasing the descriptor on exception |
| --- | --- |
| Impact | Path that previously threw `std::bad_alloc` now erases the descriptor and rethrows; callers may rely on the prior descriptor presence |
| Likelihood | Low (the only caller is `attach_checkpoint_payload`, which already calls `remove_payload` on failure) |
| Mitigation | Symmetric cleanup; the descriptor + hot_payload pair is consistent in both pre- and post-fix paths |
| Detection | V2 137/137 unit tests (which exercise `attach_payload` through several existing paths) |

### Risk R5: TP-27-UT-01 may not deterministically reproduce heap corruption

| Trigger | The MSVC heap manager does not detect alloc+free churn as corruption unless specific debug flags are set (`_CrtSetDbgFlag`) |
| --- | --- |
| Impact | The test is a pass on both pre-fix and post-fix binaries; it does not detect the regression |
| Likelihood | Medium (the test's primary contract is "destination buffer not allocated", not "heap corruption detected") |
| Mitigation | The post-condition invariant (`cp.data_tgt.empty()` after admission) is the contract, not the heap corruption signal |
| Detection | V4 Stage 24 rerun -05 |

### Risk R6: New SRV_DBG log line at end of `tx_save` may impact performance

| Trigger | Adding one SRV_DBG line that calls `snprintf` per save |
| --- | --- |
| Impact | Marginal perf cost (~microseconds per save); under debug builds the cost is higher |
| Likelihood | Low (SRV_DBG is gated by log level) |
| Mitigation | Acceptable for the diagnostic value |
| Detection | V4 Stage 24 rerun -05 timing measurements |

## Open questions

### OQ-27-01: Should Step 3 (telemetry SRV_DBG) be applied even when Step 1 passes?

Resolution: YES. The telemetry is a one-line addition with no behavior change. It is independent of the root-cause fix and provides bounded observability for future failures. Recommended disposition: include Step 3 unconditionally.

### OQ-27-02: Should the regression test live in `tests/test-cache-controller.cpp` or a new file?

Resolution: existing file. The existing test file already houses TP-26-UT-01..05 and TP-25-UT-01..10. Adding TP-27-UT-01 next to TP-26-UT-05 keeps the Stage 27 row visible in the file scan and avoids new build dependencies.

### OQ-27-03: Should the Stage 24 rerun use a new runner suffix (-05) or reuse -03?

Resolution: NEW suffix (-05). The Stage 24 runner uses a fresh RunRoot per call (`_test_output/stage24-chat-s02-s03-20260626-05`); reusing -03 would overwrite prior artifacts. New suffix keeps the comparison clean.

### OQ-27-04: If Candidate A fails, is Step 2 the right next step?

Resolution: YES, with reservation. Step 2 (try/catch hardening) is the next-priority candidate. If Step 2 also fails, the next-priority candidate is Candidate C (use-after-free in `materialize_entry_payload`), which would require a deeper investigation. The design budgets 1-2 fix iterations; deeper investigation should escalate to Manager as a plan-change.

### OQ-27-05: Does the telemetry addition interact with the Stage 26 cold-store accounting?

Resolution: NO. The SRV_DBG line is read-only on cache state; it does not modify `cold_payload_bytes_by_id_`, `n_cold_payload_bytes`, or any other counter. No interaction.

## Handoff

Six risks identified; three are bounded by the verification chain (R1, R2, R5), two are accepted as marginal (R3, R6), and one requires care (R4). Five open questions resolved by the design; one (OQ-27-04) carries an explicit escalation path to Manager if the fix chain exceeds two iterations.
