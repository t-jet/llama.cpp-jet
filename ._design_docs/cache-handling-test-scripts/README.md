# Cache Handling Test Scripts

**Location:** `._design_docs/cache-handling-test-scripts/`  
**Created:** 2026-05-25  
**Last Updated:** 2026-05-26  
**Status:** Active - All phases implemented (89 tests)

## Overview

This directory contains comprehensive PowerShell test scripts for cache handling integration testing as defined in [cache-handling-test-plan.md](../cache-handling-test-plan.md). The test suite covers Stages 1-3 of the cache handling architecture with ~85 integration tests and 4 stress tests.

## Scripts

### `run_cache_integration.ps1`

Helper module providing test infrastructure functions:

**Core Functions:**

- `Get-FreePort` - Find available TCP port for server
- `Start-LlamaServer` - Start server with test configuration
- `Wait-ForServer` - Wait for server health check
- `Stop-LlamaServer` - Clean shutdown of server process
- `Invoke-Test` - Execute individual test case with logging

**Helper Functions (Added 2026-05-26):**

- `Get-LogField` - Extract specific fields from debug logs
- `Get-CacheMetrics` - Parse Prometheus metrics from /metrics endpoint
- `Invoke-ParallelRequests` - Execute concurrent requests with throttling

This module is imported by execution scripts.

### `execute_tests.ps1`

Main test execution script running all integration test cases:

**Test Categories:**

- **Mode Selection (C01-C06, C10):** Legacy/hybrid mode selection, metrics validation
- **Stage 2: Boundary Metadata (B01-B06):** Degraded mode, fallback handling, protection flags
- **Stage 3: Hybrid Cache Core (H01-H29):**
  - Basic operations (H01-H08): Save/restore, exact matching, serialization
  - LRU eviction (H10, H19-H23): Basic and extended eviction scenarios
  - Namespace isolation (H24-H29): Model path, LoRA, control vectors, multimodal, template, KV mode
- **Concurrent Access (C11-C15):** Parallel save/load, mixed operations, eviction safety
- **Regression Prevention (R03-R04):** Default mode verification, opt-in validation
- **Negative Scenarios (N01-N13):** Invalid inputs, edge cases, failure handling
- **Draft Model Tests (D01-D05):** Paired save/restore (requires draft model, currently skipped)

**Total Tests:** ~85 integration tests

### `stress_tests.ps1`

Extended-duration stress tests (run separately with explicit flags):

- **S01:** Memory pressure (30 min, 1000 unique prompts)
- **S02:** High concurrency (30 min, 8 parallel slots)
- **S03:** Eviction churn (30 min, small cache)
- **S04:** Long-running stability (6 hours, mixed workload)

**Usage:**

```powershell
# Run specific stress test
& "._design_docs\cache-handling-test-scripts\stress_tests.ps1" -IncludeS01

# Run all stress tests (WARNING: 8+ hours total)
& "._design_docs\cache-handling-test-scripts\stress_tests.ps1" -All
```

## Usage

### Quick Start

Run all integration tests with default configuration:

```powershell
cd d:\source\llama.cpp-jet
& "._design_docs\cache-handling-test-scripts\execute_tests.ps1"
```

### Custom Model Path

Override the test model location:

```powershell
$env:LLAMA_CACHE_TEST_MODEL = "path\to\your\model.gguf"
& "._design_docs\cache-handling-test-scripts\execute_tests.ps1"
```

Note: The script currently has the model path hardcoded. Edit line 5 of `run_cache_integration.ps1` to change the default.

### Custom Build Directory

If using a different build directory (e.g., `build-cuda`):

Edit the `$BuildDir` parameter in `run_cache_integration.ps1` (line 4) or pass it to the script.

## Test Output

Test results are written to:

- **Console:** Real-time test execution status with pass/fail indicators
- **Test Report:** `._design_docs\.test_reports\test-report-YYYYMMDD-HH.md`
- **Logs:** `._test_output\cache-handling\<timestamp>/`
  - Individual test logs: `<TestID>.log`
  - Error logs: `<TestID>.err.log`

## Prerequisites

### MANDATORY: Clean Build Requirement

**CRITICAL**: ALL test executions MUST begin with a clean build. This is NON-NEGOTIABLE and MUST be enforced before every test session. Testing against stale or incrementally built binaries can produce false failures, invalid results, and waste debugging time.

**Required clean build procedure:**

```powershell
# Step 1: Remove ALL build artifacts
Remove-Item -Recurse -Force build -ErrorAction SilentlyContinue

# Step 2: Configure fresh build from scratch
cmake -B build -S . -DCMAKE_BUILD_TYPE=Release

# Step 3: Build llama-server target only (faster than full build)
cmake --build build --config Release --target llama-server -j 4

# Step 4: VERIFY binary timestamp is fresh
$Binary = Get-Item build\bin\Release\llama-server.exe
$BuildAge = (Get-Date) - $Binary.LastWriteTime
if ($BuildAge.TotalMinutes -gt 10) {
    Write-Error "Binary is stale (built $($BuildAge.TotalMinutes) minutes ago). Rebuild required."
    exit 1
}
Write-Host "Binary verified fresh (built $([Math]::Round($BuildAge.TotalMinutes, 1)) minutes ago)"
```

**Why this is mandatory:**

- Incremental builds may not catch header changes
- Stale object files can cause crashes or wrong behavior
- Test failures from stale builds waste hours of investigation
- Clean build ensures all code changes are compiled

**Enforcement**: The test runner should verify binary timestamp before executing tests. If binary is older than 30 minutes from test start time, ABORT and require rebuild.

### Additional Prerequisites

1. **Test Model:** A valid GGUF model file (default: `._test_models/Qwen2.5-VL-3B-Instruct-GGUF/Qwen2.5-VL-3B-Instruct-Q6_K.gguf`)

2. **Available Ports:** Tests need free TCP ports starting from 8120 (integration) and 8200 (stress)

3. **PowerShell 5.1+:** Required for parallel job execution

### Command-Line Flag Reference

**Log Verbosity Levels** (defined in `common/arg.cpp:3374-3387`):

```powershell
--log-verbosity 0  # Generic messages only
--log-verbosity 1  # Error messages
--log-verbosity 2  # Warnings
--log-verbosity 3  # Info (default)
--log-verbosity 4  # Trace
--log-verbosity 5  # Debug (most verbose)
```

**Aliases:** `-lv N`, `--verbosity N`, `--log-verbosity N` (all equivalent)

**IMPORTANT:** Log verbosity uses **numeric values only** (0-5). String values like "debug" or "info" are NOT supported and will cause errors.

**Cache Configuration:**

```powershell
--cache-mode hybrid    # Enable hybrid cache (Phase 3)
--cache-ram N          # RAM budget in MB (converted to bytes internally: N * 1024 * 1024)
--cache-disk N         # Disk budget in MB
```

**Testing Flags:**

```powershell
--metrics              # Enable Prometheus metrics at /metrics endpoint
--temp 0               # Deterministic output (disable sampling)
--seed 42              # Fixed random seed
--ctx-size 512         # Context size for testing
```

### Finding Implementation Details

When writing bug reports or investigating issues:

**Find function definitions:**
```powershell
# Search for function name in codebase
grep_search -query "function_name" -isRegexp $false -includePattern "tools/server/**"

# Get function implementation with context
read_file -filePath "path/to/file.cpp" -startLine 1 -endLine 300
```

**Verify command-line flags:**
```powershell
# Check flag definitions and allowed values
grep_search -query "--flag-name" -isRegexp $false -includePattern "common/arg.cpp"
```

**Find metrics definitions:**
```powershell
# Search for Prometheus metric exports
grep_search -query "llamacpp_cache_" -isRegexp $false -includePattern "tools/server/server-context.cpp"
```

**Verify function calls:**
```powershell
# Find where a function is called
grep_search -query "function_name\\(" -isRegexp $true -includePattern "tools/server/**"
```

## Maintenance Guidelines

### When Cache Functionality Changes

When new cache functionality is implemented or existing behavior changes:

1. **Review Test Plan:** Check [cache-handling-test-plan.md](../cache-handling-test-plan.md) for affected test scenarios
2. **Update Test Definitions:** Modify Part 3 (integration test matrix) with new expected behaviors
3. **Update Script Implementations:** Modify `execute_tests.ps1` to reflect new behaviors
4. **Verify Coverage:** Ensure new functionality has corresponding tests
5. **Run Full Suite:** Execute all tests and verify no regressions

### Adding New Test Cases

Follow this pattern when adding new tests:

```powershell
# Test XYZ: Description
$Result = Invoke-Test -TestId "XYZ" -Description "Clear test description" `
    -ServerArgs @{
        "--cache-mode" = "hybrid"
        "--ctx-size" = 512
        "--parallel" = 2
        "--cont-batching" = $true
        "--kv-unified" = $true
        "--cache-ram" = 100
        "--temp" = 0
        "--seed" = 42
        "--metrics" = $true
        "--log-verbosity" = "DEBUG"  # Add for tests needing log inspection
    } `
    -TestScript {
        param($Port, $ServerInfo)
        
        try {
            # 1. Send request(s)
            $Body = @{
                prompt = "Test prompt"
                n_predict = 5
            } | ConvertTo-Json
            
            $Response = Invoke-WebRequest -Uri "http://127.0.0.1:$Port/completion" `
                -Method Post -ContentType "application/json" -Body $Body -TimeoutSec 60
            
            if ($Response.StatusCode -ne 200) {
                return @{ Passed = $false; Message = "Request failed" }
            }
            
            # 2. Verify observable signals (metrics, logs, response data)
            $Metrics = Get-CacheMetrics -Port $Port
            if ($Metrics.ContainsKey("hits_hybrid") -and $Metrics["hits_hybrid"] -gt 0) {
                return @{ Passed = $true; Message = "Test passed with expected signal" }
            }
            
            return @{ Passed = $false; Message = "Expected signal not found" }
        }
        catch {
            return @{ Passed = $false; Message = "Exception: $($_.Exception.Message)" }
        }
    }

Add-TestResult $Result
```

**Key Principles:**

- **Test ID Format:** Use category prefix (B, C, H, N, R, D, S) + sequential number
- **Clear Description:** Describe what is being tested, not implementation details
- **Observable Signals:** Test via metrics, logs, or response data - never rely on timing alone
- **Error Handling:** Always wrap in try/catch and return structured result
- **Deterministic:** Use `--temp 0` and `--seed 42` for reproducible results
- **Cleanup:** Helper functions handle server lifecycle automatically

### Test Organization

Tests are organized by category and added in logical sections:

1. **Mode Selection Tests (C series):** After line 48
2. **Boundary Metadata Tests (B series):** After line ~410 (after C10)
3. **Hybrid Cache Tests (H series):** After line ~771 (Phase 3 section)
4. **Concurrent Tests (C11-C15):** After H-series tests
5. **Regression Tests (R series):** After concurrent tests
6. **Negative Tests (N series):** After line ~309
7. **Draft Tests (D series):** After regression tests
8. **Stress Tests (S series):** In separate `stress_tests.ps1` file

**When adding tests:**

- Place in appropriate category section
- Use sequential ID numbers within category
- Update `Add-TestResult` call after test definition
- Add to summary/reporting logic if creating new category

### Modifying Helper Functions

Helper functions in `run_cache_integration.ps1` can be enhanced:

#### Example: Adding New Metric Parser

```powershell
function Get-DetailedMetrics {
    param([int]$Port)
    
    try {
        $Response = Invoke-WebRequest "http://127.0.0.1:$Port/metrics" -UseBasicParsing
        $Lines = $Response.Content -split "`n"
        
        $Metrics = @{
            Hits = @{}
            Misses = @{}
            Evictions = @{}
        }
        
        foreach ($Line in $Lines) {
            if ($Line -match 'llamacpp_cache_hits\{.*mode="([^"]+)".*\}\s+(\d+)') {
                $Metrics.Hits[$Matches[1]] = [int]$Matches[2]
            }
            # Add more patterns as needed
        }
        
        return $Metrics
    }
    catch {
        return @{}
    }
}
```

**Guidelines:**

- Keep functions focused and reusable
- Add error handling for all network calls
- Document parameters and return values
- Test with various server states (startup, running, shutting down)

## Enhancement Principles

### Test Quality

**GOOD:**

- Tests verify specific, observable behavior
- Clear pass/fail criteria
- Exact expected values (e.g., "hits=2", not "hits>=1")
- Independent tests (no state dependency between tests)

**AVOID:**

- Vague assertions ("cache works")
- Timing-dependent tests (use metrics/logs instead)
- Tests that depend on previous test results
- Hard-coded paths (use parameters)

### Coverage Philosophy

**Priority Order:**

1. **Critical Path:** Core cache save/restore, mode selection
2. **Edge Cases:** Boundary conditions, eviction limits, empty inputs
3. **Negative Cases:** Invalid inputs, failure handling, corruption
4. **Stress Testing:** Extended duration, high concurrency, memory pressure

**Coverage Goals:**

- Every architecture stage has tests
- Every public API endpoint tested
- Every error path has negative test
- Observable signals verified (not just "no crash")

### Test Maintenance Workflow

When updating tests after code changes:

1. **Identify Affected Tests:**

   ```powershell
   # Run tests to see failures
   & execute_tests.ps1 | Select-String "FAIL"
   ```

2. **Analyze Failures:**
   - Check test logs in `._test_output\cache-handling\<timestamp>/`
   - Review server debug logs with `--log-verbosity DEBUG`
   - Verify metrics output format hasn't changed

3. **Update Tests:**
   - Modify expected values if behavior intentionally changed
   - Add new tests if new functionality added
   - Update test plan documentation to match

4. **Verify:**
   - Run full test suite
   - Check for regressions in passing tests
   - Update test report with findings

### Performance Considerations

Tests should complete in reasonable time:

- **Integration tests:** < 5 seconds per test (target: 2-3 seconds)
- **Full suite:** < 10 minutes for all integration tests
- **Stress tests:** Separate execution, clearly documented duration

**If tests become slow:**

- Reduce `n_predict` values
- Use smaller test models
- Parallelize independent test groups
- Consider test sampling for CI (run subset, full suite nightly)

## Troubleshooting

### Common Issues

**Server won't start:**

- Check if port is in use: `Get-NetTCPConnection -LocalPort 8120`
- Verify model path exists
- Check build directory has `llama-server.exe`
- Review error log: `._test_output\cache-handling\<timestamp>/<TestID>.err.log`

**Tests timing out:**

- Increase timeout in `Invoke-WebRequest` calls
- Check server process is running: `Get-Process llama-server`
- Verify model loads successfully (check logs)
- Reduce model size or context window

**Metrics not found:**

- Verify `--metrics $true` in ServerArgs
- Check metrics endpoint manually: `http://127.0.0.1:<port>/metrics`
- Ensure hybrid mode active for hybrid metrics

**Flaky tests:**

- Add delays between requests (`Start-Sleep`)
- Use `Get-CacheMetrics` instead of raw regex parsing
- Check for race conditions in concurrent tests
- Verify test cleanup (server stopped between tests)

### Debug Mode

Run tests with verbose logging:

```powershell
$VerbosePreference = "Continue"
& execute_tests.ps1
```

Or add `--log-verbosity DEBUG` to ServerArgs for specific tests.

## Test Report Format

Test reports include:

- Execution timestamp
- Test environment details
- Individual test results (Pass/Fail/Skip)
- Duration per test
- Summary statistics
- Known issues section
- Recommendations section

Reports are generated automatically in `._design_docs\.test_reports/`.

## Future Enhancements

Planned improvements (see [IMPLEMENTATION_GUIDE.md](IMPLEMENTATION_GUIDE.md) for details):

1. **Draft Model Tests (D01-D05):** Implement when draft model available
2. **Extended Negative Tests:** Test harness for corruption scenarios
3. **CI Integration:** Automated test execution on commit
4. **Performance Baseline:** Track test execution time trends
5. **Coverage Analysis:** Code coverage reporting for test suite

## Related Documentation

- [cache-handling-test-plan.md](../cache-handling-test-plan.md) - Test scenarios and requirements
- [IMPLEMENTATION_GUIDE.md](IMPLEMENTATION_GUIDE.md) - Detailed implementation patterns
- [cache-handling-architecture.md](../cache-handling-architecture.md) - Architecture stages
- [cache-handling-test-plan/part-03-integration-test-matrix.md](../cache-handling-test-plan/part-03-integration-test-matrix.md) - Complete test matrix

---

**Maintainer Notes:**

- Keep test IDs sequential within categories
- Update this README when adding new test categories
- Document breaking changes in test plan updates
- Archive old test reports monthly

1. **Model Path:** Hardcoded in script, not easily overridable via environment variable
2. **Test N04:** Cannot test missing model path due to helper framework design
3. **Empty Results:** Test runner generates spurious empty result objects (cosmetic issue)
4. **No Parallel Execution:** Tests run sequentially to avoid port conflicts

## Maintenance Notes

- Scripts use PowerShell 5.1+ features
- Tested on Windows 11, PowerShell 7.x
- Requires `llama-server.exe` to be built before execution
- Each test starts a fresh server instance (no state leakage between tests)
- All tests complete in approximately 20-30 seconds total
