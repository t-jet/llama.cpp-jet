# Manager inputs: Stage 29 cache-modes comparison

Status: MANAGER INPUTS — NOT AN APPROVED DESIGN
Date: 2026-06-28
Stage: 29 (Cache Modes Comparison — legacy vs hybrid)
Gate at intake: Stage intake -> Design (in progress)
Owner of inputs: Manager
Owner of design: Architect (in fresh session, from scratch)
User directive 2026-06-28: "Don't consider design as done. It should be re-run by architect according to your inputs, reviewed etc."

## Purpose of this file

This file preserves the original proposal authored in [`._analysis\compare-cache-modes-design.md`](../../_analysis/compare-cache-modes-design.md) so the work survives even though [`._analysis`](../../_analysis) is not durable. Per project convention, only chat-log data (chat_log.json, chat_log.jsonl) may live in [`._analysis`](../../_analysis) as CLI inputs to future runs; everything else moves to the durable tree under [`._design_docs`](../../_design_docs).

This is **NOT** the design for Stage 29. The Architect will author the design from scratch in a fresh session, using the content below as one input brief. The design must answer every "Open question" and "Required decision" listed below, must address the implicit assumptions in the proposal, and must survive independent Architect review before Manager design gate PASS.

## Why the proposal is not the design

- The proposal defers 6 binding decisions: workload capture mechanism, cold-path volume, output equivalence check, number of A/B iterations, reference model, cooldown between runs.
- The proposal contains 4 open questions of its own that the design must resolve before any code is written: does llama-server expose `cache_n_tokens` consistently for both modes; does cold-path write block the request thread; are there workload classes where legacy outperforms hybrid by design; what is the metric-vs-reality drift profile.
- The proposal names Stage 24 as the prior comparison work, but Stage 24 closed 2026-06-25 with D-EXEC-24-03 (silent crash) reclassified BLOCKED-structural-not-infra. The Architect must reconcile Stage 24's findings with the new comparison contract.
- The proposal assumes A/B legs run sequentially on the same port. Stage 24 already documented port collision and host-resource contention concerns; the design must justify or revise this choice.
- The proposal lists evidence classes per `tools/server/hybrid-cache.md`; the design must cite the durable version of that doc (it lives under `tools/server/` after Stage 26 metrics alignment) and reconcile with the renamed metrics (`llamacpp_X` -> `llamacpp:X`).

## Original proposal (preserved verbatim from `_analysis/compare-cache-modes-design.md`)

The content below is the original proposal. The Architect may quote from it but must not treat any clause as approved design.

---

## Original proposal heading

### Cache mode comparison test design (Option A)

Status: design proposal
Date: 2026-06-28
Scope: legacy vs hybrid cache mode A/B test on real agentic sessions
Source: review verdict on `how_to_replay.md` + `extract_replay.py` for fitness to compare native vs hybrid caching

This document is the design for the Option A approach discussed in the review verdict above. It captures the latest version: a new comparison driver that boots two llama-server instances (one `--cache-mode legacy`, one `--cache-mode hybrid`) and replays a real agentic workload against both, collecting per-request, per-mode, and aggregate statistics for hybrid-cache improvement decisions.

## 1. Scope

In scope:

- Run two llama-server sessions sequentially, one per cache mode, on the same port, identical except for `--cache-mode` and cold-path presence.
- Capture a real agentic completion-request stream (logging HTTP proxy in front of one llama-server).
- Replay the captured workload twice in separate runs: once against `--cache-mode legacy`, then once against `--cache-mode hybrid`. The two runs never overlap in time.
- Scrape `/metrics` before and after each request within each run.
- Emit a three-layer report (Correctness, Per-request, Aggregated) plus a decision-support section.
- Per-metric evidence classification per `tools/server/hybrid-cache.md` (Public Prometheus, Structured log, Direct stats, Harness-only).

Out of scope:

- L1 prompt-cache measurement (no upstream proxy in this design).
- Product code changes to hybrid cache.
- Coverage measurement (implementation-level, not runtime behaviour).
- Stage 24 chat runner reuse (different driver, different output contract).

## 2. Topology

The two instances are run sequentially, never in parallel. Each run gets the full host's VRAM, CPU, RAM, disk bandwidth, and `/metrics` scrape window. Running both at once would make VRAM contention (two model weights + two KV caches resident), CPU contention, and cold-store I/O contention pollute the latency comparison.

```text
Run 1 (legacy):
+-------------------+        +------------------------+
|  workload source  | -----> |  llama-server  legacy  |  /metrics  port A
|  (captured JSONL) |        +------------------------+
+-------------------+
        |
        v  shutdown + cooldown (host state back to baseline)
        |
Run 2 (hybrid):
+-------------------+        +------------------------+
|  workload source  | -----> |  llama-server  hybrid  |  /metrics  port A + cold dir
|  (same JSONL)     |        +------------------------+
+-------------------+
```

Both runs use the same port (since they are not concurrent) and the same captured workload JSONL. Variables held constant between the two runs: model file, `--ctx-size`, `--cache-ram`, `--parallel`, server start time budget, prompt sequence, prompt timings, system time-of-day within the cooldown window, available disk for cold store, GPU driver state. Variables that differ: `--cache-mode`, presence of `--cache-cold-path`. Each run starts cold (clean `--cache-ram` budget, empty cold dir for hybrid).

## 3. Workload capture (real agentic sessions)

The current artefacts do not capture real agentic completion requests:

- `chat_log.jsonl` and `chat_log.replay.json` capture the agent's tool invocations and user prompts, not the LLM completion request stream.
- `bench-cache-correctness.js` is synthetic, not real agent.
- `extract_replay.py` does not extract completion requests.

To capture real agentic sessions, run a logging HTTP proxy in front of one llama-server instance and let one or more real agent sessions (Copilot, Claude, custom) drive traffic through it. The proxy logs every request body, response body, and per-request wall-clock to a JSONL. That JSONL becomes the workload source.

Proxy requirements:

- Pass-through HTTP forwarding, no body modification.
- JSONL log with one entry per request: timestamp, method, path, request body, response body, wall_clock_ms, http_status.
- Body size cap (32 MiB) to avoid disk exhaustion.
- Graceful shutdown on SIGINT that flushes the log.

Workload capture can happen once. The captured JSONL is replayed twice (once against legacy, once against hybrid). Workload corpora live under `._test_output/agentic-workloads/` or similar.

## 4. Per-request metrics

For each request in the workload, capture the following:

| Metric | Source | Evidence class |
| --- | --- | --- |
| `wall_clock_ms` | client timestamp, request start to last byte | Direct stats |
| `ttft_ms` | response `timings.prompt_ms` (time-to-first-token proxy) | Direct stats |
| `prompt_n` | response `timings.prompt_n` | Direct stats |
| `predicted_n` | response `timings.predicted_n` | Direct stats |
| `cache_n_tokens` | response `timings.cache_n` | Direct stats |
| `cache_n_ratio` | derived `cache_n / prompt_n` | Direct stats |
| `cache_hit` | derived `cache_n > 0` | Direct stats |
| `llamacpp:cache_hits_total` delta | `/metrics` scrape | Public Prometheus |
| `llamacpp:cache_misses_total` delta | `/metrics` scrape | Public Prometheus |
| `cache_exact_blob_restores_total` delta | `/metrics` scrape | Public Prometheus |
| `cache_fallback_restores_total` delta | `/metrics` scrape | Public Prometheus |
| `cache_payload_transitions_total` delta | `/metrics` scrape | Public Prometheus |
| `cache_payload_evictions_by_shape_total` delta | `/metrics` scrape | Public Prometheus |
| `llamacpp:cold_payload_bytes` | `/metrics` snapshot | Public Prometheus |
| `llamacpp:cold_payload_count` | `/metrics` snapshot | Public Prometheus |
| Cold-store on-disk bytes | `du -sb` on cold dir | Direct stats (ground truth) |
| Cold-store file count | `find` on cold dir | Direct stats (ground truth) |
| VRAM peak | nvidia-smi sample | Direct stats |
| CPU/RAM sample | process sampler | Direct stats |

`cache_n_tokens` and `cache_n_ratio` are the headline per-request KV-reuse indicators. Cumulative `/metrics` counter deltas give the population-level view. Ground-truth cross-checks (`du -sb`, output equivalence) catch metric-vs-reality drift.

## 5. Three-layer report structure

### Layer 1 - Correctness

Mandatory before any performance claim is considered valid.

- Cold-store validity (hybrid only): every cold file passes magic + format + version + payload-id + pair-state + size + checksum validation. No `cache_validation_mismatches_total` increments during the workload.
- Output equivalence (optional but recommended): for identical prompts with seed fixed, legacy and hybrid produce equivalent decoded output. Hybrid must not silently substitute a wrong blob.
- `cache_fallback_restores_total` rate: if hybrid is falling back frequently, correctness is fine but performance story is weak.
- Verdict: PASS only if all three sub-checks pass. Otherwise FAIL with concrete counter values.

### Layer 2 - Per-request comparison

Side-by-side table per request:

| Column | Legacy | Hybrid | Delta |
| --- | --- | --- | --- |
| `cache_n_ratio` | value | value | hybrid - legacy |
| `ttft_ms` | value | value | hybrid - legacy |
| `wall_clock_ms` | value | value | hybrid - legacy |
| `cache_hit` (bool) | value | value | n/a |

Distributions over the full workload: p50, p95, p99 of `wall_clock_ms` and `ttft_ms` per mode. Also the `cache_n_ratio` distribution. If hybrid is slower on cache hits than legacy on hits, that is a problem to fix.

### Layer 3 - Aggregated comparison

- Mean cache hit rate per cache mode over the full workload.
- Total tokens reused per cache mode (sum of `cache_n_tokens`).
- Cold-store utilisation at end of workload (hybrid only).
- VRAM peak per cache mode.
- Failure modes observed: cold-store validation errors, fallback restores, eviction storms.
- Total wall-clock savings (or cost) of hybrid over legacy.

## 6. Decision-support framing for hybrid improvements

The output must answer these specific questions, in order:

1. **Does hybrid actually reuse more KV than legacy on this workload?** If `cache_n_ratio_hybrid` mean < `cache_n_ratio_legacy` mean on aggregate, the hybrid path is not hitting the cache that legacy would have. Look for cold-store write failures, namespace mismatches, descriptor-validation mismatches.
2. **When hybrid hits, is it faster than legacy?** If `ttft_ms_hybrid_hit` p50 > `ttft_ms_legacy_hit` p50, the restore path has overhead. Likely fixes: blob deserialisation, namespace re-validation, pdb source-path substitution.
3. **When hybrid misses, how much overhead?** Compare cold-miss vs warm-miss latencies. If cold restore adds more than an acceptable threshold (proposed: 50 ms at p50 for the reference model), decide whether the cold-path is worth it given hit rate.
4. **Does hybrid evict the hot set too aggressively?** If `cache_payload_evictions_by_shape_total` is high relative to hit rate, the eviction policy is hurting reuse. Look at Stage 4 LRU + protected roots.
5. **Does hybrid correctness hold?** Validation mismatches, fallback restores, and output equivalence together tell you whether hybrid is safe to recommend.

Each question maps to a specific improvement target. The output gives a clear "fix or ship" recommendation per question with concrete metric thresholds.

## 7. Reuse from existing artefacts

| Existing artefact | Reuse? | How |
| --- | --- | --- |
| `extract_replay.py` | No | Designed for chat-completions replay with placeholder tool results. Does not extract completion requests. |
| `how_to_replay.md` | Partial | Prefix-stability principle only. The "discard tool results" rule is inverted here: we want real `/metrics` deltas. |
| `bench-cache-correctness.js` | Yes | Sanity check at the start of each measurement window. |
| `cache-handling-test-scripts/run_benchmark_k6.ps1` | Adapt | Add `--cache-mode`, `--cache-cold-path`, and dual-port k6 invocation; output to two artifact subdirs. |
| `cache-handling-test-scripts/run_coverage.ps1` | No | Coverage is implementation-level, out of scope. |
| `tools/server/hybrid-cache.md` | Yes | Metric list and evidence-classification rule reused verbatim in the report template. |

## 8. New artefacts needed

1. **Logging HTTP proxy** (PowerShell or Python, ~150 lines). Pass-through forwarding, JSONL log per request. Stored under `._test_output/agentic-workloads/proxy/` or in the test-scripts folder.
2. **`compare-legacy-vs-hybrid.ps1`** (or `.py`). Two-phase driver: Phase 1 boots `--cache-mode legacy`, runs the captured workload against it, scrapes `/metrics` around each request, shuts down, then waits for a configurable cooldown. Phase 2 boots `--cache-mode hybrid`, runs the same workload from the same JSONL, scrapes `/metrics`, shuts down. Driver writes per-request + aggregated output for both runs. Stored under `cache-handling-test-scripts/`.
3. **Comparison report template** with the three-layer structure (Correctness, Per-request, Aggregated) plus the decision-support questions. Markdown format matching the existing test-report style.
4. **Workload corpus**: one or more captured real-agent JSONL files. Stored under `._test_output/agentic-workloads/`.

## 9. Required decisions before code

- **Workload capture mechanism**: confirm logging proxy approach (recommended) versus OpenAI client instrumentation or synthetic-but-representative workload.
- **Cold-path volume**: pick a size (e.g., 2-4 GiB) matching realistic hybrid deployments. Document the choice so future readers can reproduce.
- **Output equivalence check**: in scope or out of scope? Adds a correctness dimension. Requires seed-pinning on llama-server.
- **Number of workload iterations**: at least 3 full A/B cycles (each cycle = one legacy run + one hybrid run) for statistical confidence on the latency comparison.
- **Reference model**: which GGUF fixture to use. Qwen3-0.6B for quick runs, Qwen3.5-4B-MTP for representative agentic workloads.
- **Cooldown between runs**: how long to wait after shutdown before booting the next mode. Must cover VRAM release, file handle release, and cold-store unmount. A safe default is 30 seconds plus a `nvidia-smi` check that VRAM is back to baseline.

## 10. Open questions

- Does llama-server expose `cache_n_tokens` consistently for both `--cache-mode legacy` and `--cache-mode hybrid`? If not, the per-request KV-reuse comparison breaks down.
- Does the cold-path write path block the request thread, or is it asynchronous? Affects `ttft_ms` interpretation for first cold-store hit.
- Are there workload classes where legacy outperforms hybrid by design (e.g., short single-turn chats with no prefix reuse)? The report should call these out rather than averaging them away.

## 11. Handoff state

- Status: design proposal, ready for review.
- Required reviewer: anyone owning `cache-handling-test-scripts/` plus the hybrid-cache implementation owner for the decision-support output contract.
- Next step: confirm the Required Decisions above, then implement `compare-legacy-vs-hybrid.ps1` and the logging proxy.
