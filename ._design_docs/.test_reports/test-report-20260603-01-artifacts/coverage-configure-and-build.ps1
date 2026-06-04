#requires -Version 5
# Configure and build focused test binaries with clang-cl + LLVM source coverage.
# Reuses the existing MSVC build tree but selects clang-cl for the test targets
# and instruments with -fprofile-instr-generate -fcoverage-mapping.

$ErrorActionPreference = 'Stop'
$art = "D:\source\llama.cpp-jet\._design_docs\.test_reports\test-report-20260603-01-artifacts"
$src = "D:\source\llama.cpp-jet"
$covBuild = "D:\source\llama.cpp-jet\build-cov"
$llvmBin = 'C:\Program Files\Microsoft Visual Studio\18\Community\VC\Tools\Llvm\x64\bin'

# Pick up devcmd env (cmake + msbuild + MSVC system libs).
. (Join-Path $art 'setup-env.ps1') | Out-Null

# Set clang-cl as the C and C++ compiler.
$env:CC  = (Join-Path $llvmBin 'clang-cl.exe')
$env:CXX = (Join-Path $llvmBin 'clang-cl.exe')
$env:CCACHE_DISABLE = '1'

# Coverage flags applied only to our hybrid sources, not to the heavy ggml backends.
$env:LLAMA_COVERAGE_FLAGS = '-fprofile-instr-generate -fcoverage-mapping -fno-omit-frame-pointer -O0'

if (Test-Path $covBuild) { Remove-Item -Recurse -Force $covBuild }

& cmake -S $src -B $covBuild -G "Ninja" `
    -DCMAKE_BUILD_TYPE=Release `
    -DCMAKE_C_COMPILER="$env:CC" `
    -DCMAKE_CXX_COMPILER="$env:CXX" `
    -DCMAKE_C_FLAGS_RELEASE="/O0" `
    -DCMAKE_CXX_FLAGS_RELEASE="/O0" `
    -DLLAMA_BUILD_TESTS=ON `
    -DLLAMA_BUILD_SERVER=OFF `
    -DLLAMA_CURL=OFF `
    -DLLAMA_OPENSSL=OFF `
    2>&1 | Out-String -Stream | Select-Object -Last 10
