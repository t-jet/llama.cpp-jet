$base = "http://127.0.0.1:18113"
$slotPath = "D:\source\llama.cpp-jet\._design_docs\.test_reports\test-report-20260609-05-artifacts"
$savePath = "$slotPath\slots"
$SlotFile = "$savePath\slot_0.bin"
$prompt = "Hello, this is a hybrid cache test."

Write-Host "=== E13-10 /slots/{id_slot}?action=... ==="
$health = Invoke-RestMethod -Uri "$base/health" -TimeoutSec 5
Write-Host "HEALTH status=$($health.status) model=$($health.model)"

$slotsBefore = Invoke-RestMethod -Uri "$base/slots" -TimeoutSec 10
$slotsBefore | ConvertTo-Json -Depth 6 | Out-File "$slotPath\E13-10-1-slots-before.json"

try {
    $saveRes = Invoke-RestMethod -Uri "$base/slots/0?action=save" -Method Post -ContentType "application/json" -Body "{}" -TimeoutSec 30 -ErrorAction Stop
    $saveRes | ConvertTo-Json -Depth 6 | Out-File "$slotPath\E13-10-2-save-response.json"
    Write-Host "SAVE-OK resp=$($saveRes | ConvertTo-Json -Compress)"
} catch {
    Write-Host "SAVE-ERR $($_.Exception.Message)"
    if ($_.Exception.Response) {
        $stream = $_.Exception.Response.GetResponseStream()
        $reader = New-Object System.IO.StreamReader($stream)
        $body2 = $reader.ReadToEnd()
        $body2 | Out-File "$slotPath\E13-10-2-save-error.txt"
    }
}

$body = @{
    prompt = $prompt
    n_predict = 8
    temperature = 0.0
    cache_prompt = $true
} | ConvertTo-Json -Compress
$gen = Invoke-RestMethod -Uri "$base/completion" -Method Post -ContentType "application/json" -Body $body -TimeoutSec 60
$gen | ConvertTo-Json -Depth 6 | Out-File "$slotPath\E13-10-3-generation.json"
Write-Host "GEN content=$($gen.content) cache_n=$($gen.timings.cache_n)"

$slotsAfterGen = Invoke-RestMethod -Uri "$base/slots" -TimeoutSec 10
$slotsAfterGen | ConvertTo-Json -Depth 6 | Out-File "$slotPath\E13-10-4-slots-after-gen.json"

try {
    $eraseRes = Invoke-RestMethod -Uri "$base/slots/0?action=erase" -Method Post -ContentType "application/json" -Body "{}" -TimeoutSec 30 -ErrorAction Stop
    $eraseRes | ConvertTo-Json -Depth 6 | Out-File "$slotPath\E13-10-5-erase-response.json"
    Write-Host "ERASE-OK resp=$($eraseRes | ConvertTo-Json -Compress)"
} catch {
    Write-Host "ERASE-ERR $($_.Exception.Message)"
    if ($_.Exception.Response) {
        $stream = $_.Exception.Response.GetResponseStream()
        $reader = New-Object System.IO.StreamReader($stream)
        $body2 = $reader.ReadToEnd()
        $body2 | Out-File "$slotPath\E13-10-5-erase-error.txt"
    }
}

$slotsAfterErase = Invoke-RestMethod -Uri "$base/slots" -TimeoutSec 10
$slotsAfterErase | ConvertTo-Json -Depth 6 | Out-File "$slotPath\E13-10-6-slots-after-erase.json"

Get-ChildItem $savePath -ErrorAction SilentlyContinue | Select-Object Name, Length | Format-Table -AutoSize | Out-File "$slotPath\E13-10-7-slot-files.txt"

$restoreBody = @{
    filename = $SlotFile
} | ConvertTo-Json -Compress
try {
    $restoreRes = Invoke-RestMethod -Uri "$base/slots/0?action=restore" -Method Post -ContentType "application/json" -Body $restoreBody -TimeoutSec 30 -ErrorAction Stop
    $restoreRes | ConvertTo-Json -Depth 6 | Out-File "$slotPath\E13-10-8-restore-response.json"
    Write-Host "RESTORE-OK resp=$($restoreRes | ConvertTo-Json -Compress)"
} catch {
    Write-Host "RESTORE-ERR $($_.Exception.Message)"
    if ($_.Exception.Response) {
        $stream = $_.Exception.Response.GetResponseStream()
        $reader = New-Object System.IO.StreamReader($stream)
        $body2 = $reader.ReadToEnd()
        $body2 | Out-File "$slotPath\E13-10-8-restore-body.txt"
    }
}

$slotsFinal = Invoke-RestMethod -Uri "$base/slots" -TimeoutSec 10
$slotsFinal | ConvertTo-Json -Depth 6 | Out-File "$slotPath\E13-10-9-slots-final.json"
Write-Host "FINAL-OK"
