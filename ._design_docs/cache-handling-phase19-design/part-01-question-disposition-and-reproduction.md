# Stage 19 design part 1: question, disposition, reproduction plan

Status: authored; pending Architect design review
Date: 2026-06-18
Stage: 19 (System-Level Model Warmup Crash Investigation)
Source: [entry doc](../cache-handling-phase19-design.md)

## Stage 19 question

Does the baseline warmup crash (no cache flags, default config) still
reproduce in the current system state at `HEAD = cb93f3dbd`?

## Three-branch disposition

The design serves the question with three possible closure branches.
The investigation (Developer + QA in a future session) selects one branch
based on the reproduction test result.

### Branch A: crash reproduces (code-related root cause)

Closure path: Stage 19 produces a minimal targeted fix (similar to Stage
18 fix style: move validation block, replace throws with returns, add
bounded diagnostics). Implementation plan in a follow-up part file. Test
plan in a follow-up part file. Closure criteria: clean bounded exit on
the reproduction command; no STATUS_STACK_BUFFER_OVERRUN; focused
regression test added.

### Branch B: crash reproduces (environmental root cause)

Closure path: Stage 19 documents the environmental trigger (memory
pressure from `fit_params` projection discrepancy) and proposes
environment stability checks (startup memory probe, `fit_params`
projection logging at SRV_DBG, conditional startup budget warning). No
code fix. Closure criteria: reproduction captured with system-state
evidence (memory snapshot, `fit_params` projection log); environmental
follow-up surfaced as a new separate stage.

### Branch C: crash does NOT reproduce

Closure path: Stage 19 documents the no-reproduction finding with
current system-state evidence. The Stage 18 fix is sufficient as-is.
Closure criteria: 5 successive baseline launches (no cache flags) all
reach `/health` HTTP 200; no STATUS_STACK_BUFFER_OVERRUN; memory
snapshot shows no accumulation across the 5 launches.

## Reproduction plan

The reproduction test must capture the baseline path WITHOUT any cache
flags. The Stage 18 fix is gated by `cache_ram_mib != 0`; using any
cache flag would not test the baseline.

### Reproduction command

```text
build-cov\bin\Release\llama-server.exe --port 18220 --model ._test_models\Qwen3-0.6B-GGUF\Qwen3-0.6B-Q8_0.gguf
```

No `--cache-mode`, no `--cache-ram-mib`, no `--cache-cold-path`,
no `--cache-cold-max-mib`, no `--cache-prompt-evidence`,
no `--cache-prompt-evidence-dir`, no `--log-prompts-dir`.

### Evidence capture

| Item | Where | Clean path | Crash path |
| --- | --- | --- | --- |
| Exit code | process $LASTEXITCODE | 0 (or 1 if /health probe fails) | -1073740791 (0xC0000409) |
| Server stderr | `._test_output/stage19-repro/<run>/server.err.log` | init + `server is listening on 127.0.0.1:18220` | init + warmup + abrupt exit |
| Server stdout | `._test_output/stage19-repro/<run>/server.out.log` | health probe `{"status":"ok"}` | empty or partial |
| Process lifetime | wall clock start to exit | > 10 seconds | < 2 seconds |
| Memory snapshot | PowerShell `Get-Process` before/after | working set stable | n/a |

### Run matrix

| Run | Command | Repeat | Purpose |
| --- | --- | --- | --- |
| TP-19-RT1.1 | baseline (no cache flags) | 1 | single reproduction |
| TP-19-RT1.2 | baseline (no cache flags) | 5 | memory accumulation check |
| TP-19-RT1.3 | baseline + `--port 18221` | 1 | rule out port conflict |
| TP-19-RT1.4 | baseline + process watcher | 1 | confirm crash site timing |

The 5x repeat on RT1.2 checks whether memory pressure from prior
`llama-server.exe` instances accumulates and triggers the
STATUS_STACK_BUFFER_OVERRUN. Stage 17 D17-EXEC-02 evidence shows the
crash was deterministic 3/3 with single launches, so 5x is enough to
detect a pattern shift.

This file uses LF line endings, plain ASCII status labels, and stays under
the 300-line durable doc cap.
