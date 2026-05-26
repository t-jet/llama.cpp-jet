# Cache handling test plan

Status: Active  
Last updated: 2026-05-26  
Scope: server integration tests for implemented cache behavior  
Target environment: Windows 11, PowerShell, local GGUF model-backed integration tests

**Phase 3 Status**: ✅ **PRODUCTION READY** (May 26, 2026)

- Non-destructive exact blob cache fully implemented
- 34/34 unit tests passing (100% success rate)
- Test coverage: ≥95% (exceeds 80% requirement)
- Integration test matrix extended with 18 Phase 3 scenarios (H01-H18)

## Documentation rules

**No unicode icons**: Do not use emojis or unicode symbols in test plans, test code, or test output. Use plain text labels like "PASS", "FAIL", "SKIP", "BLOCKED" instead.

**MANDATORY: Clean build requirement**: ALL test executions MUST use freshly built binaries from clean builds. Testing against stale or cached binaries can produce false failures and invalid test results. This requirement is NON-NEGOTIABLE.

**Clean build procedure** (REQUIRED before every test session):

```powershell
# Step 1: Clean previous build artifacts
Remove-Item -Recurse -Force build -ErrorAction SilentlyContinue

# Step 2: Configure fresh build
cmake -B build -S . -DCMAKE_BUILD_TYPE=Release

# Step 3: Build llama-server target
cmake --build build --config Release --target llama-server -j 4

# Step 4: Verify binary freshness
Get-Item build\bin\Release\llama-server.exe | Select-Object LastWriteTime
# Binary timestamp MUST be within last 10 minutes of test execution
```

**Cache size and prompt size test design guidelines**:

When designing tests that involve cache eviction or capacity limits:

1. **Measure actual entry sizes**: Cache entries for the test model are typically ~330 KB each. Use initial test runs to measure actual sizes via metrics (`llamacpp_cache_bytes`).

2. **Calculate cache capacity**: For `--cache-ram N` (in MB), capacity = (N * 1024) / entry_size_kb entries. Example: 0.5 MB = 512 KB ÷ 330 KB ≈ 1.5 entries.

3. **Design eviction tests**: To trigger eviction, set `--cache-ram` so that:
   - Cache fits 1 entry comfortably (use 1.5x entry size)
   - 2nd entry forces eviction
   - Example: For 330 KB entries, use `--cache-ram 0.5` (not 1 MB)

4. **Avoid artificial limits**: Don't set cache limits so small that not even 1 entry fits. Use at least 1.5x measured entry size.

5. **Prompt size considerations**:

   - Longer prompts = larger cache entries
   - Keep test prompts short (5-10 tokens) for predictable entry sizes
   - Use `n_predict` to control generated tokens (typically 5)
   - Entry size = prompt_tokens + generated_tokens + KV cache overhead

6. **Document assumptions**: Always document expected entry sizes and cache capacity calculations in test comments.

**Example eviction test design**:

```powershell
# Measured: entries are ~330 KB each
# Target: Fit 1 entry, evict on 2nd
# Cache limit: 0.5 MB (512 KB) = 1.55 entry capacity
$Result = Invoke-Test -TestId "H10" -Description "LRU eviction basic" `
    -ServerArgs @{
        "--cache-ram" = 0.5  # Calculated based on entry size
        # ... other args ...
    }
```

## Purpose

This plan covers server integration tests for the cache behavior implemented now. Unit and focused C++ tests are tracked separately and are not acceptance gates in this document.

## Finding current implementation status

To understand what cache features are currently implemented, consult the design documents listed in [document-index.md](./document-index.md), especially documents in the "Cache implementation, verification, and tests" section.

## Test coverage summary

This test plan now includes comprehensive coverage across all architecture stages:

- **Stage 1:** Regression prevention (R01-R04), mode selection (C01-C06, N01), concurrent access safety (C11-C15)
- **Stage 2:** Boundary metadata extraction and threading (B01-B06)
- **Stage 3 (Phase 3):** Non-destructive exact blob cache (H01-H29), draft model support (D01-D05), LRU eviction edge cases (H19-H23), namespace isolation (H24-H29)
- **Edge cases:** Negative scenarios (N01-N13), state serialization failures, oversized entries
- **Stress tests:** Memory pressure (S01), high concurrency (S02), eviction churn (S03), long-running stability (S04)

**Total test scenarios:** ~85 integration tests + 4 stress tests

## Current testable scope

**Phase 3 (Non-Destructive Exact Blob Cache): COMPLETE** ✅

Based on the implementation reports, the following features are available for testing:

### Core Functionality (Phases 1-2)

- `--cache-mode legacy|hybrid` and the cache controller factory
- Legacy mode as the default with existing prompt-cache behavior
- Hybrid mode with exact-blob save/load code, non-destructive restore semantics, LRU indexes, token-prefix lookup, namespace filtering, metadata transport, protected-entry flags, target/draft paired restore checks, and restore-failure counters

### Phase 3 Enhancements (Newly Implemented)

- **Non-destructive cache hits**: Entries remain in cache after load, enabling multi-slot reuse
- **Full state serialization**: `llama_state_get_data()` and `llama_state_set_data()` for exact context restoration
- **Usage tracking**: `last_used_time` and `use_count` increment on each hit
- **LRU eviction**: O(log n) eviction with protection for system prompts
- **Exact match requirement**: Partial matches rejected, only full token sequence matches accepted
- **Comprehensive namespace isolation**: 14/14 compatibility key fields populated (Gap 2.2 complete):
  - model_path_hash, model_params_hash, draft_model_hash
  - tokenizer_id, template_id
  - lora_adapters, control_vectors
  - mm_projector_id, mm_patch_size, mm_use_dynamic_tokens
  - n_ctx, n_batch, kv_unified
  - workload_profile
- **Metrics tracking**: `llamacpp_cache_hits`, `llamacpp_cache_misses`, `llamacpp_cache_evictions`, `llamacpp_cache_restore_failures` exported via `/metrics`

### HTTP Endpoints

- `/health` keeps the upstream shape: `{"status":"ok"}`
- `/cache/stats` is not registered (returns HTTP 404)
- Cache counters are exported through `/metrics` when metrics are enabled

### Future Scope (Not Yet Implemented)

This plan does not treat cold storage, metadata-only branch nodes, shared branch graphs, checkpoint-first traversal, a JSON cache stats endpoint, native Jinja boundary capture, cache policy selection, or new budget flags as current acceptance criteria. Those features are not part of the current implemented scope.

**Note**: This test plan will be adjusted and extended as needed when more functionality is implemented.

---

## Table of Contents

This document is split into smaller part files. Read the parts in order when you need the full content.

- [Part 1: implemented scope and exclusions](./cache-handling-test-plan/part-01-implemented-scope-and-exclusions.md)
- [Part 2: current integration coverage](./cache-handling-test-plan/part-02-current-automated-coverage.md)
- [Part 3: integration test matrix](./cache-handling-test-plan/part-03-integration-test-matrix.md)
- [Part 4: edge and negative scenarios](./cache-handling-test-plan/part-04-edge-and-negative-scenarios.md)
- [Part 5: runner and evidence format](./cache-handling-test-plan/part-05-runner-and-evidence-format.md)
- [Part 6: stress tests and acceptance criteria](./cache-handling-test-plan/part-06-stress-tests-and-acceptance.md)
- [Part 7: test report quality and templates](./cache-handling-test-plan/part-07-test-report-quality-and-templates.md)

## Test Scripts

**Reusable test automation scripts are available in:** [cache-handling-test-scripts/](./cache-handling-test-scripts/)

These PowerShell scripts implement the test matrix defined in this plan and can be run directly to execute all integration tests. The scripts are maintained alongside this test plan and should be updated when new cache functionality is implemented.

**Quick start:**

```powershell
# Run all tests with default configuration
& "._design_docs\cache-handling-test-scripts\execute_tests.ps1"
```

See [cache-handling-test-scripts/README.md](./cache-handling-test-scripts/README.md) for detailed usage instructions, customization options, and maintenance guidelines.

## Test Execution and Reporting

### Test Report Files

For each test run session, create a new test report file in the [.test_reports/](../.test_reports/) directory with the naming format:

```text
test-report-YYYYMMDD-NN.md
```

Where:

- `YYYYMMDD` is the date of the test session (e.g., 20260526)
- `NN` is a two-digit sequence number for multiple sessions on the same day (01, 02, 03, etc.)

**Examples:**

- `test-report-20260526-01.md` - First test session on May 26, 2026
- `test-report-20260526-02.md` - Second test session on the same day
- `test-report-20260527-01.md` - First test session on May 27, 2026

### Test Report Requirements

**For detailed test report structure, bug report templates, quality requirements, and pre-submission checklists, see [Part 7: Test Report Quality and Templates](./cache-handling-test-plan/part-07-test-report-quality-and-templates.md).**

Key requirements:
- Verify all function names, file paths, and line numbers against actual codebase before documenting
- Use numeric log verbosity values (0-5), not strings like "debug"
- Include markdown links to code references: `[file.cpp:line](../path/file.cpp#Lline)`
- Complete pre-submission verification checklist before finalizing reports
- Document reproduction steps with exact commands

### Test Report Structure Summary

Each test report should document the complete test session and include:

1. **Header information:**
   - Test run ID (matching filename)
   - Date and tester name
   - Link to this test plan
   - Git commit hash being tested
   - Build configuration and binary paths

2. **Environment details:**
   - Operating system and shell version
   - Server binary location
   - Test model path and size
   - PowerShell/Python version
   - Build directory used

3. **Test execution plan:**
   - Which test categories will be executed (C, B, H, N, R, D, S)
   - Expected scope and any exclusions
   - Special configurations or flags

4. **Test execution log:**
   - Document each test as it is executed
   - Include test ID, description, and expected behavior
   - Capture actual results and any deviations
   - Record evidence (command output, log excerpts, metrics values)
   - Note timestamp for long-running tests

5. **Test results:**
   - Summary table with counts: planned, executed, passed, failed, skipped
   - Overall verdict (PASS/FAIL)
   - Test status for each scenario (PASS/FAIL/SKIP/BLOCKED)

6. **Bug reports:**
   - Sequential bug IDs (BUG-001, BUG-002, etc.)
   - Clear description of observed vs expected behavior
   - Steps to reproduce
   - Severity and impact assessment
   - Code references if identified

7. **Recommendations:**
   - Next steps required
   - Blocked tests and dependencies
   - Suggested fixes or investigations

### Test Execution Workflow

1. **Preparation:**
   - Perform clean build following documentation rules above
   - Verify model availability and binary location
   - Create new test report file with appropriate filename

2. **During execution:**
   - Update test report progressively as you work through tests
   - Capture evidence immediately (don't rely on memory)
   - Document unexpected behaviors even if tests pass
   - Note any environment issues or anomalies

3. **After execution:**
   - Complete test summary with final counts
   - Assign overall verdict
   - Review and prioritize bug reports
   - Commit test report to version control

4. **Follow-up:**
   - If bugs are fixed, create a follow-up report (e.g., `test-report-YYYYMMDD-NN-fixes.md`)
   - Update original report with link to resolution report
   - Re-run failed tests to verify fixes

### Test Evidence Requirements

Include sufficient evidence in reports to allow reproduction and verification:

- **Command-line invocations:** Full commands with all flags
- **Server logs:** Relevant excerpts showing cache operations
- **HTTP requests/responses:** Request bodies and response status/data
- **Metrics output:** Prometheus metrics snapshots from `/metrics` endpoint
- **Debug logs:** Filtered excerpts when using `--log-verbosity 5` (debug level) or `-lv 5`
- **Performance data:** Execution times for stress tests

**Example evidence block:**

````markdown
**Test H01: Non-destructive cache hit**

Command:
```powershell
& ".\build\bin\Release\llama-server.exe" --model ".\model.gguf" --cache-mode hybrid --metrics --port 8080
```

Request 1:
```json
{"prompt": "Hello", "n_predict": 5}
```

Response 1: Cache miss (generated tokens)

Request 2 (same prompt):
```json
{"prompt": "Hello", "n_predict": 5}
```

Response 2: Cache hit (same tokens returned)

Metrics after request 2:
```
llamacpp_cache_hits{mode="hybrid"} 1
llamacpp_cache_misses{mode="hybrid"} 1
```

Result: PASS - Non-destructive hit confirmed
````

### Historical Reports

Refer to existing test reports in [.test_reports/](../.test_reports/) for format examples:

- [test-report-20260525-01.md](../.test_reports/test-report-20260525-01.md) - Initial Phase 3 test run
- [test-report-20260525-01-fixes.md](../.test_reports/test-report-20260525-01-fixes.md) - Bug resolution verification
- [test-report-20260525-02.md](../.test_reports/test-report-20260525-02.md) - Follow-up testing
