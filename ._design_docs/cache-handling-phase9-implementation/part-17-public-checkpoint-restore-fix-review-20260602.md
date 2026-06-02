# Stage 9 public checkpoint restore fix review - 2026-06-02

Source: [../cache-handling-phase9-implementation.md](../cache-handling-phase9-implementation.md)
Fix evidence: [part-16-public-checkpoint-restore-fix-20260602.md](part-16-public-checkpoint-restore-fix-20260602.md)
Owner: Architect
Status: PASS

## Scope

This review covers the Developer correction for public checkpoint restore after
Part 15. It checks the restore flag mapping, restored prompt/cache accounting,
production validation path, focused test hook scope, and Stage 9 documentation.

## Verdict

PASS.

Checkpoint payloads now restore with the same
`LLAMA_STATE_SEQ_FLAGS_PARTIAL_ONLY` flag used when live checkpoints are
exported. Exact blobs still use `LLAMA_STATE_SEQ_FLAGS_NONE`, so full-state
restore behavior is unchanged.

The restore accounting fix is also correct for the public custom-template probe:
checkpoint restore reports the validated descriptor span when the descriptor
starts at token `0` and ends within the entry. That leaves the suffix tokens in
the task prompt for normal replay after checkpoint restore.

## Findings

No blocking findings.

## Evidence checked

- `tools/server/server-context.cpp`: both `try_restore_from_cache()` and
  `load_slot()` still validate the selected descriptor through
  `validate_payload_for_restore()` before applying payload bytes.
- `tools/server/server-context.cpp`: both restore paths now call
  `restore_state_flags_for_payload()` and use the resulting flags for target and
  draft state application.
- `tools/server/server-context.cpp`: both restore paths update
  `slot.prompt.tokens`, `n_prompt_tokens_cache`, and
  `n_prompt_tokens_processed` from `restored_token_count_for_payload()`.
- `tools/server/server-cache-hybrid.cpp`: `restore_state_flags_for_payload()`
  maps `payload_kind::checkpoint` to `LLAMA_STATE_SEQ_FLAGS_PARTIAL_ONLY` and
  all other payload kinds to `LLAMA_STATE_SEQ_FLAGS_NONE`.
- `tools/server/server-cache-hybrid.cpp`: `restored_token_count_for_payload()`
  uses the checkpoint descriptor span only when the descriptor starts at token
  `0`, has a positive end, and the end is inside the entry. Invalid descriptor
  spans do not bypass the production restore validator.
- `tools/server/server-cache-hybrid.cpp`: the new test hook overload admits a
  shorter checkpoint span through `attach_checkpoint_payload()`, so it still
  exercises checkpoint descriptor validation instead of mutating restore state
  directly.
- `tests/test-cache-controller.cpp`: the added regression covers a four-token
  entry with a two-token checkpoint descriptor and asserts the restore token
  count is `2`.
- `part-16-public-checkpoint-restore-fix-20260602.md`: the fix record describes
  the durable behavior change and keeps the remaining model-backed public probe
  as QA work.

## Verification

- `cmake --build build --target test-cache-controller --config Release`: PASS
- `build\bin\Release\test-cache-controller.exe`: PASS, 60 tests

## Review decision

The correction conforms to the accepted Stage 9 design. Checkpoint payloads keep
the descriptor-owned validation path, exact blobs keep full-state restore flags,
and checkpoint restore now exposes only the restored descriptor span to prompt
accounting. No production validation was weakened by the focused test hook.

## Next action

Next owner: QA.

QA should rerun the public custom-template MTP probe from Part 15 to confirm
successful model-backed checkpoint restore and public checkpoint hit metrics.
