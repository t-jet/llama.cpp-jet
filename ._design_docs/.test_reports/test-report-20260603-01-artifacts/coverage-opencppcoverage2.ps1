#requires -Version 5
# Use OpenCppCoverage (GCOV-style fallback) to measure line coverage of hybrid
# sources during focused test execution against the new build-cov binaries
# that have PDBs and full debug info.
$ErrorActionPreference = 'Stop'

$art  = "D:\source\llama.cpp-jet\._design_docs\.test_reports\test-report-20260603-01-artifacts"
$src  = "D:\source\llama.cpp-jet"
$bin  = "D:\source\llama.cpp-jet\build-cov\bin\Release"
$oc   = "D:\app\OpenCppCoverage\OpenCppCoverage.exe"

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

# Build per-test Cobertura + HTML output.
$idx = 0
foreach ($exe in $exeTargets) {
    $idx++
    $covFile = Join-Path $outBase ("cobertura-{0:D2}-{1}.xml" -f $idx, $exe)
    $logFile = Join-Path $outBase ("run-{0:D2}-{1}.log" -f $idx, $exe)
    $perArgs = @(
        '--quiet',
        '--modules', ("{0}\{1}.exe" -f $bin, $exe),
        '--working_dir', $bin,
        '--sources', 'D:\source\llama.cpp-jet\tools\server\*.cpp',
        '--sources', 'D:\source\llama.cpp-jet\tools\server\*.h',
        '--sources', 'D:\source\llama.cpp-jet\tests\test-cache-controller.cpp',
        '--sources', 'D:\source\llama.cpp-jet\tests\test-step10-metrics.cpp',
        '--sources', 'D:\source\llama.cpp-jet\tests\test-stage10-cold-store-hardening.cpp',
        '--sources', 'D:\source\llama.cpp-jet\tests\test-step6-demotion-protocol.cpp',
        '--sources', 'D:\source\llama.cpp-jet\tests\test-step7-promotion-protocol.cpp',
        '--sources', 'D:\source\llama.cpp-jet\tests\test-step11-test-hooks-fault-injection.cpp',
        '--sources', 'D:\source\llama.cpp-jet\tests\test-step12-branch-graph.cpp',
        '--sources', 'D:\source\llama.cpp-jet\tests\test-step13-stage8.cpp',
        '--excluded_sources', 'D:\app\',
        '--excluded_sources', 'D:\source\llama.cpp-jet\build\',
        '--excluded_sources', 'D:\source\llama.cpp-jet\build-cov\',
        '--excluded_sources', 'D:\source\llama.cpp-jet\ggml\',
        '--excluded_sources', 'D:\source\llama.cpp-jet\common\',
        '--excluded_sources', 'D:\source\llama.cpp-jet\src\',
        '--excluded_sources', 'D:\source\llama.cpp-jet\vendor\',
        '--excluded_sources', 'D:\source\llama.cpp-jet\tools\mtmd\',
        '--export_type', ('cobertura:' + $covFile),
        '--',
        ("{0}.exe" -f $exe)
    )
    "running: $exe" | Out-File -FilePath $logFile -Encoding utf8
    $proc = Start-Process -FilePath $oc -ArgumentList $perArgs -WorkingDirectory $bin -NoNewWindow -PassThru -Wait -RedirectStandardOutput ($logFile + '.stdout') -RedirectStandardError ($logFile + '.stderr')
    "  exit: $($proc.ExitCode)" | Out-File -FilePath $logFile -Append -Encoding utf8
    if (Test-Path $covFile) {
        "  cobertura: $((Get-Item $covFile).Length) bytes" | Out-File -FilePath $logFile -Append -Encoding utf8
    }
}
