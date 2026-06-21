# Stage 23 Manager test execution gate 01

Status: FAIL accepted for bug handoff
Date: 2026-06-21
Stage: 23 (Full S/L Matrix Execution)
Owner: Manager
Report: [stage23-sl-matrix-20260621-01.md](../.test_reports/stage23-sl-matrix-20260621-01.md)
Scope: Manager acceptance of QA execution evidence, not stage closure.

## Decision

VERDICT: FAIL accepted for bug handoff.

Decision D23-EXEC-01: accept `stage23-sl-matrix-20260621-01.md` as the current
Stage 23 execution report. It is a valid CUDA-gated execution report through
S03, not a passing matrix report.

Decision D23-EXEC-02: stop the matrix at S03. S01 and S02 PASS evidence may be
kept as context, but S04..S08 and L01..L03 remain not run until the S03 failure
is triaged and the next Manager handoff defines rerun scope.

## Basis

- CPU-only report `stage23-sl-matrix-20260620-01.md` remains invalid for
  acceptance.
- CUDA restart report `stage23-sl-matrix-20260621-01.md` proves CUDA execution:
  `GGML_CUDA:BOOL=ON`, CUDA0/CUDA1 device listing, wrapper dry-run with
  `--n-gpu-layers all --fit off`, live CUDA smoke with `offloaded 34/34 layers
  to GPU`, and row-level NVIDIA telemetry.
- S01 passed with complete evidence.
- S02 passed with complete evidence for both phases.
- S03 failed after request-phase traffic. The server exited before final
  metrics and row summary, leaving no `metrics-after.txt`, no
  `evidence-summary.md`, and no `cap-exit.json`.
- S03 logs show payload budget pressure, demotion queue pressure, immediate
  eviction fallback, and resident payload far above the 512 MiB budget before
  the row lost the server.

## Handoff

Next owner: Developer test-results review and failure triage. Start from:

- `._design_docs/.test_reports/stage23-sl-matrix-20260621-01.md`
- `._test_output/stage23-sl-matrix-20260621-01/S03-Jnew/server.err.log`
- `._test_output/stage23-sl-matrix-20260621-01/S03-Jnew/launch.err`

Developer must classify S03 as product bug, harness bug, or accepted
Manager reclassification candidate. If code or harness changes are needed,
create a fix report beside the execution report.

This file uses plain ASCII text and stays under the 300-line durable-doc cap.
