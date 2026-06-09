#requires -Version 5
# Read-GgufChatTemplate.ps1
# Stage 12 V2 jinja extraction helper.
# Extracts the tokenizer.chat_template string from a GGUF file by
# invoking the gguf-py gguf_dump.py --json path and parsing the
# resulting JSON for the metadata key
# "tokenizer.chat_template" value field, per
# gguf-py/gguf/constants.py:270 (Tokenizer.CHAT_TEMPLATE).
#
# Replaces the bad --print-chat-template fallback named in
# part-21a section 2 (no such CLI flag exists in this build).
#
# Usage (dot-source then call):
#   . $PSScriptRoot\Read-GgufChatTemplate.ps1
#   $tmpl = Read-GgufChatTemplate -GgufPath $gguf
#   # or via stderr/stdout capture
#   $tmpl = Read-GgufChatTemplate -GgufPath $gguf -ReturnNullOnMissing
#
# Companion helpers in this file:
#   Resolve-MtpJinjaPath   - resolves chat_template[_new].jinja
#                            for a given MtpVariant, JinjaVariant,
#                            and model path. Returns the absolute
#                            path or $null when MtpVariant=0.
#   Merge-MtpJinjaFlag     - appends --chat-template-file to a
#                            server flag array when a jinja file
#                            is present on disk.

param()

function Read-GgufChatTemplate {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [string] $GgufPath,
        [string] $PythonExe   = 'python',
        [string] $GgufDumpPy  = '',
        [int]    $TimeoutSec  = 60,
        [switch] $ReturnNullOnMissing
    )

    if (-not (Test-Path $GgufPath)) {
        if ($ReturnNullOnMissing) { return $null }
        throw "Read-GgufChatTemplate: GGUF not found at $GgufPath"
    }

    if (-not $GgufDumpPy) {
        $scriptDir  = $PSScriptRoot
        $sourceRoot = (Resolve-Path (Join-Path $scriptDir '..\..\..')).Path
        $GgufDumpPy = Join-Path $sourceRoot 'gguf-py\gguf\scripts\gguf_dump.py'
    }
    if (-not (Test-Path $GgufDumpPy)) {
        throw "Read-GgufChatTemplate: gguf_dump.py not found at $GgufDumpPy"
    }

    $tmpOut = [System.IO.Path]::GetTempFileName()
    $tmpErr = [System.IO.Path]::GetTempFileName()
    try {
        $proc = Start-Process -FilePath $PythonExe `
            -ArgumentList @($GgufDumpPy, '--json', '--no-tensors', $GgufPath) `
            -RedirectStandardOutput $tmpOut `
            -RedirectStandardError  $tmpErr `
            -NoNewWindow -PassThru
        $exited = $proc.WaitForExit($TimeoutSec * 1000)
        if (-not $exited) {
            try { Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue } catch {}
            throw "Read-GgufChatTemplate: gguf_dump.py did not exit within $TimeoutSec s"
        }
        if ($proc.ExitCode -ne 0) {
            $errText = if (Test-Path $tmpErr) { (Get-Content -Raw $tmpErr) } else { '' }
            throw "Read-GgufChatTemplate: gguf_dump.py exit $($proc.ExitCode): $errText"
        }
        $rawJson = Get-Content -Raw $tmpOut
    } finally {
        Remove-Item -Force -ErrorAction SilentlyContinue $tmpOut
        Remove-Item -Force -ErrorAction SilentlyContinue $tmpErr
    }

    if ([string]::IsNullOrWhiteSpace($rawJson)) {
        if ($ReturnNullOnMissing) { return $null }
        throw "Read-GgufChatTemplate: empty JSON from gguf_dump.py for $GgufPath"
    }

    try {
        $obj = $rawJson | ConvertFrom-Json
    } catch {
        if ($ReturnNullOnMissing) { return $null }
        throw "Read-GgufChatTemplate: JSON parse failed for $GgufPath ($($_.Exception.Message))"
    }
    if (-not $obj.metadata) {
        if ($ReturnNullOnMissing) { return $null }
        throw "Read-GgufChatTemplate: JSON missing metadata block for $GgufPath"
    }
    $metaProp = $obj.metadata.PSObject.Properties['tokenizer.chat_template']
    if (-not $metaProp) {
        if ($ReturnNullOnMissing) { return $null }
        throw "Read-GgufChatTemplate: metadata key 'tokenizer.chat_template' not found in $GgufPath"
    }
    $valueProp = $metaProp.Value.PSObject.Properties['value']
    if (-not $valueProp) {
        if ($ReturnNullOnMissing) { return $null }
        throw "Read-GgufChatTemplate: metadata entry 'tokenizer.chat_template' has no 'value' field in $GgufPath"
    }
    $tmpl = [string] $valueProp.Value
    if ([string]::IsNullOrEmpty($tmpl)) {
        if ($ReturnNullOnMissing) { return $null }
        throw "Read-GgufChatTemplate: empty chat_template string in $GgufPath"
    }
    return $tmpl
}

function Resolve-MtpJinjaPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [int]    $MtpVariant,
        [Parameter(Mandatory = $true)] [string] $JinjaVariant,
        [string] $ModelPath  = '',
        [string] $SourceRoot = ''
    )

    if ($MtpVariant -eq 0) { return $null }

    if (-not $SourceRoot) {
        $scriptDir  = $PSScriptRoot
        $SourceRoot = (Resolve-Path (Join-Path $scriptDir '..\..\..')).Path
    }

    $modelDir = switch ($MtpVariant) {
        1 { Join-Path $SourceRoot '._test_models\Qwen3.5-4B-MTP-GGUF' }
        3 { Join-Path $SourceRoot '._test_models\Qwen3.6-27B-MTP-GGUF' }
        2 {
            if ($ModelPath) { Split-Path -Parent $ModelPath }
            else            { Join-Path $SourceRoot '._test_models\Qwen3-0.6B-GGUF' }
        }
        default { return $null }
    }

    $fileName = if ($JinjaVariant -eq 'marked') { 'chat_template_new.jinja' } else { 'chat_template.jinja' }
    return Join-Path $modelDir $fileName
}

function Merge-MtpJinjaFlag {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [string[]] $Flags,
        [string] $JinjaPath = ''
    )

    if ($JinjaPath -and (Test-Path $JinjaPath)) {
        return @($Flags) + @('--chat-template-file', $JinjaPath)
    }
    return ,@($Flags)
}
