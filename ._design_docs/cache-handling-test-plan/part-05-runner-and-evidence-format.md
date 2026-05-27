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
