# Stress tests for cache handling
# Created: 2026-05-26
# These tests run for extended durations and should only be invoked explicitly

param(
    [string] $BuildDir = "build",
    [string] $Model = "._test_models\Qwen2.5-VL-3B-Instruct-GGUF\Qwen2.5-VL-3B-Instruct-Q6_K.gguf",
    [int] $StartPort = 8200,
    [switch] $IncludeS01,
    [switch] $IncludeS02,
    [switch] $IncludeS03,
    [switch] $IncludeS04,
    [switch] $All
)

# Import helper functions
. "._design_docs\cache-handling-test-scripts\run_cache_integration.ps1"

$ErrorActionPreference = "Stop"

$Global:StressResults = @()

function Add-StressResult {
    param($Result)
    $Global:StressResults += $Result
    Write-Host ""
    Write-Host "Result: $($Result.Status) - $($Result.Message)"
}

Write-Host ""
Write-Host "=========================================="
Write-Host "Cache Stress Tests - Starting"
Write-Host "=========================================="
Write-Host ""
Write-Host "WARNING: Stress tests run for extended durations"
Write-Host "S01: ~30 minutes"
Write-Host "S02: ~30 minutes"
Write-Host "S03: ~30 minutes"
Write-Host "S04: ~6 hours"
Write-Host ""

if (-not ($IncludeS01 -or $IncludeS02 -or $IncludeS03 -or $IncludeS04 -or $All)) {
    Write-Host "No stress tests selected. Use -IncludeS01, -IncludeS02, -IncludeS03, -IncludeS04, or -All"
    exit 0
}

# Test S01: Memory pressure sustained (30 minutes)
if ($IncludeS01 -or $All) {
    Write-Host ""
    Write-Host "=========================================="
    Write-Host "S01: Memory Pressure Sustained (30 min)"
    Write-Host "=========================================="
    Write-Host ""
    
    $Result = Invoke-Test -TestId "S01" -Description "Memory pressure with 1000 unique prompts over 30 minutes" `
        -ServerArgs @{
            "--cache-mode" = "hybrid"
            "--ctx-size" = 512
            "--parallel" = 2
            "--cont-batching" = $true
            "--kv-unified" = $true
            "--cache-ram" = 50
            "--temp" = 0
            "--seed" = 42
            "--metrics" = $true
        } `
        -TestScript {
            param($Port, $ServerInfo)
            
            try {
                $StartTime = Get-Date
                $Duration = New-TimeSpan -Minutes 30
                $MemoryReadings = @()
                $RequestCount = 0
                
                Write-Host "  Starting memory pressure test (30 minutes)..."
                Write-Host "  Start time: $StartTime"
                
                # Generate 1000 unique prompts
                $Prompts = 1..1000 | ForEach-Object { "Stress test prompt variation $_: $(Get-Random)" }
                
                while ((Get-Date) - $StartTime -lt $Duration) {
                    foreach ($Prompt in $Prompts) {
                        $Body = @{
                            prompt = $Prompt
                            n_predict = 5
                        } | ConvertTo-Json
                        
                        $Response = Invoke-WebRequest -Uri "http://127.0.0.1:$Port/completion" `
                            -Method Post -ContentType "application/json" -Body $Body -TimeoutSec 60 -ErrorAction SilentlyContinue
                        
                        if ($Response -and $Response.StatusCode -eq 200) {
                            $RequestCount++
                        }
                        
                        # Sample memory every minute
                        $Elapsed = (Get-Date) - $StartTime
                        if ($Elapsed.TotalSeconds % 60 -lt 2 -and $MemoryReadings.Count -lt ($Duration.TotalMinutes + 1)) {
                            $Process = Get-Process -Id $ServerInfo.Process.Id -ErrorAction SilentlyContinue
                            if ($Process) {
                                $Memory = $Process.WorkingSet64 / 1MB
                                $MemoryReadings += $Memory
                                Write-Host "  [$([Math]::Floor($Elapsed.TotalMinutes)) min] Memory: $([Math]::Round($Memory, 1)) MB, Requests: $RequestCount"
                            }
                        }
                        
                        Start-Sleep -Milliseconds 100
                        
                        # Break if duration exceeded
                        if ((Get-Date) - $StartTime -ge $Duration) {
                            break
                        }
                    }
                }
                
                # Verify memory stability (< 10% growth)
                if ($MemoryReadings.Count -ge 2) {
                    $InitialMemory = $MemoryReadings[0..2] | Measure-Object -Average | Select-Object -ExpandProperty Average
                    $FinalMemory = $MemoryReadings[-3..-1] | Measure-Object -Average | Select-Object -ExpandProperty Average
                    $Growth = ($FinalMemory - $InitialMemory) / $InitialMemory
                    
                    Write-Host ""
                    Write-Host "  Initial memory: $([Math]::Round($InitialMemory, 1)) MB"
                    Write-Host "  Final memory: $([Math]::Round($FinalMemory, 1)) MB"
                    Write-Host "  Growth: $([Math]::Round($Growth * 100, 2))%"
                    Write-Host "  Total requests: $RequestCount"
                    
                    if ($Growth -lt 0.10) {
                        return @{ Passed = $true; Message = "Memory stable over 30 min: growth=$([Math]::Round($Growth * 100, 2))%, requests=$RequestCount" }
                    }
                    return @{ Passed = $false; Message = "Memory growth excessive: $([Math]::Round($Growth * 100, 2))% (limit 10%)" }
                }
                
                return @{ Passed = $false; Message = "Insufficient memory readings collected" }
            }
            catch {
                return @{ Passed = $false; Message = "Test failed: $($_.Exception.Message)" }
            }
        }
    
    Add-StressResult $Result
}

# Test S02: High concurrency stress (30 minutes)
if ($IncludeS02 -or $All) {
    Write-Host ""
    Write-Host "=========================================="
    Write-Host "S02: High Concurrency Stress (30 min)"
    Write-Host "=========================================="
    Write-Host ""
    
    $Result = Invoke-Test -TestId "S02" -Description "8 concurrent slots under sustained load for 30 minutes" `
        -ServerArgs @{
            "--cache-mode" = "hybrid"
            "--ctx-size" = 512
            "--parallel" = 8
            "--cont-batching" = $true
            "--kv-unified" = $true
            "--cache-ram" = 100
            "--temp" = 0
            "--seed" = 42
            "--metrics" = $true
        } `
        -TestScript {
            param($Port, $ServerInfo)
            
            try {
                $StartTime = Get-Date
                $Duration = New-TimeSpan -Minutes 30
                $TotalRequests = 0
                $FailedRequests = 0
                
                Write-Host "  Starting high concurrency test (30 minutes, 8 slots)..."
                Write-Host "  Start time: $StartTime"
                
                $Prompts = 1..100 | ForEach-Object { "Concurrent prompt $_" }
                
                while ((Get-Date) - $StartTime -lt $Duration) {
                    # Send 8 parallel requests
                    $Jobs = @()
                    foreach ($i in 1..8) {
                        $Prompt = $Prompts[(Get-Random -Maximum $Prompts.Count)]
                        $Job = Start-Job -ScriptBlock {
                            param($P, $Pr)
                            try {
                                $Body = @{
                                    prompt = $Pr
                                    n_predict = 5
                                } | ConvertTo-Json
                                
                                $Response = Invoke-WebRequest -Uri "http://127.0.0.1:$P/completion" `
                                    -Method Post -ContentType "application/json" -Body $Body -TimeoutSec 60
                                
                                return @{ Success = ($Response.StatusCode -eq 200) }
                            }
                            catch {
                                return @{ Success = $false }
                            }
                        } -ArgumentList $Port, $Prompt
                        
                        $Jobs += $Job
                    }
                    
                    # Wait for completion
                    Wait-Job -Job $Jobs -Timeout 120 | Out-Null
                    $Results = $Jobs | Receive-Job -ErrorAction SilentlyContinue
                    $Jobs | Remove-Job -Force
                    
                    $TotalRequests += 8
                    $FailedRequests += ($Results | Where-Object { -not $_.Success }).Count
                    
                    $Elapsed = (Get-Date) - $StartTime
                    if ($Elapsed.TotalSeconds % 120 -lt 5) {
                        Write-Host "  [$([Math]::Floor($Elapsed.TotalMinutes)) min] Requests: $TotalRequests, Failed: $FailedRequests"
                    }
                    
                    Start-Sleep -Milliseconds 500
                }
                
                $FailureRate = $FailedRequests / $TotalRequests
                
                Write-Host ""
                Write-Host "  Total requests: $TotalRequests"
                Write-Host "  Failed requests: $FailedRequests"
                Write-Host "  Failure rate: $([Math]::Round($FailureRate * 100, 2))%"
                
                if ($FailureRate -lt 0.01) {
                    return @{ Passed = $true; Message = "High concurrency stable: failure_rate=$([Math]::Round($FailureRate * 100, 2))%, requests=$TotalRequests" }
                }
                return @{ Passed = $false; Message = "High failure rate: $([Math]::Round($FailureRate * 100, 2))% (limit 1%)" }
            }
            catch {
                return @{ Passed = $false; Message = "Test failed: $($_.Exception.Message)" }
            }
        }
    
    Add-StressResult $Result
}

# Test S03: Eviction churn stress (30 minutes)
if ($IncludeS03 -or $All) {
    Write-Host ""
    Write-Host "=========================================="
    Write-Host "S03: Eviction Churn Stress (30 min)"
    Write-Host "=========================================="
    Write-Host ""
    
    $Result = Invoke-Test -TestId "S03" -Description "1000 unique requests with small cache over 30 minutes" `
        -ServerArgs @{
            "--cache-mode" = "hybrid"
            "--ctx-size" = 512
            "--parallel" = 2
            "--cont-batching" = $true
            "--kv-unified" = $true
            "--cache-ram" = 2
            "--temp" = 0
            "--seed" = 42
            "--metrics" = $true
        } `
        -TestScript {
            param($Port, $ServerInfo)
            
            try {
                $StartTime = Get-Date
                $Duration = New-TimeSpan -Minutes 30
                $RequestCount = 0
                
                Write-Host "  Starting eviction churn test (30 minutes, cache-ram=2)..."
                Write-Host "  Start time: $StartTime"
                
                # Generate many unique prompts to force evictions
                $Prompts = 1..1000 | ForEach-Object { "Eviction churn $_: $(Get-Random)" }
                
                while ((Get-Date) - $StartTime -lt $Duration) {
                    foreach ($Prompt in $Prompts) {
                        $Body = @{
                            prompt = $Prompt
                            n_predict = 5
                        } | ConvertTo-Json
                        
                        $Response = Invoke-WebRequest -Uri "http://127.0.0.1:$Port/completion" `
                            -Method Post -ContentType "application/json" -Body $Body -TimeoutSec 60 -ErrorAction SilentlyContinue
                        
                        if ($Response -and $Response.StatusCode -eq 200) {
                            $RequestCount++
                        }
                        
                        $Elapsed = (Get-Date) - $StartTime
                        if ($Elapsed.TotalSeconds % 120 -lt 2) {
                            $Metrics = Get-CacheMetrics -Port $Port
                            $Evictions = if ($Metrics.ContainsKey("evictions_hybrid")) { $Metrics["evictions_hybrid"] } else { 0 }
                            Write-Host "  [$([Math]::Floor($Elapsed.TotalMinutes)) min] Requests: $RequestCount, Evictions: $Evictions"
                        }
                        
                        Start-Sleep -Milliseconds 100
                        
                        if ((Get-Date) - $StartTime -ge $Duration) {
                            break
                        }
                    }
                }
                
                # Check final eviction count
                $MetricsFinal = Get-CacheMetrics -Port $Port
                $FinalEvictions = if ($MetricsFinal.ContainsKey("evictions_hybrid")) { $MetricsFinal["evictions_hybrid"] } else { 0 }
                
                Write-Host ""
                Write-Host "  Total requests: $RequestCount"
                Write-Host "  Total evictions: $FinalEvictions"
                
                if ($FinalEvictions -gt 100 -and $RequestCount -gt 500) {
                    return @{ Passed = $true; Message = "Eviction churn stable: evictions=$FinalEvictions, requests=$RequestCount" }
                }
                return @{ Passed = $false; Message = "Insufficient churn: evictions=$FinalEvictions, requests=$RequestCount" }
            }
            catch {
                return @{ Passed = $false; Message = "Test failed: $($_.Exception.Message)" }
            }
        }
    
    Add-StressResult $Result
}

# Test S04: Long-running stability (6 hours)
if ($IncludeS04 -or $All) {
    Write-Host ""
    Write-Host "=========================================="
    Write-Host "S04: Long-Running Stability (6 hours)"
    Write-Host "=========================================="
    Write-Host ""
    
    $Result = Invoke-Test -TestId "S04" -Description "Mixed workload for 6 hours" `
        -ServerArgs @{
            "--cache-mode" = "hybrid"
            "--ctx-size" = 512
            "--parallel" = 4
            "--cont-batching" = $true
            "--kv-unified" = $true
            "--cache-ram" = 100
            "--temp" = 0
            "--seed" = 42
            "--metrics" = $true
        } `
        -TestScript {
            param($Port, $ServerInfo)
            
            try {
                $StartTime = Get-Date
                $Duration = New-TimeSpan -Hours 6
                $TotalRequests = 0
                $FailedRequests = 0
                $MemoryReadings = @()
                
                Write-Host "  Starting long-running stability test (6 hours)..."
                Write-Host "  Start time: $StartTime"
                Write-Host "  Expected end: $($StartTime + $Duration)"
                
                # Mix of repeated and unique prompts
                $CommonPrompts = 1..50 | ForEach-Object { "Common prompt $_" }
                $UniquePrompts = 1..200 | ForEach-Object { "Unique prompt $_: $(Get-Random)" }
                
                while ((Get-Date) - $StartTime -lt $Duration) {
                    # 70% common, 30% unique
                    $Prompt = if ((Get-Random -Maximum 10) -lt 7) {
                        $CommonPrompts[(Get-Random -Maximum $CommonPrompts.Count)]
                    } else {
                        $UniquePrompts[(Get-Random -Maximum $UniquePrompts.Count)]
                    }
                    
                    $Body = @{
                        prompt = $Prompt
                        n_predict = 5
                    } | ConvertTo-Json
                    
                    $Response = Invoke-WebRequest -Uri "http://127.0.0.1:$Port/completion" `
                        -Method Post -ContentType "application/json" -Body $Body -TimeoutSec 60 -ErrorAction SilentlyContinue
                    
                    if ($Response -and $Response.StatusCode -eq 200) {
                        $TotalRequests++
                    } else {
                        $FailedRequests++
                    }
                    
                    # Report every 30 minutes
                    $Elapsed = (Get-Date) - $StartTime
                    if ($Elapsed.TotalSeconds % 1800 -lt 5) {
                        $Process = Get-Process -Id $ServerInfo.Process.Id -ErrorAction SilentlyContinue
                        if ($Process) {
                            $Memory = $Process.WorkingSet64 / 1MB
                            $MemoryReadings += $Memory
                            $Metrics = Get-CacheMetrics -Port $Port
                            $Hits = if ($Metrics.ContainsKey("hits_hybrid")) { $Metrics["hits_hybrid"] } else { 0 }
                            $Misses = if ($Metrics.ContainsKey("misses_hybrid")) { $Metrics["misses_hybrid"] } else { 0 }
                            $Evictions = if ($Metrics.ContainsKey("evictions_hybrid")) { $Metrics["evictions_hybrid"] } else { 0 }
                            
                            Write-Host "  [$([Math]::Floor($Elapsed.TotalHours))h $([Math]::Floor($Elapsed.Minutes))m] Requests: $TotalRequests (failed: $FailedRequests), Memory: $([Math]::Round($Memory, 1)) MB, Hits: $Hits, Misses: $Misses, Evictions: $Evictions"
                        }
                    }
                    
                    Start-Sleep -Milliseconds 200
                }
                
                # Final checks
                $FailureRate = if ($TotalRequests -gt 0) { $FailedRequests / $TotalRequests } else { 1.0 }
                
                Write-Host ""
                Write-Host "  Total requests: $TotalRequests"
                Write-Host "  Failed requests: $FailedRequests"
                Write-Host "  Failure rate: $([Math]::Round($FailureRate * 100, 2))%"
                
                if ($MemoryReadings.Count -ge 2) {
                    $InitialMemory = $MemoryReadings[0]
                    $FinalMemory = $MemoryReadings[-1]
                    $Growth = ($FinalMemory - $InitialMemory) / $InitialMemory
                    Write-Host "  Memory growth: $([Math]::Round($Growth * 100, 2))%"
                    
                    if ($FailureRate -lt 0.01 -and $Growth -lt 0.15) {
                        return @{ Passed = $true; Message = "Long-running stability verified: failure_rate=$([Math]::Round($FailureRate * 100, 2))%, memory_growth=$([Math]::Round($Growth * 100, 2))%, requests=$TotalRequests" }
                    }
                }
                
                return @{ Passed = $false; Message = "Stability issues detected: failure_rate=$([Math]::Round($FailureRate * 100, 2))%" }
            }
            catch {
                return @{ Passed = $false; Message = "Test failed: $($_.Exception.Message)" }
            }
        }
    
    Add-StressResult $Result
}

# Generate summary
Write-Host ""
Write-Host "=========================================="
Write-Host "Stress Test Summary"
Write-Host "=========================================="

$PassCount = ($Global:StressResults | Where-Object { $_.Status -eq "PASS" }).Count
$FailCount = ($Global:StressResults | Where-Object { $_.Status -eq "FAIL" }).Count
$TotalCount = $Global:StressResults.Count

Write-Host "Total: $TotalCount, Passed: $PassCount, Failed: $FailCount"
Write-Host ""

foreach ($Result in $Global:StressResults) {
    Write-Host "[$($Result.TestId)] $($Result.Description): $($Result.Status)"
}

Write-Host ""
Write-Host "=========================================="
Write-Host "Tests completed: $(Get-Date)"
Write-Host "=========================================="

# Exit with error if any tests failed
if ($FailCount -gt 0) {
    exit 1
}
