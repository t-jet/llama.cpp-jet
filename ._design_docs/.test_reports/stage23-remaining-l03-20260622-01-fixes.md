# Stage 23 L03 runner-contract fix 20260622-01

Verdict: READY-FOR-ARCHITECT-REVIEW
Owner: Developer
Scope: L03 runner contract only. No product code, public flags, public metrics, test fixtures, commit, or push.

## Trigger

Focused L03 report [stage23-remaining-l03-20260622-01.md](stage23-remaining-l03-20260622-01.md) is `BLOCKED-runner-contract`. The live run stayed healthy for two hours, but `longrun_s12_l03_2h_mixed_workload.ps1` still ran the legacy-control workload: `Variant: legacy-2h`, one repeated probe, only `profile=checkpoint_dependent` plus `lookup_outcome=exact_entry_absent`, and root `evidence-summary.md` stayed `PENDING`.

## Fix

- Reworked `longrun_s12_l03_2h_mixed_workload.ps1` to run Stage 23 hybrid mixed workload evidence instead of legacy control.
- Kept the row cap as the whole L03 cap. The runner splits it across four prompt classes: 30% exact/cache_prompt, 30% checkpoint-dependent, 20% near/non-exact, and 20% new/uncached.
- Added root `l03-mixed-workload.json` with plan, request counts, profile counts, HTTP status counts, server flags, metrics deltas, prompt-evidence profile/outcome/checksum counts, distinct lookup path count, and final status.
- Root `evidence-summary.md` now uses `Variant: mixed-workload` and a non-PENDING result when all prompt classes make requests.
- Updated the Stage 20 wrapper to print an L03 mixed-workload plan in dry-run and live side logs.
- Updated the wrapper row gate for L03 only to require `l03-mixed-workload.json` and `evidence-summary.md`.

## Evidence

Parse checks:

```text
PARSE_OK ._design_docs/cache-handling-test-scripts/longrun/longrun_s12_l03_2h_mixed_workload.ps1
PARSE_OK ._design_docs/cache-handling-test-scripts/kickoff-stage20-stress-longrun.ps1
```

Wrapper dry-run:

```text
DryRun OK; 1 rows; per-row flags present
DryRun L03 mixed_workload_plan rowCapSeconds=7200 exact_cache_prompt_seconds=2160 checkpoint_dependent_seconds=2160 near_non_exact_seconds=1440 new_uncached_seconds=1440 artifact=l03-mixed-workload.json
```

Child dry-run:

```text
Plan: rowCapSeconds=60 profiles=exact-cache-prompt=18s,checkpoint-dependent=18s,near-non-exact=12s,new-uncached=12s
DRY-RUN: artifact l03-mixed-workload.json; evidence-summary result PASS when all profiles make requests
```

One minute child smoke:

```text
status: PASS
request_count: 14
profile_counts: exact-cache-prompt=4, checkpoint-dependent=4, near-non-exact=3, new-uncached=3
prompt_evidence records=14 profiles={checkpoint_dependent:14} lookup_outcomes={exact_entry_absent:14}
distinct_token_span_checksum_count=8
distinct_lookup_path_count=8
evidence-summary.md: Variant mixed-workload; Result PASS
```

The smoke used the primary Qwen3.5 MTP fixture, hybrid mode, CUDA all, fit off, cold max 512 MiB, `--cache-ram 512`, cold path, redacted prompt evidence, evidence directory, Jinja new, and a direct 60 second cap. Full L03 was not rerun.

## Limitations

- The smoke is not a replacement for the two hour L03 QA rerun.
- The MTP fixture still reports public prompt evidence profile `checkpoint_dependent` for all requests. The runner artifact records the harness prompt-class mix and distinct token-span/lookup-path spread so QA can verify the run is no longer one repeated absent-control probe.
- Architect should review the runner contract before QA reruns focused L03.

## Handoff

Next owner: Architect for L03 bugfix review. If accepted, QA should rerun focused L03 with a fresh suffix and no full S/L matrix rerun.
