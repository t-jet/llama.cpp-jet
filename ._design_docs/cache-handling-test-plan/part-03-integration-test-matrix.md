# Cache handling test plan - Part 3: integration test matrix

Source: [../cache-handling-test-plan.md](../cache-handling-test-plan.md)

## Server defaults for integration tests

Use a helper that starts `llama-server` with these defaults unless a test overrides them:

```powershell
--model <resolved model path>
--host 127.0.0.1
--port <free port>
--ctx-size 512
--parallel 2
--cont-batching
--kv-unified
--server-slots
--cache-ram 100
--temp 0
--seed 42
--metrics
```

Each test should stop the server in `finally` cleanup and collect stderr, stdout, `/metrics`, and the final response JSON.

## Regression Prevention Tests (Stage 1)

| ID | Scenario | Mode | Expected result |
| --- | --- | --- | --- |
| R01 | Legacy mode unchanged | legacy | Run Phase 0 baseline tests. Verify exact same behavior as upstream llama.cpp. No hybrid-specific metrics or features. |
| R02 | Default mode is legacy | no `--cache-mode` | Verify mode="legacy" in `/metrics`. Server behavior identical to R01. |
| R03 | Hybrid opt-in only | hybrid | Explicitly verify default mode != hybrid. Hybrid features only available with `--cache-mode=hybrid`. |
| R04 | No new dependencies | both modes | Build system check: verify no new external dependencies added. Document baseline dependencies. |

## Mode Selection and Configuration Tests (Stage 1)

| ID | Scenario | Mode | Expected result |
| --- | --- | --- | --- |
| C01 | Default cache mode | no `--cache-mode` | Server starts; `/metrics` has `llamacpp_cache_*{mode="legacy"}`; `/health` is `{"status":"ok"}`. |
| C02 | Explicit legacy mode | `legacy` | Server starts; cache metrics use `mode="legacy"`. |
| C03 | Explicit hybrid mode | `hybrid` | Server starts; cache metrics use `mode="hybrid"`. |
| C04 | Invalid cache mode | invalid value | Process exits nonzero and prints `invalid cache mode`. |
| C05 | `/cache/stats` absent | both modes | `GET /cache/stats` returns 404. |
| C06 | Metrics disabled | hybrid, no `--metrics` | `/metrics` returns the server's not-supported error. Cache behavior should still work. |
| C10 | Legacy compatibility smoke | legacy | Same prompt reuse succeeds and existing `cache_prompt` behavior remains valid. Do not require hybrid hit counters. |

## Concurrent Access Tests (Stage 1 & 3)

| ID | Scenario | Mode | Expected result |
| --- | --- | --- | --- |
| C11 | Concurrent save operations | hybrid, `-np 2` | 2 slots saving different prompts simultaneously. Verify both entries created correctly. No race conditions or corruption. |
| C12 | Concurrent load operations | hybrid, `-np 2` | 2 slots loading same entry simultaneously. Both succeed with cache hits. Entry persists after both loads. |
| C13 | Save during load | hybrid, `-np 2` | Slot A loading cached entry, Slot B saving new entry. Verify no corruption, both operations succeed. |
| C14 | Eviction during load | hybrid, `-np 2`, `--cache-ram 1` | Trigger eviction while another slot loads different entry. Verify loading slot unaffected by concurrent eviction. |
| C15 | Metrics under concurrency | hybrid, `-np 2` | Parallel hits and misses. Verify `/metrics` counters accurate with no lost increments. Test with 10+ concurrent requests. |

## Stage 2: Boundary Metadata Tests

| ID | Scenario | Mode | Expected result |
| --- | --- | --- | --- |
| B01 | Boundary extraction in degraded mode | hybrid | Verify `boundaries_native=false` flag in metadata. Check `degraded_reason` is set to "inferred_from_rendered_text". Verify inferred boundaries are plausible (within prompt token range). |
| B02 | Boundary metadata threading | hybrid | Verify metadata flows from HTTP layer → `server_task` → `server_slot`. Check metadata survives task pipeline without corruption. |
| B03 | Missing boundary fallback | hybrid | `/completion` endpoint with minimal metadata. Verify degraded markers present in slot metadata. Server continues without boundary info. |
| B04 | Repeated message content | hybrid | Chat with same text in multiple messages. Verify distinct boundary positions for each occurrence. Boundaries must not collapse to single span. |
| B05 | Empty message handling | hybrid | Chat with empty user/assistant messages. Verify boundary extraction doesn't fail. Empty messages get zero-length or role-token-only spans. |
| B06 | Protection flag propagation | hybrid | Chat with system prompt (should set `protected_root=true`). Verify protection flag reaches cache entry. Check entry skipped during eviction. |

## Phase 3: Hybrid Cache Integration Tests

| ID | Scenario | Mode | Expected result |
| --- | --- | --- | --- |
| H01 | Non-destructive hit (single reuse) | hybrid | First request creates cache entry. Second identical request hits cache. `/metrics` shows `llamacpp_cache_hits{mode="hybrid"}` incremented. Both requests succeed. |
| H02 | Multi-slot reuse | hybrid, `-np 2` | Send 2 identical requests in parallel. Both should hit same cache entry. `/metrics` shows `llamacpp_cache_hits` >= 1. Cache entry count remains 1. |
| H03 | Sequential reuse (3x) | hybrid | Send same prompt 3 times sequentially. `/metrics` shows `llamacpp_cache_hits` = 2 (second and third requests). Entry persists in cache. |
| H04 | Usage tracking increment | hybrid | Create cache entry, then load it twice. Verify logs show usage count incrementing (1, then 2). Timestamp updates on each hit. |
| H05 | Cache miss tracking | hybrid | Send different prompts. `/metrics` shows `llamacpp_cache_misses{mode="hybrid"}` increments for each unique prompt. |
| H06 | Exact match requirement | hybrid | Save entry with tokens [1,2,3,4,5]. Request with tokens [1,2,3] (prefix only). Should be **cache miss**, not partial hit. `/metrics` shows miss increment. |
| H07 | Reject divergent sequence | hybrid | Save entry with tokens [1,2,3,4,5]. Request with tokens [1,2,3,99,100]. Should be cache miss. No partial match. |
| H08 | State serialization round-trip | hybrid | First request generates 10 tokens. Second identical request should restore state and generate consistent output with same seed. Verify `timings.cache_n` > 0 for second request. |
| H09 | Empty slot rejection | hybrid | Attempt to save slot with 0 tokens (edge case in code). Should log warning and not create entry. `/metrics` shows no hit/miss change. |
| H10 | LRU eviction basic | hybrid, `--cache-ram 1` | Send 3 different prompts with small cache limit. Verify `/metrics` shows `llamacpp_cache_evictions{mode="hybrid"}` > 0. Oldest entry evicted. |
| H11 | LRU eviction ordering | hybrid, `--cache-ram 1` | Save entries A, B, C. Access A (updates LRU). Send entry D (triggers eviction). Verify B evicted (oldest unused), not A (recently used). |
| H12 | Namespace isolation (different models) | hybrid | Not testable in single-server run. Verify architecture enhancement allows model_path_hash in compatibility key. Check logs for namespace ID diversity. |
| H13 | Namespace isolation (different templates) | hybrid | Start server with chat template A. Verify logs show template_id in compatibility key. Documentation check: different templates produce different namespace IDs. |
| H14 | Metrics counter accuracy | hybrid | Perform sequence: miss, miss, hit, eviction. Verify `/metrics` shows exact counts: misses=2, hits=1, evictions>=1. |
| H15 | Restore failure tracking | hybrid | Simulate restore failure (requires code-level test or corrupted state). Verify `llamacpp_cache_restore_failures{mode="hybrid"}` increments. |
| H16 | Protected entry behavior | hybrid | Save entry with system prompt boundary (protected_root=true). Verify protected entries skipped during eviction until all entries protected. |
| H17 | Multi-namespace entry count | hybrid | Run with different configurations (model A, then model B). Verify per-namespace entry counts separate in internal state (requires debug logs or test helpers). |
| H18 | Concurrent access safety | hybrid, `-np 2` | Send 2 different prompts simultaneously. Both should complete without race conditions. Cache entries correct. No crashes. |

## Extended LRU Eviction Tests (Phase 3)

| ID | Scenario | Mode | Expected result |
| --- | --- | --- | --- |
| H19 | Multiple evictions in one update | hybrid, `--cache-ram 1` | Cache with 5 entries, budget allows only 2. Add new entry triggering update. Verify exactly 4 entries evicted (5 existing - 2 that fit + 1 new = 4 evicted). Check `llamacpp_cache_evictions` increment. |
| H20 | Eviction during active restore | hybrid, `-np 2`, `--cache-ram 1` | Slot A loading entry (slow operation). Slot B triggers eviction of different entry. Verify no race conditions, both operations complete successfully. |
| H21 | Protected root exhaustion | hybrid, `--cache-ram 1` | All entries have `protected_root=true`, budget exceeded. Verify explicit diagnostic logged: "all entries protected, evicting oldest protected entry". Verify oldest protected entry evicted. |
| H22 | Protected vs unprotected ordering | hybrid, `--cache-ram 5` | Mix of 3 protected and 3 unprotected entries. Trigger eviction. Verify all unprotected entries evicted before any protected entry. Check LRU ordering respected within each group. |
| H23 | Eviction metrics accuracy | hybrid, `--cache-ram 1` | Perform sequence: add entry A, add B (evicts A), add C (evicts B), add D (evicts C). Verify `llamacpp_cache_evictions{mode="hybrid"}` = 3 exactly. |

## Namespace Isolation Tests (Phase 3)

| ID | Scenario | Mode | Expected result |
| --- | --- | --- | --- |
| H24 | Model path isolation | hybrid | Start server, save cache entry. Check logs for `model_path_hash` in compatibility key. Document: different model files produce different namespace IDs. |
| H25 | LoRA adapter isolation | hybrid | Start with `--lora adapter1.gguf --lora-scaled adapter2.gguf 0.5`. Verify logs show `lora_adapters` in compatibility key with both adapters. Different adapter sets = different namespaces. |
| H26 | Control vector isolation | hybrid | Start with `--control-vector vec1.gguf`. Verify compatibility key includes `control_vectors` field. Different vectors = different namespaces. |
| H27 | Multimodal configuration isolation | hybrid | Start with `--mmproj projector.gguf`. Verify logs show `mm_projector_id` in compatibility key. Different projectors = different namespaces. |
| H28 | Template isolation | hybrid | Start with custom `--chat-template`. Verify compatibility key includes `template_id` hash. Different templates = different namespaces (prevents cross-template cache hits). |
| H29 | KV mode isolation | hybrid | Compare run with `--kv-unified` vs without. Verify compatibility key includes `kv_unified` flag. Different KV modes = different namespaces. |

## Draft Model Tests (Phase 3)

| ID | Scenario | Mode | Expected result |
| --- | --- | --- | --- |
| D01 | Draft model paired save | hybrid, `--model-draft <draft.gguf>` | First request saves cache entry. Verify logs show both target and draft states serialized. Entry size accounts for both contexts. |
| D02 | Draft model paired restore | hybrid, draft model | Second identical request hits cache. Verify both target and draft contexts restored. Check `timings.cache_n` > 0. Generation uses draft model. |
| D03 | Draft restore failure handling | hybrid, draft model | Simulate draft deserialization failure (requires test harness or corrupted cache). Verify `llamacpp_cache_restore_failures` increments. Slot state reset, request continues without cache. |
| D04 | Draft-only mismatch | hybrid, draft model | Cache entry has target state but missing draft payload. Verify atomic failure: neither target nor draft restored. Increment `n_restore_failures`. Log warning. |
| D05 | Target/draft compatibility | hybrid | Run with model A + draft A, save cache. Restart with model A + draft B. Verify different `draft_model_hash` in compatibility key = cache miss. No unsafe cross-draft restore. |

## Notes on observable assertions

Prefer stable signals:

- HTTP status codes.
- `timings.cache_n` (number of cached tokens reused).
- Prometheus cache counters (`llamacpp_cache_hits`, `llamacpp_cache_misses`, `llamacpp_cache_evictions`, `llamacpp_cache_restore_failures`).
- Log messages for cache mode, hit, miss, eviction, and restore failure.

Avoid assertions on exact generated text. Cache tests only need successful generation and cache state evidence.

## Phase 3 Observable Signals

For hybrid mode tests (H01-H18), verify:

- **Metrics counters**: Check `/metrics` for exact counts of hits, misses, evictions, restore failures with `mode="hybrid"` label.
- **Usage tracking**: Debug logs should show `use_count` and `last_used_time` updates (requires DEBUG build or server with verbose logging).
- **Non-destructive behavior**: Multiple hits to same entry should not remove it from cache. Verify via multiple identical requests succeeding with cache hits.
- **State restoration**: Second request should have `timings.cache_n` > 0 and faster `timings.prompt_ms` than first request.
- **Namespace isolation**: Different configuration fingerprints in logs (model_path_hash, template_id, lora_adapters, etc.).
- **Entry persistence**: Cache entry count should remain stable across reuses (monitor via logs or test helpers).
