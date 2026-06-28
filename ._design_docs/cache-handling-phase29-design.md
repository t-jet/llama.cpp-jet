# Stage 29 design entry: Cache modes comparison (legacy vs hybrid on a representative agentic workload)

Status: design in progress (Architect session, 2026-06-28)
Date: 2026-06-28
Stage: 29 (Cache Modes Comparison - legacy vs hybrid on a representative agentic workload)
Owner: Architect (design); Developer (implementation); Manager (design gate)
Source brief: [.manager-inputs/manager-input-20260628-stage29-cache-modes-comparison.md](.manager-inputs/manager-input-20260628-stage29-cache-modes-comparison.md)
Original proposal source: [../_analysis/compare-cache-modes-design.md](../_analysis/compare-cache-modes-design.md) (preserved verbatim in the brief; treated as one input, not as the design)

User directive 2026-06-28: "Don't consider design as done. It should be re-run by architect according to your inputs, reviewed etc."

## Goal

Run an apples-to-apples A/B comparison of `--cache-mode legacy` (default) against `--cache-mode hybrid` (post-Stage-27 closed binary) on a reproducible agentic-shaped workload. Produce a three-layer report (Correctness, Per-request, Aggregated) plus a decision-support section that names concrete improvement targets for the hybrid path. This stage produces comparison evidence only. It does not change hybrid-cache product code.

## Contents

| Part | Title | Purpose |
| --- | --- | --- |
| [part-01](./cache-handling-phase29-design/part-01-goals-scope-exclusions.md) | Goals, non-goals, scope, exclusions | Read first; sets the boundary for the design. |
| [part-02](./cache-handling-phase29-design/part-02-workload-capture-mechanism.md) | Workload capture mechanism | Justifies synthetic-but-representative workload plus optional one-shot proxy capture. |
| [part-03](./cache-handling-phase29-design/part-03-comparison-driver-design.md) | Comparison driver design | Sequencing, port allocation, cooldown, contention analysis, runner shape. |
| [part-04](./cache-handling-phase29-design/part-04-per-request-metric-list.md) | Per-request metric list | Post-Stage-26 metric names, evidence classes, ground-truth cross-checks. |
| [part-05](./cache-handling-phase29-design/part-05-three-layer-report-and-decision-support.md) | Three-layer report + decision-support framing | Correctness, per-request, aggregated layers and the five decision-support questions. |
| [part-06](./cache-handling-phase29-design/part-06-binding-decisions-resolved.md) | Six binding decisions resolved | Cold-path volume, output equivalence, iterations, reference model, cooldown, reuse. |
| [part-07](./cache-handling-phase29-design/part-07-open-questions-resolved.md) | Three open questions resolved | Per-request KV field parity, cold-path write thread, workload classes where legacy wins. |
| [part-08](./cache-handling-phase29-design/part-08-reuse-vs-new-artefacts.md) | Reuse vs new artefacts | What we keep, what we adapt, what we do not touch. |
| [part-09](./cache-handling-phase29-design/part-09-risk-register.md) | Risk register with mitigation | Six risks with concrete triggers, impacts, mitigations. |
| [part-10](./cache-handling-phase29-design/part-10-traceability.md) | Traceability | Requirements to design sections; architecture invariants to design sections. |
| [part-11](./cache-handling-phase29-design/part-11-reconciliation-with-prior-stages.md) | Reconciliation with prior stages | Stage 24 closure, Stage 25 tx_*, Stage 26 metrics, Stage 27 heap fix, Stage 28 tech debt. |

## Prerequisites

- All Stage 25-27 invariants preserved: I-25-01 atomicity, I-25-02 isolation, I-25-03 durability-within-transaction (Stage 25); D-EXEC-26-01 SEH handler (Stage 26); D-EXEC-26-02 argv function-scope vector and cold-store per-id accounting (Stage 26); D-EXEC-27-08 tx_demote_payload at server-cache-hybrid.cpp:3396 (Stage 27).
- Stage 28 tech debt removal closed 2026-06-27 with 142/142 unit tests PASS and R28-BUG-02 cold-store reconcile applied. The comparison binary is the post-Stage-28 closed binary.
- `build-cuda/bin/Release/llama-server.exe` and `llama-server-impl.dll` are fresh from a clean `cmake --build build-cuda --config Release -j --target llama-server`.
- `._test_models/Qwen3.5-4B-MTP-GGUF/Qwen3.5-4B-Q4_K_M.gguf` exists (Stage 24 fixture).
- `._design_docs/cache-handling-test-scripts/lib/agentic-prompt-generator.ps1` (Stage 20 lib) is available for synthetic workload generation.
- Ports 8900..8911 are free, or Manager assigns a replacement base port.
- Cold-path volume (default `D:\tmp\cache-cold-stage29`) has at least 30 GiB free before execution.
- Output volume has at least 30 GiB free before execution.
- nvidia-smi is callable from the runner; the GPU model, VRAM total, and driver version are recorded.

## Binding decisions (one-line each; full rationale in part-06)

| ID | Decision | Rationale (short) |
| --- | --- | --- |
| D29-DESIGN-01 | Workload capture = synthetic-but-representative via `agentic-prompt-generator.ps1`, deterministic seed, plus optional one-shot proxy capture for ground truth | Eliminates capture-once complexity; uses Stage 20 lib already calibrated against Stage 16 model-log analysis. |
| D29-DESIGN-02 | Cold-path volume = 2048 MiB | Enough headroom for promotion/eviction exercise; fits developer hosts. |
| D29-DESIGN-03 | Output equivalence check = IN SCOPE, 5 prompts with seed=42, byte-identical expected | Detects silent cache-blob substitution early; aligns with Stage 24 S03 seed-pinning. |
| D29-DESIGN-04 | Iterations = 3 warm A/B cycles plus 1 cold-start cycle (each cycle = one legacy run + one hybrid run) | Statistical confidence on latency comparison; cold-start cycle measures first-request latency. |
| D29-DESIGN-05 | Reference model = `._test_models/Qwen3.5-4B-MTP-GGUF/Qwen3.5-4B-Q4_K_M.gguf` | Matches Stage 24 precedent; exercises MTP checkpoint path; no new fixture verification. |
| D29-DESIGN-06 | Cooldown between runs = 30s sleep + nvidia-smi VRAM back-to-baseline check, max 120s wait | Covers VRAM release, file handle release, cold-store unmount on Windows. |

## Decisions the original proposal did not make (one-liners)

1. **Workload source = synthetic-but-representative**, not a one-shot proxy capture. Proposal recommended the proxy approach; this design replaces it with a deterministic generator plus an optional supplementary proxy capture.
2. **Metric namespace = post-Stage-26 `llamacpp:cache_X`** for every Prometheus counter. Proposal mixed pre-Stage-26 and post-Stage-26 names; Stage 26 alignment closed the legacy underscore form.
3. **Cold-path volume = 2048 MiB**, not 512 MiB or 4 GiB. Proposal deferred the choice; 2 GiB balances representative hybrid deployment with developer-host fit.
4. **Output equivalence check is mandatory**, not optional. Proposal listed it as optional; this design makes it a pre-workload correctness gate.
5. **Iterations = 3 warm cycles + 1 cold-start cycle**, not "at least 3". The cold-start cycle measures first-request latency separately from steady-state behavior.
6. **Cooldown has a hard nvidia-smi gate**, not just a sleep. Proposal suggested 30s + nvidia-smi check; this design makes the nvidia-smi check binding (max 120s) so VRAM is verifiably back to baseline before the next boot.
7. **Driver is `compare-legacy-vs-hybrid.ps1`**, a new script, not an extension of `stage24-chat-s02-s03-comparison.ps1`. Proposal's Section 8 listed `compare-legacy-vs-hybrid.ps1` as new; this design confirms a separate driver is required because the output contract (three-layer comparison) differs from Stage 24's per-row comparison.

## Open questions resolved (one-line each; full rationale in part-07)

| ID | Question | Resolution |
| --- | --- | --- |
| D29-OQ-01 | Does llama-server expose `cache_n_tokens` consistently for both modes? | Both modes emit `timings.cache_n` in chat-completion responses. Stage 24 evidence shows hybrid `cache_n` is non-zero on hit; legacy `cache_n` follows the same field shape. If the field is missing or zero on hybrid, the report classifies `BLOCKED-metric-unavailable` and falls back to `llamacpp:cache_hits_total` / `llamacpp:cache_misses_total` Prometheus deltas. |
| D29-OQ-02 | Does the cold-path write block the request thread? | No for demotion (post-Stage-25 tx_demote_payload is synchronous but operates on already-loaded payload bytes; demotion enqueue is replaced by synchronous tx_save path; the cold write itself is a file rename after the request returns). YES for the first cold-store load (tx_load is synchronous and reads from disk before returning the restored token count). Document the asymmetry and record `ttft_ms` for cold-miss vs warm-miss separately. |
| D29-OQ-03 | Are there workload classes where legacy outperforms hybrid by design? | Yes for short single-turn chats with no prefix reuse: hybrid pays the namespace-validation cost on every restore attempt and the warm-miss path is the same as legacy. The report calls this out as a per-class column rather than averaging it away. |

## Exclusions (binding)

- L1 prompt-cache measurement (no upstream proxy in this design).
- Product code changes to hybrid cache (comparison-only stage).
- Coverage measurement (implementation-level, not runtime behavior).
- Full S01..S08 / L01..S03 matrix rerun.
- Real agentic traffic as primary workload source (deferred; see part-02 for optional one-shot proxy capture).
- Heavy-tier fixture Qwen3.6-27B-MTP (deferred to a future stage if Manager requests).
- `/v1/completion` route (chat-completion only, matching Stage 24).
- Stage 24 runner reuse (different driver, different output contract).

## Risks (one-line; full register in part-09)

- R29-01: Synthetic workload may not represent real agentic behavior. Mitigation: reuse Stage 20 lib calibrated against Stage 16 model-log analysis; document workload shape in the report.
- R29-02: VRAM release delay between legs. Mitigation: hard nvidia-smi gate with 120s timeout.
- R29-03: Output equivalence diff caused by model nondeterminism, not cache. Mitigation: same-prompt replay in both modes independently; record diff text.
- R29-04: Cold-store drift still observed after Stage 28 R28-BUG-02 reconcile. Mitigation: record `cold_store_drift_ratio` per leg; cite Stage 28 baseline.
- R29-05: 4 cycles x 2 modes x 10 minutes exceeds session budget. Mitigation: 80 minute budget documented; Manager may approve 2 cycles.
- R29-06: Stage 29 is comparison-only. Mitigation: scope explicitly excludes product code changes; cite scope in handoff.

## Reconciliation with prior stages (one-line each; full text in part-11)

- **Stage 24**: same workload intent (S02/S03 chat) but different driver, different output contract. Cite Stage 24 evidence as the closest precedent; S03 hybrid BLOCKED-structural-not-infra is closed by Stage 27 fix.
- **Stage 25**: tx_* architecture; cold-store write is synchronous; cold-store load is also synchronous on first hit.
- **Stage 26**: all metric references use post-Stage-26 `llamacpp:cache_X` namespace; cold-store per-id accounting means drift should now be small.
- **Stage 27**: D-EXEC-24-03 heap corruption root cause is closed; Stage 24 -07 reaches 687 reqs on S03 hybrid with no crash.
- **Stage 28**: tech debt removal closed 142/142 PASS; R28-BUG-02 cold-store reconcile applied; comparison binary starts from a known-clean baseline.

## Traceability

See [part-10](./cache-handling-phase29-design/part-10-traceability.md) for the full requirements to design section map and architecture invariant to design section map.

## Handoff

Next owner: Manager (design gate review). After Manager gate PASS: Developer (implementation plan). After Developer implementation plan PASS: QA (test plan). After test plan PASS: Manager (execution gate). After execution: Developer (test-results review). After Developer review PASS: Manager (closure per D-CLOSURE-29-NN).

This stage does not authorize code, runner, test plan, or document-index changes by the Architect. All implementation actions are downstream of Manager design gate PASS.

This file uses LF line endings, plain ASCII status labels, no BOM, no trailing whitespace, and stays under the 300-line durable-doc cap.
