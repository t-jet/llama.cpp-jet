# Part 6: Six binding decisions resolved

Status: design in progress (Architect session)
Date: 2026-06-28
Stage: 29 (Cache Modes Comparison - legacy vs hybrid)
Source: [../cache-handling-phase29-design.md](../cache-handling-phase29-design.md)
Source brief: [../.manager-inputs/manager-input-20260628-stage29-cache-modes-comparison.md](../.manager-inputs/manager-input-20260628-stage29-cache-modes-comparison.md) section 9

## D29-DESIGN-01: Workload capture mechanism

**Decision**: Synthetic-but-representative via
`_design_docs/cache-handling-test-scripts/lib/agentic-prompt-generator.ps1`
(Stage 20 lib) with a deterministic seed. Optional one-shot logging HTTP
proxy capture is allowed as supplementary ground truth.

**Rationale** (see part-02 for full): deterministic, no redaction risk,
controlled branch-forest topology, no new generator code. The proposal
recommended the proxy approach; this design replaces it as primary.

**Rejected alternatives**:

- Logging HTTP proxy only: requires one-time capture, redaction risk, no
  controlled branch-forest topology.

- OpenAI client instrumentation: same drawbacks as proxy plus tighter
  coupling to client API.

- Synthetic-only via new generator: redundant with Stage 20 lib.

## D29-DESIGN-02: Cold-path volume

**Decision**: 2048 MiB (`--cache-cold-max-mib 2048`).

**Rationale**: Stage 24 used 512 MiB; Stage 26 evidence shows S02 hybrid
reached 5.37 GiB on disk in some runs (5.78 GiB in -05). A representative
hybrid deployment uses 2-8 GiB cold budget. 2048 MiB is the lower end of
representative and fits on most developer hosts. Documented in the runner
as `-ColdBudgetMiB 2048` (default).

**Rejected alternatives**:

- 512 MiB (Stage 24 default): too small to exercise the LRU/protected-
  roots behavior; cold evictions happen too early.

- 4096 MiB (proposal's upper suggestion): exceeds some developer-host
  free-space thresholds; not necessary to demonstrate hybrid behavior.

- Unlimited (`--cache-cold-max-mib -1`): skips eviction exercise entirely.

## D29-DESIGN-03: Output equivalence check

**Decision**: IN SCOPE. Mandatory pre-workload gate. 5 prompts with
seed=42, max_tokens=8, byte-identical expected.

**Rationale**: Silent cache-blob substitution is a correctness defect that
should fail fast. Stage 24 S03 used seed=42 and `--parallel 2`; the same
seed pin applies here. 5 prompts is enough to surface common substitution
defects without dominating the session budget (~2 minutes).

**Rejected alternatives**:

- Out of scope (proposal's "optional but recommended"): leaves silent
  substitution undetected until later.

- Larger prompt set (50+ prompts): exceeds the session budget for what is
  a correctness check, not a performance test.

- Token-level comparison instead of byte-level: allows cosmetic
  differences that could mask real substitution.

## D29-DESIGN-04: Number of A/B iterations

**Decision**: 3 warm A/B cycles plus 1 cold-start cycle. Each cycle =
one legacy run + one hybrid run. Total = 4 cycles x 2 modes x 200
requests = 1600 requests.

**Rationale**:

- 3 warm cycles give statistical confidence on latency distributions.
- 1 cold-start cycle measures first-request latency separately from
  steady-state behavior (cold-start latency is a different metric than
  warm-cache latency and should not be averaged with it).

- 200 requests per cycle is enough to populate the p50/p95/p99
  distributions without dominating the 10-minute leg cap.

- 4 cycles total + cooldowns fits in the 80-minute session budget.

**Rejected alternatives**:

- "At least 3" (proposal's suggestion): leaves cold-start behavior
  ambiguous.

- 5+ warm cycles: exceeds session budget for marginal statistical gain.
- 1 cycle: insufficient for confidence on latency distributions.

## D29-DESIGN-05: Reference model

**Decision**: `._test_models/Qwen3.5-4B-MTP-GGUF/Qwen3.5-4B-Q4_K_M.gguf`
(Stage 24 fixture).

**Rationale**:

- Stage 24 used this fixture; the runner already knows the path.
- MTP exercise exercises the checkpoint path, which is the new hybrid
  capability legacy mode does not have.

- 4B parameter size fits ctx=4096, parallel=2 on developer hardware.
- No new fixture verification needed (Stage 20 D20-EXEC-02 verified the
  Qwen3.6-27B-MTP fixture separately; the 4B variant is lighter).

**Rejected alternatives**:

- Qwen3-0.6B (proposal's "quick" suggestion): too small to exercise
  checkpoint path; no MTP.

- Qwen3.6-27B-MTP (Stage 20 heavy-tier): exceeds developer-host VRAM with
  ctx=4096, parallel=2; deferred to a future stage.

- No fixture (use any GGUF): no MTP exercise; comparison would not test
  the checkpoint path.

## D29-DESIGN-06: Cooldown between runs

**Decision**: 30-second sleep + `nvidia-smi` VRAM back-to-baseline check
(max 120-second wait). See part-03 for the full cooldown logic.

**Rationale**:

- 30 seconds covers most VRAM release latency on Windows + NVIDIA drivers.
- The `nvidia-smi` check makes the cooldown verifiable rather than a
  hopeful sleep. If VRAM is not at baseline within 120s, the comparison
  aborts as `BLOCKED-vram-release`.

- Matches Stage 24 cooldown precedent (which used a simple sleep without
  the nvidia-smi gate).

**Rejected alternatives**:

- 30 seconds sleep only (proposal's suggestion): leaves VRAM contention
  possible if driver release is slow.

- 60 seconds sleep only: longer with no additional guarantee.
- No cooldown: VRAM contention between legs invalidates the latency
  comparison.

## Summary table

| ID | Decision | Value |
| --- | --- | --- |
| D29-DESIGN-01 | Workload capture | synthetic-but-representative (Stage 20 lib) |
| D29-DESIGN-02 | Cold-path volume | 2048 MiB |
| D29-DESIGN-03 | Output equivalence check | in scope, 5 prompts, byte-identical |
| D29-DESIGN-04 | A/B iterations | 3 warm + 1 cold-start = 4 cycles |
| D29-DESIGN-05 | Reference model | Qwen3.5-4B-MTP (Stage 24 fixture) |
| D29-DESIGN-06 | Cooldown | 30s sleep + nvidia-smi gate, max 120s |

## Handoff

Part 6 reviewable. Part 7 covers the three open questions from the proposal.
