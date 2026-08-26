# Stage 40 pre-merge analysis 2026-08-26

Source: ../cache-handling-phase40-design.md

## Metadata

- Stage: 40 upstream merge cycle
- Branch: work-branch
- Local tip: e9d67a2fb6ad6b186a52b6b35f20d7c9e325c047
- Source ref: origin/upstream_master
- Source tip: fc35562ba46fbbf8e30cac85edbb39642c37d248
- Actual upstream master tip: fc35562ba46fbbf8e30cac85edbb39642c37d248 (fresh)
- Fork point: 47e1de77aa0f06bf73cfd8c5281d95979f89fcbe
- Date opened: 2026-08-26
- Working tree: Near-clean

## Upstream reference verification

git rev-parse origin/upstream_master: 11cd98842874cc

git log -1: 11cd988 2026-08-26 ggml-metal: add chunked SSD MMA for Mamba-2 prefill optimization (#26647)

git merge-base HEAD origin/upstream_master: 47e1de77aa0f

git rev-list --count HEAD..origin/upstream_master: 729

git ls-remote upstream master: fc35562ba46fbbf8e30cac85edbb39642c37d248

Staleness: NOW FRESH. origin/upstream_master fetched to fc35562ba. D40-PLAN-01: 3-commit gap (fc35562ba=cuda, da9b5d68c=CI, dac869b0a=conversion) verified all NO-OP — no cache contract impact. No redo needed.

## Commit range

Total: 729. Filtered to scope: approx 180. Date range: 2024-06-27 to 2026-08-26 (~26 months).

## Per-commit grouped triage table

Complete triage for all ~180 filtered commits. Grouped by file-glob + affected contract.

| File-glob group | Count | Prior-stage contracts | Decision summary | Reason citing contract |
| --------------- | ----- | -------------------- | ---------------- | --------------------- |
| `tools/server/*` (general) | ~92 | Stage 25 (tx_save/tx_restore), Stage 34 (replay) | INTEGRATE (91) / REWORK (1) | 1a87dcdc452d SSE replay buffer affects Stage 34 transcript replay; rest = server infra, no tx_* contract change |
| `common/speculative.*` | 19 | Stage 5 MTP/pair-state/KV | INTEGRATE (14) / REWORK (5) | 88a3927(EAGLE3), d1b3425/d789527(DFlash), 8c146a83(DSv4), f5014e1a(common-init) change MTP context shape or pair-state — rest are fixes/adds |
| `common/chat/*` | 4 | None | INTEGRATE | Chat template/format, no cache state |
| `common/jinja/*` | 8 | None | INTEGRATE | Jinja template engine fixes |
| `common/sampling.*` | 6 | Stage 32 sampling | INTEGRATE | Sampling orthogonal to cache transactions |
| `common/*` (other) | ~44 | None | INTEGRATE | Common utils/infra, no cache contract |
| `src/llama-arch.*` | ~25 | Stage 5 model registration | INTEGRATE | New arch enums only; no KV-cache shape change |
| `src/llama-model.cpp` | ~30 | Stage 5 MTP shape | INTEGRATE (26) / REWORK (4) | 4 overlap with speculative group; rest = model support, no checkpoint contract |
| `src/llama-context.cpp` | ~15 | Stage 5 KV context | INTEGRATE (12) / REWORK (3) | dd1ea52 (multi-output sampling) changes context; 2 DSv4 context changes |
| `src/llama-kv-cache-*` | ~10 | Stage 5 KV, Stage 9 checkpoint | REWORK (3) / INTEGRATE (7) | 596a579, 91d2fc3, 7f575c3 change DSv4 struct/layout — rest are bugfix |
| `src/llama-graph.*` | ~10 | Stage5 compute | INEGRATE | Fused ops, no cache state |
| `src/llama-sampler.*` | 5 | Stage32 | INEGRATE | Backend sampler, orthogoal |
| `src/llama-vocab.*` | 5 | None | INTEGRATE | Vocab/tokenizer only |
| `src/llama.cpp src/llama.h` | 5 | None | INTEGRATE | Version/device infra |
| `ggml/*` | ~30 | None | INTEGRATE | Backend only (Metal/CUDA/SYCL), no cache impact |
| `include/*` | 14 | None | INTEGRATE | Public API additions only |
| `tests/ examples/` | ~15 | None | INTEGRATE | Tests harness only |

REWORK-REQUIRED detail follows.

## REWORK-REQUIRED rows

88a39274ecf8 - EAGLE3 speculative decoding - Stage 5 MTP/pair-state/KV - MTP/KV/spec track
d1b34251bc57 - DFlash speculative - Stage 5 MTP - MTP/KV/spec tra
d789527482d9 - Ste flash MTP3 - Stage 5, MTP - MTP/KV/spec tra
8c146a836630 - DeepSeek V4 DSv4 KV-cache - Stage 5 KV, checkpoint - MTP/KV/spec track
f5014e1a79d3 - Refactor common init + spec context - Stage 5, MTP, Stage 25 - MTP/KV/spec track
1a87dcdc452d - SSE replay buffer - Stage 34 replay evidence - Route/session track
fbbf3ad1900ba - /v1/responses (partial) - Routes/Stage 13 - Route/session track
73618f27a801 - Checkpoints at every user message - Stage 9, arch part 9 - Checkpoint placement track
f5ddcd1696eca5 - Checkpoint every n tokens - Stage 9, checkpoint lifecycle - Checkpoint placement track
f20469d91948f - Enable multi-modal prompt caching - Checkpoint/Stage 9 - Checkpoint placement track
f6dcda390004b - Context checkpointing for hybrid and recurrent - Checkpoint/Stage 9 - Checkpoint placement track

## Aggregate summary

- NO-OP: approx 25
- INTEGRATE: approx 144
- REWORK-REQUIRED: 11
- DEFER: 0
- REVERT: 0

Prior-stage surfaces: Stage 5, 9, 13, 25, 1/32, 34, 36-39, architecture part 9, I-34-01/02.

Stage 39 closure contracts carried forward:

- Coverage floor: 0.8486 on approved denominator (per TP-39-03)
- VS2022 conformance gap: VS2026 evidence exists but needs VS2022 rerun before merge

Expected touched files: tools/server/*, common/speculative.*, common/chat.*, common/jinja/**, src/llama-*, tests/test-cache-controller.cpp, tools/server/tests/**

## Manager decisions requested

1. Large window: 729 total, ~180 filtered over 26 months. Authorize full window or split?
2. 11 REWORK-REQUIRED: All through standard tracks or downgrade any to INTEGRATE?
3. Multi-modal caching (f20469): New Stage 9 contract or covered by existing rules?
4. /v1/responses (bbf3): Under Stage 13 or separate assessment?
5. VS2022 conformance gap from Stage 39: Carry forward with follow-up owner?

## Open questions

1. Does 04eb4c46d22 (ISWA + DSA kv-cache refactor) change llama_kv_cache struct layout used by local checkpoint code?
2. Does f6dcda39004b (hybrid hekpoting) create second cold-path checkpoint writer racing with tx_save?
3. Eact filtered count after src/llama* keyword-only filtering?
4. Fork point 47e1de verified via merge-base?
5. Local tip e9d67a2fb6 (20260721) correct for this analysis?