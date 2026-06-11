# Stage 12 batch runner v5 - foreground direct call, bounded durations
$ErrorActionPreference = 'Continue'
$root = 'D:\source\llama.cpp-jet\._design_docs\cache-handling-test-scripts'
$date = '20260607-04'
$env:LLAMA_CACHE_TEST_MODEL = 'D:\source\llama.cpp-jet\._test_models\Qwen3-0.6B-GGUF\Qwen3-0.6B-Q8_0.gguf'
$env:LLAMA_CACHE_TEST_TARGET_MODEL = 'D:\source\llama.cpp-jet\._test_models\Qwen3-8B-GGUF\Qwen3-8B-Q6_K.gguf'
$env:LLAMA_CACHE_TEST_DRAFT_MODEL = 'D:\source\llama.cpp-jet\._test_models\Qwen3-0.6B-GGUF\Qwen3-0.6B-Q8_0.gguf'
$env:LLAMA_CACHE_TEST_K6_PATH = 'D:\app\k6\k6.exe'
$build = 'D:\source\llama.cpp-jet\build-cov'

$results = @()
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

$stressDir = Join-Path $root 'stress'
$benchDir  = Join-Path $root 'bench'
$longrunDir= Join-Path $root 'longrun'

foreach ($id in 's01','s02','s03','s04','s05','s06','s07','s08') {
    $matches = @(Get-ChildItem -Path $stressDir -Filter ("stress_s12_" + $id + "_*.ps1"))
    if ($matches.Count -lt 1) { continue }
    $script = $matches[0]
    $evDir = "D:\source\llama.cpp-jet\._design_docs\.test_reports\stress-s12-$($id.ToUpper())-$date"
    New-Item -ItemType Directory -Force -Path $evDir | Out-Null
    $dryLog = Join-Path $evDir 'dryrun.log'
    $liveLog = Join-Path $evDir 'live.log'
    # Dry-run
    $dryOut = & $script.FullName -BuildDir $build -OutDir $evDir -DryRun 2>&1 | Out-String
    [System.IO.File]::WriteAllText($dryLog, $dryOut, $utf8NoBom)
    $dryExit = $LASTEXITCODE
    # Live (1 min)
    $liveOut = & $script.FullName -BuildDir $build -OutDir $evDir -DurationMin 1 2>&1 | Out-String
    [System.IO.File]::WriteAllText($liveLog, $liveOut, $utf8NoBom)
    $liveExit = $LASTEXITCODE
    $results += [pscustomobject]@{ Id="S12-$($id.ToUpper())"; Dry=($dryExit -eq 0); DryExit=$dryExit; Live=($liveExit -eq 0); LiveExit=$liveExit; Evidence=$evDir }
    Write-Host "S12-$($id.ToUpper()): dry=$dryExit live=$liveExit"
    # Kill any orphan llama-server before next scenario
    Get-Process -Name llama-server -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
}

foreach ($id in 'b01','b02','b03','b04','b05','b06','b07','b08') {
    $matches = @(Get-ChildItem -Path $benchDir -Filter ("bench_s12_" + $id + "_*.ps1"))
    if ($matches.Count -lt 1) { continue }
    $script = $matches[0]
    $evDir = "D:\source\llama.cpp-jet\._design_docs\.test_reports\bench-s12-$($id.ToUpper())-$date"
    New-Item -ItemType Directory -Force -Path $evDir | Out-Null
    $dryLog = Join-Path $evDir 'dryrun.log'
    $liveLog = Join-Path $evDir 'live.log'
    $dryOut = & $script.FullName -BuildDir $build -OutDir $evDir -DryRun 2>&1 | Out-String
    [System.IO.File]::WriteAllText($dryLog, $dryOut, $utf8NoBom)
    $dryExit = $LASTEXITCODE
    $liveOut = & $script.FullName -BuildDir $build -OutDir $evDir -MeasurementSec 60 2>&1 | Out-String
    [System.IO.File]::WriteAllText($liveLog, $liveOut, $utf8NoBom)
    $liveExit = $LASTEXITCODE
    $results += [pscustomobject]@{ Id="S12-$($id.ToUpper())"; Dry=($dryExit -eq 0); DryExit=$dryExit; Live=($liveExit -eq 0); LiveExit=$liveExit; Evidence=$evDir }
    Write-Host "S12-$($id.ToUpper()): dry=$dryExit live=$liveExit"
    Get-Process -Name llama-server -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
}

# Long-run with bounded durations for first session
foreach ($id in 'l01','l02','l03') {
    $matches = @(Get-ChildItem -Path $longrunDir -Filter ("longrun_s12_" + $id + "_*.ps1"))
    if ($matches.Count -lt 1) { continue }
    $script = $matches[0]
    $evDir = "D:\source\llama.cpp-jet\._design_docs\.test_reports\longrun-s12-$($id.ToUpper())-$date"
    New-Item -ItemType Directory -Force -Path $evDir | Out-Null
    $dryLog = Join-Path $evDir 'dryrun.log'
    $liveLog = Join-Path $evDir 'live.log'
    $dryOut = & $script.FullName -BuildDir $build -OutDir $evDir -DryRun 2>&1 | Out-String
    [System.IO.File]::WriteAllText($dryLog, $dryOut, $utf8NoBom)
    $dryExit = $LASTEXITCODE
    # Reduced: L01=0.5h=30m, L02=5m, L03=0.25h=15m
    if ($id -eq 'l01') { $liveOut = & $script.FullName -BuildDir $build -OutDir $evDir -DurationHours 0.5 2>&1 | Out-String }
    elseif ($id -eq 'l02') { $liveOut = & $script.FullName -BuildDir $build -OutDir $evDir -DurationMin 5 2>&1 | Out-String }
    else { $liveOut = & $script.FullName -BuildDir $build -OutDir $evDir -DurationHours 0.25 2>&1 | Out-String }
    [System.IO.File]::WriteAllText($liveLog, $liveOut, $utf8NoBom)
    $liveExit = $LASTEXITCODE
    $results += [pscustomobject]@{ Id="S12-$($id.ToUpper())"; Dry=($dryExit -eq 0); DryExit=$dryExit; Live=($liveExit -eq 0); LiveExit=$liveExit; Evidence=$evDir }
    Write-Host "S12-$($id.ToUpper()): dry=$dryExit live=$liveExit"
    Get-Process -Name llama-server -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
}

$results | Format-Table -AutoSize
$results | Export-Csv -NoTypeInformation "D:\source\llama.cpp-jet\._design_docs\.test_reports\batch-s12-20260607-04-results.csv"
