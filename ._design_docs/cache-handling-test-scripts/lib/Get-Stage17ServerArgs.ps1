#requires -Version 5

function Get-Stage17ServerArgsFromBase64 {
    param(
        [string] $Encoded = ''
    )

    if (-not $Encoded) {
        return @()
    }

    $json = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($Encoded))
    $args = @($json | ConvertFrom-Json)
    return [string[]] $args
}
