# Cache handling test plan - Part 4: edge and negative scenarios

Source: [../cache-handling-test-plan.md](../cache-handling-test-plan.md)

## Input and mode validation

| ID | Scenario | Expected result |
| --- | --- | --- |
| N01 | `--cache-mode` value is not `legacy` or `hybrid` | Startup fails with a clear error. |
| N02 | Cache disabled with `--cache-ram 0` | No cache controller is active; requests still succeed. |
| N03 | `--cache-idle-slots` without `--kv-unified` | Server disables idle-slot caching or rejects the combination according to existing server behavior. |
| N04 | Missing model path | Startup fails before cache setup can be treated as valid. |

## HTTP surface

| ID | Scenario | Expected result |
| --- | --- | --- |
| N05 | `GET /cache/stats` | 404. This is the expected upstream target. |
| N06 | `GET /health` | Response is exactly `{"status":"ok"}`. Do not add cache fields. |
| N07 | `GET /metrics` without metrics enabled | The endpoint returns a not-supported error; cache tests that need counters must enable metrics explicitly. |

## Hybrid lookup and restore

| ID | Scenario | Expected result |
| --- | --- | --- |
| N08 | Empty saved slot | Server-level scenario should leave cache entry metrics unchanged and keep the request path usable. Direct `save_slot()` behavior belongs in unit tests. |
| N09 | Divergent partial prefix | Hybrid restore rejects the partial exact-blob match, miss metrics increase, and the request still completes. |
| N10 | Missing target payload | Integration-only debug build or fault injection makes restore fail, increments restore failures, and falls back to prompt processing. |
| N11 | Draft model configured but entry has no draft payload | Integration-only debug build or fault injection fails before applying a partial paired restore. |
| N12 | Draft restore fails after target restore | Integration-only debug build or fault injection proves the slot is cleared or otherwise safe before recomputation. |
| N13 | Repeated hit on same entry | Entry remains available and a second restore still succeeds. |
| N14 | Compatibility-key mismatch | No cross-namespace hit; request recomputes. |
| N15 | Multimodal compatibility-key mismatch | No hit across different media layout or projector identity metadata. |

## Eviction and budget pressure

| ID | Scenario | Expected result |
| --- | --- | --- |
| N16 | Cache exceeds token limit | LRU eviction runs until the limit is satisfied. |
| N17 | Cache exceeds byte limit | LRU eviction runs until the limit is satisfied. |
| N18 | Recently used entry under pressure | Older entry is evicted first. |
| N19 | Protected plus unprotected entries under pressure | Unprotected entry is evicted before protected entry. |
| N20 | All entries protected and over budget | Fallback eviction frees budget and logs the protected-pressure path. |
| N21 | Entry larger than total budget | Save either rejects it or evicts other entries and leaves stats consistent. The test should accept either behavior only if logs make it explicit. |

## Metadata behavior

| ID | Scenario | Expected result |
| --- | --- | --- |
| N22 | Chat message content appears more than once in rendered prompt | Server request succeeds and logs or integration diagnostics show degraded metadata, not a strong boundary-capture claim. |
| N23 | Chat message content cannot be found in rendered prompt | Request succeeds with degraded or minimal metadata. |
| N24 | `/completion` prompt has no chat boundaries | Minimal metadata is attached; no boundary-aware protection is assumed. |
| N25 | Malformed adopted Jinja marker template is used in an integration-only template run | Server rejects the template path or falls back safely; marked text is never sent to the model. Pure fixture parser tests are out of scope here. |

## Stability

| ID | Scenario | Expected result |
| --- | --- | --- |
| N26 | Server stops while cache entries exist | Clean shutdown without access violation or leaked child process. |
| N27 | Server restarts | In-memory cache is empty after restart. No cold persistence is expected. |
| N28 | Concurrent slots save and restore | No crash, no mixed slot prompt state, and metrics remain parseable. |
