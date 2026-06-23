# Stage 23 L02 runner-contract fix

Verdict: ready for Architect review
Owner: Developer
Date: 2026-06-22
Scope: L02 runner contract only. L03 was not run.

## Trigger

QA report [stage23-remaining-l02-20260622-01.md](stage23-remaining-l02-20260622-01.md)
blocked L02 because `longrun_s12_l02_30m_legacy_comparison.ps1` ran one
hybrid leg, wrote no legacy control leg, wrote no paired comparison artifact,
and left `evidence-summary.md` at `PENDING`.

## Fix

Changed `longrun_s12_l02_30m_legacy_comparison.ps1` so L02 owns the paired
comparison evidence:

- split the Stage 23 30 minute row cap into two bounded legs:
  `legacy-control=900s` and `hybrid-stage23=900s`;
- run the control leg with `--cache-mode legacy`;
- run the hybrid leg with Stage 23 hybrid flags, including cold max 512 MiB,
  cold path, redacted prompt evidence, evidence dir, CUDA all, fit off, model,
  and cache RAM;
- write `legacy-control/` and `hybrid-stage23/` evidence folders with
  per-leg `server-flags.txt`, metrics, request samples, logs, resource samples,
  and evidence summaries;
- write root `l02-comparison.json` with both modes, flags, request counts,
  cache sample counts, metric deltas, and filtered legacy arguments;
- write root `evidence-summary.md` with `Result: PASS` when both legs make
  requests.

Legacy mode filters hybrid-only Stage 23 flags:

```text
--cache-mode hybrid
--cache-cold-max-mib 512
--cache-cold-path <path>
--cache-prompt-evidence redacted
--cache-prompt-evidence-dir <path>
```

Reason: those flags configure hybrid cold storage or hybrid prompt evidence.
The hybrid leg keeps them, so the Stage 23 cold-budget and redacted-evidence
contract still applies to the hybrid half of L02.

Changed `kickoff-stage20-stress-longrun.ps1` so dry-run/live side logs expose
the L02 split plan and row gate requires `l02-comparison.json` plus
`evidence-summary.md` for L02.

No product code, public flags, public metrics, unit tests, fixtures, commits,
or pushes changed.

## Evidence

Syntax checks:

```text
L02 parse OK
wrapper parse OK
```

Direct child dry-run:

```text
S12-L02 legacy comparison; stub=False
DRY-RUN: paired legacy comparison plan legacy-control=900s,hybrid-stage23=900s,total=1800s
DRY-RUN: legacy-control mode=legacy filters hybrid-only cold/evidence args; hybrid-stage23 mode=hybrid keeps Stage 23 cold/evidence args
```

Wrapper dry-run:

```text
DryRun OK; 1 rows; per-row flags present
DryRun L02 comparison_plan rowCapSeconds=1800 legacy_control_seconds=900 hybrid_stage23_seconds=900 legacy_mode=legacy hybrid_mode=hybrid comparison_artifact=l02-comparison.json legacy_filters=cache-cold-max-mib,cache-cold-path,cache-prompt-evidence,cache-prompt-evidence-dir
```

Short child smoke, not the full L02 row:

```text
OutDir: ._test_output/stage23-l02-dev-smoke-child6
Duration: 60 seconds total
Plan: legacy-control=30s, hybrid-stage23=30s
Exit code: 0
Root evidence-summary.md: Result: PASS
l02-comparison.json: status PASS
legacy-control: mode legacy, 3 requests, 3 live samples
hybrid-stage23: mode hybrid, 3 requests, 3 live samples
```

Flag proof from the smoke:

```text
legacy-control server-flags.txt:
--cache-mode legacy ... --cache-ram 512 --n-gpu-layers all --fit off

hybrid-stage23 server-flags.txt:
--cache-mode hybrid ... --cache-cold-max-mib 512 --cache-ram 512 --n-gpu-layers all --fit off --cache-cold-path ... --cache-prompt-evidence redacted --cache-prompt-evidence-dir ...
```

## Limitations

The smoke used a 60 second total cap to prove the runner path and artifacts.
It is not full QA L02 evidence. QA should rerun focused L02 after Architect
review. L03 remains stopped.

