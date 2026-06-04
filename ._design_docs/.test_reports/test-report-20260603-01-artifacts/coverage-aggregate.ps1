#requires -Version 5
# Parse all cobertura XMLs and aggregate per-file line coverage for the hybrid
# denominator. Report combined percentage and per-file percentages.
$ErrorActionPreference = 'Stop'

$art = "D:\source\llama.cpp-jet\._design_docs\.test_reports\test-report-20260603-01-artifacts"
$covDir = Join-Path $art 'coverage'

# Files considered part of the hybrid denominator.
$denominator = @(
    'server-cache-hybrid.cpp'
    'server-cache-hybrid.h'
    'server-cache-controller.cpp'
    'server-cache-controller.h'
    'server-cache-store-cold.cpp'
    'server-cache-store-cold.h'
    'server-cache-policy-lru.cpp'
    'server-cache-graph.cpp'
    'server-cache-graph.h'
    'server-cache-io-worker.cpp'
    'server-cache-legacy.h'
    'server-cache-legacy.cpp'
    'server-context.cpp'
    'server-context.h'
    'test-cache-controller.cpp'
    'test-step10-metrics.cpp'
    'test-stage10-cold-store-hardening.cpp'
    'test-step6-demotion-protocol.cpp'
    'test-step7-promotion-protocol.cpp'
    'test-step11-test-hooks-fault-injection.cpp'
    'test-step12-branch-graph.cpp'
    'test-step13-stage8.cpp'
)

$outLines = @()
$outLines += '# Coverage summary'
$outLines += ''
$outLines += "Denominator: hybrid sources and the 8 focused test files."
$outLines += "Source: OpenCppCoverage Cobertura XML, line-rate (branch-rate is 0 because OpenCppCoverage does not produce branch coverage)."
$outLines += "Fallback reason: line coverage is used because LLVM source-based coverage on the MSVC build requires clang-cl + clang_rt.profile, which fails to link cleanly due to MSVC ABI and template instantiation differences on this host (see log entries cov-configure.log and cov-build.log). GCOV-style fallback via OpenCppCoverage was used instead."
$outLines += ''

$totalCovered = 0
$totalValid = 0

# Process each cobertura XML.
$xmls = Get-ChildItem $covDir -Filter "cobertura-*.xml" | Sort-Object Name
foreach ($xml in $xmls) {
    $testName = $xml.BaseName -replace '^cobertura-\d+-', ''
    [xml] $data = Get-Content $xml.FullName -Raw
    $root = $data.coverage
    $rootCovered = [int]$root.lines_covered
    $rootValid = [int]$root.lines_valid
    $rootRate = [double]$root.'line-rate'
    $outLines += "## $testName"
    $outLines += ""
    $outLines += "- Aggregate line rate: $rootRate"
    $outLines += "- Lines covered: $rootCovered / $rootValid"
    $outLines += ""
    $outLines += "| File | Line rate | Covered | Valid |"
    $outLines += "| --- | --- | --- | --- |"
    foreach ($class in $data.coverage.packages.package.classes.class) {
        $name = $class.filename
        $base = Split-Path $name -Leaf
        if ($denominator -contains $base) {
            $rate = [math]::Round([double]$class.'line-rate', 4)
            $covered = 0
            $valid = 0
            if ($class.lines -and $class.lines.line) {
                foreach ($line in $class.lines.line) {
                    $hits = [int]$line.'hits'
                    $valid++
                    if ($hits -gt 0) { $covered++ }
                }
            }
            $outLines += "| $base | $rate | $covered | $valid |"
        }
    }
    $outLines += ""
}

# Compute combined denominator line rate.
$combined = @{covered = 0; valid = 0}
$combinedLines = @()
foreach ($xml in $xmls) {
    [xml] $data = Get-Content $xml.FullName -Raw
    foreach ($class in $data.coverage.packages.package.classes.class) {
        $name = $class.filename
        $base = Split-Path $name -Leaf
        if ($denominator -contains $base) {
            if ($class.lines -and $class.lines.line) {
                foreach ($line in $class.lines.line) {
                    $hits = [int]$line.'hits'
                    $combined.valid++
                    if ($hits -gt 0) { $combined.covered++ }
                }
            }
        }
    }
}
if ($combined.valid -gt 0) {
    $combinedRate = $combined.covered / $combined.valid
    $outLines += "## Combined denominator (sum across all 8 coverage runs)"
    $outLines += ""
    $outLines += "- Combined line rate: $([math]::Round($combinedRate, 4))"
    $outLines += "- Combined covered: $($combined.covered) / $($combined.valid)"
    $outLines += "- 80% threshold: $(if ($combinedRate -ge 0.8) { 'PASS' } else { 'FAIL' })"
}

$outPath = Join-Path $art 'coverage-summary.md'
$outLines | Out-File -FilePath $outPath -Encoding utf8
"wrote: $outPath"
Get-Content $outPath
