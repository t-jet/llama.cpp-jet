# Stage 12 dry-run only batch
$ErrorActionPreference = 'Continue'
$build = 'D:\source\llama.cpp-jet\build-cov'
$date = '20260607-04'
$env:LLAMA_CACHE_TEST_MODEL = 'D:\source\llama.cpp-jet\._test_models\Qwen3-0.6B-GGUF\Qwen3-0.6B-Q8_0.gguf'
$env:LLAMA_CACHE_TEST_TARGET_MODEL = 'D:\source\llama.cpp-jet\._test_models\Qwen3-8B-GGUF\Qwen3-8B-Q6_K.gguf'
$env:LLAMA_CACHE_TEST_DRAFT_MODEL = 'D:\source\llama.cpp-jet\._test_models\Qwen3-0.6B-GGUF\Qwen3-0.6B-Q8_0.gguf'
$env:LLAMA_CACHE_TEST_K6_PATH = 'D:\app\k6\k6.exe'
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$results = @()
$stressDir = 'D:\source\llama.cpp-jet\._design_docs\cache-handling-test-scripts\stress'
$benchDir  = 'D:\source\llama.cpp-jet\._design_docs\cache-handling-test-scripts\bench'
$longrunDir= 'D:\source\llama.cpp-jet\._design_docs\cache-handling-test-scripts\longrun'
foreach ($id in 's01','s02','s03','s04','s05','s06','s07','s08') {
    $m = @(Get-ChildItem -Path $stressDir -Filter ("stress_s12_" + $id + "_*.ps1"))
    if ($m.Count -lt 1) { continue }
    $evDir = "D:\source\llama.cpp-jet\._design_docs\.test_reports\stress-s12-$($id.ToUpper())-$date"
    New-Item -ItemType Directory -Force -Path $evDir | Out-Null
    $log = Join-Path $evDir 'dryrun.log'
    $out = & $m[0].FullName -BuildDir $build -OutDir $evDir -DryRun 2>&1 | Out-String
    [System.IO.File]::WriteAllText($log, $out, $utf8NoBom)
    $exit = $LASTEXITCODE
    $results += [pscustomobject]@{ Id="S12-$($id.ToUpper())"; Kind='stress'; DryExit=$exit; Evidence=$evDir }
    Write-Host "S12-$($id.ToUpper()): dry=$exit"
}
foreach ($id in 'b01','b02','b03','b04','b05','b06','b07','b08') {
    $m = @(Get-ChildItem -Path $benchDir -Filter ("bench_s12_" + $id + "_*.ps1"))
    if ($m.Count -lt 1) { continue }
    $evDir = "D:\source\llama.cpp-jet\._design_docs\.test_reports\bench-s12-$($id.ToUpper())-$date"
    New-Item -ItemType Directory -Force -Path $evDir | Out-Null
    $log = Join-Path $evDir 'dryrun.log'
    $out = & $m[0].FullName -BuildDir $build -OutDir $evDir -DryRun 2>&1 | Out-String
    [System.IO.File]::WriteAllText($log, $out, $utf8NoBom)
    $exit = $LASTEXITCODE
    $results += [pscustomobject]@{ Id="S12-$($id.ToUpper())"; Kind='bench'; DryExit=$exit; Evidence=$evDir }
    Write-Host "S12-$($id.ToUpper()): dry=$exit"
}
foreach ($id in 'l01','l02','l03') {
    $m = @(Get-ChildItem -Path $longrunDir -Filter ("longrun_s12_" + $id + "_*.ps1"))
    if ($m.Count -lt 1) { continue }
    $evDir = "D:\source\llama.cpp-jet\._design_docs\.test_reports\longrun-s12-$($id.ToUpper())-$date"
    New-Item -ItemType Directory -Force -Path $evDir | Out-Null
    $log = Join-Path $evDir 'dryrun.log'
    $out = & $m[0].FullName -BuildDir $build -OutDir $evDir -DryRun 2>&1 | Out-String
    [System.IO.File]::WriteAllText($log, $out, $utf8NoBom)
    $exit = $LASTEXITCODE
    $results += [pscustomobject]@{ Id="S12-$($id.ToUpper())"; Kind='longrun'; DryExit=$exit; Evidence=$evDir }
    Write-Host "S12-$($id.ToUpper()): dry=$exit"
}
$results | Format-Table -AutoSize
$results | Export-Csv -NoTypeInformation "D:\source\llama.cpp-jet\._design_docs\.test_reports\dryrun-s12-20260607-04-results.csv"
