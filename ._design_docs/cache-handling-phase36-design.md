# Stage 36 design entry: Hybrid hit and performance validation

Status: design review PASS; Manager design gate PASS
Date: 2026-07-10
Stage: 36
Owner: Architect
Source brief: [.manager-inputs/manager-input-20260710-stage36-stage33-hybrid-cache-performance-rerun.md](.manager-inputs/manager-input-20260710-stage36-stage33-hybrid-cache-performance-rerun.md)

## Goal

Validate hybrid cache hits and performance on the current post-Stage-35 tree
using the Stage 33 comparison lineage. Stage 36 keeps the Stage 33 correctness,
metrics, hot-RAM, cold-store, performance, cleanup, and hygiene rows, but uses a
tight duplicate workload so positive hybrid hits are expected.

Stage 33 must not be rerun unchanged for this goal. Its closure already records
that zero hits are expected for long-spaced duplicates at a 512 MiB hot-cache
budget.

## Review and gate records

| Document | Result |
| --- | --- |
| [Part 01: Design review](./cache-handling-phase36-design/part-01-design-review-20260710.md) | PASS |
| [Part 02: Manager design gate](./cache-handling-phase36-design/part-02-manager-design-gate-20260710.md) | PASS |

## Scope

In scope:

- A Stage-36-specific workload mode in the existing Stage 29/33 driver lineage,
  or an equivalent prebuilt workload input consumed by that driver.
- `/v1/chat/completions` only.
- Legacy and hybrid A/B legs on the same model, seed, context size, parallelism,
  hot budget, and cold budget used by Stage 33 unless the implementation plan
  records a measured reason to change them.
- Positive hit evidence from both per-request cached-token fields and
  `llamacpp:cache_hits_total{mode="hybrid"}`.
- Stage 33 performance evidence: prompt/generation timing, hot RAM vs legacy,
  cold-store counters, bounded labels, HELP/TYPE shape, errors, cleanup, and
  hygiene.

Out of scope:

- Product code changes before a failing Stage 36 report proves a product bug.
- Changing cache semantics, cold-store startup loading, or eviction policy.
- Reclassifying the Stage 33 zero-hit result.
- Commits, pushes, PRs, merge aborts, or reviewer responses.

## Prerequisites

- Stage 35 is closed PASS at merge commit
  `89d13d2e3047c9976d37f22dfe3e8375862c0e87`.
- The Stage 32 corrected extraction rule remains in the driver lineage:
  `/v1/chat/completions` cached tokens are read from
  `usage.prompt_tokens_details.cached_tokens` before any `timings.cache_n`
  fallback.
- `._test_models/Qwen3.5-4B-MTP-GGUF/Qwen3.5-4B-Q4_K_M.gguf` exists.
- QA starts from a clean Release CUDA configure and build. The missing
  `test-cache-controller.exe` observed at intake must be rebuilt before test
  execution.

## Workload design

The Stage 36 workload should use repeated chat-completion bursts:

| Parameter | Target |
| --- | --- |
| Burst count | 8 |
| Repeats per burst | 6 identical requests |
| Exact duplicate rows | 48 |
| Optional filler | 0 to 48 near-prefix or new-branch rows, only if needed for cache pressure |
| Prompt size | Same 2k class used by Stage 33 unless build timing requires smaller measured prompts |
| Max tokens | 8 |
| Temperature | 0 |
| Seed | 42 |

Each burst sends the same message payload repeatedly before moving to the next
anchor. This keeps duplicate inter-arrival inside the hot-cache retention window
that Stage 33 estimated at roughly 25 to 50 seconds.

The implementation plan must choose one of two runner approaches:

1. Add a Stage-36-only workload mode to `compare-legacy-vs-hybrid.ps1` and
   `lib/compare-legacy-vs-hybrid-workload.ps1`.
2. Add a prebuilt workload input parameter to the driver and generate the burst
   workload with a small helper script.

The preferred approach is the smallest change that preserves Stage 29/33 output
layout and per-leg evidence.

## Execution shape

Recommended execution:

- cold-start legacy and hybrid legs;
- one warm legacy and hybrid leg;
- 30 to 60 minute wall-clock budget;
- base port 8900 unless occupied;
- hot budget 512 MiB and cold budget 2048 MiB;
- context size 4096 and parallel 2.

The design permits one additional warm cycle if the first run is fast enough and
QA can keep all evidence aligned.

## Acceptance criteria

Stage 36 can pass only if:

- setup evidence is clean and fresh;
- output equivalence diff is empty;
- hybrid duplicate rows show positive cached-token evidence;
- `llamacpp:cache_hits_total{mode="hybrid"}` increases during hybrid legs;
- namespace/public labels remain bounded;
- HELP/TYPE blocks are unique;
- hybrid hot RAM is at least 40 percent below comparable legacy rows, or the
  report explains why tight bursts reduce the memory delta without introducing a
  product bug;
- hybrid prompt/generation throughput is no more than 10 percent below legacy
  on comparable rows, unless an accepted host cause is documented;
- cold-store failure counters stay zero;
- server logs show no crash, SEH dump, fatal request error, or product-level
  checksum/token mismatch;
- cleanup and hygiene checks pass.

Zero hybrid hits on the tight duplicate workload is FAIL and must go to
Developer test-results review.

## Handoff

Next owner: Developer.

Next gate: implementation planning.
