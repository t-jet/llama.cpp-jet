# E13-08 verdict

Row: E13-08 - POST /audio/transcriptions alias (no /v1 prefix)

Verdict: FAIL

Date: 2026-06-10 (sub-session 04)

Server: Omni Qwen2.5-Omni-3B-f16.gguf on 127.0.0.1:18114

Args: --cache-mode hybrid --cache-ram 100 --ctx-size 1024 --parallel 1 --metrics --log-verbosity 5 --reasoning-budget 0

## Status

- HTTP status: not returned (server closed TCP connection mid-response)
- PowerShell error: "An error occurred while sending the request."
- WinHTTP detail: "Unable to read data from the transport connection: An existing connection was forcibly closed by the remote host."

## Response shape

No HTTP response body. Server crashed before completion.

## Server log evidence

- L2587: `D srv operator (): Request converted: OpenAI Transcriptions -> OpenAI Chat Completions`
- L2588: `D srv operator (): converted request: {"model":"whisper-1","response_format":"json","messages":[{"role":"user","content":"Transcribe audio to text<__media_ixXnS6VoxcEvfzATfuEUt8F6OJr1isVb__>"}],"stream":false}`
- L2623: `D:\source\llama.cpp-jet\tools\server\server-common.cpp:398: GGML_ASSERT(!has_mtmd) failed`

## Same bug as E13-07

Yes. Same server-common.cpp:398 GGML_ASSERT(!has_mtmd) crash. Same route family (OpenAI Transcriptions -> OpenAI Chat Completions) reached mtmd response path. Same assertion site as E13-01c.

## Health re-check

Post-probe GET /health: connection refused (server crashed).

## Route inventory

OPTIONS /v1/audio/transcriptions -> 200 (route registered, accepts alias family).

## Required handoff

Developer: server-common.cpp:398 server_tokens::set_token asserts !has_mtmd. When the OpenAI Transcriptions route is converted to OpenAI Chat Completions and the media marker is passed through, the response-delivery path (via server_tokens) trips the assert. Same as E13-01c. Fix should route mtmd-bearing result tokens through the mtmd-aware response path or guard the set_token/get_tokens text-only fast path when has_mtmd is true.

## Artifacts in this directory

- request.bin (multipart body sent)
- error.txt (PowerShell exception message)
- error-body.txt (WinHTTP transport detail)
- status.txt (status or exception marker)
- health-after.json (post-probe /health state)
- route-inventory.txt (OPTIONS probe result)
- metrics.txt (post-probe /metrics, server down -> empty)
- probe-E13-08-alias-20260610-04.ps1 (probe script)
- verdict.md (this file)
