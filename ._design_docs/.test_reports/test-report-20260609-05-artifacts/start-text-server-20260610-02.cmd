@echo off
setlocal
set MODEL=D:\source\llama.cpp-jet\._test_models\Qwen3-0.6B-GGUF\Qwen3-0.6B-Q8_0.gguf
set SLOTPATH=D:\source\llama.cpp-jet\._design_docs\.test_reports\test-report-20260609-05-artifacts\slots
if not exist "%SLOTPATH%" mkdir "%SLOTPATH%"
set ARGS=--model "%MODEL%" --host 127.0.0.1 --port 18113 --cache-mode hybrid --cache-ram 100 --ctx-size 1024 --parallel 2 --metrics --slots --slot-save-path "%SLOTPATH%" --log-verbosity 5
echo %ARGS% > "D:\source\llama.cpp-jet\._design_docs\.test_reports\test-report-20260609-05-artifacts\text-server-20260610-02.args.txt"
D:\source\llama.cpp-jet\build\bin\Release\llama-server.exe %ARGS% 1> "D:\source\llama.cpp-jet\._design_docs\.test_reports\test-report-20260609-05-artifacts\text-server-20260610-02.stdout.log" 2> "D:\source\llama.cpp-jet\._design_docs\.test_reports\test-report-20260609-05-artifacts\text-server-20260610-02.stderr.log"
