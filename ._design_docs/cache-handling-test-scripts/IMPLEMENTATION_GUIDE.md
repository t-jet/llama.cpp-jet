# Test Script Implementation Guide

**Document:** Cache Handling Test Scripts - Implementation Guide for New Test Scenarios  
**Date:** May 26, 2026  
**Related:** [cache-handling-test-plan.md](../cache-handling-test-plan.md)

## Overview

The test plan has been expanded with ~65 new test scenarios across 9 categories. This document provides guidance for implementing these scenarios in the existing PowerShell test scripts.

## New Test Categories to Implement

### Priority 1: Critical Gaps (Must implement for production readiness)

#### 1. Stage 2: Boundary Metadata Tests (B01-B06)

**File:** `execute_tests.ps1`  
**Section:** Add new "Boundary Metadata Tests" section after mode selection tests

**Implementation approach:**

- B01-B03: Check logs/metadata for degraded flags
- B04-B05: Send specific message patterns, verify boundaries via debug logs
- B06: Send system prompt, verify protection flag in cache entry

**Example implementation:**

```powershell
# B01: Boundary extraction in degraded mode
$Result = Invoke-Test -TestId "B01" -Description "Boundary extraction in degraded mode" `
    -ServerArgs @{
        "--cache-mode" = "hybrid"
        "--ctx-size" = 512
        "--log-verbosity" = "DEBUG"
    } `
    -TestScript {
        param($Port)
        # Send chat request
        $Response = Invoke-ChatCompletion -Port $Port -Messages @(
            @{role="user"; content="Hello"}
        )
        # Check logs for boundaries_native=false
        $Logs = Get-Content "$LogPath\B01.log"
        $HasDegraded = $Logs -match "boundaries_native=false"
        return $HasDegraded
    }
```

#### 2. Draft Model Tests (D01-D05)

**Prerequisite:** Requires a draft model (small GGUF file for speculative decoding)

**Implementation approach:**

- Add `--model-draft` parameter support to `Start-LlamaServer`
- D01-D02: Test paired save/restore with draft model
- D03-D05: Test failure handling and compatibility

**Status:** Mark as SKIP if draft model not available, implement when ready

#### 3. Extended LRU Eviction Tests (H19-H23)

**File:** `execute_tests.ps1`  
**Section:** Extend existing "Phase 3 Hybrid Cache" section

**Implementation approach:**

- H19: Set `--cache-ram 1`, send 5+ prompts, verify multiple evictions
- H20: Use `-np 2` for concurrent operations
- H21: Create all protected entries, exceed budget, verify diagnostic
- H22: Mix protected/unprotected entries, verify eviction order
- H23: Sequence of add/evict, verify exact counter

### Priority 2: Important Gaps (Implement after Priority 1)

#### 4. Namespace Isolation Tests (H24-H29)

**Implementation approach:**

- Most tests verify logs contain expected compatibility key fields
- Can test in single-server run by checking debug logs
- H24: Check for `model_path_hash` in logs
- H25-H28: Start with specific config flags, check compatibility key

**Example:**

```powershell
# H25: LoRA adapter isolation
$Result = Invoke-Test -TestId "H25" -Description "LoRA adapter isolation" `
    -ServerArgs @{
        "--cache-mode" = "hybrid"
        "--lora" = "path/to/adapter.gguf"
        "--log-verbosity" = "DEBUG"
    } `
    -TestScript {
        param($Port)
        # Check logs for lora_adapters in compatibility key
        $Logs = Get-Content "$LogPath\H25.log"
        $HasLoRA = $Logs -match "lora_adapters"
        return $HasLoRA
    }
```

#### 5. Concurrent Access Tests (C11-C15)

**Implementation approach:**

- Use PowerShell jobs or parallel requests
- C11-C12: Send parallel requests, verify both succeed
- C13-C14: Coordinate timing with delays
- C15: Send batch of requests, verify metrics accurate

**Example:**

```powershell
# C12: Concurrent load operations
$Result = Invoke-Test -TestId "C12" -Description "Concurrent load operations" `
    -ServerArgs @{
        "--cache-mode" = "hybrid"
        "--parallel" = 2
    } `
    -TestScript {
        param($Port)
        # First request to populate cache
        Invoke-Completion -Port $Port -Prompt "Hello"
        
        # Two parallel identical requests (both should hit cache)
        $Job1 = Start-Job { Invoke-Completion -Port $Port -Prompt "Hello" }
        $Job2 = Start-Job { Invoke-Completion -Port $Port -Prompt "Hello" }
        
        $Result1 = Receive-Job -Job $Job1 -Wait
        $Result2 = Receive-Job -Job $Job2 -Wait
        
        # Both should succeed, metrics should show 2 hits
        $Metrics = Get-Metrics -Port $Port
        return ($Result1.success -and $Result2.success -and $Metrics.cache_hits -ge 2)
    }
```

#### 6. Regression Prevention Tests (R01-R04)

**Implementation approach:**

- R01-R02: Already covered by existing C01-C02
- R03: Verify default != hybrid (check metrics mode label)
- R04: Document test - list dependencies

### Priority 3: Enhancement (Implement for comprehensive coverage)

#### 7. Additional Negative Scenarios (N08-N13)

**Implementation approach:**

- N08: Requires test harness to simulate corruption (may need C++ test)
- N09: Send very large prompt, verify rejection
- N10: Edge case - duplicate of H09
- N11-N13: Documentation tests

#### 8. Stress Tests (S01-S04)

**File:** Create new `stress_tests.ps1` script  
**Invocation:** Via `-IncludeStress` flag

**Implementation approach:**

- Each stress test runs for extended duration (30 min - 6 hours)
- Monitor metrics and memory throughout
- Capture evidence at intervals
- Report pass/fail based on acceptance criteria

**Example structure:**

```powershell
# S01: Memory pressure sustained
function Test-S01-MemoryPressure {
    param($Port)
    
    $StartTime = Get-Date
    $Duration = New-TimeSpan -Minutes 30
    $MemoryReadings = @()
    
    # Generate 1000 unique prompts
    $Prompts = 1..1000 | ForEach-Object { "Prompt variation $_" }
    
    while ((Get-Date) - $StartTime -lt $Duration) {
        foreach ($Prompt in $Prompts) {
            Invoke-Completion -Port $Port -Prompt $Prompt
            Start-Sleep -Seconds 1
            
            # Sample memory every minute
            if ((Get-Date).Second -eq 0) {
                $Memory = (Get-Process llama-server).WorkingSet64 / 1MB
                $MemoryReadings += $Memory
            }
        }
    }
    
    # Verify memory stable (< 5% growth)
    $InitialMemory = $MemoryReadings[0]
    $FinalMemory = $MemoryReadings[-1]
    $Growth = ($FinalMemory - $InitialMemory) / $InitialMemory
    
    return $Growth -lt 0.05
}
```

## Implementation Order

### Week 1: Critical Boundary Tests

1. Implement B01-B06 (Boundary metadata)
2. Verify degraded mode markers
3. Test with existing model

### Week 2: LRU and Namespace

1. Implement H19-H23 (Extended LRU)
2. Implement H24-H29 (Namespace isolation)
3. Verify with different configurations

### Week 3: Concurrency and Regression

1. Implement C11-C15 (Concurrent access)
2. Implement R03-R04 (Regression prevention)
3. Verify thread safety

### Week 4: Draft Models (if available)

1. Obtain or create small draft model
2. Implement D01-D05 (Draft model tests)
3. Verify paired save/restore

### Week 5: Stress Tests

1. Create `stress_tests.ps1` script
2. Implement S01-S04 (Stress scenarios)
3. Run extended duration tests
4. Verify stability criteria

## Helper Function Updates Needed

### 1. Add Debug Log Parsing

```powershell
function Get-LogField {
    param(
        [string]$LogPath,
        [string]$FieldName
    )
    $Content = Get-Content $LogPath
    $Pattern = "$FieldName[=:](.+?)[\s;,]"
    if ($Content -match $Pattern) {
        return $Matches[1]
    }
    return $null
}
```

### 2. Add Metrics Helper

```powershell
function Get-CacheMetrics {
    param([int]$Port)
    
    $Response = Invoke-WebRequest "http://127.0.0.1:$Port/metrics" -UseBasicParsing
    $Lines = $Response.Content -split "`n"
    
    $Metrics = @{}
    foreach ($Line in $Lines) {
        if ($Line -match 'llamacpp_cache_(\w+)\{mode="([^"]+)"\}\s+(\d+)') {
            $MetricName = $Matches[1]
            $Mode = $Matches[2]
            $Value = [int]$Matches[3]
            $Metrics["${MetricName}_${Mode}"] = $Value
        }
    }
    return $Metrics
}
```

### 3. Add Concurrent Request Helper

```powershell
function Invoke-ParallelRequests {
    param(
        [int]$Port,
        [array]$Prompts,
        [int]$MaxParallel = 4
    )
    
    $Jobs = @()
    foreach ($Prompt in $Prompts) {
        $Job = Start-Job -ScriptBlock {
            param($P, $Pr)
            Invoke-Completion -Port $P -Prompt $Pr
        } -ArgumentList $Port, $Prompt
        
        $Jobs += $Job
        
        # Throttle to MaxParallel
        if ($Jobs.Count -ge $MaxParallel) {
            $Completed = Wait-Job -Job $Jobs -Any
            $Jobs = $Jobs | Where-Object { $_.State -ne 'Completed' }
        }
    }
    
    # Wait for remaining jobs
    Wait-Job -Job $Jobs | Out-Null
    
    # Collect results
    $Results = $Jobs | Receive-Job
    $Jobs | Remove-Job
    
    return $Results
}
```

## Test Report Updates

The test report format already supports the new test categories. Update the summary section to include:

- Regression prevention (R series)
- Boundary metadata (B series)
- Draft models (D series)
- Extended LRU (H19+)
- Namespace isolation (H24+)
- Concurrent access (C11+)
- Stress tests (S series)

## Notes

- **Draft models:** D-series tests require a draft model. Mark as SKIP if unavailable.
- **Stress tests:** S-series tests take hours to run. Only run with explicit `-IncludeStress` flag.
- **Debug logging:** Many new tests require `--log-verbosity DEBUG` to verify internal state.
- **Metrics validation:** All H-series and C-series tests should verify metrics counters.

## Acceptance Criteria

Tests are considered complete when:

1. All Priority 1 tests implemented and passing
2. All Priority 2 tests implemented and passing
3. Stress tests (S01-S04) run successfully
4. Test coverage report shows ~85 integration tests executed
5. No regressions in existing tests
6. All tests documented in test report

## Current Status

- **Existing tests:** C01-C06, C10, H01-H18, N01-N07 (implemented and passing)
- **New tests:** R01-R04, B01-B06, H19-H29, D01-D05, C11-C15, N08-N13, S01-S04 (defined, not yet implemented)
- **Total gap:** ~65 tests to implement

## Estimated Implementation Effort

- Priority 1 (B, H19-23): 2-3 days
- Priority 2 (H24-29, C11-15, R): 2-3 days
- Priority 3 (N08-13, D, S): 3-5 days
- **Total:** 7-11 days for full implementation
