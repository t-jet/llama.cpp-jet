# Stage 15 implementation part 9: post-closure follow-up summary (2026-06-16)

Status: applied, 2026-06-16
Stage: 15 (post-closure follow-up)
Date: 2026-06-16
Source implementation: [part-08](part-08-stage15-post-closure-chat-path-impl.md)
Source design: [../cache-handling-phase15-design/part-09-post-closure-chat-path-prompt-boundary.md](../cache-handling-phase15-design/part-09-post-closure-chat-path-prompt-boundary.md)
Source architecture: [../cache-handling-architecture/part-09-chat-path-prompt-boundary-invariant.md](../cache-handling-architecture/part-09-chat-path-prompt-boundary-invariant.md)

## Summary

The 2026-06-16 model log analysis on
`d:\source\llama.cpp-jet\._analysis\model_log.txt` (38 MiB, 319,204
lines, 2h 25m 14s wall clock, MTP fixture) surfaced that the
MTP /v1/chat/completions path still produces
`hybrid cache: checkpoint admission skipped (missing checkpoint
boundary metadata)` warnings on every save (10/10 in the
analyzed log), even with the Stage 15 two-diff fix in place.
The exact-blob path is unaffected; the cache works via the
exact-blob restore, but the checkpoint optimization is silently
disabled.

## Root cause

The chat-completion path in
`cache_metadata_from_chat_messages` emits per-message boundaries
covering each rendered message span, but no boundary covers the
assistant role header at the end of the rendered prompt. The
first end-of-prefill checkpoint has `n_tokens` equal to the full
prompt size, which no per-message boundary covers. The matching
loop skips all boundaries, then sets
`descriptor.checkpoint_boundary_required = true` with empty
`boundary_id`, and the strict validator at
`server-cache-hybrid.cpp:2984` returns
`fail("missing checkpoint boundary metadata")` and rolls back the
checkpoint payload.

## Fix (Option A, surgical)

Add a `MESSAGE_END` boundary at `[0, n_prompt_tokens]` in
`cache_metadata_from_chat_messages` after the per-message loop,
with `metadata = "prompt"` and `protect = false`, and a checksum
computed over the full prompt range. This is the same shape as
the fallback path in `cache_metadata_for_request` and provides a
boundary whose `token_end` equals the full chat prompt size,
allowing the first end-of-prefill checkpoint to attach.

Affected file: `tools/server/server-context.cpp`,
`cache_metadata_from_chat_messages`. One insertion (14 lines,
including a 10-line comment).

## Verification

Pending. The pre-fix state on the MTP fixture was 0/30 successful
restores. The expected post-fix state is 29/30 or 30/30, mirroring
the V2 separate-draft fix at 29/29.

Required verification steps:

1. **Build verification**: `cmake --build build-cov --config
   Release --target llama-server` exit 0. The file touched is
   `server-context.cpp`; the change is contained to one function
   and does not require other recompiles.
2. **Unit test**: a new unit test in
   `tests/test-cache-controller.cpp` that calls
   `cache_metadata_from_chat_messages` with a representative chat
   input (3-message: system, user, assistant-prefix) and asserts
   the metadata has at least one `MESSAGE_END` boundary at
   `[0, n_prompt_tokens]` with `metadata == "prompt"`. This is a
   pure-metadata test, no model required.
3. **Integration test**: a new integration test that exercises
   hybrid cache save on the chat-completion path with the MTP
   fixture and asserts `n_checkpoint_payload_descriptors`
   increases after the first save (was 0 before the fix).
4. **QA benchmark rerun**: rerun the Stage 15 B05/B06 benchmark
   on the MTP fixture
   ([stage15-benchmark-20260613-03.md](../../.test_reports/stage15-benchmark-20260613-03.md))
   and assert the chat-completion variant now produces non-zero
   `cache_checkpoint_admissions_total` and `cache_n > 0` on
   subsequent identical requests.

## Manager follow-up

The Manager closure decision 1 (2026-06-13) reclassified
B02/B05/B06 to NOT-IN-SCOPE for the MTP fixture. After the QA
verification of this fix on the MTP fixture, the Manager may
revisit that reclassification. The Manager owns the cache
stage tracker row update per the improvement memory
`Closure sweep keeps durable docs aligned without re-running
the report`.

The test plan follow-up picks up the proposed test plan rows
TP-15-PC1..TP-15-PC7 in design part-09.

## Cross-references

- Implementation: [part-08](part-08-stage15-post-closure-chat-path-impl.md)
- Design: [../cache-handling-phase15-design/part-09](../cache-handling-phase15-design/part-09-post-closure-chat-path-prompt-boundary.md)
- Architecture: [../cache-handling-architecture/part-09](../cache-handling-architecture/part-09-chat-path-prompt-boundary-invariant.md)
- Stage 15 design entry: [../cache-handling-phase15-design.md](../cache-handling-phase15-design.md)
- Stage 15 implementation entry: [../cache-handling-phase15-implementation.md](../cache-handling-phase15-implementation.md)
