#requires -Version 5
# Use OpenCppCoverage (GCOV-style fallback) to measure line coverage of hybrid
# sources during focused test execution. Output Cobertura XML + HTML for the
# Stage 10 hybrid denominator.
$ErrorActionPreference = 'Stop'

$art  = "D:\source\llama.cpp-jet\._design_docs\.test_reports\test-report-20260603-01-artifacts"
$src  = "D:\source\llama.cpp-jet"
$bin  = "D:\source\llama.cpp-jet\build\bin\Release"
$oc   = "D:\app\OpenCppCoverage\OpenCppCoverage.exe"

# Hybrid denominator: list of included source patterns.
$hybridSources = @(
    'tools/server/server-cache-hybrid.cpp',
    'tools/server/server-cache-hybrid.h',
    'tools/server/server-cache-store-cold.cpp',
    'tools/server/server-cache-store-cold.h',
    'tools/server/server-cache-controller.cpp',
    'tools/server/server-cache-controller.h',
    'tools/server/server-cache-legacy.cpp',
    'tools/server/server-cache-legacy.h',
    'tools/server/server-context.cpp',
    'tools/server/server-context.h',
    'tests/test-cache-controller.cpp',
    'tests/test-step10-metrics.cpp',
    'tests/test-stage10-cold-store-hardening.cpp',
    'tests/test-step6-demotion-protocol.cpp',
    'tests/test-step7-promotion-protocol.cpp',
    'tests/test-step11-test-hooks-fault-injection.cpp',
    'tests/test-step12-branch-graph.cpp',
    'tests/test-step13-stage8.cpp'
)

# Excluded: not part of hybrid denominator.
$excludedSources = @(
    'D:\app\',
    'D:\source\llama.cpp-jet\build\',
    'D:\source\llama.cpp-jet\ggml\',
    'D:\source\llama.cpp-jet\common\',
    'D:\source\llama.cpp-jet\src\',
    'D:\source\llama.cpp-jet\vendor\',
    'D:\source\llama.cpp-jet\tools\mtmd\'
)

# Build args.
$sourceArgs = @()
foreach ($s in $hybridSources) { $sourceArgs += @('--sources', (Join-Path $src $s)) }
$excludedArgs = @()
foreach ($e in $excludedSources) { $excludedArgs += @('--excluded_sources', $e) }

# Run the focused tests through OpenCppCoverage and collect coverage of all
# .obj-loaded source files.
$exeTargets = @(
    'test-cache-controller',
    'test-step10-metrics',
    'test-stage10-cold-store-hardening',
    'test-step6-demotion-protocol',
    'test-step7-promotion-protocol',
    'test-step11-test-hooks-fault-injection',
    'test-step12-branch-graph',
    'test-step13-stage8'
)

$outBase = Join-Path $art 'coverage'

# Build the full command for one coverage run that runs all focused tests in
# sequence, accumulating coverage.
$allArgs = @(
    '--quiet',
    '--modules', 'build\bin\Release\test-*.exe',
    '--working_dir', (Join-Path $src 'build\bin\Release'),
    '--export_type', 'cobertura:' + (Join-Path $outBase 'cobertura.xml'),
    '--cover_children',
    '--'
)
foreach ($exe in $exeTargets) {
    $allArgs += $exe
}

# For each test, run individually to keep the log readable. Then merge.
$idx = 0
foreach ($exe in $exeTargets) {
    $idx++
    $covFile = Join-Path $outBase ("cobertura-{0:D2}-{1}.xml" -f $idx, $exe)
    $logFile = Join-Path $outBase ("run-{0:D2}-{1}.log" -f $idx, $exe)
    $perArgs = @(
        '--quiet',
        '--modules', ("build\bin\Release\{0}.exe" -f $exe),
        '--working_dir', (Join-Path $src 'build\bin\Release'),
        '--sources', (Join-Path $src 'tools\server\*.cpp'),
        '--sources', (Join-Path $src 'tools\server\*.h'),
        '--sources', (Join-Path $src 'tests\test-cache-controller.cpp'),
        '--sources', (Join-Path $src 'tests\test-step10-metrics.cpp'),
        '--sources', (Join-Path $src 'tests\test-stage10-cold-store-hardening.cpp'),
        '--sources', (Join-Path $src 'tests\test-step6-demotion-protocol.cpp'),
        '--sources', (Join-Path $src 'tests\test-step7-promotion-protocol.cpp'),
        '--sources', (Join-Path $src 'tests\test-step11-test-hooks-fault-injection.cpp'),
        '--sources', (Join-Path $src 'tests\test-step12-branch-graph.cpp'),
        '--sources', (Join-Path $src 'tests\test-step13-stage8.cpp'),
        '--excluded_sources', 'D:\app\',
        '--excluded_sources', 'D:\source\llama.cpp-jet\build\',
        '--excluded_sources', 'D:\source\llama.cpp-jet\ggml\',
        '--excluded_sources', 'D:\source\llama.cpp-jet\common\',
        '--excluded_sources', 'D:\source\llama.cpp-jet\src\',
        '--excluded_sources', 'D:\source\llama.cpp-jet\vendor\',
        '--excluded_sources', 'D:\source\llama.cpp-jet\tools\mtmd\',
        '--export_type', ('cobertura:' + $covFile),
        '--export_type', ('html:' + (Join-Path $outBase ("html-{0:D2}-{1}" -f $idx, $exe))),
        '--',
        ("{0}.exe" -f $exe)
    )
    "running: $exe" | Out-File -FilePath $logFile -Encoding utf8
    $proc = Start-Process -FilePath $oc -ArgumentList $perArgs -WorkingDirectory (Join-Path $src 'build\bin\Release') -NoNewWindow -PassThru -Wait -RedirectStandardOutput ($logFile + '.stdout') -RedirectStandardError ($logFile + '.stderr')
    "  exit: $($proc.ExitCode)" | Out-File -FilePath $logFile -Append -Encoding utf8
    if (Test-Path $covFile) {
        "  cobertura: $((Get-Item $covFile).Length) bytes" | Out-File -FilePath $logFile -Append -Encoding utf8
    }
}
