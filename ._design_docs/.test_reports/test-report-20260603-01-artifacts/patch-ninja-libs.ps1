#requires -Version 5
# Patch build.ninja to add clang_rt.profile-x86_64.lib to every LINK_LIBRARIES line.
$ErrorActionPreference = 'Stop'

$ninjaPath = "D:\source\llama.cpp-jet\build-cov\build.ninja"
$libPath   = "C:/Program Files/Microsoft Visual Studio/18/Community/VC/Tools/Llvm/x64/lib/clang/20/lib/windows/clang_rt.profile-x86_64.lib"

$content = Get-Content $ninjaPath -Raw
$matches = ([regex]::Matches($content, '(?ms)(  LINK_LIBRARIES = )'))
"link_lines: $($matches.Count)"

$patched = $content -replace '(  LINK_LIBRARIES = )', "`$1`"$libPath`"  "
Set-Content -Path $ninjaPath -Value $patched -NoNewline
"patched: $($patched.Length) bytes"
