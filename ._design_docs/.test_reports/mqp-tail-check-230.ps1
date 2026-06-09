$f = 'D:\source\llama.cpp-jet\._design_docs\.test_reports\test-report-20260607-08-V1-RECONSTRUCTED.md'
$lines = (Get-Content $f)
Write-Output ("Total lines: {0}" -f $lines.Count)
$last5 = $lines | Select-Object -Last 5
$last5 | ForEach-Object { Write-Output ("[{0}] {1}" -f $lines.IndexOf($$_)+1, $_) }
