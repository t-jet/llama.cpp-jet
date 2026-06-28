# Part 11: Reconciliation with prior stages

Status: design in progress (Architect session)
Date: 2026-06-28
Stage: 29 (Cache Modes Comparison - legacy vs hybrid)
Source: [../cache-handling-phase29-design.md](../cache-handling-phase29-design.md)

## Stage 24 reconciliation

[cache-handling-phase24-design.md](../cache-handling-phase24-design.md)
compared `--cache-mode legacy` and `--cache-mode hybrid` on `/v1/chat/completions`
S02/S03 workload intent. Closed 2026-06-25 per D-CLOSURE-24-01 with:

- S02-chat native-legacy: PASS.
- S02-chat hybrid-stage24: PASS (was FAIL-http-request in -04; D-EXEC-24-01 verified).
- S03-chat native-legacy: PASS.
- S03-chat hybrid-stage24: BLOCKED-structural-not-infra (D-EXEC-24-03).

Reconciliation:

- Stage 24 runner (`stage24-chat-s02-s03-comparison.ps1`) is the closest
  precedent for the workload shape and runner param shape. Stage 29
  references Stage 24 for runner-param conventions but creates a new driver
  (`compare-legacy-vs-hybrid.ps1`) because the output contract differs.

- Stage 24 S03 hybrid BLOCKED-structural-not-infra is closed by Stage 27
  D-EXEC-27-08 fix. The new binary should reach 687 reqs on S03 hybrid
  (Stage 24 -07 evidence) without crashing. Stage 29 inherits this.

- Stage 24 S02 hybrid cold-store drift (5.37 GiB on disk vs 502 MiB metric)
  is closed by Stage 28 R28-BUG-02 reconcile. Stage 29 records drift
  ratio per leg as a quality signal but does not fail on it.

- Stage 24 fixture (Qwen3.5-4B-MTP) is reused as the Stage 29 reference
  model.

## Stage 25 reconciliation

[cache-handling-phase25-design.md](../cache-handling-phase25-design.md)
introduced atomic transactional cache writes (synchronous `tx_*` paths).
Closed 2026-06-25 per D-CLOSURE-25-01 with:

- D25-EXEC-01: tx_save / tx_load / tx_restore / tx_apply_restore real;
  slot lifecycle routes through tx_*; 10 tx_assert_mutex_held guards;
  132/132 tests; OQ-25-02 Option B worker retire; OQ-25-04 reentrancy
  depth; OQ-25-03 wait diagnostic.

- D25-EXEC-02: TP-25-PF-01/02 unit perf tests ACCEPT.
- D25-EXEC-03: TP-25-PF-03 BLOCKED-evidence-gap.
- D25-EXEC-04: TP-25-IT-01/02 BLOCKED-structural-not-infra
  (D-EXEC-24-03 reproduces with new architecture).

Reconciliation:

- Stage 29 D29-OQ-02 (cold-path write thread blocking) is answered by
  Stage 25: the cold-path write is synchronous in the tx_* path. The
  cold-path load is also synchronous on first hit. The report separates
  cold-miss latency from warm-miss latency.

- Stage 25 invariants I-25-01, I-25-02, I-25-03 are preserved by Stage 29
  (no architecture changes; the comparison binary is the post-Stage-28
  closed binary).

## Stage 26 reconciliation

[cache-handling-phase26-design.md](../cache-handling-phase26-design.md)
aligned metrics to the post-Stage-26 `llamacpp:cache_X` namespace and fixed
the cold-store per-id accounting. Closed 2026-06-26 per D-CLOSURE-26-02.

Reconciliation:

- Stage 29 part-04 metric list uses ONLY the post-Stage-26 names.
  Pre-Stage-26 underscore forms (`llamacpp_cache_X`) are NOT accepted.
  Driver's metrics-format grep fails any leg emitting underscore-form
  metrics.

- Stage 29 part-04 cold-store drift ratio is the observable signal of
  Stage 26 D-EXEC-26-02 cold-store per-id accounting. Target drift ratio
  <= 1.10 after Stage 28 R28-BUG-02 reconcile.

- Stage 26 D-EXEC-26-01 SEH handler is preserved. If a crash occurs
  during a comparison leg, the SEH dump is captured at the configured
  `--crash-dump-dir` and the report records the dump path.

## Stage 27 reconciliation

[cache-handling-phase27-design.md](../cache-handling-phase27-design.md)
fixed the D-EXEC-24-03 heap corruption root cause (enqueue-only demotion
leak via legacy `demote_payload` to retired Stage 25 `io_worker`). Closed
2026-06-26 per D-CLOSURE-27-01 with the 1-character fix at
`tools/server/server-cache-hybrid.cpp:3396`.

Reconciliation:

- The Stage 29 comparison binary is the post-Stage-27 closed binary. The
  S03 hybrid leg should reach 687 reqs (Stage 24 -07 evidence) without
  crashing. If S03 hybrid crashes before 687 reqs, the comparison
  classifies the leg as `FAIL-correctness-crash` and the report routes
  to a bug-fix loop (Stage 30 or similar).

- D-EXEC-27-08 (tx_demote_payload; historical line reference was
  `tools/server/server-cache-hybrid.cpp:3396` at the time of Stage 27
  closure 2026-06-26; the file has since grown to 5400 lines and the
  legacy `demote_payload` definition sits around line 462). The line
  number is a HISTORICAL reference only. Stage 29 does not modify this
  code; it preserves the closed binary's behavior.

## Stage 28 reconciliation

[cache-handling-phase28-design.md](../cache-handling-phase28-design.md)
removed technical debt and fixed all known open bugs. Closed 2026-06-27
with 142/142 unit tests PASS and:

- D-EXEC-28-NEWBUG-01 production crash fix PASS.
- D-EXEC-28-NEWBUG-02 production crash fix PASS.
- R28-BUG-02 cold-store reconcile PASS.
- R28-BUG-01 cold-store reconcile (line 4253) PASS.
- R28-BUG-03 ASan LNK2038 PASS.
- R28-BUG-04 Phase B + Phase C worker body deletion PASS.

Reconciliation:

- The Stage 29 comparison binary is the post-Stage-28 closed binary. All
  142/142 unit tests PASS. The binary is the cleanest cache-mode binary
  available.

- R28-BUG-02 cold-store reconcile means `cold_store_drift_ratio` should
  be <= 1.10 in Stage 29. If drift is higher, the report classifies the
  leg as `OK-with-drift-warning` (drift ratio <= 5.0) or
  `BLOCKED-cold-store-drift` (drift ratio > 5.0).

- R28-BUG-04 Phase C deletion removed the async worker thread body.
  Stage 29 D29-OQ-02 (cold-path write thread blocking) is answered by
  Stage 28: there is no async worker to enqueue to. All cold-path
  operations are synchronous tx_*.

## Stage 22 reconciliation

[cache-handling-phase22-design.md](../cache-handling-phase22-design.md)
fixed the demotion coordination refactor. Closed 2026-06-20.

Reconciliation:

- F-22-DR-01 (demotion coordination) is preserved. The Stage 29
  comparison observes this via `llamacpp:cache_payload_demotions_total`
  and `llamacpp:cache_payload_promotions_total` counter deltas.

- Stage 22 evidence (TP-21-HV1/HV2 closure: req-008/009/010 all
  `cache_n=26`) is the closest precedent for cache_n=positive on
  chat-completion hybrid. Stage 29 should reproduce this on the
  cache_class=exact requests.

## Stage 17 reconciliation

[cache-handling-phase17-design.md](../cache-handling-phase17-design.md)
introduced agentic cache reuse, cold disk budget, restore-miss
diagnostics, prompt identity evidence, checkpoint-density policy,
redacted evidence mode, and QA reproduction hooks. Closed 2026-06-17.

Reconciliation:

- Stage 17 F-17-EXEC-01 (validation order bug fix) is preserved by the
  closed binary. Stage 29 does not change validation order.

- Stage 17 `--cache-cold-max-mib` flag is used by Stage 29 with value
  2048 MiB (D29-DESIGN-02).

- Stage 17 `--cache-prompt-evidence redacted` and
  `--cache-prompt-evidence-dir` flags are set by the Stage 29 driver for
  hybrid legs only.

## Handoff

Part 11 reviewable. This is the final part file. The Stage 29 design is
complete after Manager design gate review.
