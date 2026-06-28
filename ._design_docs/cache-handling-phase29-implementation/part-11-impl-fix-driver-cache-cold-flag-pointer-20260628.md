# Stage 29 implementation fix pointer: S29-IMPL-FIX-02

Status: pointer entry (entry-doc was at the 300-line cap, so this fix
got a separate part file instead of growing the entry doc)

Date: 2026-06-28
Stage: 29 (Cache Modes Comparison: legacy vs hybrid on a representative agentic-shaped workload)
Owner: Developer (fix session in response to Manager BLOCKING flag-mismatch finding)
Source finding: Manager brief identified a one-character BLOCKING bug at `compare-legacy-vs-hybrid.ps1:88`
Full details: [./part-10-impl-fix-driver-cache-cold-flag-20260628.md](./part-10-impl-fix-driver-cache-cold-flag-20260628.md)

## Summary

S29-IMPL-FIX-02: One-character fix at driver L88 (`--cache-cold-dir`
to `--cache-cold-path`). Status DONE.

## Self-test

Re-run `compare-legacy-vs-hybrid.ps1 -DryRun` expected outcome: exit 0,
preflight `status: PASS` (assuming CUDA build root has
`GGML_CUDA:BOOL=ON` in `CMakeCache.txt`, model fixture is present, and
BasePort is free). Not executed in this session per Manager brief.

## Root cause

Transcription error. Stage 29 design always specified
`--cache-cold-path` as the cache-cold directory flag (matching
`common/arg.cpp`). The driver copy-paste introduced `dir` instead of
`path`.

## Next owner

Manager (implementation-fix gate review).
