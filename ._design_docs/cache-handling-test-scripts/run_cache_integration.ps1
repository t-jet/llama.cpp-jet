# Cache handling integration test runner
# Created: 2026-05-25

param(
    [string] $BuildDir = "build",
    [string] $Model = "d:\source\llama.cpp-jet\._test_models\Qwen2.5-VL-3B-Instruct-GGUF\Qwen2.5-VL-3B-Instruct-Q6_K.gguf",
    [int] $StartPort = 8120
)

$ErrorActionPreference = "Stop"

# Test configuration
$ServerPath = Join-Path $BuildDir "bin\Release\llama-server.exe"
$TestTimestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$LogDir = "._test_output\cache-handling\$TestTimestamp"

# Create log directory
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null

Write-Host "Cache Integration Test Runner"
Write-Host "=============================="
Write-Host "Server: $ServerPath"
Write-Host "Model: $Model"
Write-Host "Logs: $LogDir"
Write-Host ""

# Helper functions
function Get-FreePort {
    param([int] $StartFrom)
    $Port = $StartFrom
    while ($Port -lt 65535) {
        $Listener = $null
        try {
            $Listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, $Port)
            $Listener.Start()
            $Listener.Stop()
            return $Port
        }
        catch {
            $Port++
        }
        finally {
            if ($null -ne $Listener) { $Listener.Stop() }
        }
    }
    throw "No free port found starting from $StartFrom"
}

function Start-LlamaServer {
    param(
        [string] $TestId,
        [hashtable] $ServerArgs
    )
    
    $Port = Get-FreePort -StartFrom $StartPort
    $LogFile = Join-Path $LogDir "$TestId.log"
    $ErrorLog = Join-Path $LogDir "$TestId.err.log"
    
    # Build argument list
    $ArgList = @(
        "--model", $Model,
        "--host", "127.0.0.1",
        "--port", $Port
    )
    
    # Add custom arguments
    foreach ($key in $ServerArgs.Keys) {
        if ($ServerArgs[$key] -eq $true) {
            $ArgList += $key
        } elseif ($ServerArgs[$key] -ne $false) {
            $ArgList += $key, $ServerArgs[$key]
        }
    }
    
    Write-Host "[$TestId] Starting server on port $Port..."
    
    $Process = Start-Process -FilePath $ServerPath `
        -ArgumentList $ArgList `
        -NoNewWindow `
        -PassThru `
        -RedirectStandardOutput $LogFile `
        -RedirectStandardError $ErrorLog
    
    return @{
        Process = $Process
        Port = $Port
        LogFile = $LogFile
        ErrorLog = $ErrorLog
    }
}

function Wait-ForServer {
    param(
        [int] $Port,
        [int] $TimeoutSeconds = 30
    )
    
    $Deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $Deadline) {
        try {
            $Response = Invoke-WebRequest -Uri "http://127.0.0.1:$Port/health" -TimeoutSec 2 -ErrorAction SilentlyContinue
            if ($Response.StatusCode -eq 200) {
                return $true
            }
        }
        catch {
            # Server not ready yet
        }
        Start-Sleep -Milliseconds 500
    }
    return $false
}

function Stop-LlamaServer {
    param($ServerInfo)
    
    if ($ServerInfo.Process -and -not $ServerInfo.Process.HasExited) {
        $ServerInfo.Process.Kill($true)
        $ServerInfo.Process.WaitForExit(5000)
    }
}

function Invoke-Test {
    param(
        [string] $TestId,
        [string] $Description,
        [hashtable] $ServerArgs,
        [scriptblock] $TestScript,
        [switch] $ShouldFail
    )
    
    Write-Host ""
    Write-Host "[$TestId] $Description"
    Write-Host ("=" * 80)
    
    $Result = @{
        TestId = $TestId
        Description = $Description
        Status = "FAIL"
        Message = ""
        Duration = 0
    }
    
    $StartTime = Get-Date
    $ServerInfo = $null
    
    try {
        $ServerInfo = Start-LlamaServer -TestId $TestId -ServerArgs $ServerArgs
        
        if ($ShouldFail) {
            # Wait a bit to see if process exits
            Start-Sleep -Seconds 2
            if ($ServerInfo.Process.HasExited) {
                $ExitCode = $ServerInfo.Process.ExitCode
                $ErrorContent = Get-Content $ServerInfo.ErrorLog -Raw -ErrorAction SilentlyContinue
                $Result.Status = "PASS"
                $Result.Message = "Server failed to start as expected (exit code: $ExitCode)"
                Write-Host "  PASS: Server failed to start as expected"
                Write-Host "  Exit code: $ExitCode"
                if ($ErrorContent) {
                    Write-Host "  Error output: $($ErrorContent.Substring(0, [Math]::Min(200, $ErrorContent.Length)))"
                }
            } else {
                $Result.Message = "Server should have failed to start but is running"
                Write-Host "  FAIL: $($Result.Message)"
                Stop-LlamaServer $ServerInfo
            }
        } else {
            # Wait for server to be ready
            $Ready = Wait-ForServer -Port $ServerInfo.Port
            if (-not $Ready) {
                $ErrorContent = Get-Content $ServerInfo.ErrorLog -Raw -ErrorAction SilentlyContinue
                $Result.Message = "Server did not become ready in time. Error: $ErrorContent"
                Write-Host "  FAIL: $($Result.Message)"
            } else {
                Write-Host "  Server ready on port $($ServerInfo.Port)"
                
                # Run custom test script
                $TestResult = & $TestScript -Port $ServerInfo.Port -ServerInfo $ServerInfo
                
                if ($TestResult.Passed) {
                    $Result.Status = "PASS"
                    $Result.Message = $TestResult.Message
                    Write-Host "  PASS: $($TestResult.Message)"
                } else {
                    $Result.Message = $TestResult.Message
                    Write-Host "  FAIL: $($TestResult.Message)"
                }
            }
        }
    }
    catch {
        $Result.Message = "Exception: $($_.Exception.Message)"
        Write-Host "  FAIL: $($Result.Message)"
    }
    finally {
        if ($ServerInfo) {
            Stop-LlamaServer $ServerInfo
        }
        $Result.Duration = ((Get-Date) - $StartTime).TotalSeconds
    }
    
    return $Result
}
