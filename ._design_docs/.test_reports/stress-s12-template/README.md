# Stage 12 stress evidence dir template

This template documents the layout that stress scripts
(.\stress_s12_sNN_*.ps1) populate when they run. The actual evidence
directory is created at run time under
.\_design_docs\.test_reports\stress-s12-sNN-{timestamp}\.

## Layout

```text
stress-s12-sNN-<timestamp>/
    evidence-summary.md      Per-scenario summary, written by the
                             stress driver via Write-StressEvidence.ps1
    server.out.log           llama-server stdout
    server.err.log           llama-server stderr
    metrics-before.txt       /metrics snapshot before warmup
    metrics-during.txt       /metrics snapshot during load (or STUB)
    metrics-after.txt        /metrics snapshot after cooldown
    resource-samples.csv     Sampler CSV: elapsed_s,workingset_bytes,handle_count
                             (plus cold_files where applicable)
```

Per-scenario subdirectories may be added for variants (for example
`parallel4` and `parallel8` under S12-S02). Each subdirectory carries
its own copy of the layout above.

## Evidence classification

Each measurement in `evidence-summary.md` is classified as one of:

- public Prometheus: counter rows from /metrics
- structured log: server stderr or bounded diagnostic rows
- direct stats: per-request timings (cache_n, prompt_ms) where exposed
- harness-only: resource sampler rows from resource-samples.csv

## Stub evidence

When a model fixture is missing, the driver writes STUB markers to each
artifact and records `Verdict: BLOCKED` in `evidence-summary.md`. STUB
rows are not counted as PASS for closure.

## Required fields in evidence-summary.md

The driver writes these fields:

- Date
- Stub data flag
- Scenario ID
- Variant
- Model fixture
- Build type
- Server flags
- Request count
- Prompt generator seed
- Duration seconds
- Verdict
- Notes

## Owner

QA execution consumes this template and runs the stress drivers.
Developer implementation only writes the template; the per-scenario
evidence is produced by QA-run stress invocations.
