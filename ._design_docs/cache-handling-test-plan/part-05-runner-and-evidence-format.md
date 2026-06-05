# Cache handling test plan - Part 5: runner and evidence format

Source: [../cache-handling-test-plan.md](../cache-handling-test-plan.md)

## Implemented runner

**Implementation available:** The test runner described below has been implemented and is available in [../cache-handling-test-scripts/](../cache-handling-test-scripts/).

**Quick start:**

```powershell
# Run all tests with default configuration
& "._design_docs\cache-handling-test-scripts\execute_tests.ps1"
```

See [../cache-handling-test-scripts/README.md](../cache-handling-test-scripts/README.md) for usage instructions and customization options.

## Runner specification

The implemented PowerShell runner (`execute_tests.ps1`) includes these features:

**Configuration:**

- `$BuildDir` - Build directory path (default: "build")
- `$Model` - Test model path. If not set, `run_cache_integration.ps1` uses `LLAMA_CACHE_TEST_MODEL`, then the local Qwen2.5-VL default path.
- `$StartPort` - Starting port for server instances (default: 8120)

The runner:

1. Uses a pre-built `llama-server` from the specified build directory (build must be done separately).
2. Starts a fresh server for each integration test case.
3. Writes logs to `._test_output/cache-handling/<timestamp>/`.
4. Saves stdout, stderr, and process exit codes for each test.
5. Writes a report to the next available `._design_docs/.test_reports/test-report-YYYYMMDD-NN.md`.
6. Exits with non-zero code if any tests fail.

## Helper functions

The runner includes helper functions in `run_cache_integration.ps1`:

- `Get-FreePort` - Finding a free TCP port
- `Start-LlamaServer` - Starting `llama-server` with test configuration
- `Wait-ForServer` - Waiting for `/health` endpoint to become ready
- `Stop-LlamaServer` - Stopping server processes cleanly
- `Invoke-Test` - Executing individual test cases with logging and error handling
- `Add-TestResult` - Recording test results to the report file

The helper functions handle HTTP requests to `/completion`, `/health`, `/metrics`, and `/cache/stats`, capture logs even when startup fails, and ensure process cleanup in finally blocks.

The implementation follows the principle: keep the helper script boring. Cache tests are hard enough without clever shell behavior.

## Test evidence format specification

For each test run, capture the following evidence in structured format:

### 1. Environment Evidence

```text
Test ID: <test-id>
Date: <ISO-8601 timestamp>
Git Commit: <commit hash or "working-tree-dirty">
Build Directory: <absolute path>
Server Binary: <absolute path to llama-server>
Model Path: <absolute path to test model>
Model Size: <file size in bytes>
Build Type: <Release|Debug>
Compiler: <MSVC version | GCC version | Clang version>
```

### 2. Command Evidence

```text
Command: <full llama-server command line with all flags>
Working Directory: <directory where command executed>
Environment Variables: <relevant env vars if any>
```

### 3. Metrics Snapshots

Capture `/metrics` response at key points:

```text
--- Metrics: Before Test ---
llamacpp_cache_hits_total{mode="hybrid"} 0
llamacpp_cache_misses_total{mode="hybrid"} 0
llamacpp_cache_evictions_total{mode="hybrid"} 0
llamacpp_cache_restore_failures_total{mode="hybrid"} 0
llamacpp_cache_payload_evictions_total{mode="hybrid"} 0
llamacpp_cache_protected_root_decisions_total{mode="hybrid"} 0
llamacpp_cache_descriptor_validation_failures_total{mode="hybrid"} 0
llamacpp_cache_pairing_violations_total{mode="hybrid"} 0
llamacpp_cache_fallback_restores_total{mode="hybrid"} 0
llamacpp_cache_hot_payload_descriptors{mode="hybrid"} 0
llamacpp_cache_evicted_payload_descriptors{mode="hybrid"} 0

--- Metrics: After Operation 1 (cache miss) ---
llamacpp_cache_hits_total{mode="hybrid"} 0
llamacpp_cache_misses_total{mode="hybrid"} 1

--- Metrics: After Operation 2 (cache hit) ---
llamacpp_cache_hits_total{mode="hybrid"} 1
llamacpp_cache_misses_total{mode="hybrid"} 1
```

### 4. Log Excerpts

Include relevant log lines with timestamps:

```text
[2026-05-26 14:32:10] SRV_DBG cache controller created: mode=hybrid, limit_size=104857600, limit_tokens=unlimited
[2026-05-26 14:32:15] SRV_DBG hybrid cache: saved entry, namespace=abc123, tokens=42, size=1024 bytes
[2026-05-26 14:32:20] SRV_DBG hybrid cache: hit, namespace=abc123, use_count=2
```

### 5. HTTP Response Evidence

Full JSON responses for assertions:

```json
{
  "content": "Hello! How can I assist you today?",
  "timings": {
    "prompt_n": 15,
    "cache_n": 10,
    "prompt_ms": 45.2,
    "predicted_ms": 120.5
  }
}
```

### 6. Resource Usage

For budget validation tests:

```text
Peak Memory (Working Set): 256 MB
Cache Memory Used: 100 MB (within --cache-ram 100 limit)
Resident Payload Bytes: 1048576
Hot Payload Budget Bytes: 1048576
Protected Payload Bytes: 0
Unprotected Payload Bytes: 1048576
Entry Count: 3
Total Cached Tokens: 150
```

### 7. Pass/Fail Determination

```text
Expected: llamacpp_cache_hits = 1
Actual:   llamacpp_cache_hits = 1
Result:   PASS

Expected: llamacpp_cache_evictions >= 1
Actual:   llamacpp_cache_evictions = 2
Result:   PASS

Expected: llamacpp_cache_payload_evictions_total >= 1
Actual:   llamacpp_cache_payload_evictions_total = 1
Result:   PASS
```

### 8. Stage 4 evidence

For Stage 4 cases, include:

- measured entry size and how the `--cache-ram` budget was chosen
- operation order used to prove LRU recency
- whether the restore was successful or intentionally failed; a successful public restore requires `timings.cache_n > 0`
- metrics before and after equivalent-entry refresh
- protected and unprotected entry mix
- protected-root diagnostics from logs, stats-capable harness evidence, or focused C++ controller stats
- confirmation that legacy mode did not require hybrid-only Stage 4 behavior

H31 and H32 must block before recency assertions if the setup does not prove the restore precondition. Public HTTP evidence must show `cache_n > 0` for the refresh/restore being used to update recency. Because public verification probes can save new entries, the eviction-order proof may come from a stats-capable harness that exposes entry identity or ordered cache state.

H33 requires fault injection or a code-level harness that can corrupt or replace an admitted serialized payload after lookup but before restore completes. The focused controller test `hybrid failed restore does not refresh recency` is acceptable evidence when it passes. If only public HTTP is available, mark H33 `BLOCKED`; do not infer failed-restore recency from ordinary cache misses.

H35 and H36 require trusted protected entries. If public HTTP cannot create them because metadata is degraded, use focused C++ controller tests or a stats-capable harness. If neither is available in the session, mark the rows `BLOCKED` and state that no trusted protected-entry precondition was created.

H37 requires an oversized trusted protected entry to reach cache admission. The focused controller test `hybrid protected admission rejection stats` is acceptable evidence when it passes. A parser or HTTP validation rejection before `save_slot()` is not protected admission evidence and must be reported as `BLOCKED`.

### 9. Stage 5 evidence

For Stage 5 rows, include the evidence source because not every branch is reachable from public HTTP:

- Public HTTP evidence can cover normal target-only save/restore, model-backed hit evidence with `timings.cache_n > 0`, `/metrics` shape, legacy compatibility, missing `/cache/stats`, and measured eviction pressure.
- Draft-mode public HTTP evidence must name the runtime shape: no draft, normal separate draft model, target-derived `draft-mtp`, or separate-model `draft-mtp`. Include the exact startup flags and model paths. For normal separate draft mode, prove that `--model-draft` and `--spec-draft-model` are aliases. For MTP modes, include startup evidence that the selected model or model pair actually created an MTP draft context.
- Focused controller or fault-injection evidence is required for corrupted descriptors, checksum or size mismatch, owner mismatch, store-ref mismatch, evicted or cold residency, pair-state/runtime mismatch, target or draft apply failure, commit failure, rollback failure, empty-preimage rollback, and unsupported clear preflight.
- Draft-model integration evidence is required before marking target-plus-draft public restore rows as `PASS`; otherwise mark them `SKIP` if the session has no draft model or `BLOCKED` if the required fixture should have been available.
- Cross-mode isolation evidence must show that a cache entry saved in one runtime mode is not reused in a different runtime mode. If the implementation lacks a compatibility-key field for MTP versus non-MTP draft contexts, record a Developer handoff instead of weakening the expected result.

Capture these Stage 5 metric names when `/metrics` is enabled:

```text
llamacpp_cache_descriptor_validation_failures_total{mode="hybrid"}
llamacpp_cache_pairing_violations_total{mode="hybrid"}
llamacpp_cache_fallback_restores_total{mode="hybrid"}
llamacpp_cache_hot_payload_descriptors{mode="hybrid"}
llamacpp_cache_evicted_payload_descriptors{mode="hybrid"}
```

For focused controller evidence, map each `PASS` claim to the exact focused test name or source location. Acceptable focused evidence includes descriptor creation, target-plus-draft descriptor validation, pair mismatch, checksum failure, evicted descriptor rejection, paired byte accounting, transaction failure counters, and empty-preimage rollback. Do not mark a Stage 5 failure row as `PASS` from a script that only proves the server started or requests completed.

### 10. Stage 8 evidence

For Stage 8 rows, include the evidence source because most internal graph states are not reachable from public HTTP:

- Focused Stage 8 evidence can cover metadata-only retention, active-ref eviction blocking, protected-root metadata survival, safe pruning, re-materialization plans, mismatch handling, equivalent deduplication, cold cleanup ownership, and metadata admission rejection.
- Public HTTP evidence can cover model-backed Stage 4-7 regression, public surface stability, and `/metrics` output when the server starts with the requested cache mode.
- Python metric-shape evidence can cover Stage 8 Prometheus names and labels. With `LLAMA_SERVER_TEST_SKIP_MODEL_PRELOAD=1`, use it only for startup, public surface, and metric-label rows.
- Fault-injection or stats-capable harness evidence is required for cold cleanup ownership conflicts, forced metadata pressure, descriptor corruption, or canonical branch identity when focused tests do not expose the precondition.
- Do not mark re-materialization rows `PASS` from metric presence alone. Evidence must show the selected metadata-only node, validation result, restore source, and post-operation metadata or payload state.

Capture these Stage 8 metric names when `/metrics` is enabled:

```text
cache_metadata_only_retentions_total{namespace=...,reason=...}
cache_node_rematerializations_total{namespace=...,result=...}
cache_node_rematerialization_bytes_total{namespace=...}
cache_validation_mismatches_total{namespace=...,method=...}
cache_mismatch_parent_selections_total{namespace=...,source=...}
cache_equivalent_branch_deduplications_total{namespace=...,action=...}
cache_branch_pruning_total{namespace=...,result=...,reason=...}
cache_branch_pruned_metadata_bytes_total{namespace=...}
cache_cold_cleanup_total{namespace=...,result=...}
cache_branch_metadata_admission_rejections_total{namespace=...,reason=...}
```
