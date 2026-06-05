# Stage 9 public checkpoint restore fix - 2026-06-02

Source: [../cache-handling-phase9-implementation.md](../cache-handling-phase9-implementation.md)
Previous note: [part-15-public-checkpoint-admission-follow-up-20260602.md](part-15-public-checkpoint-admission-follow-up-20260602.md)
Owner: Developer
Status: implemented with focused regression evidence

## Scope

This part records the narrow product fix for the public custom-template MTP
checkpoint probe. Part 15 showed that checkpoint admission can succeed, but the
second request failed when hybrid restore applied checkpoint payload bytes.

## Root cause

Live context checkpoints are exported with
`LLAMA_STATE_SEQ_FLAGS_PARTIAL_ONLY` in `server_context::create_checkpoint`.
Hybrid restore applied checkpoint payload bytes with
`LLAMA_STATE_SEQ_FLAGS_NONE` in both `try_restore_from_cache` and `load_slot`.
That mismatch can reject otherwise valid checkpoint payload bytes during target
restore.

The same paths also updated restored prompt/cache length from the full cache
entry length. A checkpoint payload can cover only the checkpoint descriptor span
inside a longer prepared entry. Restoring the full entry length hides suffix
tokens that still need prompt replay after checkpoint restore.

## Code changes

- `tools/server/server-cache-hybrid.*`
  - Added payload-kind helpers for restore apply flags and restored token count.
  - Checkpoint payloads now map to `LLAMA_STATE_SEQ_FLAGS_PARTIAL_ONLY`; exact
    blobs keep `LLAMA_STATE_SEQ_FLAGS_NONE`.
  - Checkpoint restored token count now comes from the descriptor span when the
    descriptor starts at token 0 and ends within the entry.
  - Added focused Stage 9 test hooks for admitting a shorter checkpoint span and
    reading the restore token count.

- `tools/server/server-context.cpp`
  - `hybrid_cache_controller::try_restore_from_cache` now applies checkpoint
    payload bytes with the checkpoint restore flags.
  - `hybrid_cache_controller::load_slot` now applies checkpoint payload bytes
    with the checkpoint restore flags.
  - Both paths update `slot.prompt.tokens`, `n_prompt_tokens_cache`, and
    `n_prompt_tokens_processed` from the checkpoint descriptor span for
    checkpoint payloads, leaving suffix tokens for replay.

- `tests/test-cache-controller.cpp`
  - Added `test_stage9_checkpoint_restore_uses_descriptor_span`.
  - The test admits a checkpoint for the first two tokens of a four-token entry
    and asserts the restore token count is `2`, not the full entry length.

## Evidence

- Built focused target:
  - `cmake --build build --target test-cache-controller --config Release`
  - Result: PASS

- Ran focused regression binary:
  - `build\bin\Release\test-cache-controller.exe`
  - Result: PASS, 60 tests

## Remaining work

The focused unit coverage verifies descriptor-span accounting and the target
build compiles the changed restore paths. QA should rerun the public
custom-template MTP probe from Part 15 to collect model-backed evidence that the
repeated request now restores the admitted checkpoint and reports checkpoint hit
metrics.
