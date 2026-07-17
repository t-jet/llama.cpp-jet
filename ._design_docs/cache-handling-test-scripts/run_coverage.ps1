#requires -Version 5
# run_coverage.ps1
# Hybrid-cache line coverage via OpenCppCoverage.
#
# Runs the current focused cache tests and an HTTP probe under individual coverage
# sessions, merges the binary .cov files into a single Cobertura XML, and
# reports union line coverage for the hybrid-mode denominator.
#
# The hybrid-mode denominator is the set of hybrid cache implementation
# sources and the focused test files. server-context.cpp and server-context.h
# are excluded because they belong to the general server dispatcher, not the
# hybrid cache paths.
#
# Usage (run from repo root or any directory):
#   .\._design_docs\cache-handling-test-scripts\run_coverage.ps1 `
#       [-BuildDir <path>]    # release bin parent, default .\build
#       [-SourceRoot <path>]  # repo root, default auto-detected from this file
#       [-OutDir <path>]      # output directory for .cov and XML files
#       [-ModelPath <gguf>]   # model used for the HTTP probe
#       [-OcPath <exe>]       # OpenCppCoverage.exe path
#       [-Port <int>]         # HTTP probe server port, default 8144
#       [-SkipServerProbe]    # skip the llama-server HTTP probe
#
# Requires:
#   OpenCppCoverage 0.9.9.0+ from https://github.com/OpenCppCoverage/OpenCppCoverage
#   A Release build of the focused test targets and llama-server.
#   A GGUF model at $ModelPath for the HTTP probe (or set LLAMA_CACHE_TEST_MODEL).
#
# Evidence classes (T114 / T115):
#   Line coverage, OpenCppCoverage Cobertura XML (branch-rate is 0 because
#   OpenCppCoverage does not produce branch coverage). LLVM source-based
#   coverage is blocked on this MSVC + clang-cl host because lld-link does
#   not accept -fprofile-instr-generate as a linker flag and the profile
#   runtime library is unavailable.

param(
    [string] $BuildDir       = '',
    [string] $SourceRoot     = '',
    [string] $Config         = 'Release',
    [string] $OutDir         = '',
    [string] $ModelPath      = '',
    [string] $OcPath         = 'D:\app\OpenCppCoverage\OpenCppCoverage.exe',
    [int]    $Port           = 8144,
    [switch] $SkipServerProbe,
    [switch] $AllowIncompleteStage39Coverage,
    [switch] $CoverageValidationSelfTest
)

$ErrorActionPreference = 'Stop'

function Get-AbsolutePath {
    param(
        [Parameter(Mandatory = $true)][string] $Path,
        [string] $BasePath = (Get-Location).Path
    )
    if ([string]::IsNullOrWhiteSpace($Path)) {
        throw 'Path value is empty.'
    }
    $expanded = [Environment]::ExpandEnvironmentVariables($Path)
    if ([System.IO.Path]::IsPathRooted($expanded)) {
        return [System.IO.Path]::GetFullPath($expanded)
    }
    return [System.IO.Path]::GetFullPath((Join-Path $BasePath $expanded))
}

function Resolve-ExistingPath {
    param(
        [Parameter(Mandatory = $true)][string] $Path,
        [Parameter(Mandatory = $true)][string] $Name,
        [ValidateSet('Container', 'Leaf')][string] $PathType
    )
    $absPath = Get-AbsolutePath -Path $Path
    if (-not (Test-Path -LiteralPath $absPath -PathType $PathType)) {
        throw "$Name not found or not a $PathType`: $absPath"
    }
    return (Resolve-Path -LiteralPath $absPath).Path
}

function Resolve-OutputDirectory {
    param([Parameter(Mandatory = $true)][string] $Path)
    $absPath = Get-AbsolutePath -Path $Path
    if (-not (Test-Path -LiteralPath $absPath)) {
        New-Item -ItemType Directory -Force -Path $absPath | Out-Null
    }
    if (-not (Test-Path -LiteralPath $absPath -PathType Container)) {
        throw "OutDir exists but is not a directory: $absPath"
    }
    return (Resolve-Path -LiteralPath $absPath).Path
}

function Assert-DebugSymbolsAvailable {
    param([Parameter(Mandatory = $true)][string] $ExePath)
    $pdbPath = [System.IO.Path]::ChangeExtension($ExePath, '.pdb')
    if (-not (Test-Path -LiteralPath $pdbPath -PathType Leaf)) {
        throw "Required debug symbols not found for OpenCppCoverage: $pdbPath. Rebuild the coverage target with MSVC /Zi and linker /DEBUG:FULL before running coverage."
    }
}

function Assert-CoberturaDenominator {
    param(
        [Parameter(Mandatory = $true)][xml] $CoverageXml,
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][object[]] $Rows,
        [Parameter(Mandatory = $true)][int] $TotalValid
    )
    $xmlValid = [int] $CoverageXml.coverage.'lines-valid'
    $packages = $CoverageXml.SelectNodes('//package')
    if ($xmlValid -le 0) {
        throw "Merged Cobertura XML has zero denominator: lines-valid=$xmlValid. OpenCppCoverage output is not valid coverage evidence."
    }
    if ($null -eq $packages -or $packages.Count -eq 0) {
        throw 'Merged Cobertura XML has no packages. OpenCppCoverage output is not valid coverage evidence.'
    }
    if ($TotalValid -le 0) {
        throw "No approved denominator rows were found in merged Cobertura XML. Matched rows=$($Rows.Count), valid lines=$TotalValid."
    }
}

function Invoke-CoverageValidationSelfTest {
    $zeroXml = [xml] '<coverage line-rate="1" lines-covered="0" lines-valid="0"><sources/><packages/></coverage>'
    $missingPackageXml = [xml] '<coverage line-rate="1" lines-covered="1" lines-valid="1"><sources/><packages/></coverage>'
    $missingRowsXml = [xml] '<coverage line-rate="1" lines-covered="1" lines-valid="1"><sources/><packages><package name="p"/></packages></coverage>'
    $validXml = [xml] '<coverage line-rate="1" lines-covered="1" lines-valid="1"><sources/><packages><package name="p"/></packages></coverage>'
    $validRows = @([pscustomobject]@{ File = 'test.cpp'; Valid = 1; Covered = 1; Rate = 1 })

    $cases = @(
        [pscustomobject]@{ Name = 'zero-denominator'; Xml = $zeroXml; Rows = @(); Total = 0; ShouldThrow = $true },
        [pscustomobject]@{ Name = 'missing-packages'; Xml = $missingPackageXml; Rows = $validRows; Total = 1; ShouldThrow = $true },
        [pscustomobject]@{ Name = 'missing-denominator-rows'; Xml = $missingRowsXml; Rows = @(); Total = 0; ShouldThrow = $true },
        [pscustomobject]@{ Name = 'valid-denominator'; Xml = $validXml; Rows = $validRows; Total = 1; ShouldThrow = $false }
    )

    foreach ($case in $cases) {
        $threw = $false
        try {
            Assert-CoberturaDenominator -CoverageXml $case.Xml -Rows $case.Rows -TotalValid $case.Total
        } catch {
            $threw = $true
            if (-not $case.ShouldThrow) {
                throw "Coverage validation self-test '$($case.Name)' failed unexpectedly: $($_.Exception.Message)"
            }
            Write-Host "PASS negative: $($case.Name) -> $($_.Exception.Message)"
        }
        if ($case.ShouldThrow -and -not $threw) {
            throw "Coverage validation self-test '$($case.Name)' did not fail closed."
        }
        if (-not $case.ShouldThrow) {
            Write-Host "PASS positive: $($case.Name)"
        }
    }
    Write-Host 'Coverage validation self-test PASS'
}

if ($CoverageValidationSelfTest) {
    Invoke-CoverageValidationSelfTest
    exit 0
}

if ($SkipServerProbe -and -not $AllowIncompleteStage39Coverage) {
    throw '-SkipServerProbe requires -AllowIncompleteStage39Coverage; incomplete runs cannot claim Stage 39 coverage.'
}

# Auto-detect repo root from this script's location.
if (-not $SourceRoot) {
    $SourceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
}
if (-not $BuildDir) {
    $BuildDir = Join-Path $SourceRoot 'build'
}
if (-not $OutDir) {
    $OutDir = Join-Path $SourceRoot '._design_docs\.test_reports\coverage-run'
}
if (-not $ModelPath) {
    $ModelPath = $env:LLAMA_CACHE_TEST_MODEL
}
if (-not $ModelPath) {
    $ModelPath = Join-Path $SourceRoot '._test_models\Qwen3-0.6B-GGUF\Qwen3-0.6B-Q8_0.gguf'
}

$SourceRoot = Resolve-ExistingPath -Path $SourceRoot -Name 'SourceRoot' -PathType Container
$BuildDir   = Resolve-ExistingPath -Path $BuildDir -Name 'BuildDir' -PathType Container
$OutDir     = Resolve-OutputDirectory -Path $OutDir
$OcPath     = Resolve-ExistingPath -Path $OcPath -Name 'OcPath' -PathType Leaf
if (-not $SkipServerProbe) {
    $ModelPath = Resolve-ExistingPath -Path $ModelPath -Name 'ModelPath' -PathType Leaf
}

$binDir  = Resolve-ExistingPath -Path (Join-Path $BuildDir "bin\$Config") -Name 'Build output directory' -PathType Container
$covDir  = Join-Path $OutDir 'cov-binary'
$htmlDir = Join-Path $OutDir 'html'

foreach ($d in @($OutDir, $covDir, $htmlDir)) {
    if (-not (Test-Path $d)) { New-Item -ItemType Directory -Force -Path $d | Out-Null }
}

# Hybrid-mode denominator: implementation files and focused test files.
# server-context.cpp and server-context.h are excluded.
$srcPatterns = @(
    (Join-Path $SourceRoot 'tools\server\server-cache-hybrid.cpp'),
    (Join-Path $SourceRoot 'tools\server\server-cache-hybrid.h'),
    (Join-Path $SourceRoot 'tools\server\server-cache-store-cold.cpp'),
    (Join-Path $SourceRoot 'tools\server\server-cache-store-cold.h'),
    (Join-Path $SourceRoot 'tools\server\server-cache-controller.cpp'),
    (Join-Path $SourceRoot 'tools\server\server-cache-controller.h'),
    (Join-Path $SourceRoot 'tools\server\server-cache-graph.cpp'),
    (Join-Path $SourceRoot 'tools\server\server-cache-graph.h'),
    (Join-Path $SourceRoot 'tools\server\server-cache-io-worker.cpp'),
    (Join-Path $SourceRoot 'tools\server\server-cache-policy-lru.cpp'),
    (Join-Path $SourceRoot 'tools\server\server-cache-legacy.h'),
    (Join-Path $SourceRoot 'tests\test-cache-controller.cpp'),
    (Join-Path $SourceRoot 'tests\test-step1-state-machine.cpp'),
    (Join-Path $SourceRoot 'tests\test-step2-cold-store.cpp'),
    (Join-Path $SourceRoot 'tests\test-step3-4-cold-store-write-read.cpp'),
    (Join-Path $SourceRoot 'tests\test-step9-startup-validation.cpp'),
    (Join-Path $SourceRoot 'tests\test-step10-metrics.cpp'),
    (Join-Path $SourceRoot 'tests\test-step6-demotion-protocol.cpp'),
    (Join-Path $SourceRoot 'tests\test-stage10-policy-lru.cpp'),
    (Join-Path $SourceRoot 'tests\test-stage10-cold-store-hardening.cpp'),
    (Join-Path $SourceRoot 'tests\test-step12-branch-graph.cpp'),
    (Join-Path $SourceRoot 'tests\test-step13-stage8.cpp')
)

$excludePatterns = @(
    'D:\app\',
    (Join-Path $SourceRoot 'build\'),
    (Join-Path $SourceRoot 'ggml\'),
    (Join-Path $SourceRoot 'common\'),
    (Join-Path $SourceRoot 'src\'),
    (Join-Path $SourceRoot 'vendor\'),
    (Join-Path $SourceRoot 'tools\mtmd\')
)

function Build-OcArgs {
    param([string[]] $Sources, [string[]] $Excludes)
    $ocArgList = @('--quiet', '--optimized_build')
    foreach ($s in $Sources)  { $ocArgList += @('--sources', $s) }
    foreach ($e in $Excludes) { $ocArgList += @('--excluded_sources', $e) }
    return $ocArgList
}

# Binary .cov files to merge.
$covFiles = [System.Collections.Generic.List[string]]::new()

# --- Phase 1: Focused tests -------------------------------------------------
$focusedTests = @(
    'test-cache-controller',
    'test-step1-state-machine',
    'test-step2-cold-store',
    'test-step3-4-cold-store-write-read',
    'test-step9-startup-validation',
    'test-step10-metrics',
    'test-step6-demotion-protocol',
    'test-stage10-policy-lru',
    'test-stage10-cold-store-hardening',
    'test-step12-branch-graph',
    'test-step13-stage8'
)

Write-Host "Phase 1: running $($focusedTests.Count) focused tests under OpenCppCoverage"
$idx = 0
foreach ($t in $focusedTests) {
    $idx++
    $exePath  = Join-Path $binDir "$t.exe"
    $covFile  = Join-Path $covDir ("{0:D2}-{1}.cov" -f $idx, $t)
    $logFile  = Join-Path $OutDir ("{0:D2}-{1}.log" -f $idx, $t)
    if (-not (Test-Path $exePath)) {
        throw "Required coverage binary not found: $exePath"
    }
    Assert-DebugSymbolsAvailable -ExePath $exePath
    Write-Host "  [$idx/$($focusedTests.Count)] $t"
    $ocArgs = (Build-OcArgs -Sources $srcPatterns -Excludes $excludePatterns) + @(
        '--modules', $exePath,
        '--working_dir', $binDir,
        '--export_type', "binary:$covFile",
        '--', $exePath
    )
    $proc = Start-Process -FilePath $OcPath -ArgumentList $ocArgs `
                          -WorkingDirectory $binDir `
                          -NoNewWindow -PassThru -Wait `
                          -RedirectStandardOutput "$logFile.stdout" `
                          -RedirectStandardError  "$logFile.stderr"
    "exit: $($proc.ExitCode)" | Out-File -FilePath $logFile -Encoding utf8
    if ($proc.ExitCode -ne 0) {
        throw "Coverage target failed: $t (exit $($proc.ExitCode))"
    }
    if (Test-Path $covFile) {
        $covFiles.Add($covFile)
        Write-Host "    PASS (exit $($proc.ExitCode)), cov: $([int](Get-Item $covFile).Length) bytes"
    } else {
        throw "OpenCppCoverage produced no .cov for smoke target $t"
    }
}

# --- Phase 2: HTTP probe via llama-server ------------------------------------
$serverCovFile = Join-Path $covDir "server-http-probe.cov"
$serverExe = Join-Path $binDir 'llama-server.exe'
if (-not $SkipServerProbe) {
    if (-not (Test-Path $serverExe)) {
        throw "Required Stage 39 coverage server not found: $serverExe"
    }
    Assert-DebugSymbolsAvailable -ExePath $serverExe
    if (-not (Test-Path $ModelPath)) {
        throw "Required Stage 39 coverage model not found: $ModelPath"
    } else {
        Write-Host "Phase 2: running llama-server HTTP probe under OpenCppCoverage"
        $serverArgs = @(
            '--model',         $ModelPath,
            '--cache-mode',    'hybrid',
            '--ctx-size',      '512',
            '--parallel',      '1',
            '--cache-ram',     '100',
            '--temp',          '0',
            '--seed',          '42',
            '--metrics',
            '--host',          '127.0.0.1',
            '--port',          "$Port",
            '--log-verbosity', '1'
        )
        $ocArgs = (Build-OcArgs -Sources $srcPatterns -Excludes $excludePatterns) + @(
            '--modules', $serverExe,
            '--working_dir', $binDir,
            '--export_type', "binary:$serverCovFile",
            '--', $serverExe
        ) + $serverArgs

        $serverLog = Join-Path $OutDir 'server-probe.log'
        $proc = Start-Process -FilePath $OcPath -ArgumentList $ocArgs `
                              -WorkingDirectory $binDir `
                              -NoNewWindow -PassThru `
                              -RedirectStandardOutput "$serverLog.stdout" `
                              -RedirectStandardError  "$serverLog.stderr"

        # Wait for /health (up to 120 s).
        $ready    = $false
        $deadline = (Get-Date).AddSeconds(120)
        while ((Get-Date) -lt $deadline) {
            try {
                $h = Invoke-WebRequest -Uri "http://127.0.0.1:$Port/health" -UseBasicParsing -TimeoutSec 4
                if ($h.StatusCode -eq 200) { $ready = $true; break }
            } catch {}
            Start-Sleep -Seconds 2
        }

        if ($ready) {
            # Capture /metrics before probe.
            $metBefore = (Invoke-WebRequest -Uri "http://127.0.0.1:$Port/metrics" -UseBasicParsing -TimeoutSec 10).Content
            $metBefore | Out-File -FilePath (Join-Path $OutDir 'server-probe-metrics-before.txt') -Encoding utf8

            # Cold completion (cache miss, seeds entry).
            $body = '{"prompt":"Cache QA deterministic prompt.","n_predict":8,"temperature":0,"seed":42,"cache_prompt":true}'
            $null = Invoke-WebRequest -Uri "http://127.0.0.1:$Port/completion" -Method POST `
                                      -Body $body -ContentType 'application/json' -UseBasicParsing -TimeoutSec 120

            # Warm completions (cache hits).
            for ($i = 1; $i -le 5; $i++) {
                $null = Invoke-WebRequest -Uri "http://127.0.0.1:$Port/completion" -Method POST `
                                          -Body $body -ContentType 'application/json' -UseBasicParsing -TimeoutSec 120
            }

            # Capture /metrics after probe.
            $metAfter = (Invoke-WebRequest -Uri "http://127.0.0.1:$Port/metrics" -UseBasicParsing -TimeoutSec 10).Content
            $metAfter | Out-File -FilePath (Join-Path $OutDir 'server-probe-metrics-after.txt') -Encoding utf8
        } else {
            throw 'Required Stage 39 coverage server probe did not become ready.'
        }

        # Graceful shutdown: find the llama-server child and stop it.
        # OpenCppCoverage detects the process exit via its debug loop and writes
        # the binary .cov file before exiting itself.
        $serverPid = Get-Process -Name 'llama-server' -ErrorAction SilentlyContinue |
                     Where-Object { $_.Parent.Id -eq $proc.Id } |
                     Select-Object -ExpandProperty Id -First 1
        if ($serverPid) {
            Stop-Process -Id $serverPid -Force -ErrorAction SilentlyContinue
        } else {
            # Fallback: stop by name.
            Get-Process -Name 'llama-server' -ErrorAction SilentlyContinue |
                Stop-Process -Force -ErrorAction SilentlyContinue
        }

        # Wait for OpenCppCoverage to finish (up to 30 s).
        $proc.WaitForExit(30000) | Out-Null

        if (Test-Path $serverCovFile) {
            $covFiles.Add($serverCovFile)
            Write-Host "  server probe .cov: $([int](Get-Item $serverCovFile).Length) bytes"
        } else {
            throw 'Required Stage 39 server coverage capture produced no .cov file.'
        }
    }
} else {
    if ($SkipServerProbe) {
        Write-Host "Phase 2: skipped (-SkipServerProbe)"
    }
}

if ($covFiles.Count -eq 0) {
    Write-Error "No .cov files produced; cannot generate coverage report."
}

# --- Phase 3: Merge all .cov files ------------------------------------------
Write-Host "Phase 3: merging $($covFiles.Count) .cov files"
$mergedXml  = Join-Path $OutDir 'coverage-merged.xml'
$mergedHtml = $htmlDir

$inputArgs  = @()
foreach ($cf in $covFiles) { $inputArgs += @('--input_coverage', $cf) }
$sourceArgs = @()
foreach ($s in $srcPatterns)  { $sourceArgs += @('--sources', $s) }
$excArgs    = @()
foreach ($e in $excludePatterns) { $excArgs += @('--excluded_sources', $e) }
$mergeTail = Join-Path $env:SystemRoot 'System32/whoami.exe'
if (-not (Test-Path -LiteralPath $mergeTail -PathType Leaf)) {
    throw "Coverage merge tail executable not found: $mergeTail"
}

$mergeArgs = @('--quiet', '--optimized_build') + $sourceArgs + $excArgs + $inputArgs + @(
    '--export_type', "cobertura:$mergedXml",
    '--export_type', "html:$mergedHtml",
    '--', $mergeTail
)
$proc = Start-Process -FilePath $OcPath -ArgumentList $mergeArgs `
                      -NoNewWindow -PassThru -Wait `
                      -RedirectStandardOutput (Join-Path $OutDir 'merge.stdout') `
                      -RedirectStandardError  (Join-Path $OutDir 'merge.stderr')
Write-Host "  merge exit: $($proc.ExitCode)"
if ($proc.ExitCode -ne 0) {
    throw "OpenCppCoverage merge failed with exit code $($proc.ExitCode)"
}

if (-not (Test-Path $mergedXml)) {
    Write-Error "Merged cobertura XML not produced."
}

# --- Phase 4: Parse and report ----------------------------------------------
Write-Host "Phase 4: computing hybrid-denominator coverage"

[xml] $xml = Get-Content $mergedXml -Raw

# Denominator basenames (to identify coverage rows for reporting).
$denomBasenames = @(
    'server-cache-hybrid.cpp',  'server-cache-hybrid.h',
    'server-cache-store-cold.cpp', 'server-cache-store-cold.h',
    'server-cache-controller.cpp', 'server-cache-controller.h',
    'server-cache-graph.cpp',   'server-cache-graph.h',
    'server-cache-io-worker.cpp',
    'server-cache-policy-lru.cpp',
    'server-cache-legacy.h',
    'test-cache-controller.cpp',
    'test-step1-state-machine.cpp',
    'test-step2-cold-store.cpp',
    'test-step3-4-cold-store-write-read.cpp',
    'test-step9-startup-validation.cpp',
    'test-step10-metrics.cpp',
    'test-step6-demotion-protocol.cpp',
    'test-stage10-policy-lru.cpp',
    'test-stage10-cold-store-hardening.cpp',
    'test-step12-branch-graph.cpp',
    'test-step13-stage8.cpp'
)

$totalCovered = 0
$totalValid   = 0
$rows         = [System.Collections.Generic.List[object]]::new()
# Track already-counted basenames so the per-file table lists each file once.
# Use a case-insensitive normalized key so path-separator and Windows case
# differences cannot reintroduce duplicate rows.
$seenFiles    = @{}

$allClasses = $xml.SelectNodes('//class')
foreach ($cls in $allClasses) {
    $filename = $cls.'filename'
    $basename = [System.IO.Path]::GetFileName($filename)
    if ($denomBasenames -notcontains $basename) { continue }
    # OpenCppCoverage emits one <class> per <package> per source file. The
    # merged XML is a union merge, so the <lines> child is identical across
    # duplicates. Skip duplicates by normalized (case-insensitive) basename so
    # the per-file table lists each file exactly once.
    $key = $basename.ToLowerInvariant()
    if ($seenFiles.ContainsKey($key)) { continue }
    $seenFiles[$key] = $true
    $linesHit   = 0
    $linesTotal = 0
    foreach ($line in $cls.lines.line) {
        $linesTotal++
        if ([int]$line.hits -gt 0) { $linesHit++ }
    }
    if ($linesTotal -eq 0) { continue }
    $rate = [math]::Round($linesHit / $linesTotal, 4)
    $rows.Add([pscustomobject]@{
        File      = $basename
        Rate      = $rate
        Covered   = $linesHit
        Valid     = $linesTotal
    })
    $totalCovered += $linesHit
    $totalValid   += $linesTotal
}

$combinedRate = if ($totalValid -gt 0) { [math]::Round($totalCovered / $totalValid, 4) } else { 0 }
Assert-CoberturaDenominator -CoverageXml $xml -Rows $rows.ToArray() -TotalValid $totalValid
$verdict      = if ($combinedRate -ge 0.80) { 'PASS' } else { 'FAIL' }

# Write report.
$reportLines = @(
    "# Hybrid-mode coverage report",
    "",
    "Denominator: hybrid cache implementation files and current focused test files.",
    "Excluded: server-context.cpp, server-context.h (general dispatcher).",
    "Tool: OpenCppCoverage, Cobertura XML line-rate.",
    "Branch-rate: not available (OpenCppCoverage does not produce branch coverage).",
    "LLVM fallback blocked: lld-link rejects -fprofile-instr-generate as a linker flag on this MSVC host.",
    "",
    "| File | Line rate | Covered | Valid |",
    "| --- | --- | --- | --- |"
)
foreach ($r in ($rows | Sort-Object File)) {
    $reportLines += "| $($r.File) | $($r.Rate) | $($r.Covered) | $($r.Valid) |"
}
$reportLines += @(
    "",
    "## Combined result",
    "",
    "- Combined line rate: $combinedRate",
    "- Combined covered: $totalCovered / $totalValid",
    "- 80% threshold: $verdict"
)

$reportPath = Join-Path $OutDir 'coverage-report.md'
$reportLines | Out-File -FilePath $reportPath -Encoding utf8

Write-Host ""
Write-Host "Combined line rate: $combinedRate  ($totalCovered / $totalValid lines)"
Write-Host "80% threshold: $verdict"
Write-Host "Report: $reportPath"
Write-Host "HTML:   $mergedHtml\index.html"

if ($verdict -ne 'PASS') {
    Write-Warning "Coverage below 80%. Review uncovered hybrid paths in: $mergedHtml\index.html"
    exit 1
}
