param(
    [string] $Base = "http://127.0.0.1:18213",
    [string] $Row = "X",
    [string] $Path = "/v1/chat/completions",
    [string] $Method = "Post",
    [string] $Body = "{}",
    [int] $Timeout = 90
)

$ErrorActionPreference = "Stop"
$outDir = "D:\source\llama.cpp-jet\._design_docs\.test_reports\test-report-20260609-05-artifacts"
$prefix = "$Row-$($Path.Trim('/') -replace '[/?&=]', '_')"
[System.IO.File]::WriteAllText("$outDir\$prefix.request.json", $Body, [System.Text.UTF8Encoding]::new($false))

$respFile = "$outDir\$prefix.response.json"
$status = -1
$errMsg = ""

try {
    $handler = [System.Net.Http.HttpClientHandler]::new()
    $client = [System.Net.Http.HttpClient]::new($handler)
    $client.Timeout = [TimeSpan]::FromSeconds($Timeout)
    $req = [System.Net.Http.HttpRequestMessage]::new([System.Net.Http.HttpMethod]::Parse($Method), "$Base$Path")
    if ($Method -in @("Post","Put","Patch") -and -not [string]::IsNullOrEmpty($Body)) {
        $req.Content = [System.Net.Http.StringContent]::new($Body, [System.Text.Encoding]::UTF8, "application/json")
    }
    $resp = $client.SendAsync($req).GetAwaiter().GetResult()
    $status = [int]$resp.StatusCode
    $content = $resp.Content.ReadAsStringAsync().GetAwaiter().GetResult()
    [System.IO.File]::WriteAllText($respFile, $content, [System.Text.UTF8Encoding]::new($false))
    $client.Dispose()
} catch {
    $status = -1
    $errMsg = $_.Exception.Message
    [System.IO.File]::WriteAllText($respFile, "request-failed: $errMsg", [System.Text.UTF8Encoding]::new($false))
}

"row=$Row path=$Path status=$status" | Out-File "$outDir\$prefix.status.txt"
if ($errMsg) { "err=$errMsg" | Out-File "$outDir\$prefix.status.txt" -Append }
return $status

