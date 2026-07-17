# Part 67: TP-39-03 context execution evidence

Date: 2026-07-13
Status: PARTIAL; CANONICAL RUN BLOCKED BY MEASUREMENT PREFLIGHT
Authority: D39-EXEC-06, design Parts 23-24, implementation Parts 62 and 65

## Driver correction

The TP-39-03 driver now requires context 8192, fixed 2048 MiB startup budgets,
a 20-minute wall cap, 16 GiB RSS cap, 4 GiB cold-root cap, and at most six chat
requests. It rejects a reused TP-39-03 root.

Each TP-39-03 pass records compact request SHA-256 values, prompt-token counts,
per-request elapsed time, RSS, cold-root bytes, and context allocation log rows.
It checks both source counts at 3,631, both incoming counts at 3,632, checked sum
7,263, and margin 929. A canonical pass would derive integer MiB hot and cold
budgets from its own discovery snapshot and verify all four inequalities before
apply. Caller-supplied measurement sizes no longer drive TP-39-03 apply.

PowerShell parsing and metric self-tests pass under Windows PowerShell 5 and
PowerShell 7. The self-test covers the token-capacity and integer-budget helpers.

## Binary identity

The valid measurement used the Part 64 seam-ON build:

| File | Modified | SHA-256 |
| --- | --- | --- |
| `build-stage39-seam-on/bin/Release/llama-server.exe` | 2026-07-13 15:55:42 | `AF0029E474D3AF28F7437BC8F917DA0B234FDC959F31C211B5121095777E4F92` |
| `build-stage39-seam-on/bin/Release/llama-server-impl.dll` | 2026-07-13 15:55:41 | `E261C1F3EB16217F5C5D4583C9C8D50CD050E552BE756D24AA5BEB4CB784FACD` |

An earlier launch selected `build/bin/Release/llama-server.exe`. It was stopped
during request one, before any response, discovery, or apply, and is not
measurement evidence. No server process remained before the valid pass.

## Measurement result

The valid fresh process and root completed four chat requests in 360.782
seconds. Source requests reported 3,631 prompt tokens and incoming requests
reported 3,632. Their checked sum is 7,263, leaving the required 929-token
margin under context 8,192.

The first two requests created real checkpoints at token spans ending 3,103,
3,119 or 3,120, and 3,627 or 3,628. Each checkpoint log reported 50.251 MiB.
Normal saves retained two entries and 7,263 tokens. Cache payload reached
429.079 MiB under the 2,048 MiB startup hot limit.

Peak captured RSS was 5,397,516,288 bytes. Captured cold-root bytes stayed zero.
Request bodies were stable across fillers:

| Role | UTF-8 bytes | SHA-256 |
| --- | ---: | --- |
| source | 5,687 | `d34dee12bb4b0c0782975f853f25a9a063f1a01d76d1552de1202e7457379a49` |
| incoming | 5,688 | `a81ced76f8500dcbc4ab5c291f5f51aa61253d988dda72fff98205bfcbf1948b` |

## Fail-closed preflight

Discovery generation 61 contained two distinct hot exact owners:

- payload 1, owner 1, 172,761,412 resident bytes;
- payload 3, owner 2, 171,777,772 resident bytes.

Both incoming cold sets were present but had empty candidate arrays. The cold
root had no payload file. Discovery therefore contained no compatible cold
checkpoint, although runtime checkpoint creation was real. The driver stopped
with `SKIP-preflight-compatible-checkpoint-set`.

No `control-apply-request.json` or `control-apply-response.json` exists. The
seam was not consumed. Ownership apply, zero eligible victims, one
`evicted/both_filled`, zero transaction delta, tombstone, retained checkpoint
file, post-apply topology, pruning, log, byte reconciliation, and rollback proof
were not reached and cannot be claimed.

## Evidence

- `._test_output/stage39-tp03-ctx-ps5-selftest.log`
- `._test_output/stage39-tp03-ctx-ps7-selftest.log`
- `._test_output/stage39-tp03-measurement-ctx8192-seam-on-20260713/`
- `._test_output/stage39-tp03-measurement-ctx8192-seam-on-console.log`

Coverage remains QA-owned and was not run.

## Handoff

Canonical execution is blocked. The accepted workload creates real runtime
checkpoints and retains both owners, but the fixed 2,048 MiB startup budgets
leave no compatible checkpoint cold descriptor for guarded reassignment.
Architect review must classify this reachability mismatch before any new model
run or workload, budget, selector, ownership, or discovery change.
