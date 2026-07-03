# Stage 34 reopened live QA: small model cache4g

Date: 2026-07-01
Owner: QA
Scope: reopened Stage 34 live evidence using local Qwen3 0.6B model and the real `._analysis/chat_log.jsonl` replay.

## Verdict

FAIL for reopened live gate.

Sequential replay proves the expected-hit model and baseline cache path: 23 of 23 predicted hot exact-hit rows returned non-zero `cache_n`, and `llamacpp:cache_hits_total{mode="hybrid"}` increased by 23.

Concurrent warm replay against the same server is the blocker: only 8 of 23 predicted hot exact-hit rows returned non-zero `cache_n`; 15 predicted hot exact-hit rows returned `cache_n=0`. The run had 56 of 56 HTTP 200 responses, bounded namespace count 1, no request errors, and no crash evidence, so this is not a transport or startup failure.

Do not close Stage 34 from this evidence.

## Setup

- Server: `http://127.0.0.1:9136`
- PID: 34352
- Binary: `D:\source\llama.cpp-jet\build-cuda\bin\Release\llama-server.exe`
- Binary timestamp: 2026-07-01 10:33:04
- Process start: 2026-07-01 10:39:42 Europe/Sofia
- Model: `._test_models\Qwen3-0.6B-GGUF\Qwen3-0.6B-Q8_0.gguf`
- Server args: `--cache-mode hybrid --cache-ram 4096 --cache-cold-path D:\source\llama.cpp-jet\_test_output\stage34-reopen-live-small-cache4g\cold --cache-cold-max-mib 4096 --metrics --ctx-size 16384 --parallel 4 --temp 0 --seed 42 --n-gpu-layers all`

Clean build was not rerun by this QA sub-session. The running `llama-server.exe` is newer than the modified Stage 34 source files inspected in this session, but this report classifies only the reopened live evidence requested by Manager.

## Artifacts

- Server stdout: `_test_output/stage34-reopen-live-small-cache4g/server.log`
- Server stderr: `_test_output/stage34-reopen-live-small-cache4g/server.err.log`
- Cold store: `_test_output/stage34-reopen-live-small-cache4g/cold`
- Sequential run: `_test_output/stage34-reopen-live-small-cache4g/real-chatlog-sequential`
- Concurrent warm run: `_test_output/stage34-reopen-live-small-cache4g/real-chatlog-concurrent-warm`

## Row classification

| Stage 34 row/scope | Verdict | Evidence |
| --- | --- | --- |
| TP-34-AH-03 real expected-hit table | PASS | Both live runs produced 56 expected rows: 23 `expected_result=hit`, 33 expected misses; sources were 14 same-branch exact checksums, 9 cross-branch exact checksums, 33 first observations. |
| Sequential real replay | PASS | `summary.json`: 56 responses, 56 success, 0 errors. All 23 predicted hot exact-hit rows had `cache_n > 0`. Metrics delta: hits +23, misses +33, evictions +55, namespace count 1. |
| TP-34-RR-03 concurrent live runner | PASS as runner | Concurrent warm command completed and wrote `events.jsonl`, `requests.jsonl`, `expected-hits.jsonl`, `responses.jsonl`, `metrics-before.txt`, `metrics-after.txt`, and `summary.json`. HTTP result: 56 responses, 56 success, 0 errors. |
| TP-34-CC concurrent main/subagent cache reuse | FAIL | Concurrent warm run had 23 predicted hot exact-hit rows but only 8 rows with `cache_n > 0`; 15 predicted hot rows returned `cache_n=0`. Metrics hit delta was +8, matching response evidence. |
| TP-34-CL/OB cold and metrics evidence | PARTIAL | Cold store exists with 22 files, 4,085,286,884 bytes. Concurrent metrics deltas: hits +8, misses +48, evictions +79, entries -2, bytes +354,301,136, namespace count unchanged at 1, promotions +1, promotion failures 0. |
| Server log health scan | PASS for crash/request health; PARTIAL for restore-apply text | `server.err.log` counts: checksum 14, token_count 66, namespace 76, restore-apply 0, crash 0, request-error 0, error 0, exception 0, corruption 0, ASSERT 0, failed 0. |

## Concurrent miss rows

Predicted hot exact-hit rows with `cache_n=0` in concurrent warm:

`row-00052`, `row-00090`, `row-00095`, `row-00131`, `row-00148`, `row-00170`, `row-00196`, `row-00226`, `row-00242`, `row-00254`, `row-00285`, `row-00303`, `row-00312`, `row-00340`, `row-00347`.

Rows that did hit in concurrent warm:

`row-00078`, `row-00105`, `row-00107`, `row-00206`, `row-00238`, `row-00259`, `row-00298`, `row-00308`.

## Blocker classification

Blocker: `FAIL-concurrent-expected-hot-hit-miss`.

Why: expected-hit analyzer classified all 23 hit rows as `required_residency=hot`. Sequential run on same transcript and same server process proved all 23 exact rows can hit. Concurrent warm run had bounded namespace count and clean HTTP/log health, but missed 15 predicted hot hits. This points to concurrent cache reuse behavior or replay concurrency ordering, not transcript incompleteness, server startup, or stale namespace expansion.

Next owner: Developer/Manager bug-handoff decision. Stage remains open.
