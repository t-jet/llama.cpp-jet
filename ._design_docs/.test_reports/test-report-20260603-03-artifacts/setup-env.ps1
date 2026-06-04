# setup-env.ps1 - 20260603-03 session
# Capture devcmd env, tool versions, and key paths for the execution report.

$ErrorActionPreference = 'Continue'
$art = "D:\source\llama.cpp-jet\._design_docs\.test_reports\test-report-20260603-03-artifacts"

$vsdevcmd = "C:\Program Files\Microsoft Visual Studio\18\Community\Common7\Tools\vsdevcmd.bat"
$llvmBin  = "C:\Program Files\Microsoft Visual Studio\18\Community\VC\Tools\Llvm\x64\bin"

# Build a single batch file that calls devcmd, prepends LLVM, and runs all
# the tool version commands. This avoids the spawn-env problem.
$bat = Join-Path $art 'capture-versions.bat'
$lines = @(
    '@echo off',
    "call `"$vsdevcmd`" -arch=x64 -host_arch=x64 > nul",
    "set PATH=$llvmBin;%PATH%",
    'echo === cl ===',
    'cl 2>&1',
    'echo === clang ===',
    'clang --version',
    'echo === clang-cl ===',
    'clang-cl --version',
    'echo === llvm-profdata ===',
    'llvm-profdata --version',
    'echo === llvm-cov ===',
    'llvm-cov --version',
    'echo === cmake ===',
    'cmake --version',
    'echo === ninja ===',
    'ninja --version',
    'echo === k6 ===',
    '"D:\app\k6\k6.exe" version',
    'echo === python ===',
    'python --version',
    'echo === matplotlib ===',
    'python -c "import matplotlib; print(matplotlib.__version__)"',
    'echo === OpenCppCoverage ===',
    '"D:\app\OpenCppCoverage\OpenCppCoverage.exe" --version',
    'echo === git-head ===',
    'git rev-parse HEAD'
)
$lines -join "`r`n" | Out-File -FilePath $bat -Encoding ascii

# Run it and capture stdout
$outBat = Join-Path $art 'capture-versions.out.log'
cmd /c $bat > $outBat 2>&1
$rc = $LASTEXITCODE

# Persist raw
Get-Content $outBat -Raw | Out-File -FilePath (Join-Path $art 'tool-versions-raw.txt') -Encoding utf8

# Save devcmd invocation for the report
"call `"$vsdevcmd`" -arch=x64 -host_arch=x64" | Out-File -FilePath (Join-Path $art 'vsdevcmd-env.bat') -Encoding ascii

# Save git status
git status --short 2>&1 | Out-File -FilePath (Join-Path $art 'git-status.txt') -Encoding ascii

# Save git head
git rev-parse HEAD 2>&1 | Out-File -FilePath (Join-Path $art 'git-head.txt') -Encoding ascii

Write-Host "Tools and git status saved to $art (rc=$rc)"
Get-Content $outBat -Raw
