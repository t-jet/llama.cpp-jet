@echo off
setlocal
call "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat" >nul
if errorlevel 1 ( echo VCVARS_FAIL & exit /b 1 )
echo === START_BUILD %DATE% %TIME% ===
cmake --build build --config Release --target llama-server test-cache-controller -j 4
set RC=%errorlevel%
echo === END_BUILD rc=%RC% %DATE% %TIME% ===
exit /b %RC%
