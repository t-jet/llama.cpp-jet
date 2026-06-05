# Software Architecture: Alternate Hybrid Cache Mode for llama-server - Part 4: ADR-009: Distinguish Payload Eviction from Branch Pruning and Support Metadata-Only Branch Nodes

Source: [../cache-handling-architecture.md](../cache-handling-architecture.md)

### ADR-009: Distinguish Payload Eviction from Branch Pruning and Support Metadata-Only Branch Nodes

Status: Proposed  
Requirement support: R38a, R38b, R38c, R71a, R71b, R71c, R71d, R71e, R76a, R79a, R79b, R38a, R55a

Context:

The requirements introduce a distinction between payload eviction and branch pruning that did not exist in the original baseline. Payload eviction removes payload bytes from a node; branch pruning removes the node from the graph entirely. A node that has had its payload evicted may still be needed to preserve valid topology for retained descendants. Earlier drafts of this architecture treated payload eviction and branch pruning as a single event, which would break descendant-reachability guarantees and cold-layer cleanup safety.

Decision:

Make payload eviction and branch pruning two distinct lifecycle events with separate rules:

- Payload eviction marks a node as metadata-only by clearing its payload descriptor and removing payload bytes from hot or cold storage. The node remains in the graph.
- Branch pruning removes a node and its metadata from the graph entirely. It is subject to descendant-reachability checks, protection state, and remaining reuse value before proceeding.
- If an intermediate node is retained only as a metadata-only node, parent-child topology must remain valid for all retained descendants.
- Cold-layer cleanup triggered by pruning must verify that deleted payloads are not owned by any retained branch or descendant.
- When a metadata-only node becomes the selected restore or branching point, the implementation re-materializes it from the nearest retained payload-bearing ancestor or from the root, validates the path segment before replay, and stores the new payload only for the selected node.

Alternatives considered:

- Treat payload eviction and branch pruning as the same event. Rejected because it cannot preserve descendant reachability when an intermediate ancestor's payload is evicted, and it violates the cold-layer cleanup safety requirements.
- Keep all ancestors pinned in RAM until all descendants are also pruned. Rejected because it prevents payload bytes from being evicted independently of branch metadata and defeats the hot/cold separation model.
- Use reference counting on payload descriptors across descendants. Rejected because payload ownership must be explicit and singular; shared ownership of descriptors complicates integrity tracking and violates R71a.

Consequences:

- Branch metadata handling becomes more nuanced but remains safe and auditable.
- The graph can preserve valid topology through long chains of metadata-only ancestors without RAM overhead for payload bytes.
- Re-materialization adds a recompute cost when a metadata-only node is selected, but the cost is bounded by the distance to the nearest retained payload-bearing ancestor.
- Tests must cover both events independently and their interaction with cold-layer cleanup.

## Security Review

The hybrid mode must be reviewed against the most relevant OWASP Top 10 categories for the new functionality.

| Risk area | Architecture concern | Required mitigation |
| --- | --- | --- |
| A01 Broken Access Control | Externally influenced file names or paths could escape the cold-store root. | All cold-store paths must be derived from internal IDs under a configured root. Slot save/restore remains separately gated and disabled by default unless explicitly enabled. |
| A03 Injection | Request-driven cache markers or metadata could be used to trigger unsafe parsing or path construction. | Treat request metadata as structured data only. No shell invocation, no unchecked path concatenation, and strict schema validation on cache markers. |
| A04 Insecure Design | A fast but unsafe restore path could return invalid model state. | Compatibility validation, atomic target/draft restore, and explicit safe fallback are mandatory before any restore is applied. |
| A05 Security Misconfiguration | Cold persistence or hybrid mode could be enabled accidentally in environments that should remain RAM-only. | Keep hybrid mode and cold-store persistence opt-in via explicit flags. Require budgets and directories to be set deliberately. |
| A08 Software and Data Integrity Failures | Corrupted or stale payloads could be promoted from cold storage. | Version all descriptors, verify checksums, use atomic write/rename, and invalidate descriptors on mismatch. |
| A09 Security Logging and Monitoring Failures | Restore failures and integrity violations may be invisible without explicit telemetry. | Add structured logs and metrics for integrity failures, unsupported paths, promotions, demotions, and fallback restores. |

Security-sensitive review points before implementation completion:

- cold-store path normalization and root enforcement
- paired payload integrity and descriptor validation
- invalid-input handling for request-provided cache markers
- privilege assumptions around local filesystem persistence
- explicit rejection paths for unsupported multimodal and draft combinations

## Observability

Hybrid mode should expose metrics through the existing Prometheus `/metrics` endpoint when `--metrics` is enabled. Logs should use the existing server logging path. Do not add a cache-specific endpoint for the initial upstream target.

Hybrid mode should expose at least these metrics and diagnostics:

- exact full-state blob hits
- checkpoint-based restores
- hot-to-cold demotions
- cold-to-hot promotions
- payload evictions (distinct from branch pruning)
- branch pruning and node deletion events
- metadata-only node retentions and re-materializations
- protected-root admissions, rejections, and forced demotions
- restore failures by reason
- fallback restores by reason
- validation mismatch events and new-branch creations
- cold restore latency and bytes moved

Recommended metric names:

- `cache_exact_blob_hits_total`
- `cache_checkpoint_restores_total`
- `cache_payload_promotions_total`
- `cache_payload_demotions_total`
- `cache_payload_evictions_total`
- `cache_branch_pruning_total`
- `cache_metadata_only_retentions_total`
- `cache_node_rematerializations_total`
- `cache_validation_mismatches_total`
- `cache_protected_root_decisions_total`
- `cache_restore_failures_total`
- `cache_fallback_restores_total`

## Verification Strategy

### Unit-Level Verification

- branch matching against token spans and checksum spans
- workload-profile-aware restore ranking
- LRU and protected-root behavior under resident-byte budgets
- descriptor validation and target/draft pair integrity
- deterministic residency transitions using injected clocks and fake stores
- metadata-only node retention after payload eviction with retained descendants
- re-materialization of a metadata-only node from the nearest retained payload-bearing ancestor
- validation mismatch handling: new-branch creation from the latest validated ancestor with deterministic tie-breaking
- equivalent-branch deduplication when multiple requests converge on the same validated path
- three-part budget enforcement: preference for payload demotion before branch pruning under pressure
- cold-layer cleanup safety: pruning must not delete payloads owned by retained descendants

### Integration Verification

- legacy mode unchanged when `--cache-mode` is not `hybrid`
- non-destructive exact blob reuse across multiple slots
- prepared boundary propagation from HTTP layer into `server_context`
- protected-root behavior under hot-budget pressure
- cold offload and restore for exact blobs
- cold offload and restore for checkpoint payloads
- target/draft pairing across promotion and demotion
- checkpoint-first restore behavior for checkpoint-dependent workloads
- explicit failure for unsupported multimodal or draft combinations
- safe fallback when payloads are missing, invalid, or incompatible

### Failure-Injection Verification

- missing cold payload file
- checksum mismatch
- descriptor-version mismatch
- partial pair availability
- simulated I/O timeout or worker failure
- invalid request-provided cache markers

### Benchmark Verification

- exact full-state blob hit rate
- checkpoint-based branch hit rate
- promotion/demotion frequency and latency
- end-to-end prompt processing savings
- tail latency impact of cold promotion under concurrent slots

### Line Coverage Reporting

The repository does not define a built-in C++ line-coverage target for `llama-server`. On Windows/MSVC, use OpenCppCoverage around the focused cache tests.

Build a Debug test binary with symbols:

```powershell
cmake -S . -B build-coverage -DLLAMA_BUILD_TESTS=ON -DBUILD_SHARED_LIBS=OFF
cmake --build build-coverage --config Debug --target test-cache-controller
```

Run a broad server/test report when checking for accidental untested server code:

```powershell
D:\app\OpenCppCoverage\OpenCppCoverage.exe `
  --sources D:\source\llama.cpp-jet\tools\server `
  --sources D:\source\llama.cpp-jet\tests `
  --excluded_sources D:\source\llama.cpp-jet\build-coverage `
  --excluded_sources D:\source\llama.cpp-jet\build-phase2 `
  --export_type html:D:\source\llama.cpp-jet\build-coverage\coverage-html `
  --export_type cobertura:D:\source\llama.cpp-jet\build-coverage\coverage.xml `
  -- D:\source\llama.cpp-jet\build-coverage\bin\Debug\test-cache-controller.exe
```

Run a focused cache report for phase-gate evidence:

```powershell
D:\app\OpenCppCoverage\OpenCppCoverage.exe `
  --sources D:\source\llama.cpp-jet\tools\server\server-cache-hybrid.cpp `
  --sources D:\source\llama.cpp-jet\tools\server\server-cache-hybrid.h `
  --sources D:\source\llama.cpp-jet\tools\server\server-cache-controller.cpp `
  --sources D:\source\llama.cpp-jet\tools\server\server-cache-controller.h `
  --sources D:\source\llama.cpp-jet\tools\server\server-task.h `
  --sources D:\source\llama.cpp-jet\tests\test-cache-controller.cpp `
  --export_type html:D:\source\llama.cpp-jet\build-coverage\coverage-cache-html `
  --export_type cobertura:D:\source\llama.cpp-jet\build-coverage\coverage-cache.xml `
  -- D:\source\llama.cpp-jet\build-coverage\bin\Debug\test-cache-controller.exe
```

Record both the raw report paths and the line-rate numbers in the phase verification report. The broad report is useful as context, but the focused report is the phase-gate signal until model-backed integration tests cover more of `server_context` and the runtime restore path.

## Phased Delivery Plan

The implementation is staged into ten incremental phases. Each phase produces runnable, compilable, testable code that preserves correctness while adding new capabilities.

### Stage 1: Mode Gate and Controller Interface

**Objective:** Establish the architectural seam between legacy and hybrid modes without changing existing behavior.

**Deliverables:**

- Define `cache_mode` enum (`legacy`, `hybrid`) and add `--cache-mode` CLI flag
- Define `server_cache_controller` abstract interface with methods for lookup, restore, save, evict
- Implement `server_cache_legacy_adapter` that wraps existing `server_prompt_cache` behavior
- Implement `server_cache_hybrid_controller` as a no-op stub that returns "not implemented" errors
- Add mode dispatch in `server_context` that selects the controller based on CLI flag
- Add initial diagnostics logging for mode selection

**Exit criteria:**

- Server compiles and runs
- Legacy mode works unchanged when `--cache-mode=legacy` or flag is omitted
- Hybrid mode compiles but returns explicit "not yet implemented" diagnostics
- Mode selection is testable in isolation
- Code follows repository style and conventions

**Test coverage:** Mode dispatch logic, legacy adapter wrapper correctness

---

### Stage 2: Prepared-Prompt Boundary Metadata

**Objective:** Capture message boundaries during prompt preparation and thread them through to `server_context`.

**Deliverables:**

- Define `PreparedPromptMetadata` structure with boundary spans, protection hints, compatibility keys
- Define `BoundarySpan` structure with kind, token offsets, checksums, protection flags
- Extend HTTP prompt-preparation path to capture boundaries during chat template application
- Add metadata field to `server_task` structure
- Thread metadata from HTTP layer through task queue to `server_context`
- Add fallback diagnostics when metadata is absent
- For `/completion` endpoints, attach minimal metadata or emit degraded-behavior diagnostics

**Exit criteria:**

- Boundary metadata flows from HTTP layer to `server_context` for chat endpoints
- Metadata is available but not yet used by cache logic
- Existing behavior unchanged; metadata is purely additive
- Boundary capture is testable with fixture prompts
- Diagnostics clearly indicate when metadata is missing

**Test coverage:** Boundary capture for various chat templates, metadata propagation through task pipeline, fallback behavior

---

### Stage 3: Non-Destructive Exact Blob Cache

**Objective:** Make prompt-cache hits non-destructive and add usage tracking.

**Deliverables:**

- Modify `server_cache_hybrid_controller` to implement basic lookup and restore
- Store exact full-state blobs in a non-destructive internal cache structure
- Add usage metadata: last access timestamp, access count, hot/cold residency state
- Update usage on cache hit instead of consuming the entry
- Preserve exact blob restore semantics (full target + optional draft state)
- Add metrics: `cache_exact_blob_hits_total`, `cache_exact_blob_misses_total`
- Support multiple slots referencing the same cached blob

**Exit criteria:**

- Hybrid mode can restore exact blobs without removing them from cache
- Multiple slots can hit the same blob over time
- Usage tracking updates on each hit
- Metrics correctly report hits and misses
- Legacy mode behavior unchanged

**Test coverage:** Non-destructive hits, multi-slot reuse, usage tracking accuracy, exact restore correctness

---

