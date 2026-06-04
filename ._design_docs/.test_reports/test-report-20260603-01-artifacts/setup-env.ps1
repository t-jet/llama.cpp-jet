#requires -Version 5
# Capture Visual Studio 2026 devcmd environment, then prepend LLVM toolchain.
# Returns a hashtable of PATH and tool paths for use by the run script.

$ErrorActionPreference = 'Stop'

$vsdevcmd = 'C:\Program Files\Microsoft Visual Studio\18\Community\Common7\Tools\vsdevcmd.bat'
$llvmBin  = 'C:\Program Files\Microsoft Visual Studio\18\Community\VC\Tools\Llvm\x64\bin'

if (-not (Test-Path $vsdevcmd)) { throw "vsdevcmd not found at $vsdevcmd" }
if (-not (Test-Path $llvmBin))  { throw "LLVM bin not found at $llvmBin" }

# Capture the devcmd env as text using a helper batch to avoid quoting issues.
$bat = Join-Path $PSScriptRoot 'vsdevcmd-env.bat'
if (-not (Test-Path $bat)) { throw "Helper batch not found: $bat" }
$envText = & cmd.exe /c $bat 2>&1
if (-not $envText) { throw "vsdevcmd env capture returned no output" }

$map = @{}
foreach ($line in $envText) {
    if ($line -match '^([A-Za-z_][A-Za-z0-9_()]*)=(.*)$') {
        $map[$Matches[1]] = $Matches[2]
    }
}

# Apply into current process.
foreach ($k in $map.Keys) {
    Set-Item -Path "Env:$k" -Value $map[$k]
}

# Prepend LLVM bin so clang/llvm-cov/llvm-profdata resolve before the bare MSVC clang.
$env:Path = $llvmBin + ';' + $env:Path

# Persist key version output.
$result = [ordered]@{
    vsdevcmd      = 'C:\Program Files\Microsoft Visual Studio\18\Community\Common7\Tools\vsdevcmd.bat'
    llvmBin       = $llvmBin
    clExe         = (Get-Command cl.exe -ErrorAction SilentlyContinue).Path
    cmake         = (Get-Command cmake.exe -ErrorAction SilentlyContinue).Path
    clang         = (Get-Command clang.exe -ErrorAction SilentlyContinue).Path
    clangcl       = (Get-Command clang-cl.exe -ErrorAction SilentlyContinue).Path
    llvmProfdata  = (Get-Command llvm-profdata.exe -ErrorAction SilentlyContinue).Path
    llvmCov       = (Get-Command llvm-cov.exe -ErrorAction SilentlyContinue).Path
    k6            = (Get-Command k6.exe -ErrorAction SilentlyContinue).Path
    python        = (Get-Command python.exe -ErrorAction SilentlyContinue).Path
    pythonVersion = (& python -c "import sys; print(sys.version.split()[0])" 2>$null)
    matplotVer    = (& python -c "import matplotlib; print(matplotlib.__version__)" 2>$null)
    k6Version     = (& k6 version 2>$null | Select-Object -First 1)
    clangVersion  = (& clang --version 2>$null | Select-Object -First 1)
    llvmCovVer    = (& llvm-cov --version 2>$null | Select-Object -First 1)
    llvmProfVer   = (& llvm-profdata --version 2>$null | Select-Object -First 1)
}

$result | ConvertTo-Json -Depth 2 | Write-Host
$result | ConvertTo-Json -Depth 2 | Out-File -FilePath (Join-Path $PSScriptRoot 'setup-env.json') -Encoding utf8
return $result
