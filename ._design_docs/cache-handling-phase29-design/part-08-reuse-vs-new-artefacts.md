# Part 8: Reuse vs new artefacts

Status: design in progress (Architect session)
Date: 2026-06-28
Stage: 29 (Cache Modes Comparison - legacy vs hybrid)
Source: [../cache-handling-phase29-design.md](../cache-handling-phase29-design.md)
Source brief: [../.manager-inputs/manager-input-20260628-stage29-cache-modes-comparison.md](../.manager-inputs/manager-input-20260628-stage29-cache-modes-comparison.md) section 7

## Reuse (existing artefacts)

| Artefact | Reuse? | How |
| --- | --- | --- |
| `lib/agentic-prompt-generator.ps1` (Stage 20) | YES primary | Wrapper script dot-sources it and loops `New-AgenticChatPrompt` (target tokens, size class, prompt class, out path, server URL). Stage 20 lib is NOT modified. Cited per review finding B-04: the prior row's claimed parameters did not exist in the lib; this row reflects the corrected wrapper-based invocation. |
| `lib/compare-legacy-vs-hybrid-workload.ps1` (Stage 29, NEW) | YES new | Stage 29 design-correction option (a) wrapper per review finding B-01 (see `part-12-design-review-20260628.md`). Replaces the prior fabricated direct-driver invocation. Calls the Stage 20 lib in a loop with 40/30/30 cache_class distribution and emits a per-request JSONL matching the part-04 metric fields. Cited per review finding B-04 as the corrected reuse entry. |
| `lib/Read-BaselineJson.ps1` (Stage 12) | YES | Reuse for any optional baseline-json consumption. No modification. |
| `lib/Write-BenchEvidence.ps1` (Stage 12) | YES adapt | Reuse the JSON-write helpers and evidence-format conventions. Driver may call into it for shared utilities. |
| `stage24-chat-s02-s03-comparison.ps1` (Stage 24) | YES reference only | Driver copies the param-shape, the metric-format grep, the dry-run gate, the CUDA build proof, the leak-scan call. NO modification to the Stage 24 runner. |
| `bench/bench_s12_b01_exact_blob_hit_rate.ps1` | NO | Out of scope; this stage is comparison, not benchmark. |
| `run_benchmark_k6.ps1` | NO | k6 is for load, not A/B cache-mode comparison. |
| `run_coverage.ps1` | NO | Coverage is implementation-level, out of scope. |
| `run_cache_integration.ps1` | NO | Integration is per-component, out of scope. |
| `extract_replay.py` | NO | Designed for chat-completions replay with placeholder tool results. Does not extract completion requests. |
| `how_to_replay.md` | NO | The prefix-stability principle is implicit in our synthetic workload, not explicit text. The "discard tool results" rule is inverted here. |
| `bench-cache-correctness.js` | YES once-per-mode | Sanity check at the start of each mode's first leg, NOT per cycle. |

## Adapt (extend or modify carefully)

| Artefact | Adapt? | How |
| --- | --- | --- |
| `tools/server/hybrid-cache.md` | YES cite | Cite for metric-list and evidence-classification conventions. NOTE: this file still uses pre-Stage-26 underscore names (`llamacpp_cache_X`). Driver uses post-Stage-26 colon names (`llamacpp:cache_X`). When hybrid-cache.md is updated to the post-Stage-26 form (a separate doc-maintenance task), the citations become consistent. |
| `lib/Read-GgufChatTemplate.ps1` | NO reuse, but reference | The Qwen3.5-4B-MTP fixture path is known from Stage 24. |
| `lib/Get-Stage17ServerArgs.ps1` | NO reuse | Stage 17 evidence-mode flags are hybrid-only and are set by the driver, not via this lib. |

## New artefacts (created by Stage 29 implementation)

| Artefact | Purpose | Approximate size |
| --- | --- | --- |
| `compare-legacy-vs-hybrid.ps1` | Main driver: 4 phases, sequential A/B, cooldown gate, metric scrape, three-layer report emission | ~600 lines |
| `workload-classify.ps1` (in `lib/`) | Adapter: tag each request with `cache_class` based on prefix match against prior requests | ~80 lines |
| `metric-delta.ps1` (in `lib/`) | Compute Prometheus counter deltas from before/after metrics text files | ~60 lines |
| `cold-store-drift.ps1` (in `lib/`) | Compute `cold_store_drift_ratio` from filesystem bytes and metric bytes | ~40 lines |
| `output-equivalence.ps1` (in `lib/`) | Byte-compare legacy and hybrid decoded text for the 5 seed-42 prompts | ~60 lines |
| Optional: `cache-mode-proxy.ps1` | Logging HTTP proxy for one-shot proxy capture (supplementary only) | ~150 lines |

Total new script code: ~990 lines. Test scripts follow the existing
PowerShell 5+ style with `[CmdletBinding()]`, `[Parameter()]`, and the
shared `Utf8NoBom` encoding helper from Stage 24 runner.

## Documentation updates

| Doc | Action | Reason |
| --- | --- | --- |
| `cache-handling-stage-tracker.md` | UPDATE Stage 29 row from "Design in progress" to "Design review in progress" | This design creation completes the design-draft gate. |
| `document-index.md` | UPDATE Stage 29 description to link the entry doc and part files | Match existing pattern (see Stage 25-28 entries). |
| `cache-handling-phase28-design.md` | NO change | Stage 28 closure is terminal. |
| `cache-handling-phase27-design.md` | NO change | Stage 27 closure is terminal. |
| `cache-handling-phase26-design.md` | NO change | Stage 26 closure is terminal. |
| `cache-handling-phase25-design.md` | NO change | Stage 25 closure is terminal. |
| `cache-handling-phase24-design.md` | NO change | Stage 24 closure is terminal. |

## Non-artefact notes

- The driver does NOT modify any source code in `tools/server/`,
  `tests/`, `common/`, `ggml/`, or `gguf-py/`. Stage 29 is comparison-only.

- The driver does NOT modify any existing test script. The new driver
  is added; existing scripts stay as-is.

- The driver does NOT introduce new Prometheus metrics. All metric names
  use the post-Stage-26 namespace.

- The driver does NOT modify the test plan or the implementation log.
  The test plan for Stage 29 is added by QA after Manager design gate PASS.

- The driver does NOT modify any pre-existing analysis JSONL. The proxy
  capture (if used) writes a new JSONL into `._test_output/`.

## Handoff

Part 8 reviewable. Part 9 covers the risk register with mitigation.
