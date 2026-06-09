#requires -Version 5
# kickoff-v2-bench.ps1 - short bootstrap that writes kickoff line and runs
# the V1 bench batch runner, captures stdout+stderr to v2 log.
$log = 'D:\source\llama.cpp-jet\._design_docs\.test_reports\mtp-jinja-run-20260607-V1\bench-batch-V2.log'
$now = Get-Date -Format 'o'
"$now] bench-batch-V2 kickoff" | Out-File -FilePath $log -Encoding utf8
& 'D:\source\llama.cpp-jet\._design_docs\cache-handling-test-scripts\run-v2-bench-batch.ps1' -BuildDir 'D:\source\llama.cpp-jet\build-cov' -RunRoot 'D:\source\llama.cpp-jet\._design_docs\.test_reports\mtp-jinja-run-20260607-V1' 2>&1 | Out-File -FilePath $log -Append -Encoding utf8
"rc=$LASTEXITCODE end $(Get-Date -Format 'o')" | Out-File -FilePath $log -Append -Encoding utf8
Get-Process -Name llama-server -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
'done' | Out-File -FilePath $log -Append -Encoding utf8
