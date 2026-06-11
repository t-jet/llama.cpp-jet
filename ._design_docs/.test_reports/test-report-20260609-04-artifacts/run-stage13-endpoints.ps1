param(
    [string] $BuildDir = "build",
    [string] $ModelPath = "._test_models\Qwen3-0.6B-GGUF\Qwen3-0.6B-Q8_0.gguf",
    [string] $VlModelPath = "._test_models\Qwen2.5-VL-3B-Instruct-GGUF\Qwen2.5-VL-3B-Instruct-Q6_K.gguf",
    [string] $VlMmprojPath = "._test_models\Qwen2.5-VL-3B-Instruct-GGUF\mmproj-model-f16.gguf",
    [string] $OutDir = "._design_docs\.test_reports\test-report-20260609-04-artifacts"
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path ".").Path
$out = Join-Path $root $OutDir
New-Item -ItemType Directory -Force -Path $out | Out-Null
$serverExe = Join-Path $root "$BuildDir\bin\Release\llama-server.exe"
$testExe = Join-Path $root "$BuildDir\bin\Release\test-cache-controller.exe"
$model = Join-Path $root $ModelPath
$vlModel = Join-Path $root $VlModelPath
$vlMmproj = Join-Path $root $VlMmprojPath
$slotDir = Join-Path $out "slots"
New-Item -ItemType Directory -Force -Path $slotDir | Out-Null

function Save-Text($Name, $Text) {
    [System.IO.File]::WriteAllText((Join-Path $out $Name), $Text, [System.Text.UTF8Encoding]::new($false))
}

function Json($Obj) {
    return ($Obj | ConvertTo-Json -Depth 30 -Compress)
}

function Start-StageServer($Name, [string[]] $ServerArgs, [int] $Port) {
    $stdout = Join-Path $out "$Name.stdout.log"
    $stderr = Join-Path $out "$Name.stderr.log"
    Save-Text "$Name.args.txt" (($ServerArgs -join " ") + "`n")
    $p = Start-Process -FilePath $serverExe -ArgumentList $ServerArgs -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr -WindowStyle Hidden
    $base = "http://127.0.0.1:$Port"
    $deadline = (Get-Date).AddSeconds(90)
    do {
        Start-Sleep -Milliseconds 500
        if ($p.HasExited) { throw "server $Name exited early rc=$($p.ExitCode)" }
        try {
            Invoke-WebRequest -Uri "$base/health" -Method Get -TimeoutSec 2 | Out-Null
            return @{ Process = $p; Base = $base; Name = $Name }
        } catch {}
    } while ((Get-Date) -lt $deadline)
    throw "server $Name did not become healthy"
}

function Stop-StageServer($Srv) {
    if ($null -ne $Srv -and $null -ne $Srv.Process -and -not $Srv.Process.HasExited) {
        Stop-Process -Id $Srv.Process.Id -Force
        $Srv.Process.WaitForExit()
    }
}

function Invoke-StageJson($Srv, $Row, $Path, $Body, [string] $Method = "Post") {
    $prefix = "$Row-$($Path.Trim('/') -replace '/', '_')"
    Save-Text "$prefix.request.json" (Json $Body)
    try {
        $r = Invoke-WebRequest -Uri "$($Srv.Base)$Path" -Method $Method -ContentType "application/json" -Body (Json $Body) -TimeoutSec 60
        Save-Text "$prefix.response.json" $r.Content
        return @{ Status = [int] $r.StatusCode; Body = $r.Content; Error = "" }
    } catch {
        $resp = $_.Exception.Response
        $status = if ($resp) { [int] $resp.StatusCode } else { -1 }
        $content = ""
        if ($resp) {
            $reader = [System.IO.StreamReader]::new($resp.GetResponseStream())
            $content = $reader.ReadToEnd()
        } else {
            $content = $_.Exception.Message
        }
        Save-Text "$prefix.response.json" $content
        return @{ Status = $status; Body = $content; Error = $_.Exception.Message }
    }
}

function Capture-Metrics($Srv, $Name) {
    try {
        $m = Invoke-WebRequest -Uri "$($Srv.Base)/metrics" -Method Get -TimeoutSec 10
        Save-Text "$Name.metrics.txt" $m.Content
        return $m.Content
    } catch {
        Save-Text "$Name.metrics.txt" $_.Exception.Message
        return ""
    }
}

$summary = [ordered]@{
    timestamp = (Get-Date).ToString("o")
    server_exe = $serverExe
    test_exe = $testExe
    model = $model
    vl_model = $vlModel
    vl_mmproj = $vlMmproj
    rows = @()
}

if (Test-Path $testExe) {
    & $testExe *> (Join-Path $out "test-cache-controller.log")
    $summary.test_cache_controller_rc = $LASTEXITCODE
} else {
    Save-Text "test-cache-controller.blocked.txt" "Missing focused binary at $testExe. Direct rebuild log shows LINK : fatal error LNK1104: cannot open file 'D:\source\llama.cpp-jet\build\bin\Release\test-cache-controller.exe'."
    $summary.test_cache_controller_rc = "BLOCKED"
}

$srv = $null
try {
    $args = @(
        "--model", $model, "--host", "127.0.0.1", "--port", "8613",
        "--cache-mode", "hybrid", "--cache-ram", "64", "--metrics",
        "--parallel", "1", "--ctx-size", "1024", "--n-predict", "4",
        "--temp", "0", "--seed", "123", "--slot-save-path", $slotDir
    )
    $srv = Start-StageServer "text-server" $args 8613

    $props = Invoke-WebRequest -Uri "$($srv.Base)/props" -Method Get -TimeoutSec 10
    Save-Text "route-props.json" $props.Content

    $plain = @{ prompt = "Stage13 plain prompt alpha beta gamma"; n_predict = 4; temperature = 0; seed = 123; cache_prompt = $true }
    Invoke-StageJson $srv "E13-01a-first" "/completion" $plain | Out-Null
    Invoke-StageJson $srv "E13-01a-second" "/completion" $plain | Out-Null
    Capture-Metrics $srv "E13-01a" | Out-Null

    $legacyArgs = @(
        "--model", $model, "--host", "127.0.0.1", "--port", "8614",
        "--cache-mode", "legacy", "--metrics", "--parallel", "1",
        "--ctx-size", "1024", "--n-predict", "4", "--temp", "0", "--seed", "123"
    )
    $legacy = Start-StageServer "legacy-control" $legacyArgs 8614
    try {
        Invoke-StageJson $legacy "E13-01a-legacy-control" "/completion" $plain | Out-Null
        Capture-Metrics $legacy "E13-01a-legacy-control" | Out-Null
    } finally { Stop-StageServer $legacy }

    $tokReq = @{ content = "Stage13 token array prompt alpha beta gamma"; add_special = $true }
    $tok = Invoke-StageJson $srv "tokenize" "/tokenize" $tokReq
    $tokens = (($tok.Body | ConvertFrom-Json).tokens)
    $tokenBody = @{ prompt = @($tokens); n_predict = 4; temperature = 0; seed = 123; cache_prompt = $true }
    Invoke-StageJson $srv "E13-01b-first" "/completion" $tokenBody | Out-Null
    Invoke-StageJson $srv "E13-01b-second" "/completion" $tokenBody | Out-Null
    Capture-Metrics $srv "E13-01b" | Out-Null

    Invoke-StageJson $srv "E13-01d-first" "/completions" $plain | Out-Null
    Invoke-StageJson $srv "E13-01d-second" "/completions" $plain | Out-Null
    Capture-Metrics $srv "E13-01d" | Out-Null

    $oaic = @{ model = "local"; prompt = "Stage13 OpenAI completions alpha beta"; max_tokens = 4; temperature = 0; seed = 123 }
    Invoke-StageJson $srv "E13-02-first" "/v1/completions" $oaic | Out-Null
    Invoke-StageJson $srv "E13-02-second" "/v1/completions" $oaic | Out-Null
    Capture-Metrics $srv "E13-02" | Out-Null

    $chat = @{ model = "local"; messages = @(@{ role = "system"; content = "short answers" }, @{ role = "user"; content = "Stage13 chat alpha beta" }); max_tokens = 4; temperature = 0; seed = 123 }
    Invoke-StageJson $srv "E13-03-v1" "/v1/chat/completions" $chat | Out-Null
    Invoke-StageJson $srv "E13-03-alias" "/chat/completions" $chat | Out-Null
    Capture-Metrics $srv "E13-03" | Out-Null

    $respString = @{ model = "local"; input = "Stage13 responses string alpha"; max_output_tokens = 4; temperature = 0 }
    $respList = @{ model = "local"; input = @(@{ role = "user"; content = @(@{ type = "input_text"; text = "Stage13 responses list alpha" }) }); max_output_tokens = 4; temperature = 0 }
    Invoke-StageJson $srv "E13-04-v1-string" "/v1/responses" $respString | Out-Null
    Invoke-StageJson $srv "E13-04-alias-list" "/responses" $respList | Out-Null
    Capture-Metrics $srv "E13-04" | Out-Null

    $anth = @{ model = "local"; system = "short answers"; messages = @(@{ role = "user"; content = "Stage13 anthropic alpha" }); max_tokens = 4; temperature = 0 }
    Invoke-StageJson $srv "E13-05" "/v1/messages" $anth | Out-Null
    Capture-Metrics $srv "E13-05" | Out-Null
    Invoke-StageJson $srv "E13-06" "/v1/messages/count_tokens" $anth | Out-Null
    Capture-Metrics $srv "E13-06" | Out-Null

    $audioProbe = @{ model = "local"; file = "missing"; response_format = "json" }
    Invoke-StageJson $srv "E13-07" "/v1/audio/transcriptions" $audioProbe | Out-Null
    Invoke-StageJson $srv "E13-08" "/audio/transcriptions" $audioProbe | Out-Null

    $slots0 = Invoke-WebRequest -Uri "$($srv.Base)/slots" -Method Get -TimeoutSec 10
    Save-Text "E13-10-slots-before.response.json" $slots0.Content
    Invoke-StageJson $srv "E13-10-save" "/slots/0?action=save" @{ filename = "stage13.slot" } | Out-Null
    Invoke-StageJson $srv "E13-10-restore" "/slots/0?action=restore" @{ filename = "stage13.slot" } | Out-Null
    Invoke-StageJson $srv "E13-10-erase" "/slots/0?action=erase" @{} | Out-Null
    $slots1 = Invoke-WebRequest -Uri "$($srv.Base)/slots" -Method Get -TimeoutSec 10
    Save-Text "E13-10-slots-after.response.json" $slots1.Content
    Capture-Metrics $srv "E13-10" | Out-Null

    $marker = @{ prompt = "Stage13 marker leak <|reserved_special_token_0|> alpha"; n_predict = 4; temperature = 0; seed = 123; cache_prompt = $true }
    Invoke-StageJson $srv "E13-11" "/completion" $marker | Out-Null
    Capture-Metrics $srv "E13-11" | Out-Null

    $degraded = @{ model = "local"; input = @(@{ role = "user"; content = @(@{ type = "input_text"; text = "Stage13 degraded alpha" }, @{ type = "input_text"; text = "second text part" }) }); max_output_tokens = 4; temperature = 0 }
    Invoke-StageJson $srv "E13-14" "/v1/responses" $degraded | Out-Null
    Capture-Metrics $srv "E13-14" | Out-Null

} finally {
    Stop-StageServer $srv
}

$emb = $null
try {
    $embArgs = @(
        "--model", $model, "--host", "127.0.0.1", "--port", "8615",
        "--cache-mode", "hybrid", "--cache-ram", "64", "--metrics",
        "--parallel", "1", "--ctx-size", "512", "--embedding", "--pooling", "mean"
    )
    $emb = Start-StageServer "embedding-server" $embArgs 8615
    $embBody = @{ content = "Stage13 embedding alpha" }
    Invoke-StageJson $emb "E13-09-native-embedding" "/embedding" $embBody | Out-Null
    Invoke-StageJson $emb "E13-09-native-embeddings" "/embeddings" $embBody | Out-Null
    $embOai = @{ model = "local"; input = "Stage13 embedding alpha" }
    Invoke-StageJson $emb "E13-09-oai" "/v1/embeddings" $embOai | Out-Null
    Capture-Metrics $emb "E13-09" | Out-Null
} catch {
    Save-Text "E13-09-embedding-server.blocked.txt" $_.Exception.Message
} finally {
    Stop-StageServer $emb
}

$mm = $null
try {
    $imgBytes = [System.IO.File]::ReadAllBytes((Join-Path $root "tools\mtmd\test-1.jpeg"))
    $img64 = [Convert]::ToBase64String($imgBytes)
    $mmArgs = @(
        "--model", $vlModel, "--mmproj", $vlMmproj, "--host", "127.0.0.1", "--port", "8616",
        "--cache-mode", "hybrid", "--cache-ram", "128", "--metrics",
        "--parallel", "1", "--ctx-size", "1024", "--n-predict", "4",
        "--temp", "0", "--seed", "123"
    )
    $mm = Start-StageServer "multimodal-server" $mmArgs 8616
    $mmBody = @{ prompt = "Stage13 multimodal <__media__> alpha"; multimodal_data = @($img64); n_predict = 4; temperature = 0; seed = 123; cache_prompt = $true }
    Invoke-StageJson $mm "E13-01c-first" "/completion" $mmBody | Out-Null
    Invoke-StageJson $mm "E13-01c-second" "/completion" $mmBody | Out-Null
    Capture-Metrics $mm "E13-01c" | Out-Null
} catch {
    Save-Text "E13-01c-multimodal.blocked.txt" $_.Exception.Message
} finally {
    Stop-StageServer $mm
}

Save-Text "stage13-helper-summary.json" (Json $summary)
