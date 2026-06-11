$ErrorActionPreference = 'Continue'
$Root = (Resolve-Path '.').Path
$Art = (Resolve-Path '._design_docs/.test_reports/test-report-20260610-03-artifacts').Path
$env:PATH = 'D:\app\cuda_13_2\bin\x64;D:\app\cuda_13_2\bin;' + $env:PATH
$ServerExe = Join-Path $Root 'build-cuda-stage13/bin/Release/llama-server.exe'
$OmniModel = Join-Path $Root '._test_models/Qwen2.5-Omni-3B-GGUF/Qwen2.5-Omni-3B-f16.gguf'
$OmniMmproj = Join-Path $Root '._test_models/Qwen2.5-Omni-3B-GGUF/mmproj-Qwen2.5-Omni-3B-f16.gguf'
$QwenModel = Join-Path $Root '._test_models/Qwen3-0.6B-GGUF/Qwen3-0.6B-Q8_0.gguf'
$Audio = Join-Path $Root '.media/sample-speech-5m.mp3'
$Video = Join-Path $Root '.media/sample-5s.mp4'
function SaveText($Name, $Text) { $Text | Set-Content -LiteralPath (Join-Path $Art $Name) -Encoding ascii }
function AppendText($Name, $Text) { $Text | Add-Content -LiteralPath (Join-Path $Art $Name) -Encoding ascii }
function Wait-Ready($Base, $Proc, $Prefix, $MaxSeconds) {
    $ready = $false
    for ($i = 0; $i -lt [Math]::Ceiling($MaxSeconds / 2); $i++) {
        if ($Proc.HasExited) { break }
        try {
            Invoke-RestMethod -Method Get -Uri "$Base/health" -TimeoutSec 2 | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath (Join-Path $Art "$Prefix-health-ready.json") -Encoding ascii
            try { Invoke-RestMethod -Method Get -Uri "$Base/props" -TimeoutSec 10 | ConvertTo-Json -Depth 40 | Set-Content -LiteralPath (Join-Path $Art "$Prefix-props.json") -Encoding ascii } catch { SaveText "$Prefix-props-error.txt" $_.ToString() }
            $ready = $true
            break
        } catch { Start-Sleep -Seconds 2 }
    }
    return $ready
}
function Start-Server($Prefix, $Port, $ServerArgs) {
    $base = "http://127.0.0.1:$Port"
    $out = Join-Path $Art "$Prefix-server.out.log"
    $err = Join-Path $Art "$Prefix-server.err.log"
    SaveText "$Prefix-timestamps.txt" ("start=" + (Get-Date -Format o))
    SaveText "$Prefix-server-command.txt" ($ServerExe + ' ' + ($ServerArgs -join ' '))
    $proc = Start-Process -FilePath $ServerExe -ArgumentList $ServerArgs -RedirectStandardOutput $out -RedirectStandardError $err -PassThru -WindowStyle Hidden
    AppendText "$Prefix-timestamps.txt" "pid=$($proc.Id)"
    return @{ Proc = $proc; Base = $base; Prefix = $Prefix }
}
function Stop-Server($State) {
    $proc = $State.Proc
    $prefix = $State.Prefix
    AppendText "$prefix-timestamps.txt" ("end=" + (Get-Date -Format o))
    if ($null -ne $proc -and -not $proc.HasExited) {
        Stop-Process -Id $proc.Id -Force
        AppendText "$prefix-timestamps.txt" 'stopped=true'
    } elseif ($null -ne $proc) {
        AppendText "$prefix-timestamps.txt" "server_exit=$($proc.ExitCode)"
    }
}
function Invoke-JsonPost($Base, $Route, $BodyObj, $Row, $TimeoutSec) {
    $req = Join-Path $Art "$Row-request.json"
    $BodyObj | ConvertTo-Json -Depth 80 | Set-Content -LiteralPath $req -Encoding ascii
    try {
        $body = Get-Content -Raw -LiteralPath $req
        $res = Invoke-RestMethod -Method Post -Uri "$Base$Route" -ContentType 'application/json' -Body $body -TimeoutSec $TimeoutSec
        $res | ConvertTo-Json -Depth 80 | Set-Content -LiteralPath (Join-Path $Art "$Row-response.json") -Encoding ascii
        SaveText "$Row-status.txt" 'status=OK'
    } catch {
        SaveText "$Row-error.txt" $_.ToString()
        SaveText "$Row-status.txt" 'status=ERROR'
    }
}
function Invoke-AudioCurl($Base, $Route, $Row) {
    $curl = (Get-Command curl.exe).Source
    SaveText "$Row-command.txt" "curl.exe -sS -X POST $Base$Route -F file=@$Audio -F model=local -F response_format=json -F max_tokens=8 -F temperature=0"
    & $curl -sS -X POST "$Base$Route" -F "file=@$Audio" -F "model=local" -F "response_format=json" -F "max_tokens=8" -F "temperature=0" -o (Join-Path $Art "$Row-response.json") 2> (Join-Path $Art "$Row-curl.err.txt")
    SaveText "$Row-status.txt" "exit=$LASTEXITCODE"
}
# E13-01c native multimodal /completion with Omni and documented marker.
$port = 18231
$serverArgs = @('--model', $OmniModel, '--mmproj', $OmniMmproj, '--host', '127.0.0.1', '--port', "$port", '--cache-mode', 'hybrid', '--cache-ram', '100', '--ctx-size', '4096', '--parallel', '1', '--metrics', '--slots', '--log-verbosity', '5', '--n-gpu-layers', '999')
$state = Start-Server 'e13-01c-omni-native' $port $serverArgs
$ready = Wait-Ready $state.Base $state.Proc $state.Prefix 480
AppendText 'e13-01c-omni-native-timestamps.txt' "ready=$ready"
if ($ready) {
    try { Invoke-RestMethod -Method Get -Uri "$($state.Base)/metrics" -TimeoutSec 10 | Set-Content -LiteralPath (Join-Path $Art 'e13-01c-omni-native-metrics-start.txt') -Encoding ascii } catch { SaveText 'e13-01c-omni-native-metrics-start-error.txt' $_.ToString() }
    $b64 = [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($Video))
    $body = @{ prompt = @{ prompt_string = 'Describe this media in one short sentence. <__media__>'; multimodal_data = @($b64) }; n_predict = 8; temperature = 0; cache_prompt = $true }
    Invoke-JsonPost $state.Base '/completion' $body 'E13-01c-omni-native-1' 900
    Invoke-JsonPost $state.Base '/completion' $body 'E13-01c-omni-native-2' 900
    try { Invoke-RestMethod -Method Get -Uri "$($state.Base)/metrics" -TimeoutSec 10 | Set-Content -LiteralPath (Join-Path $Art 'e13-01c-omni-native-metrics-end.txt') -Encoding ascii } catch { SaveText 'e13-01c-omni-native-metrics-end-error.txt' $_.ToString() }
}
Stop-Server $state
# E13-07 /v1/audio/transcriptions first in fresh Omni process.
$port = 18232
$serverArgs = @('--model', $OmniModel, '--mmproj', $OmniMmproj, '--host', '127.0.0.1', '--port', "$port", '--cache-mode', 'hybrid', '--cache-ram', '100', '--ctx-size', '4096', '--parallel', '1', '--metrics', '--slots', '--log-verbosity', '5', '--n-gpu-layers', '999')
$state = Start-Server 'e13-07-omni-v1-audio' $port $serverArgs
$ready = Wait-Ready $state.Base $state.Proc $state.Prefix 480
AppendText 'e13-07-omni-v1-audio-timestamps.txt' "ready=$ready"
if ($ready) { Invoke-AudioCurl $state.Base '/v1/audio/transcriptions' 'E13-07-v1-audio-transcriptions'; try { Invoke-RestMethod -Method Get -Uri "$($state.Base)/metrics" -TimeoutSec 10 | Set-Content -LiteralPath (Join-Path $Art 'e13-07-omni-v1-audio-metrics-end.txt') -Encoding ascii } catch { SaveText 'e13-07-omni-v1-audio-metrics-end-error.txt' $_.ToString() } }
Stop-Server $state
# E13-08 alias first in isolated Omni process.
$port = 18233
$serverArgs = @('--model', $OmniModel, '--mmproj', $OmniMmproj, '--host', '127.0.0.1', '--port', "$port", '--cache-mode', 'hybrid', '--cache-ram', '100', '--ctx-size', '4096', '--parallel', '1', '--metrics', '--slots', '--log-verbosity', '5', '--n-gpu-layers', '999')
$state = Start-Server 'e13-08-omni-alias-audio' $port $serverArgs
$ready = Wait-Ready $state.Base $state.Proc $state.Prefix 480
AppendText 'e13-08-omni-alias-audio-timestamps.txt' "ready=$ready"
if ($ready) { Invoke-AudioCurl $state.Base '/audio/transcriptions' 'E13-08-audio-transcriptions-alias'; try { Invoke-RestMethod -Method Get -Uri "$($state.Base)/metrics" -TimeoutSec 10 | Set-Content -LiteralPath (Join-Path $Art 'e13-08-omni-alias-audio-metrics-end.txt') -Encoding ascii } catch { SaveText 'e13-08-omni-alias-audio-metrics-end-error.txt' $_.ToString() } }
Stop-Server $state
# E13-14 native and chat degraded fallback, same fresh text model process.
$port = 18234
$serverArgs = @('--model', $QwenModel, '--host', '127.0.0.1', '--port', "$port", '--cache-mode', 'hybrid', '--cache-ram', '100', '--ctx-size', '1024', '--parallel', '1', '--metrics', '--slots', '--log-verbosity', '5', '--n-gpu-layers', '999')
$state = Start-Server 'e13-14-qwen-degraded' $port $serverArgs
$ready = Wait-Ready $state.Base $state.Proc $state.Prefix 300
AppendText 'e13-14-qwen-degraded-timestamps.txt' "ready=$ready"
if ($ready) {
    $secret1 = 'STAGE13_SECRET_DO_NOT_LEAK_NATIVE tool_arg=password123 path=C:\secret\cache.bin checksum=abcdef rawmedia=bytes'
    $body1 = @{ prompt = $secret1; n_predict = 2; temperature = 0; cache_prompt = $true }
    Invoke-JsonPost $state.Base '/completion' $body1 'E13-14-native-degraded' 300
    $secret2 = 'STAGE13_SECRET_DO_NOT_LEAK_CHAT tool_arg=password123 path=C:\secret\chat.bin checksum=abcdef rawmedia=bytes'
    $body2 = @{ messages = @(@{ role='system'; content='Answer briefly.' }, @{ role='user'; content=$secret2 }); max_tokens = 2; temperature = 0; stream = $false }
    Invoke-JsonPost $state.Base '/v1/chat/completions' $body2 'E13-14-chat-degraded' 300
    try { Invoke-RestMethod -Method Get -Uri "$($state.Base)/metrics" -TimeoutSec 10 | Set-Content -LiteralPath (Join-Path $Art 'e13-14-qwen-degraded-metrics-end.txt') -Encoding ascii } catch { SaveText 'e13-14-qwen-degraded-metrics-end-error.txt' $_.ToString() }
}
Stop-Server $state
