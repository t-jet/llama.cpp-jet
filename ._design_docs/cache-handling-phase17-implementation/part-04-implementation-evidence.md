# Stage 17 implementation evidence -- Part 4

Source: [../cache-handling-phase17-implementation.md](../cache-handling-phase17-implementation.md)
Date: 2026-06-17
Status: implemented core code and focused tests; ready for implementation review

## Scope implemented

This pass implements the Stage 17 core that could be done safely in one
Developer session:

- CLI/config fields:
  - `--cache-cold-max-mib N`
  - `--cache-prompt-evidence MODE`
  - `--cache-prompt-evidence-dir PATH`
- Startup validation:
  - invalid cold budgets below `-1` fail
  - prompt evidence modes must be `off`, `redacted`, or `raw`
  - evidence modes require hybrid cache and an evidence directory
  - raw evidence requires explicit `--log-prompts-dir`
  - enabled positive cold budgets require a cold path
- Restore-miss accounting:
  - bounded `cache_restore_miss_reason` enum
  - one primary miss reason recorded for `try_restore_from_cache` and
    `load_slot` false exits
  - `payload_unavailable` on descriptor, promotion, snapshot, restore, or
    checkpoint path failures
  - `unsafe_prefix_rejected` when a shorter prefix candidate exists
- Prompt evidence:
  - JSONL sink at `cache-prompt-evidence.jsonl`
  - one record per restore lookup when evidence is enabled
  - redacted records include preparation id, namespace hash, profile, pair
    state, token count, boundary count, first user boundary, token-span
    checksum, lookup outcome, and prefix candidate summary
  - raw mode is gated by `--log-prompts-dir`; this implementation does not
    write prompt text or raw prompt paths
  - evidence write failure updates bounded counters and does not fail requests
- Prefix policy:
  - prefix restore is not implemented
  - existing shorter-prefix candidate selection is rejected before live state
    mutation in both restore paths
- Cold budget:
  - controller stores configured cold budget bytes
  - `0` disables cold writes
  - `-1` keeps cold writes unlimited when a cold path is configured
  - positive budgets trigger skip-before-write checks
  - unprotected cold payloads can be evicted before a new demotion write
  - target/draft payload bytes are treated as one estimated write unit
- Checkpoint metrics:
  - checkpoint admission rows include bounded `policy`, `result`, and `reason`
  - compatibility-required paths are labelled `compat_required`
  - non-required paths are labelled `semantic`
- Metrics:
  - `cache_restore_misses_total`
  - `cache_prompt_evidence_records_total`
  - `cache_prefix_candidates_total`
  - `cache_checkpoint_admissions_by_shape_total`
  - `cache_cold_bytes`
  - `cache_cold_budget_bytes`
  - `cache_cold_evictions_total`
  - `cache_cold_demotions_skipped_total`

## Files changed

Code:

- `common/common.h`
- `common/arg.cpp`
- `tools/server/server-context.cpp`
- `tools/server/server-cache-hybrid.h`
- `tools/server/server-cache-hybrid.cpp`

Tests:

- `tests/test-cache-controller.cpp`

Docs:

- `._design_docs/cache-handling-phase17-implementation.md`
- `._design_docs/cache-handling-phase17-implementation/part-04-implementation-evidence.md`
- `._design_docs/document-index.md`
- `._design_docs/cache-handling-stage-tracker.md`

## Test evidence

Commands run:

```text
cmake --build build --target test-cache-controller --config Release
build\bin\Release\test-cache-controller.exe
cmake --build build --target llama-server --config Release
```

Results:

- `test-cache-controller` build: PASS
- `test-cache-controller.exe`: PASS, 74 tests
- `llama-server` build: PASS

Notes:

- The focused test suite includes two Stage 17 tests:
  - common-param defaults for cold budget and prompt evidence
  - redacted JSONL evidence for an unsafe prefix candidate
- The server build also rebuilt UI assets as part of the existing
  `llama-server` target.

## Deferred or partial items

These plan items were not completed fully in this session:

- Cold startup scan counts only controller-owned descriptors during runtime.
  Full startup ownership reconciliation for pre-existing cold files remains
  partial because descriptor ownership is not available before controller state
  is loaded.
- Orphan staging cleanup in `server_cache_store_cold` was not extended beyond
  existing write-path cleanup. This needs a focused cold-store follow-up if
  Manager requires startup cleanup closure in Stage 17.
- Checkpoint-density policy records bounded admission policy metrics, but it
  does not add a new semantic-boundary filter that skips optional dense
  checkpoints. Existing checkpoint behavior is preserved.
- Raw evidence mode is gated by `--log-prompts-dir`, but no raw prompt file
  reference is emitted. The design allows raw mode to reference raw prompt
  files, but does not require a reference for every record.
- Public `/metrics` samples were not captured from a live server in this
  session. Metric row generation was compiled through `llama-server`; live
  scrape belongs in QA or implementation review follow-up.

## Privacy and safety notes

- No metric labels include prompt text, raw paths, raw namespaces, raw
  descriptor ids, or free-form marker labels.
- Redacted evidence uses namespace hashes and token/checksum counts only.
- Prefix candidates are classified and counted, but never restored.
- Failed evidence writes and cold budget skips do not mutate live slot state.

## Handoff

Next owner: Architect or Manager for implementation review.

Recommended review focus:

- Confirm exact-restore behavior still covers existing Stage 15/16 acceptance
  cases after explicit prefix rejection.
- Decide whether the deferred cold startup scan/staging cleanup and optional
  dense-checkpoint filter must be completed inside Stage 17 or split into a
  follow-up stage.
