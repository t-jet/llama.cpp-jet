$ErrorActionPreference = "Continue"
$base = "http://127.0.0.1:18113"
$slotPath = "D:\source\llama.cpp-jet\._design_docs\.test_reports\test-report-20260609-05-artifacts"
$prefix = "E13-10-v3"

$results = New-Object System.Collections.Generic.List[string]
$results.Add("=== E13-10 /slots save+restore+erase (v3) ===")

$health = Invoke-RestMethod -Uri "$base/health" -TimeoutSec 5
$results.Add("HEALTH status=$($health.status) model=$($health.model)")

# 1. Baseline GET
$slotsBefore = Invoke-RestMethod -Uri "$base/slots" -TimeoutSec 10
$slotsBefore | ConvertTo-Json -Depth 6 | Out-File "$slotPath\$prefix-1-slots-before.json"
$results.Add("BEFORE n_slots=$((@($slotsBefore)).Count)")
$results.Add("BEFORE-fields: $(($slotsBefore[0].PSObject.Properties.Name -join ',') )")

# 2. Save
$saveBody = '{}'
try {
    $saveRes = Invoke-RestMethod -Uri "$base/slots/0?action=save" -Method Post -ContentType "application/json" -Body $saveBody -TimeoutSec 30
    $saveRes | ConvertTo-Json -Depth 6 | Out-File "$slotPath\$prefix-2-save-response.json"
    $results.Add("SAVE keys: $(($saveRes.PSObject.Properties.Name -join ','))")
    $results.Add("SAVE resp: $($saveRes | ConvertTo-Json -Compress)")
} catch {
    $results.Add("SAVE-ERR $($_.Exception.Message)")
}

# 3. Generate (to populate a slot)
$genBody = @{
    prompt = "Hello, this is a hybrid cache test v3."
    n_predict = 8
    temperature = 0.0
    cache_prompt = $true
} | ConvertTo-Json -Compress
$gen = Invoke-RestMethod -Uri "$base/completion" -Method Post -ContentType "application/json" -Body $genBody -TimeoutSec 60
$gen | ConvertTo-Json -Depth 6 | Out-File "$slotPath\$prefix-3-generation.json"
$results.Add("GEN content=$($gen.content) cache_n=$($gen.timings.cache_n)")
$genFields = ($gen.PSObject.Properties.Name -join ',')
$results.Add("GEN keys: $genFields")

# 4. Restore
$restoreBody = @{ filename = "slot_0.bin" } | ConvertTo-Json -Compress
try {
    $restoreRes = Invoke-RestMethod -Uri "$base/slots/0?action=restore" -Method Post -ContentType "application/json" -Body $restoreBody -TimeoutSec 30
    $restoreRes | ConvertTo-Json -Depth 6 | Out-File "$slotPath\$prefix-4-restore-response.json"
    $results.Add("RESTORE keys: $(($restoreRes.PSObject.Properties.Name -join ','))")
    $results.Add("RESTORE resp: $($restoreRes | ConvertTo-Json -Compress)")
} catch {
    $results.Add("RESTORE-ERR $($_.Exception.Message)")
}

# 5. Erase
try {
    $eraseRes = Invoke-RestMethod -Uri "$base/slots/0?action=erase" -Method Post -ContentType "application/json" -Body $saveBody -TimeoutSec 30
    $eraseRes | ConvertTo-Json -Depth 6 | Out-File "$slotPath\$prefix-5-erase-response.json"
    $results.Add("ERASE keys: $(($eraseRes.PSObject.Properties.Name -join ','))")
    $results.Add("ERASE resp: $($eraseRes | ConvertTo-Json -Compress)")
} catch {
    $results.Add("ERASE-ERR $($_.Exception.Message)")
}

# 6. Final GET
$slotsFinal = Invoke-RestMethod -Uri "$base/slots" -TimeoutSec 10
$slotsFinal | ConvertTo-Json -Depth 6 | Out-File "$slotPath\$prefix-6-slots-final.json"
$results.Add("FINAL n_slots=$((@($slotsFinal)).Count)")
$results.Add("FINAL-fields: $(($slotsFinal[0].PSObject.Properties.Name -join ',') )")

$results | ForEach-Object { $_ } | Out-File "$slotPath\$prefix-results.txt" -Encoding utf8
Write-Host "E13-10-v3-DONE"
