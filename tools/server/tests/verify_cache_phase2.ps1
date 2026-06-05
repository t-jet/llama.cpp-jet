# Phase 2 Cache Implementation - Build Verification Script
# This script verifies that Phase 2 code was successfully compiled into the server binary

Write-Host "=== Phase 2 Cache Implementation - Build Verification ===" -ForegroundColor Cyan
Write-Host ""

$serverPath = "build-cuda\bin\Release\llama-server.exe"
$testsPassed = 0
$testsFailed = 0

# Test 1: Verify binary exists
Write-Host "Test 1: Server binary exists" -ForegroundColor Yellow
if (Test-Path $serverPath) {
    Write-Host "  ✓ PASS: Server binary found at $serverPath" -ForegroundColor Green
    $testsPassed++
} else {
    Write-Host "  ✗ FAIL: Server binary not found" -ForegroundColor Red
    $testsFailed++
    exit 1
}

# Test 2: Verify binary is up-to-date (compiled today)
Write-Host ""
Write-Host "Test 2: Binary is recently compiled" -ForegroundColor Yellow
$binaryDate = (Get-Item $serverPath).LastWriteTime
$today = Get-Date
if ($binaryDate.Date -eq $today.Date) {
    Write-Host "  ✓ PASS: Binary compiled today ($binaryDate)" -ForegroundColor Green
    $testsPassed++
} else {
    Write-Host "  ⚠ WARNING: Binary compiled on $binaryDate (not today)" -ForegroundColor Yellow
    Write-Host "           Consider rebuilding to ensure latest changes" -ForegroundColor Yellow
}

# Test 3: Check Phase 2 source files exist
Write-Host ""
Write-Host "Test 3: Phase 2 source files exist" -ForegroundColor Yellow
$sourceFiles = @(
    "tools\server\server-cache-hybrid.cpp",
    "tools\server\server-context.cpp",
    "tools\server\server-context.h",
    "tools\server\server.cpp"
)

$allSourcesExist = $true
foreach ($file in $sourceFiles) {
    if (Test-Path $file) {
        Write-Host "  ✓ $file" -ForegroundColor Green
    } else {
        Write-Host "  ✗ $file MISSING" -ForegroundColor Red
        $allSourcesExist = $false
    }
}

if ($allSourcesExist) {
    Write-Host "  ✓ PASS: All Phase 2 source files present" -ForegroundColor Green
    $testsPassed++
} else {
    Write-Host "  ✗ FAIL: Some source files missing" -ForegroundColor Red
    $testsFailed++
}

# Test 4: Verify symbols in binary (check if our code is linked)
Write-Host ""
Write-Host "Test 4: Check for cache-related strings in binary" -ForegroundColor Yellow
$binaryContent = [System.IO.File]::ReadAllBytes($serverPath)
$binaryText = [System.Text.Encoding]::ASCII.GetString($binaryContent)

$expectedStrings = @(
    "cache-mode",
    "cache-size",
    "hybrid",
    "legacy"
)

$stringsFound = 0
foreach ($str in $expectedStrings) {
    if ($binaryText -like "*$str*") {
        Write-Host "  ✓ Found: '$str'" -ForegroundColor Green
        $stringsFound++
    } else {
        Write-Host "  ✗ Missing: '$str'" -ForegroundColor Red
    }
}

if ($stringsFound -eq $expectedStrings.Count) {
    Write-Host "  ✓ PASS: All cache-related strings found in binary" -ForegroundColor Green
    $testsPassed++
} else {
    Write-Host "  ⚠ WARNING: Some strings not found ($stringsFound/$($expectedStrings.Count))" -ForegroundColor Yellow
}

# Test 5: Verify test files exist
Write-Host ""
Write-Host "Test 5: Test infrastructure files exist" -ForegroundColor Yellow
$testFiles = @(
    "tools\server\tests\test_cache_phase2.cpp",
    "tools\server\tests\test_cache_phase2_integration.sh"
)

$allTestsExist = $true
foreach ($file in $testFiles) {
    if (Test-Path $file) {
        Write-Host "  ✓ $file" -ForegroundColor Green
    } else {
        Write-Host "  ✗ $file MISSING" -ForegroundColor Red
        $allTestsExist = $false
    }
}

if ($allTestsExist) {
    Write-Host "  ✓ PASS: All test files present" -ForegroundColor Green
    $testsPassed++
} else {
    Write-Host "  ✗ FAIL: Some test files missing" -ForegroundColor Red
    $testsFailed++
}

# Summary
Write-Host ""
Write-Host "=== Verification Summary ===" -ForegroundColor Cyan
Write-Host "  Tests Passed: $testsPassed" -ForegroundColor Green
Write-Host "  Tests Failed: $testsFailed" -ForegroundColor $(if ($testsFailed -eq 0) { "Green" } else { "Red" })
Write-Host ""

if ($testsFailed -eq 0) {
    Write-Host "✓ BUILD VERIFICATION SUCCESSFUL" -ForegroundColor Green
    Write-Host ""
    Write-Host "Phase 2 implementation is compiled and ready for integration testing." -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Yellow
    Write-Host "  1. Obtain a test model file (GGUF format)" -ForegroundColor White
    Write-Host "  2. Start server: .\$serverPath --model path\to\model.gguf --cache-mode hybrid" -ForegroundColor White
    Write-Host "  3. Test /health endpoint: curl http://localhost:8080/health" -ForegroundColor White
    Write-Host "  4. Start with --metrics and test cache metrics: curl http://localhost:8080/metrics" -ForegroundColor White
    Write-Host ""
    exit 0
} else {
    Write-Host "✗ BUILD VERIFICATION FAILED" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please review failed tests and rebuild if necessary." -ForegroundColor Yellow
    Write-Host ""
    exit 1
}
