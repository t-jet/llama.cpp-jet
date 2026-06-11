$url = "http://127.0.0.1:18114/completion"
$videoPath = "D:\source\llama.cpp-jet\.media\sample-5s.mp4"
$bytes = [System.IO.File]::ReadAllBytes($videoPath)
$b64 = [Convert]::ToBase64String($bytes)
$body = @{
    temperature = 0
    stream = $false
    n_predict = 16
    prompt = @{
        prompt_string = "Describe this video briefly: <__media__>"
        multimodal_data = @($b64)
    }
    cache_prompt = $true
} | ConvertTo-Json -Depth 10 -Compress
for ($i = 1; $i -le 2; $i++) {
    try {
        $r = Invoke-RestMethod -Uri $url -Method Post -ContentType "application/json" -Body $body -TimeoutSec 600 -ErrorAction Stop
        $r | ConvertTo-Json -Depth 6 | Out-File "D:\source\llama.cpp-jet\._design_docs\.test_reports\test-report-20260609-05-artifacts\E13-01c-$i.json"
        Write-Host "E13-01c-$i OK content=$($r.content) timings.cache_n=$($r.timings.cache_n) timings.prompt_n=$($r.timings.prompt_n)"
    } catch {
        $msg = $_.Exception.Message
        Write-Host "E13-01c-$i ERR $msg"
        if ($_.Exception.Response) {
            $stream = $_.Exception.Response.GetResponseStream()
            $reader = New-Object System.IO.StreamReader($stream)
            $body2 = $reader.ReadToEnd()
            $body2 | Out-File "D:\source\llama.cpp-jet\._design_docs\.test_reports\test-report-20260609-05-artifacts\E13-01c-$i-err.txt"
        }
    }
}
