# Cache handling phases 1 and 2 implementation gaps - Part 1: Summary

Source: [../cache-handling-phases-1-and-2-implementation-gaps.md](../cache-handling-phases-1-and-2-implementation-gaps.md)

## Summary

The code builds and the focused `test-cache-controller` target passes. Stage 1 is mostly present: `--cache-mode`, the controller interface, the factory, legacy adapter, and mode dispatch exist.

Stage 2 is only partially complete. Metadata is threaded through tasks, but the metadata shape is smaller than the architecture requires, boundary extraction is best-effort post-processing rather than capture during prompt preparation, and there are no fixture tests proving boundary correctness.

The larger risk is in the extra hybrid-cache functionality added beyond stages 1 and 2. Current hybrid restore can restore a full cached runtime state for a partial prefix match, and draft restore failure does not fail the paired restore. Both issues can break inference correctness.

## Findings and corrective actions

### 1. Hybrid restore accepts partial matches but restores full cached state

Severity: high

Evidence:

- `tools/server/server-cache-hybrid.cpp`: `find_best_match()` accepts a candidate when the common prefix is nonzero and at least 25% of the cached entry.
- `tools/server/server-context.cpp`: `hybrid_cache_controller::load_slot()` restores the full serialized cached state, then records only `match_len` tokens in the slot.

Why this is a problem:

If a cached prompt is `[A, B, C, D]` and a new request is `[A, B, X]`, the controller may restore state for `[A, B, C, D]` while slot accounting says only `[A, B]` was restored. That can make runtime state and scheduler state disagree.

Corrective action:

- For exact full-state blob restore, require `match_len == cached_entry.tokens.size()`.
- Treat partial-prefix reuse as a miss until there is a safe trim, checkpoint, or re-materialization path.
- Add a regression test for diverging prefixes:
  - save `[A, B, C, D]`
  - request `[A, B, X]`
  - verify hybrid exact-blob restore is rejected

Acceptance criteria:

- A cached full-state blob is restored only when the entire cached token sequence is a prefix of the new request.
- Slot token accounting always matches the restored runtime state.

### 2. Target/draft restore is not atomic

Severity: high

Evidence:

- `tools/server/server-context.cpp`: target state is restored first.
- Draft state restore failure logs a warning but still allows the load path to return success.

Architecture requirement:

`cache-handling-architecture.md` requires target and draft payloads to be treated as one paired restore object. Restore, offload, demotion, promotion, and eviction must operate on the pair.

Why this is a problem:

A target restore with a failed draft restore can leave speculative decoding state inconsistent. That is not a valid cache hit.

Corrective action:

- Validate that expected target and draft payloads are both present before applying either side.
- If draft restore fails, reject the whole cache hit and force a safe fallback.
- Consider restoring into a temporary or otherwise reversible path if the runtime API permits it. If not, fail before applying target when pair validation is incomplete.
- Add tests for:
  - target-only namespace
  - target-plus-draft namespace
  - missing draft payload
  - draft restore failure

Acceptance criteria:

- A paired target/draft entry either restores both sides successfully or does not count as a cache hit.
- Cache stats record paired restore failures separately from normal misses.

### 3. Stage 2 metadata does not match the architecture contract

Severity: medium

Evidence:

- `tools/server/server-task.h`: `prompt_boundary` has `type`, `token_index`, and `metadata`.
- `cache-handling-architecture.md`: Stage 2 calls for boundary spans with kind, token offsets, checksums, protection flags, plus prepared-prompt metadata with protection hints and compatibility keys.

Why this is a problem:

The current metadata can mark a token position, but it cannot validate a span, distinguish protected spans, or carry compatibility information needed by later restore planning.

Corrective action:

- Replace or extend `prompt_boundary` with a span-shaped structure:
  - kind
  - token_start
  - token_end
  - checksum
  - protect flag
  - optional label or role
- Extend `prepared_prompt_metadata` with:
  - compatibility key
  - template or prompt-preparation identifier
  - protection hints
  - degraded/absent metadata reason
- Keep conversion helpers small and local so future branch-graph work can reuse the same metadata.

Acceptance criteria:

- Metadata can identify and validate a prompt span, not just a single token index.
- Missing or degraded metadata is explicit and visible to diagnostics.

### 4. Boundary capture is best-effort post-processing, not prompt-preparation capture

Severity: medium

Evidence:

- `tools/server/server-common.cpp`: chat messages are stored after chat template application as `_cache_prompt_metadata_source`.
- `tools/server/server-context.cpp`: boundary extraction searches rendered prompt text for message content.

Why this is a problem:

Text search can produce wrong boundaries when:

- two messages contain the same text
- a template escapes or transforms content
- a message is empty
- role/control tokens are outside the content span
- tool call arguments are rendered differently from the source JSON

Corrective action:

- Capture boundary metadata as close as possible to template application and tokenization.
- If exact capture cannot be implemented yet, mark metadata as degraded and explain the reason.
- Avoid claiming full Stage 2 boundary capture until fixture tests prove correctness.
- Add fixtures for repeated content, empty content, system/developer messages, tool calls, and templates that add role/control tokens.

Acceptance criteria:

- Chat boundary fixtures produce deterministic token spans.
- Fallback extraction is clearly marked as degraded.

### 5. Prefix index misses valid short cached prefixes

Severity: medium

Evidence:

- `tools/server/server-cache-hybrid.h`: `PREFIX_INDEX_LENGTH` is 8.
- `tools/server/server-cache-hybrid.cpp`: entries are indexed by their prefix, and requests are looked up by their first 8 tokens.

Why this is a problem:

A cached entry shorter than 8 tokens, such as `[A, B]`, is indexed under `[A, B]`. A request `[A, B, C, D, E, F, G, H]` is looked up under `[A, B, C, D, E, F, G, H]`, so the shorter valid prefix candidate is missed.

Corrective action:

- Either index entries under all prefix lengths up to `PREFIX_INDEX_LENGTH`, or lookup candidate buckets for all request prefix lengths from `min(n, PREFIX_INDEX_LENGTH)` down to 1.
- Add tests for cached entries shorter than the index length.

Acceptance criteria:

- A shorter cached prompt that is a valid prefix candidate can be found by hybrid lookup.

### 6. Tests do not cover the implemented risk areas

Severity: medium

Evidence:

- `tests/test-cache-controller.cpp` covers enum, factory, metadata structure, stats shape, and simple controller construction.
- `tools/server/tests/test_cache_phase2.cpp` contains test stubs that print skipped/manual-test messages.
- No automated test currently proves hybrid save/load round trip, paired draft correctness, boundary fixture correctness, or HTTP stats behavior.

Why this is a problem:

The implementation reports cite completion and coverage, but the highest-risk behavior is not covered by executable tests.

Corrective action:

- Add model-backed integration tests using the existing tiny model fixture pattern used by other tests.
- Add boundary fixture tests that do not require a full model when possible.
- Add cache-controller tests for lookup behavior by exposing test hooks or extracting pure lookup/index helpers.
- Do not claim the 80% coverage target until coverage tooling or a measurable test plan confirms it.

Acceptance criteria:

- Automated tests cover:
  - exact blob full-prefix restore
  - divergent prefix miss
  - non-destructive repeated hits
  - LRU eviction with protected entries
  - target/draft paired failure
  - boundary metadata for representative chat fixtures
  - `/health` and `/cache/stats` response shape

### 7. Phase documents overstate completion and mix architecture stages

Severity: medium

Evidence:

- `cache-handling-phase2-design.md` says phase 2 completes architecture stages 1 and 2, but it also includes hybrid save/load, stats endpoints, slot refactoring, and LRU optimization.
- `cache-handling-phase2-implementation.md` has conflicting statements: one section says boundary extraction was deferred, while a later continuation says generic boundary extraction is complete.

Why this is a problem:

Reviewers cannot tell which architecture stage is complete. The reports also make it easy to miss that Stage 2 metadata is still incomplete.

Corrective action:

- Split reporting into:
  - architecture stage 1 status
  - architecture stage 2 status
  - extra hybrid-cache work completed ahead of later stages
  - known correctness risks
- Mark generic boundary extraction as degraded, not complete Stage 2 capture.
- Replace coverage claims with the exact tests that were run and what they do not cover.

Acceptance criteria:

- The reports do not claim Stage 2 completion until the metadata shape, capture path, diagnostics, and fixture tests meet the architecture exit criteria.

## Recommended correction order

1. Disable unsafe hybrid partial-prefix exact-blob restore by requiring a full cached-entry prefix match.
2. Make target/draft restore fail as one pair.
3. Add focused regression tests for the two correctness fixes.
4. Update Stage 2 metadata structures to span-based metadata with checksum/protection fields.
5. Replace best-effort boundary extraction claims with degraded diagnostics, then add fixture-backed capture.
6. Fix prefix-index lookup for short cached entries.
7. Clean up the phase reports so architecture stages and extra implementation work are tracked separately.

## Verification performed during review

Commands run:

```text
ctest --test-dir build-phase2 -C Release -R test-cache-controller --output-on-failure
cmake --build build-phase2 --config Release --target llama-server
```

Results:

- `test-cache-controller` passed.
- `llama-server` built successfully.

Limitations:

- The passing test target is mostly structural.
- No model-backed hybrid save/load test was run.
- No boundary fixture test was run.
- No coverage tool result was available.

## Corrective action progress

Date: 2026-05-24

Status: partial implementation complete. The highest-risk pure-code issues from this review were addressed and covered by focused unit tests. Model-backed restore tests are still needed for full runtime coverage.

### Changes made

