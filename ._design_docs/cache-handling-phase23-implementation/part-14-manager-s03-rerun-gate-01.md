# Stage 23 part 14: Manager S03 rerun gate 01

Status: FAIL-bug-handoff
Date: 2026-06-21
Owner: Manager
Scope: focused S03 CUDA rerun after S03 fix-review PASS.

## Inputs

- `cache-handling-phase23-implementation/part-13-manager-s03-fix-gate.md`
- `._design_docs/.test_reports/stage23-s03-rerun-20260621-03.md`
- `._test_output/stage23-s03-rerun-20260621-03/`
- `._test_output/stage23-s03-direct-isolation-20260621-01/`

## Decision

D23-S03-RERUN-01: FAIL-bug-handoff.

The S03 focused rerun is not accepted as PASS. The hardened wrapper correctly
failed the row because S03 did not produce required metrics evidence.

Direct isolation reproduced a startup crash with the same S03 flags:

- `ready=False`
- `exited=True`
- `exitCode=-1073740791`

The server log detects CUDA0 and CUDA1, but the process exits before health and
before GPU memory allocation appears in `nvidia-smi`.

## Harness gate

D23-S03-RERUN-02: PASS for harness hardening.

The wrapper now fails a row when child exit is nonzero or required metrics files
are absent. Stress and longrun startup waits now allow 300 seconds for CUDA
startup before readiness failure. This prevents false-green matrix rows.

## Next owner

Developer: triage and fix the S03 startup crash or prove a narrower harness
configuration issue. QA must not continue S03, S04..S08, or L01..L03 until the
fix has review approval.
