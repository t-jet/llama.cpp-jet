#requires -Version 5
# Manual coverage helper v5: invoke via cmd /c to bypass PowerShell's
# NativeCommandError on test-binary stderr, and DROP --quiet so we can
# see OpenCppCoverage's actual coverage-collection status.

param(
    [string] $BuildDir  = 'D:\source\llama.cpp-jet\build-cov',
    [string] $Config    = 'Release',
    [string] $OutDir    = 'D:\source\llama.cpp-jet\coverage-run-20260607-01',
    [string] $OcPath    = 'D:\app\OpenCppCoverage\OpenCppCoverage.exe'
)

$ErrorActionPreference = 'Stop'

$binDir  = (Resolve-Path (Join-Path $BuildDir "bin\$Config")).Path
$covDir  = Join-Path $OutDir 'cov-binary'
$srcRoot = 'D:\source\llama.cpp-jet'

$srcPatterns = @(
    (Join-Path $srcRoot 'tools\server\server-cache-hybrid.cpp'),
    (Join-Path $srcRoot 'tools\server\server-cache-hybrid.h'),
    (Join-Path $srcRoot 'tools\server\server-cache-store-cold.cpp'),
    (Join-Path $srcRoot 'tools\server\server-cache-store-cold.h'),
    (Join-Path $srcRoot 'tools\server\server-cache-controller.cpp'),
    (Join-Path $srcRoot 'tools\server\server-cache-controller.h'),
    (Join-Path $srcRoot 'tools\server\server-cache-graph.cpp'),
    (Join-Path $srcRoot 'tools\server\server-cache-graph.h'),
    (Join-Path $srcRoot 'tools\server\server-cache-io-worker.cpp'),
    (Join-Path $srcRoot 'tools\server\server-cache-policy-lru.cpp'),
    (Join-Path $srcRoot 'tools\server\server-cache-legacy.h'),
    (Join-Path $srcRoot 'tests\test-cache-controller.cpp'),
    (Join-Path $srcRoot 'tests\test-step10-metrics.cpp'),
    (Join-Path $srcRoot 'tests\test-stage10-cold-store-hardening.cpp'),
    (Join-Path $srcRoot 'tests\test-step6-demotion-protocol.cpp'),
    (Join-Path $srcRoot 'tests\test-step7-promotion-protocol.cpp'),
    (Join-Path $srcRoot 'tests\test-step11-test-hooks-fault-injection.cpp'),
    (Join-Path $srcRoot 'tests\test-step12-branch-graph.cpp'),
    (Join-Path $srcRoot 'tests\test-step13-stage8.cpp')
)

$excludePatterns = @(
    'D:\app\',
    (Join-Path $srcRoot 'build\'),
    (Join-Path $srcRoot 'ggml\'),
    (Join-Path $srcRoot 'common\'),
    (Join-Path $srcRoot 'src\'),
    (Join-Path $srcRoot 'vendor\'),
    (Join-Path $srcRoot 'tools\mtmd\')
)

$focusedTests = @(
    'test-cache-controller',
    'test-step10-metrics',
    'test-stage10-cold-store-hardening',
    'test-stage10-policy-lru',
    'test-step6-demotion-protocol',
    'test-step7-promotion-protocol',
    'test-step11-test-hooks-fault-injection',
    'test-step12-branch-graph',
    'test-step13-stage8'
)

$idx = 0
foreach ($t in $focusedTests) {
    $idx++
    $exePath = Join-Path $binDir "$t.exe"
    $covFile = Join-Path $covDir ("{0:D2}-{1}.cov" -f $idx, $t)
    $logFile = Join-Path $OutDir ("{0:D2}-{1}-manual.log" -f $idx, $t)
    if (-not (Test-Path $exePath)) { Write-Warning "  SKIP $t"; continue }
    if (Test-Path $covFile) { Remove-Item $covFile -Force }

    Write-Host "  [$idx/$($focusedTests.Count)] $t"
    $argList = @()
    foreach ($s in $srcPatterns)  { $argList += @('--sources', $s) }
    foreach ($e in $excludePatterns) { $argList += @('--excluded_sources', $e) }
    $argList += @(
        '--modules', $exePath,
        '--working_dir', $binDir,
        '--export_type', "binary:$covFile",
        '--', $exePath
    )
    # Build a single command-line string for cmd /c.  Each arg is wrapped
    # in double quotes; embedded double-quotes are doubled (cmd quoting).
    $cmdArgs = ($argList | ForEach-Object {
        $a = $_ -replace '"', '""'
        if ($a -match '\s|"') { '"' + $a + '"' } else { $a }
    }) -join ' '
    $cmdLine = "`"$OcPath`" $cmdArgs"
    $pinfo = New-Object System.Diagnostics.ProcessStartInfo
    $pinfo.FileName = 'cmd.exe'
    $pinfo.Arguments = "/c $cmdLine"
    $pinfo.RedirectStandardOutput = $true
    $pinfo.RedirectStandardError  = $true
    $pinfo.UseShellExecute = $false
    $pinfo.WorkingDirectory = $binDir
    $p = [System.Diagnostics.Process]::Start($pinfo)
    $stdout = $p.StandardOutput.ReadToEnd()
    $stderr = $p.StandardError.ReadToEnd()
    $p.WaitForExit()
    $rc = $p.ExitCode
    @($stdout) | Out-File -FilePath "$logFile.stdout" -Encoding utf8
    @($stderr) | Out-File -FilePath "$logFile.stderr" -Encoding utf8
    "exit: $rc" | Out-File -FilePath $logFile -Encoding utf8
    if (Test-Path $covFile) {
        $sz = (Get-Item $covFile).Length
        Write-Host "    cov: $sz bytes (exit $rc)"
    } else {
        Write-Warning "    no .cov file produced (exit $rc)"
    }
}
