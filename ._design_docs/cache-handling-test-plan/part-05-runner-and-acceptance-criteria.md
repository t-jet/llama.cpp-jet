# Cache handling test plan - Part 5: runner and acceptance criteria

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

**Configuration (via script variables):**

- `$BuildDir` - Build directory path (default: "build")
- `$Model` - Test model path (default: hardcoded Qwen2.5-VL-3B path)
- `$StartPort` - Starting port for server instances (default: 8120)

The runner:

1. Uses a pre-built `llama-server` from the specified build directory (build must be done separately).
2. Starts a fresh server for each integration test case.
3. Writes logs to `._test_output/cache-handling/<timestamp>/`.
4. Saves stdout, stderr, and process exit codes for each test.
5. Writes a comprehensive test report to `._design_docs/.test_reports/test-report-<date>.md`.
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
llamacpp_cache_hits{mode="hybrid"} 0
llamacpp_cache_misses{mode="hybrid"} 0
llamacpp_cache_evictions{mode="hybrid"} 0
llamacpp_cache_restore_failures{mode="hybrid"} 0

--- Metrics: After Operation 1 (cache miss) ---
llamacpp_cache_hits{mode="hybrid"} 0
llamacpp_cache_misses{mode="hybrid"} 1

--- Metrics: After Operation 2 (cache hit) ---
llamacpp_cache_hits{mode="hybrid"} 1
llamacpp_cache_misses{mode="hybrid"} 1
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
```

## Current test coverage

The implemented test suite covers:

- **R01-R04:** Regression prevention (legacy unchanged, default mode, opt-in, dependencies)
- **C01-C06:** Mode selection (default, legacy, hybrid, invalid, HTTP endpoints)
- **C10:** Legacy compatibility with prompt reuse
- **C11-C15:** Concurrent access safety (save, load, metrics under concurrency)
- **B01-B06:** Stage 2 boundary metadata (extraction, threading, fallbacks, edge cases)
- **H01-H29:** Phase 3 hybrid cache (non-destructive hits, LRU eviction, namespace isolation)
- **D01-D05:** Draft model paired save/restore
- **N01-N13:** Edge and negative scenarios (validation, failures, oversized entries)

See Parts 3 and 4 of this test plan for the complete test matrix.

## Future enhancements

The current runner does not yet implement:

- `-SkipBuild` switch (build must be done separately)
- `-IncludeDraft` switch (draft model tests not yet implemented)
- `-IncludeStress` switch (stress tests not yet implemented)
- Environment variable for model path override (path is hardcoded)
- Cache hit/miss counter validation from `/metrics`
- Multi-prompt cache behavior tests

These features should be added as the cache implementation matures and the test scope expands.

## Acceptance criteria

The test matrix scenarios (Part 3) define the testable acceptance criteria for the currently implemented cache scope. Check the design documents listed in [document-index.md](../document-index.md) to understand what features are available for testing.

## Concrete stress test scenarios

Run these only under `-IncludeStress` flag. Each stress test must run to completion without crashes, deadlocks, or memory leaks.

### S01: Memory pressure sustained

**Objective:** Verify stable memory usage under prolonged cache pressure.

**Configuration:**

- `--cache-mode hybrid --cache-ram 10 --parallel 2`
- 1000 unique prompts (different prefixes, varying lengths 10-100 tokens)
- 30 minutes continuous runtime

**Procedure:**

1. Generate 1000 unique prompt variations
2. Loop through prompts with 1-second delay between requests
3. Monitor memory usage every 60 seconds
4. Capture `/metrics` every 5 minutes

**Success Criteria:**

- Peak memory (working set) remains stable (< 5% growth over 30 minutes)
- Cache memory stays within `--cache-ram` limit (10 MiB)
- No process crashes or hangs
- Eviction metrics show expected churn
- No memory leaks detected (final memory ≈ initial memory after GC)

### S02: High concurrency

**Objective:** Verify thread safety under high concurrent load.

**Configuration:**

- `--cache-mode hybrid --parallel 8 --cache-ram 50`
- 50 unique prompts
- 500 total requests (mix of hits and misses)

**Procedure:**

1. Warm up cache with 50 unique prompts
2. Send 500 requests with 8 concurrent clients
3. Mix: 70% cache hits (repeat prompts), 30% misses (new prompts)
4. No delay between requests (maximum concurrency)

**Success Criteria:**

- All 500 requests complete successfully
- No deadlocks or race conditions
- No cache corruption (verify metrics accuracy)
- `llamacpp_cache_hits + llamacpp_cache_misses = 500` (no lost operations)
- Response times consistent (no pathological slowdowns)

### S03: Eviction churn

**Objective:** Verify eviction policy stability under constant pressure.

**Configuration:**

- `--cache-mode hybrid --cache-ram 1 --parallel 1`
- 10 unique prompts (each ~100 tokens, ~10 KB serialized)
- Budget allows only ~3 entries
- Rotate through all 10 prompts 100 times (1000 total requests)

**Procedure:**

1. Send prompts in sequence: P1, P2, P3, ..., P10, P1, P2, ...
2. Each prompt triggers eviction after first 3 entries
3. Monitor eviction metrics after each cycle

**Success Criteria:**

- All 1000 requests complete successfully
- Eviction count ~970 (1000 requests - 3 initial fills - ~27 cache hits from LRU)
- No cache corruption or invalid state
- Memory usage stable (cache size oscillates but doesn't grow)
- LRU policy maintains correct ordering (most recent 3 entries retained)

### S04: Long-running stability

**Objective:** Verify 6-hour production-like stability.

**Configuration:**

- `--cache-mode hybrid --cache-ram 100 --parallel 4`
- Mix of operations: 60% cache hits, 30% misses, 10% evictions
- 10-second intervals between request batches

**Procedure:**

1. Define 100 unique prompts (10-200 tokens each)
2. Loop for 6 hours:
   - Send batch of 4 requests (1 per slot)
   - 60% reuse recent prompts, 30% new prompts, 10% trigger eviction
   - Wait 10 seconds
3. Capture `/metrics` every 15 minutes
4. Monitor memory usage every 15 minutes

**Success Criteria:**

- Process runs 6 hours without crash or hang
- Memory usage stable (< 10% growth over 6 hours)
- Metrics remain accurate throughout (spot-check samples)
- No memory leaks (final memory ≈ stabilized memory after 1 hour)
- Cache hit rate ~60% as expected
- Response times consistent (no degradation over time)

## Stress test acceptance criteria

Stress test failures block production-readiness claims. However, they should not block basic implemented-scope coverage claims unless:

1. The failure reproduces in the normal test matrix (C/H/N/B/D/R series)
2. The failure indicates a fundamental design flaw (not environmental)
3. The failure severity is critical (crashes, data corruption, security)

Non-blocking stress failures (acceptable for Phase 3 sign-off):

- Performance degradation under extreme load (> 8 concurrent slots)
- Memory usage slightly above configured limits (< 10% overage)
- Eviction timing variations under heavy concurrency

Blocking stress failures (must be fixed before production):

- Crashes or hangs
- Memory leaks (> 20% growth over test duration)
- Cache corruption (incorrect metrics, lost entries, data mismatch)
- Race conditions or deadlocks
- Security issues (unauthorized access, descriptor corruption)

## Evidence to attach to the verification report

For each run, record:

- Git commit or working-tree status.
- Build directory and server binary path.
- Model path.
- Test command lines.
- Test summary with pass, fail, skip counts.
- Metrics snapshots around cache save, hit, miss, eviction, and restore failure cases.
- Known gaps with references to implementation gap documents.

Do not report focused cache-controller line coverage here. Integration evidence should describe server runs, model paths, HTTP requests, and metrics changes.
