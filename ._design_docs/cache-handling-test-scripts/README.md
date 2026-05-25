# Cache Handling Test Scripts

**Location:** `._design_docs/cache-handling-test-scripts/`  
**Created:** 2026-05-25  
**Status:** Active

## Overview

This directory contains reusable PowerShell scripts for executing cache handling integration tests defined in [cache-handling-test-plan.md](../cache-handling-test-plan.md).

## Scripts

### `run_cache_integration.ps1`

Helper module providing test infrastructure functions:

- `Get-FreePort` - Find available TCP port for server
- `Start-LlamaServer` - Start server with test configuration
- `Wait-ForServer` - Wait for server health check
- `Stop-LlamaServer` - Clean shutdown of server process
- `Invoke-Test` - Execute individual test case with logging

This module is imported by the main execution script.

### `execute_tests.ps1`

Main test execution script that runs all integration test cases defined in the test plan.

## Usage

### Quick Start

Run all tests with default configuration:

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

Note: The script currently has the model path hardcoded. Edit line 5 of `execute_tests.ps1` to change the default.

### Custom Build Directory

If using a different build directory (e.g., `build-cuda`):

Edit line 4 of the script or modify the `$BuildDir` parameter default value.

## Test Output

Test results are written to:

- **Console:** Real-time test execution status
- **Test Report:** `._design_docs\.test_reports\test-report-YYYYMMDD-HH.md`
- **Logs:** `._test_output\cache-handling\<timestamp>/`
  - Individual test logs: `<TestID>.log`
  - Error logs: `<TestID>.err.log`

## Prerequisites

1. **Fresh Build:** Tests require a clean build of `llama-server.exe`

   ```powershell
   Remove-Item -Recurse -Force build -ErrorAction SilentlyContinue
   cmake -B build -S . -DCMAKE_BUILD_TYPE=Release
   cmake --build build --config Release --target llama-server -j 4
   ```

2. **Test Model:** A valid GGUF model file (default: `._test_models/Qwen2.5-VL-3B-Instruct-GGUF/Qwen2.5-VL-3B-Instruct-Q6_K.gguf`)

3. **Available Ports:** Tests need free TCP ports starting from 8120

## Updating Tests

When new cache functionality is implemented:

1. Review [cache-handling-test-plan.md](../cache-handling-test-plan.md) for new test scenarios
2. Add new test cases to `execute_tests.ps1` following the existing pattern:

   ```powershell
   $Result = Invoke-Test -TestId "NEW_ID" -Description "Test description" `
       -ServerArgs @{
           "--cache-mode" = "hybrid"
           "--ctx-size" = 512
           # ... other args
       } `
       -TestScript {
           param($Port, $ServerInfo)
           
           # Test implementation
           # Return @{ Passed = $true/$false; Message = "result message" }
       }
   
   Add-TestResult $Result
   ```

3. Update test count expectations in the test plan
4. Run tests and update the test report template

## Test Categories Covered

Current test coverage (as of 2026-05-25):

- **C01-C04:** Cache mode selection (default, legacy, hybrid, invalid)
- **C05-C06:** HTTP endpoints with/without metrics
- **C10:** Legacy mode compatibility with prompt reuse
- **N01-N04:** Edge and negative scenarios
- **N05-N07:** HTTP surface validation

See [cache-handling-test-plan.md](../cache-handling-test-plan.md) for complete test matrix.

## Known Limitations

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

## Related Documentation

- [cache-handling-test-plan.md](../cache-handling-test-plan.md) - Test plan and matrix
- [cache-handling-test-plan/](../cache-handling-test-plan/) - Test plan parts 1-5
- [.test_reports/](../.test_reports/) - Historical test execution reports
- [document-index.md](../document-index.md) - Design documentation index
