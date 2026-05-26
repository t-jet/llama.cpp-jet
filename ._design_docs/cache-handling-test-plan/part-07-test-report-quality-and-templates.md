# Cache handling test plan - Part 7: test report quality and templates

Source: [../cache-handling-test-plan.md](../cache-handling-test-plan.md)

## Test Report Quality Requirements

**CRITICAL: Verify all technical claims before documentation**

When writing test reports and bug reports, you MUST verify the following against the actual codebase:

1. **Function names** - Use `grep_search` or `semantic_search` to confirm functions exist
2. **File paths** - Use `file_search` to verify exact paths  
3. **Line numbers** - Use `read_file` to confirm code location
4. **Command-line flags** - Check `common/arg.cpp` for exact flag syntax and values
5. **Metrics names** - Verify Prometheus metric names in `server-context.cpp`

**Verification workflow:**

```powershell
# Example: Verify function exists before documenting
grep_search -query "function_name" -isRegexp $false -includePattern "tools/server/**"

# Example: Get actual line numbers
read_file -filePath "tools/server/server-cache-hybrid.cpp" -startLine 1 -endLine 300

# Example: Verify flag values
grep_search -query "--log-verbosity" -isRegexp $false -includePattern "common/arg.cpp"
```

**Never assume:**
- Function names based on typical naming patterns
- File locations without verification
- Flag syntax from partial documentation
- Numeric values without checking source

## Command-Line Flag Reference

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

## Test Report Structure Template

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
   - Code references if identified (MUST be verified against codebase)

7. **Recommendations:**
   - Next steps required
   - Blocked tests and dependencies
   - Suggested fixes or investigations

## Bug Report Template Format

Each bug report MUST include verified technical details:

**BUG-NNN: [Short Title]**

**Severity:** [CRITICAL/HIGH/MEDIUM/LOW]

**Affected Tests:** Test IDs that encountered this bug

**Description:** 
[Clear description of observed vs expected behavior]

**Suspected Root Causes:**
1. [Hypothesis with technical details]
2. [Alternative hypothesis]

**Code References:** *(ALL references must be verified against codebase)*
- [filename.cpp:line](../relative/path/to/filename.cpp#Lline) - Description of relevant code
- [another-file.cpp:line-range](../path/to/another-file.cpp#Lstart-Lend) - Description

**Evidence:**
- Metrics values: `metric_name_total{labels} value`
- Log excerpts showing issue
- Test commands that reproduce issue

**Reproduction Steps:**
```powershell
# Exact commands to reproduce
```

**Impact Assessment:**
[Describe impact on production readiness]

### Example Bug Report

**BUG-001: LRU Eviction Not Triggering**

**Severity:** CRITICAL

**Affected Tests:** H10, H19, H23

**Description:**
Cache eviction does not trigger when entries exceed `--cache-ram` limit. Metrics show `llamacpp_cache_evictions_total` remains at 0 even when cache size exceeds configured budget.

**Suspected Root Causes:**
1. Eviction trigger logic in `update()` may not be checking budget correctly
2. `update()` may not be called after cache entry addition
3. Size calculation may have unit conversion errors (MB vs bytes)
4. Metrics counter `n_evictions` may not be incrementing properly

**Code References:**
- [server-cache-hybrid.cpp:23](../tools/server/server-cache-hybrid.cpp#L23) - Check `update()` eviction trigger condition: `(limit_size > 0 && calculate_total_size() > limit_size)`
- [server-cache-hybrid.cpp:207](../tools/server/server-cache-hybrid.cpp#L207) - Review `evict_lru()` implementation using multimap index
- [server-context.cpp:898](../tools/server/server-context.cpp#L898) - Verify `cache_ctrl->update()` is called after cache save operations

**Evidence:**
```
Test H10 execution with --cache-ram 0.5 (512 KB limit):
- Entry 1 size: ~330 KB (should fit within limit)
- Entry 2 size: ~330 KB (total 660 KB, should trigger eviction)
- Metrics snapshot:
  llamacpp_cache_entries{mode="hybrid"} 2
  llamacpp_cache_evictions_total{mode="hybrid"} 0  # Expected: ≥1
  llamacpp_cache_bytes{mode="hybrid"} 660000       # Exceeds 512 KB limit
```

**Reproduction Steps:**
```powershell
cd ._design_docs\cache-handling-test-scripts
.\execute_tests.ps1 -TestFilter "H10" -Verbose
# Check metrics at http://localhost:8120/metrics
# Look for llamacpp_cache_evictions_total
```

**Impact Assessment:**
CRITICAL - Blocks production deployment. Cache will grow unbounded despite configured limits, causing out-of-memory conditions in production environments. Must be fixed before any production release.

## Test Execution Workflow

1. **Preparation:**
   - Perform clean build following documentation rules in main test plan
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
   - **Run pre-submission verification checklist (see below)**
   - Commit test report to version control

4. **Follow-up:**
   - If bugs are fixed, create a follow-up report (e.g., `test-report-YYYYMMDD-NN-fixes.md`)
   - Update original report with link to resolution report
   - Re-run failed tests to verify fixes

## Pre-Submission Verification Checklist

Before finalizing any test report, verify:

- [ ] All function names verified against codebase (using `grep_search` or `semantic_search`)
- [ ] All file paths confirmed accurate (using `file_search`)
- [ ] All line numbers checked (using `read_file`)
- [ ] All command-line flags match actual syntax in `common/arg.cpp`
- [ ] All metrics names match actual exports in `server-context.cpp`
- [ ] All code references use markdown links: `[file.cpp:line](../path/file.cpp#Lline)`
- [ ] All reproduction commands tested and work as documented
- [ ] Binary timestamp within 10 minutes of test execution confirmed
- [ ] No assumptions documented without verification
- [ ] Log verbosity flags use numeric values (0-5), not strings like "debug"

**If any item cannot be verified, add explicit disclaimer:**
> ⚠️ **Unverified claim**: Function name `xyz()` assumed but not confirmed in codebase

## Test Evidence Requirements

Include sufficient evidence in reports to allow reproduction and verification:

- **Command-line invocations:** Full commands with all flags
- **Server logs:** Relevant excerpts showing cache operations
- **HTTP requests/responses:** Request bodies and response status/data
- **Metrics output:** Prometheus metrics snapshots from `/metrics` endpoint
- **Debug logs:** Filtered excerpts when using `--log-verbosity 5` (debug level)
- **Performance data:** Execution times for stress tests

**Example evidence block:**

````markdown
**Test H01: Non-destructive cache hit**

Command:
```powershell
& ".\build\bin\Release\llama-server.exe" --model ".\model.gguf" --cache-mode hybrid --metrics --port 8080 --log-verbosity 5
```

Request 1 (cache miss):
```json
{"prompt": "Hello world", "n_predict": 5}
```

Response 1: HTTP 200
```json
{"content": "Hello world, how are", "tokens_predicted": 5}
```

Metrics after request 1:
```
llamacpp_cache_hits_total{mode="hybrid"} 0
llamacpp_cache_misses_total{mode="hybrid"} 1
```

Request 2 (cache hit - identical prompt):
```json
{"prompt": "Hello world", "n_predict": 5}
```

Metrics after request 2:
```
llamacpp_cache_hits_total{mode="hybrid"} 1
llamacpp_cache_misses_total{mode="hybrid"} 1
```

Server log excerpt (--log-verbosity 5):
```
[DEBUG] Cache lookup: found exact match for 2 tokens
[DEBUG] Loading cache entry id=abc123, size=330KB
[DEBUG] Cache hit - context restored, entry retained
```

**Result:** PASS - Non-destructive cache hit confirmed
````

## Finding Implementation Details

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
