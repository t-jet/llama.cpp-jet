@echo off
setlocal
set MODEL=D:\source\llama.cpp-jet\._test_models\Qwen2.5-Omni-3B-GGUF\Qwen2.5-Omni-3B-f16.gguf
set MMPROJ=D:\source\llama.cpp-jet\._test_models\Qwen2.5-Omni-3B-GGUF\mmproj-Qwen2.5-Omni-3B-f16.gguf
D:\source\llama.cpp-jet\build\bin\Release\llama-server.exe --model "%MODEL%" --mmproj "%MMPROJ%" --host 127.0.0.1 --port 18114 --cache-mode hybrid --cache-ram 100 --ctx-size 1024 --parallel 1 --metrics --slots --log-verbosity 5 --reasoning-budget 0
