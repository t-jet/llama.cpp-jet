# Stage 15 B05/B06 bug-fix review

Date: 2026-06-13
Reviewer: Architect (fresh session)
Scope: two-diff fix to `tools/server/server-cache-hybrid.cpp` resolving the
Stage 15 B05/B06 BLOCKED rows. Fix relaxes checkpoint boundary matching
so multi-turn prompts can admit checkpoints when the last boundary ends
at `n_tokens` but starts mid-prompt.

## Reviewer note

This is a focused bug-fix review against the two-diff spec recorded in
`cache-handling-phase15-implementation.md` under "Stage 15 BUG-FIX B05/B06
implementation". The fix is minimal, targeted, and produces no other code
churn. Evidence on disk confirms the build is green, the V2 smoke test
admits checkpoints, and the MTP /completion behavior matches the
pre-fix structural-not-infra diagnosis.

The MTP /v1/chat/completions path is out of scope for this review. The
brief and the developer log both record it as a separate structural
issue (checkpoint at n_tokens=36 while metadata boundaries span to 74)
that needs a third-diff extension. The Manager closure decision 1
(2026-06-13) already reclassified B02/B05/B06 to NOT-IN-SCOPE for the
MTP fixture, so the MTP 0/10 result is not a gate for this review.

## Checklist

| # | Item | Verdict | Evidence |
| --- | --- | --- | --- |
| R1 | `attach_checkpoint_payload`: `token_start` filter removed, match on `token_end` only | PASS | git diff hunk 2: `boundary.token_start != ...` line removed, loop now skips only on `checksum == 0` or `token_end != descriptor.token_span_end` |
| R2 | `validate_checkpoint_descriptor_metadata`: `token_start` check skipped when `descriptor.token_span_start == 0` | PASS | git diff hunk 1: `(descriptor.token_span_start != 0 && boundary.token_start != ...)` guards the `token_start` compare |
| R3 | No other code changed in the two functions | PASS | `git diff tools/server/server-cache-hybrid.cpp` shows exactly two hunks (lines 2988-2994 and 3064-3068), no other production churn |
| R4 | Boundary identity preserved (no false-positive matches) | PASS | attach populates `boundary_kind`, `boundary_checksum`, `boundary_id` from the first matching boundary; validate checks type, metadata, token_end, checksum; checksum is recomputed from `entry.tokens` via `cache_token_span_checksum` |
| R5 | Build succeeded, exit 0, no new warnings | PASS | `cmake --build build-cov --config Release --target llama-server -j 4` exit 0; only `server-cache-hybrid.cpp` recompiled; binary at `build-cov/bin/Release/llama-server.exe` timestamp 2026-06-13 21:30:52 |
| R6 | V2 fixture smoke: 9 of 10 requests returned `cache_n > 0` | PASS | `._test_output/smoke-stage15-bugfix-v2-20260613/smoke-summary.json`: `cache_hits: 9`, Req 1 `CacheN=0` (warmup), Req 2-10 `CacheN=36` |
| R7 | MTP fixture 0/10 is not a regression; fallback path intact for no-boundary case | PASS | `._test_output/smoke-stage15-bugfix-20260613/smoke-summary.json`: `cache_hits: 0`; `else` branch in `attach_checkpoint_payload` (no boundaries) sets `checkpoint_boundary_required=false` and computes span checksum, unchanged by the fix |
| R8 | Exact-blob restore path untouched | PASS | Fix is in `validate_checkpoint_descriptor_metadata` and `attach_checkpoint_payload` only; exact-blob restore uses a separate code path; git diff confirms no other function touched |
| R9 | `git diff --check` exit 0 | PASS | `git -C D:\source\llama.cpp-jet diff --check tools/server/server-cache-hybrid.cpp` exit 0 |

## Findings

- BLOCKING: 0
- Non-blocking: 0
- INFO: 2

### INFO 1: V2 fixture is single-message, not multi-turn

The V2 smoke driver (`smoke-v2.ps1`) sends a single-message plain-text
prompt of ~74 tokens, which produces a full-span `[0, n_tokens]`
boundary. The spec's stated use case is multi-turn prompts where the
last boundary ends at `n_tokens` but starts mid-prompt. The V2 evidence
confirms the fix does not break the basic case and admits checkpoints
on the full-span boundary. The multi-turn case is the MTP
/v1/chat/completions path, which is a separate structural issue per the
developer log and the Manager closure decision 1.

### INFO 2: Fallback path scope

The brief's R7 wording says the fallback path is taken "when no boundary
ends at `token_span_end`". The actual code distinguishes two cases:

- No boundaries at all: `else` branch sets `checkpoint_boundary_required=false`
  and computes span checksum. This is the fallback path.
- Boundaries exist but none end at `token_span_end`: `if (!attached_boundary)`
  branch sets `checkpoint_boundary_required=true` with no boundary metadata,
  and the validate function fails with "checkpoint boundary metadata mismatch".

The MTP /completion case falls into the second branch (boundaries exist
at `[0, 78]` but `token_span_end=74`), so the fallback path is not taken
and the admission fails. This is the pre-fix structural-not-infra
behavior, not a regression. The fix is correct for its stated purpose.

## Required corrections

None.

## Handoff

Next owner: QA.
Next gate: B05/B06 rerun using the V2 separate-draft fixture
(`._test_models/Qwen3-8B-GGUF/Qwen3-8B-Q6_K.gguf` + draft
`._test_models/Qwen3-0.6B-GGUF/Qwen3-0.6B-Q8_0.gguf`).
Scope: confirm the V2 9/10 cache hit result reproduces on a clean build
and that the MTP /v1/chat/completions path is exercised separately
under the third-diff extension (per developer log "Next iteration",
path one) or under the existing Manager decision 1 reclassification.

The Architect verdict on the two-diff spec is PASS. The fix is ready
for QA verification on the V2 fixture. No further code changes are
required from the Developer for the two-diff scope.
