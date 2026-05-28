# BUG-002 fix report: MTP hybrid restore timing

Source report: [test-report-20260528-08.md](test-report-20260528-08.md)
Date: 2026-05-28

## Scope

Triage H53 and H54 after Qwen3.5 MTP startup became available. The only accepted fix scope is a cache restore or accounting bug. Legacy cache mode, target-only behavior without hybrid cache, and normal draft-model restore semantics must not change.

## Root cause

The hybrid controller restored the exact blob and incremented `n_hits` before the request was launched. The later prompt loop then decided how many tokens to reuse from `slot.task->params.cache_prompt`.

The H53/H54 public probes did not set `cache_prompt`. In hybrid mode the server still attempted non-destructive restore, so metrics showed one hit and one hot payload descriptor. The prompt loop ignored that restored state because `cache_prompt` was false, reset `n_past` to zero, reprocessed the full prompt, and returned `timings.cache_n=0`.

This is product behavior, not a QA-only evidence mismatch. A reported hybrid hit must leave prompt reuse visible to the request that caused the hit.

## Fix plan

1. Carry a slot-local marker when `try_restore_from_cache()` succeeds.
2. Let the prompt reuse branch treat that marker the same as request `cache_prompt` for the current launch.
3. Clear the marker on slot reset and prompt clear so legacy reuse and later non-hybrid requests are unchanged.
4. Add focused Python integration coverage for hybrid restore when `cache_prompt` is omitted.
5. Rebuild `llama-server` and rerun H53/H54 if the local model fixture is available.

## Progress

- 2026-05-28: Triage completed. Root cause is the `cache_prompt` gate after a successful hybrid restore.
- 2026-05-28: Implemented a slot-local `hybrid_cache_restored` marker. The prompt loop now reuses a successful exact hybrid restore even when the request omits `cache_prompt`, and it does not run the checkpoint/SWA replay fallback over a transactional exact restore.
- 2026-05-28: Added public-path regression coverage for hybrid restore without request `cache_prompt`.

## Evidence

Build:

```powershell
cmake --build build --config Release --target llama-server -j 4
```

Result: PASS.

Focused regression:

```powershell
$env:LLAMA_SERVER_BIN_PATH='D:\source\llama.cpp-jet\build\bin\Release\llama-server.exe'
$env:LLAMA_SERVER_TEST_SKIP_MODEL_PRELOAD='1'
python -m pytest tools/server/tests/unit/test_cache_modes.py -q
```

Result: PASS, `3 passed, 1 xfailed`. The remaining xfail is the existing explicit `id_slot` restore exposure limitation and is not part of H53/H54.

Public MTP rerun artifacts:

- [h53-target-derived-mtp-after-fix-v2.summary.json](test-report-20260528-08-developer-artifacts/h53-target-derived-mtp-after-fix-v2.summary.json)
- [h54-separate-model-mtp-after-fix-v2.summary.json](test-report-20260528-08-developer-artifacts/h54-separate-model-mtp-after-fix-v2.summary.json)

H53 target-derived MTP:

- Startup reached `/health`.
- Request 1: `cache_n=0`, `prompt_n=12`.
- Request 2: `cache_n=11`, `prompt_n=1`.
- Metrics: hits `1`, misses `1`, restore failures `0`, fallback restores `0`, hot payload descriptors `1`.

H54 separate-model MTP:

- Startup reached `/health`.
- Request 1: `cache_n=0`, `prompt_n=13`.
- Request 2: `cache_n=12`, `prompt_n=1`.
- Metrics: hits `1`, misses `1`, restore failures `0`, fallback restores `0`, hot payload descriptors `1`.

## Outcome

BUG-002 is fixed for the public H53/H54 acceptance path. Hybrid hit metrics now match the public `timings.cache_n > 0` signal for the repeated MTP request.
