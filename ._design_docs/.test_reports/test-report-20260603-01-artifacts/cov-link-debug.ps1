#requires -Version 5
# Patch all vcxproj Link blocks to add /DEBUG for Release config.
$ErrorActionPreference = 'Stop'

$vcxprojs = Get-ChildItem "D:\source\llama.cpp-jet\build-cov" -Recurse -Filter "*.vcxproj" -ErrorAction SilentlyContinue
foreach ($p in $vcxprojs) {
    $content = Get-Content $p.FullName -Raw
    # Skip if already patched.
    if ($content -match 'Link.*Release.*x64.*\s*<LinkErrorReporting') {
        # Insert /DEBUG into AdditionalOptions before </Link>.
        $patched = $content -replace '(<Link>\s*<AdditionalOptions>)([^<]*)(</AdditionalOptions>)', ('$1$2 /DEBUG:FULL$3')
        if ($patched -ne $content) {
            Set-Content -Path $p.FullName -Value $patched -NoNewline
        }
    }
}
"done patching $($vcxprojs.Count) vcxprojs"
