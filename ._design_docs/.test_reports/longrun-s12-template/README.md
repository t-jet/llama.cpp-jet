# Stage 12 long-run evidence dir template

This template documents the layout that long-run scripts
(.\longrun_s12_lNN_*.ps1) populate when they run. The actual evidence
directory is created at run time under
.\_design_docs\.test_reports\longrun-s12-lNN-{timestamp}\.

## Layout

```text
longrun-s12-lNN-<timestamp>/
    evidence-summary.md      Per-run summary, written by the long-run
                             driver via Write-LongrunEvidence.ps1
    server.out.log           llama-server stdout
    server.err.log           llama-server stderr
    metrics-after.txt        /metrics snapshot at run end
    resource-samples.csv     Sampler CSV: elapsed_s,workingset_bytes,
                             handle_count,server_live
    snapshot-<N>m.csv        Partial snapshot copy of resource-samples
                             produced every SnapshotEveryMin minutes
```

## Resource stability thresholds

Recorded in evidence-summary.md. Defaults from design part-02:

- working set growth after warmup < 10 percent
- handle or FD growth after warmup < 5 percent
- latency drift p95 < 20 percent without recorded cause
- counters monotonic; cold-store file count stable

## Monitor list

- Process working set (harness-only)
- Windows handle count (harness-only)
- Server liveness ping (public HTTP)
- /metrics sample (public Prometheus)
- Cold-store file count (harness-only, S12-L01 and S12-L03 only)

## Per-scenario defaults

| ID | Duration | Sampler interval | Snapshot every |
| --- | --- | --- | --- |
| S12-L01 | 6 hours | 60 s | 30 min |
| S12-L02 | 30 min | 30 s | 10 min |
| S12-L03 | 2 hours | 60 s | 30 min |

## Partial-snapshot markers

The driver copies the full resource-samples.csv to
`snapshot-<N>m.csv` at the configured cadence so QA can resume
evidence collection if the run is interrupted. The driver records
each snapshot path in evidence-summary.md under the
`PartialSnapshotPaths` rows.

## Stub evidence

When a model fixture is missing, the driver writes STUB markers and
records `Verdict: BLOCKED` in evidence-summary.md.

## Owner

QA execution consumes this template. The long-run drivers emit
`Verdict: PENDING` after a live run; QA evaluates the resource
stability thresholds and updates the verdict before the run log
closes.
