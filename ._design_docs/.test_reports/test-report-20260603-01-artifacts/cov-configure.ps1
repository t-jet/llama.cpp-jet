#requires -Version 5
# Coverage build: configure with clang-cl + LLVM source coverage.
$ErrorActionPreference = 'Stop'
$art = "D:\source\llama.cpp-jet\._design_docs\.test_reports\test-report-20260603-01-artifacts"
$src = "D:\source\llama.cpp-jet"
$covBuild = "D:\source\llama.cpp-jet\build-cov"
$llvmBin = 'C:\Program Files\Microsoft Visual Studio\18\Community\VC\Tools\Llvm\x64\bin'

# Pick up devcmd env.
$bat = Join-Path $art 'vsdevcmd-env.bat'
$envText = & cmd.exe /c $bat 2>&1
$map = @{}
foreach ($line in $envText) {
    if ($line -match '^([A-Za-z_][A-Za-z0-9_()]*)=(.*)$') { $map[$Matches[1]] = $Matches[2] }
}
foreach ($k in $map.Keys) { Set-Item -Path "Env:$k" -Value $map[$k] }
$env:Path = $llvmBin + ';' + $env:Path

$env:CC  = (Join-Path $llvmBin 'clang-cl.exe')
$env:CXX = (Join-Path $llvmBin 'clang-cl.exe')

# Coverage flags for all translation units in the coverage build.
$cflags = '/clang:-fprofile-instr-generate /clang:-fcoverage-mapping /clang:-fno-omit-frame-pointer /O1 /Z7'
$env:CFLAGS   = $cflags
$env:CXXFLAGS = $cflags
# Add a CMake cache file as the cleanest way to propagate.
$cMakeArgs = @(
    '-S', $src,
    '-B', $covBuild,
    '-G', 'Ninja',
    '-DCMAKE_BUILD_TYPE=Release',
    '-DCMAKE_C_COMPILER=' + $env:CC,
    '-DCMAKE_CXX_COMPILER=' + $env:CXX,
    '-DCMAKE_C_FLAGS_RELEASE=/O1 /Z7',
    '-DCMAKE_CXX_FLAGS_RELEASE=/O1 /Z7',
    '-DCMAKE_C_FLAGS=' + $cflags,
    '-DCMAKE_CXX_FLAGS=' + $cflags,
    '-DLLAMA_BUILD_TESTS=ON',
    '-DLLAMA_BUILD_SERVER=OFF',
    '-DLLAMA_CURL=OFF',
    '-DLLAMA_OPENSSL=OFF',
    '-DGGML_NATIVE=OFF',
    '-DGGML_CPU_ALL_VARIANTS=OFF',
    '-DGGML_OPENMP=OFF'
)

if (Test-Path $covBuild) { Remove-Item -Recurse -Force $covBuild }

& cmake @cMakeArgs 2>&1 | Tee-Object -FilePath (Join-Path $art 'cov-configure.log') | Out-String -Stream | Select-Object -Last 10
"exit: $LASTEXITCODE"
