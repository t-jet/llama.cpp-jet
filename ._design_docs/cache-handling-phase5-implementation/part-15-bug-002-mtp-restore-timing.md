# Phase 5 implementation: BUG-002 MTP restore timing fix

Source: [../cache-handling-phase5-implementation.md](../cache-handling-phase5-implementation.md)

## Scope

This note records the BUG-002 fix from [test-report-20260528-08](../.test_reports/test-report-20260528-08.md). The affected rows are H53 and H54 with the Qwen3.5 MTP fixture.

## Root cause

The hybrid controller restored the exact blob and counted a hit before launching the request. The prompt loop later decided reuse from the request `cache_prompt` flag and from checkpoint/SWA replay checks.

The public MTP probes did not set `cache_prompt`. After the first fix, MTP still replayed the full prompt because the checkpoint/SWA guard treated the restored exact state like ordinary in-memory prompt reuse and reset `n_past` to zero.

## Code change

`server_slot` now carries `hybrid_cache_restored` for the current launch. `try_restore_from_cache()` sets it only after descriptor validation, target/draft state apply, LRU update, and slot prompt restoration succeed.

The prompt loop uses the marker as a reuse gate for hybrid restores even when `cache_prompt` is false. It also skips the checkpoint/SWA replay fallback for a successful exact hybrid restore. The normal fallback remains unchanged for ordinary prompt reuse.

The marker is cleared by slot reset and prompt clear, so legacy mode and later non-restored requests do not inherit it.

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

Result: `3 passed, 1 xfailed`.

The xfail is the existing explicit `id_slot` restore exposure limitation. H53 and H54 use the public LRU slot path, not explicit `id_slot`.

Public MTP rerun:

| Row | Startup | Request 2 `cache_n` | Request 2 `prompt_n` | Hits | Misses | Restore failures | Fallback restores |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| H53 target-derived MTP | PASS | 11 | 1 | 1 | 1 | 0 | 0 |
| H54 separate-model MTP | PASS | 12 | 1 | 1 | 1 | 0 | 0 |

Artifacts:

- [h53-target-derived-mtp-after-fix-v2.summary.json](../.test_reports/test-report-20260528-08-developer-artifacts/h53-target-derived-mtp-after-fix-v2.summary.json)
- [h54-separate-model-mtp-after-fix-v2.summary.json](../.test_reports/test-report-20260528-08-developer-artifacts/h54-separate-model-mtp-after-fix-v2.summary.json)

## Handoff

State: fixed for the public H53/H54 acceptance path.

Next QA action: rerun H53 and H54 with the Qwen3.5 MTP fixture and the same public request shape from `test-report-20260528-08`.
