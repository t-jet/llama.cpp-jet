$ErrorActionPreference = "Continue"
$base = "http://127.0.0.1:18113"
$slotPath = "D:\source\llama.cpp-jet\._design_docs\.test_reports\test-report-20260609-05-artifacts"
$slotSave = "$slotPath\slots"
$prefix = "E13-10-v3c"
$slotFileName = "stage13-v3c-slot.slot"

$results = New-Object System.Collections.Generic.List[string]
$results.Add("=== E13-10 /slots save+restore+erase v3c with populated slot ===")

# 1. Baseline GET
$slotsBefore = Invoke-RestMethod -Uri "$base/slots" -TimeoutSec 10
$slotsBefore | ConvertTo-Json -Depth 6 | Out-File "$slotPath\$prefix-1-slots-before.json"
$results.Add("BEFORE n_slots=$((@($slotsBefore)).Count)")
$results.Add("BEFORE-fields: $(($slotsBefore[0].PSObject.Properties.Name -join ',') )")

# 2. Generate to populate slot 0
$genBody = @{
    prompt = "Hello, hybrid cache save+restore+erase v3c."
    n_predict = 8
    temperature = 0.0
    cache_prompt = $true
} | ConvertTo-Json -Compress
$gen = Invoke-RestMethod -Uri "$base/completion" -Method Post -ContentType "application/json" -Body $genBody -TimeoutSec 60
$gen | ConvertTo-Json -Depth 6 | Out-File "$slotPath\$prefix-2-generation.json"
$results.Add("GEN content=$($gen.content) cache_n=$($gen.timings.cache_n) tokens_cached=$($gen.tokens_cached)")

# 3. Save with filename
$saveBody = @{ filename = $slotFileName } | ConvertTo-Json -Compress
$saveRes = Invoke-RestMethod -Uri "$base/slots/0?action=save" -Method Post -ContentType "application/json" -Body $saveBody -TimeoutSec 30
$saveRes | ConvertTo-Json -Depth 6 | Out-File "$slotPath\$prefix-3-save-response.json"
$results.Add("SAVE keys: $(($saveRes.PSObject.Properties.Name -join ','))")
$results.Add("SAVE resp: $($saveRes | ConvertTo-Json -Compress)")

# 4. Restore
$restoreBody = @{ filename = $slotFileName } | ConvertTo-Json -Compress
$restoreRes = Invoke-RestMethod -Uri "$base/slots/0?action=restore" -Method Post -ContentType "application/json" -Body $restoreBody -TimeoutSec 30
$restoreRes | ConvertTo-Json -Depth 6 | Out-File "$slotPath\$prefix-4-restore-response.json"
$results.Add("RESTORE keys: $(($restoreRes.PSObject.Properties.Name -join ','))")
$results.Add("RESTORE resp: $($restoreRes | ConvertTo-Json -Compress)")

# 5. Erase
$eraseRes = Invoke-RestMethod -Uri "$base/slots/0?action=erase" -Method Post -ContentType "application/json" -Body '{}' -TimeoutSec 30
$eraseRes | ConvertTo-Json -Depth 6 | Out-File "$slotPath\$prefix-5-erase-response.json"
$results.Add("ERASE keys: $(($eraseRes.PSObject.Properties.Name -join ','))")
$results.Add("ERASE resp: $($eraseRes | ConvertTo-Json -Compress)")

# 6. Final GET
$slotsFinal = Invoke-RestMethod -Uri "$base/slots" -TimeoutSec 10
$slotsFinal | ConvertTo-Json -Depth 6 | Out-File "$slotPath\$prefix-6-slots-final.json"
$results.Add("FINAL n_slots=$((@($slotsFinal)).Count)")
$results.Add("FINAL-fields: $(($slotsFinal[0].PSObject.Properties.Name -join ',') )")

# Save the slot file list
Get-ChildItem $slotSave -ErrorAction SilentlyContinue | Select-Object Name, Length | Format-Table -AutoSize | Out-File "$slotPath\$prefix-7-slot-files.txt"

$results | ForEach-Object { $_ } | Out-File "$slotPath\$prefix-results.txt" -Encoding utf8
Write-Host "E13-10-v3c-DONE"
