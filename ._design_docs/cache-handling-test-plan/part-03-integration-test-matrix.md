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
| B02 | Boundary metadata threading | hybrid | Verify metadata flows from HTTP layer to `server_task` to `server_slot`. Check metadata survives task pipeline without corruption. |
| B03 | Missing boundary fallback | hybrid | `/completion` endpoint with minimal metadata. Verify degraded markers present in slot metadata. Server continues without boundary info. |
| B04 | Repeated message content | hybrid | Chat with same text in multiple messages. Verify distinct boundary positions for each occurrence. Boundaries must not collapse to single span. |
| B05 | Empty message handling | hybrid | Chat with empty user/assistant messages. Verify boundary extraction doesn't fail. Empty messages get zero-length or role-token-only spans. |
| B06 | Protection flag propagation | hybrid | Public chat with a system prompt may only prove degraded boundary metadata. Do not treat it as Stage 4 protected-entry evidence unless a stats-capable or code-level harness shows trusted, non-degraded protected markers reached the cache entry. |

## Phase 3: Hybrid Cache Integration Tests

| ID | Scenario | Mode | Expected result |
| --- | --- | --- | --- |
| H01 | Non-destructive hit (single reuse) | hybrid | First request creates cache entry. Second identical request hits cache. `/metrics` shows `llamacpp_cache_hits_total{mode="hybrid"}` incremented. Both requests succeed. |
| H02 | Multi-slot reuse | hybrid, `-np 2` | Send 2 identical requests in parallel. Both should hit same cache entry. `/metrics` shows `llamacpp_cache_hits` >= 1. Cache entry count remains 1. |
| H03 | Sequential reuse (3x) | hybrid | Send same prompt 3 times sequentially. `/metrics` shows `llamacpp_cache_hits` = 2 (second and third requests). Entry persists in cache. |
| H04 | Usage tracking increment | hybrid | Create cache entry, then load it twice. Verify logs show usage count incrementing (1, then 2). Timestamp updates on each hit. |
| H05 | Cache miss tracking | hybrid | Send different prompts. `/metrics` shows `llamacpp_cache_misses_total{mode="hybrid"}` increments for each unique prompt. |
| H06 | Exact match requirement | hybrid | Save entry with tokens [1,2,3,4,5]. Request with tokens [1,2,3] (prefix only). Should be **cache miss**, not partial hit. `/metrics` shows miss increment. |
| H07 | Reject divergent sequence | hybrid | Save entry with tokens [1,2,3,4,5]. Request with tokens [1,2,3,99,100]. Should be cache miss. No partial match. |
| H08 | State serialization round-trip | hybrid | First request generates 10 tokens. Second identical request should restore state and generate consistent output with same seed. Verify `timings.cache_n` > 0 for second request. |
| H09 | Empty slot rejection | hybrid | Attempt to save slot with 0 tokens (edge case in code). Should log warning and not create entry. `/metrics` shows no hit/miss change. |
| H10 | LRU eviction basic | hybrid, `--cache-ram 1` | Send enough different prompts to exceed the measured cache budget. Verify `/metrics` shows `llamacpp_cache_evictions_total{mode="hybrid"}` > 0. Oldest entry evicted. |
| H11 | LRU eviction ordering | hybrid, `--cache-ram 1` | Save entries A, B, C. Access A (updates LRU). Send entry D (triggers eviction). Verify B evicted (oldest unused), not A (recently used). |
| H12 | Namespace isolation (different models) | hybrid | Not testable in single-server run. Verify architecture enhancement allows model_path_hash in compatibility key. Check logs for namespace ID diversity. |
| H13 | Namespace isolation (different templates) | hybrid | Start server with chat template A. Verify logs show template_id in compatibility key. Documentation check: different templates produce different namespace IDs. |
| H14 | Metrics counter accuracy | hybrid | Perform sequence: miss, miss, hit, eviction. Verify `/metrics` shows exact counts: misses=2, hits=1, evictions>=1. |
| H15 | Restore failure tracking | hybrid | Simulate restore failure (requires code-level test or corrupted state). Verify `llamacpp_cache_restore_failures_total{mode="hybrid"}` increments. |
| H16 | Protected entry behavior | hybrid | Use a stats-capable integration harness or focused C++ controller test that can create trusted protected entries. Public chat with degraded rendered-text metadata is not enough to prove protected eviction behavior. |
| H17 | Multi-namespace entry count | hybrid | Run with different configurations (model A, then model B). Verify per-namespace entry counts separate in internal state (requires debug logs or test helpers). |
| H18 | Concurrent access safety | hybrid, `-np 2` | Send 2 different prompts simultaneously. Both should complete without race conditions. Cache entries correct. No crashes. |

## Extended LRU Eviction Tests (Phase 3)

| ID | Scenario | Mode | Expected result |
| --- | --- | --- | --- |
| H19 | Multiple evictions in one update | hybrid, `--cache-ram 1` | Cache with 5 entries, budget allows only 2. Add new entry triggering update. Verify exactly 4 entries evicted (5 existing - 2 that fit + 1 new = 4 evicted). Check `llamacpp_cache_evictions` increment. |
| H20 | Eviction during active restore | hybrid, `-np 2`, `--cache-ram 1` | Slot A loading entry (slow operation). Slot B triggers eviction of different entry. Verify no race conditions, both operations complete successfully. |
| H21 | Protected root exhaustion | hybrid, measured budget | Requires a stats-capable integration harness or focused C++ controller test that admits trusted protected-only entries. Verify protected entries evict oldest-first when protected bytes alone exceed the budget, with protected decision and eviction counters. |
| H22 | Protected vs unprotected ordering | hybrid, measured budget | Requires a stats-capable integration harness or focused C++ controller test that admits both trusted protected and unprotected entries. Verify unprotected entries evict first and LRU order is respected within each class. |
| H23 | Eviction metrics accuracy | hybrid, measured `--cache-ram` | Perform a measured sequence that causes known eviction pressure. Verify `llamacpp_cache_evictions_total{mode="hybrid"}` changes by the expected count. |

## Stage 4: LRU Eviction Policy with Protected Roots

Use integer MiB values for `--cache-ram`. Measure entry size first, then choose a budget and number of prompts that produce pressure without rejecting every entry.

| ID | Scenario | Mode | Expected result |
| --- | --- | --- | --- |
| H30 | Resident payload byte budget | hybrid, measured `--cache-ram` | Cache pressure is calculated from serialized target plus draft payload bytes. `llamacpp_cache_payload_evictions_total{mode="hybrid"}` increments when resident payload bytes exceed the budget. |
| H31 | Deterministic LRU ordering | hybrid, measured small budget or stats-capable harness | Choose prompts and budget so A and B are both resident before refresh. Refresh A through a successful hit, then add C. B evicts before A because A is now more recent. Public HTTP runs must prove the pre-pressure hit with `timings.cache_n > 0`; entry-state assertions may come from a stats-capable harness. Do not use sleeps to prove ordering. |
| H32 | Successful restore refreshes recency | hybrid, measured small budget or stats-capable harness | Choose prompts and budget so A and B are both resident. Restore A successfully, then add pressure and verify A survives longer than the older unrefreshed B. Public HTTP runs must prove the pre-pressure restore with `timings.cache_n > 0`; entry-state assertions may come from a stats-capable harness. |
| H33 | Failed restore does not refresh recency | hybrid with simulated or harnessed restore failure | A failed restore increments `llamacpp_cache_restore_failures_total{mode="hybrid"}` and the failed candidate remains eligible as the old entry during the next eviction. |
| H34 | Equivalent-entry refresh enforces budget | hybrid, budget reduced or pressure introduced before refresh | Refreshing an equivalent entry updates recency, does not create a duplicate, and runs budget enforcement before the operation returns. |
| H35 | Protected-root priority | hybrid, mixed protected and unprotected entries | If Stage 4 has no public trusted protected-entry creation path, use `tests/test-cache-controller.cpp` protected eviction coverage or a stats-capable integration harness. PASS requires both classes resident, unprotected entries evict before protected entries, and protected decision evidence from JSON stats, Prometheus metrics, or controller stats. If no trusted protected entry can be created, mark `BLOCKED`. |
| H36 | Protected-root fallback eviction | hybrid, protected-only over-budget working set | If Stage 4 has no public trusted protected-entry creation path, use focused C++ controller coverage or a stats-capable harness that can admit protected-only entries. PASS requires protected entries to evict oldest-first until bytes fit, with protected decision and protected eviction counters. If no trusted protected entry can be created, mark `BLOCKED`. |
| H37 | Protected admission rejection | hybrid, one trusted protected entry larger than budget | PASS requires these preconditions: the request or harness reaches cache admission, the entry has trusted non-degraded protected metadata, the serialized target plus draft payload is larger than the configured resident byte budget, and HTTP/parser validation did not reject the input first. Evidence must show no entry was admitted plus protected admission rejection diagnostics or controller stats. An HTTP 400 before admission is `BLOCKED`, not Stage 4 protected admission evidence. |
| H38 | Stage 4 metrics export | hybrid, `--metrics` | `/metrics` includes `llamacpp_cache_payload_evictions_total{mode="hybrid"}` and `llamacpp_cache_protected_root_decisions_total{mode="hybrid"}`. Existing cache metric names remain unchanged. |
| H39 | Legacy mode compatibility after Stage 4 | legacy | Legacy mode starts, serves requests, and exports legacy-labelled metrics without requiring Stage 4 hybrid decisions or protected-root behavior. |

## Stage 5: Descriptor Separation and Target/Draft Restore

Use public HTTP where it can prove model-backed behavior. Use focused controller tests or a fault-injection harness for descriptor corruption, owner/store-ref mismatch, non-hot residency, unsupported clear, and restore-applier failure phases.

| ID | Scenario | Mode | Expected result |
| --- | --- | --- | --- |
| H40 | Descriptor-backed target-only save and restore | hybrid, no draft flags | A default no-draft request saves exact-blob bytes through a `target_only` descriptor and hot payload record. A repeated request restores successfully with `timings.cache_n > 0`, increments hit metrics, and keeps `llamacpp_cache_hot_payload_descriptors{mode="hybrid"}` nonzero. |
| H41 | Descriptor validation rejects malformed metadata | hybrid with focused harness | Validation rejects unsupported descriptor version or kind, target size zero, target checksum mismatch, target size mismatch, bad `store_ref`, owner entry mismatch, non-hot residency, and missing hot payload record. Each failed restore path increments descriptor validation failures and fallback restores without reporting a hit. |
| H42 | Pair-state/runtime mismatch | hybrid with focused harness or draft fixture | A runtime without a draft context rejects a `target_and_draft` descriptor, and a runtime with a draft context rejects a `target_only` descriptor. Pairing violation and fallback counters increment. No hit or recency refresh occurs. |
| H43 | Separate draft model paired save and restore | hybrid with `--model-draft` or `--spec-draft-model` | Saving with a normal separate draft model creates one `target_and_draft` descriptor with target and draft byte sizes, checksums, and hot residency. Restore succeeds only when both sides validate and apply. `timings.cache_n > 0` proves the public restore precondition when using HTTP. `--model-draft` and `--spec-draft-model` must behave as aliases. |
| H44 | Target/draft transactional failure | hybrid with fault injection | Validation failure, target apply failure, draft apply failure after target success, commit failure, and rollback failure are whole-restore failures. The live slot returns to the exact pre-restore state when rollback succeeds. Hit, usage, and recency counters do not refresh for the failed candidate. |
| H45 | Empty-preimage rollback | hybrid with focused harness | If the target or draft side had no serialized pre-restore bytes, rollback clears that side with the whole-sequence clear path. A draft failure after target apply leaves neither side half-restored, records fallback, and records no hit. |
| H46 | Unsupported empty-side clear preflight | hybrid with fault injection | If empty-side rollback cannot clear the required sequence, restore fails before cached target bytes are applied. Failure and fallback counters increment, and live state remains untouched. |
| H47 | Paired eviction and byte accounting | hybrid, measured budget or focused harness | A `target_and_draft` descriptor accounts resident bytes as target plus draft. Eviction removes both payload sides together, never one side, and changes hot/evicted descriptor counts consistently. |
| H48 | Evicted or cold descriptor rejection | hybrid with focused harness | A descriptor with `evicted` residency or Stage 5 unsupported `cold` residency is not restorable. The controller records descriptor validation failure and fallback restore, with no hit or recency refresh. |
| H49 | Stage 5 metrics export | hybrid and legacy, `--metrics` | `/metrics` includes `llamacpp_cache_descriptor_validation_failures_total`, `llamacpp_cache_pairing_violations_total`, `llamacpp_cache_fallback_restores_total`, `llamacpp_cache_hot_payload_descriptors`, and `llamacpp_cache_evicted_payload_descriptors` for both `mode="hybrid"` and `mode="legacy"`. |
| H50 | Legacy compatibility after Stage 5 | legacy | Legacy mode starts, serves requests, preserves legacy prompt-cache behavior, keeps `/health` unchanged, and exports the Stage 5 metric names without requiring descriptor-backed hybrid behavior. |
| H51 | Stage 4 regression after Stage 5 | hybrid | Re-run H30-H39 evidence paths. Descriptor ownership must not weaken byte budget enforcement, LRU ordering, protected-root priority, failed-restore recency semantics, equivalent refresh budget enforcement, or Stage 4 metric export. |
| H52 | Public surface remains stable | both modes | Stage 5 does not add `/cache/stats`, cache fields in `/health`, cold-store CLI flags, or public JSON descriptor endpoints. |
| H53 | Target-derived MTP save and restore | hybrid with `--spec-type draft-mtp`, no draft model | When startup creates an MTP draft context from the target model, save uses `target_and_draft`, restore validates the target-derived MTP namespace, and a repeated request restores with `timings.cache_n > 0`. If this public row is in scope and the selected local model cannot create that runtime, mark `BLOCKED` with the startup evidence. |
| H54 | Separate-model MTP save and restore | hybrid with `--spec-type draft-mtp` plus `--model-draft` or `--spec-draft-model` | When startup creates an MTP draft context from the separate draft model, save uses `target_and_draft`, restore validates both draft model identity and the MTP runtime discriminator, and a repeated request restores with `timings.cache_n > 0`. If this public row is in scope and the selected model pair cannot create that runtime, mark `BLOCKED` with the startup evidence. |
| H55 | No-draft versus draft namespace isolation | hybrid, cross-run or focused harness | A target-only entry is not reused by any active draft-context runtime, and a `target_and_draft` entry is not reused by a no-draft runtime. Pairing violation or namespace miss evidence is acceptable; no hit or recency refresh may occur. |
| H56 | Normal draft alias compatibility | hybrid with separate draft model | Save with `--model-draft` and restore with `--spec-draft-model` using the same target and draft files, then reverse the order. The alias spelling must not create a different namespace by itself. |
| H57 | Normal draft versus MTP namespace isolation | hybrid, cross-run or focused harness | A normal separate draft-model entry must not restore under target-derived `draft-mtp` or separate-model `draft-mtp`. An MTP entry must not restore under normal separate draft mode. The compatibility key must include a context-type or equivalent runtime discriminator beyond `ctx_dft` presence and draft model dimensions. |
| H58 | Draft-mode legacy isolation | legacy and hybrid | Draft flags must not make legacy mode use descriptor-owned hybrid cache behavior. Existing legacy prompt-cache behavior remains unchanged, and hybrid-only descriptor counters do not become acceptance evidence for legacy cache semantics. |

## Namespace Isolation Tests (Phase 3)

| ID | Scenario | Mode | Expected result |
| --- | --- | --- | --- |
| H24 | Model path isolation | hybrid | Start server, save cache entry. Check logs for `model_path_hash` in compatibility key. Document: different model files produce different namespace IDs. |
| H25 | LoRA adapter isolation | hybrid | Start with `--lora adapter1.gguf --lora-scaled adapter2.gguf 0.5`. Verify logs show `lora_adapters` in compatibility key with both adapters. Different adapter sets = different namespaces. |
| H26 | Control vector isolation | hybrid | Start with `--control-vector vec1.gguf`. Verify compatibility key includes `control_vectors` field. Different vectors = different namespaces. |
| H27 | Multimodal configuration isolation | hybrid | Start with `--mmproj projector.gguf`. Verify logs show `mm_projector_id` in compatibility key. Different projectors = different namespaces. |
| H28 | Template isolation | hybrid | Start with custom `--chat-template`. Verify compatibility key includes `template_id` hash. Different templates = different namespaces (prevents cross-template cache hits). |
| H29 | KV mode isolation | hybrid | Compare run with `--kv-unified` vs without. Verify compatibility key includes `kv_unified` flag. Different KV modes = different namespaces. |

## Draft Runtime Mode Tests (Phase 3 and Stage 5)

| ID | Scenario | Mode | Expected result |
| --- | --- | --- | --- |
| D01 | Normal separate draft paired save | hybrid, `--model-draft <draft.gguf>` | First request saves cache entry. Verify logs show both target and draft states serialized. Entry size accounts for both contexts. |
| D02 | Normal separate draft paired restore | hybrid, draft model | Second identical request hits cache. Verify both target and draft contexts restored. Check `timings.cache_n` > 0. Generation uses draft model. |
| D03 | Draft restore failure handling | hybrid, draft model | Simulate draft deserialization failure (requires test harness or corrupted cache). Verify `llamacpp_cache_restore_failures` increments. Slot state reset, request continues without cache. |
| D04 | Draft-only mismatch | hybrid, draft model | Cache entry has target state but missing draft payload. Verify atomic failure: neither target nor draft restored. Increment `n_restore_failures`. Log warning. |
| D05 | Target/draft compatibility | hybrid | Run with model A + draft A, save cache. Restart with model A + draft B. Verify different `draft_model_hash` in compatibility key = cache miss. No unsafe cross-draft restore. |
| D06 | Target-derived MTP compatibility | hybrid, `--spec-type draft-mtp` | If the model supports target-derived MTP, verify the namespace identifies MTP separately from no-draft and normal separate draft-model runs. |
| D07 | Separate-model MTP compatibility | hybrid, `--spec-type draft-mtp --model-draft <draft.gguf>` | If the model pair supports separate-model MTP, verify the namespace includes both draft model identity and the MTP context discriminator. |
| D08 | Cross-mode reuse rejection | hybrid, cross-run or focused harness | Save in one draft runtime mode and attempt restore in each other mode. Only the same runtime mode and compatible model identity may produce a hit. |

## Notes on observable assertions

Prefer stable signals:

- HTTP status codes.
- `timings.cache_n` (number of cached tokens reused).
- Prometheus cache counters (`llamacpp_cache_hits_total`, `llamacpp_cache_misses_total`, `llamacpp_cache_evictions_total`, `llamacpp_cache_restore_failures_total`, `llamacpp_cache_payload_evictions_total`, `llamacpp_cache_protected_root_decisions_total`).
- Log messages for cache mode, hit, miss, eviction, and restore failure.

Avoid assertions on exact generated text. Cache tests only need successful generation and cache state evidence.

## Observable signals

For hybrid mode tests, verify:

- Metrics counters with `mode="hybrid"` or `mode="legacy"` labels.
- Successful restore evidence such as `timings.cache_n` greater than zero.
- Debug logs for recency, payload bytes, protected state, budget pressure, and eviction decisions.
- Non-destructive behavior through repeated identical requests that continue to hit.
- Namespace isolation through configuration fingerprints in logs.
- Entry count and byte counters that change in the expected direction around save, refresh, and eviction.

## Protected-root evidence paths

Public chat requests currently produce degraded rendered-text metadata. They must not be used by themselves to pass H35, H36, or H37 because the cache only treats non-degraded protected metadata as trusted.

Acceptable evidence sources for Stage 4 protected-root rows are:

- A stats-capable integration harness that can create trusted protected entries and expose protected, unprotected, decision, eviction, and admission counters.
- Focused C++ controller tests that use the existing debug helpers to create protected entries with known payload sizes and then verify controller stats and eviction order.
- A `BLOCKED` result that states the missing precondition: no public protected-entry creation path, no stats-capable harness, or parser/HTTP rejection before cache admission.
