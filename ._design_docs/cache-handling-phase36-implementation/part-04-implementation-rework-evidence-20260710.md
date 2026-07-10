# Part 04: Implementation rework evidence

Date: 2026-07-10
Stage: 36
Owner: Developer
Verdict: READY-FOR-REVIEW

## Corrections

F36-IMPL-01 corrected:

- README metric references now use current colon-form `llamacpp:cache_*` names.
- Benchmark evidence rows now use `llamacpp:cache_hits_total` and
  `llamacpp:cache_misses_total`.
- Stage 36 burst `FillerCount` validation now rejects values above 48.

## Evidence

PowerShell parser:

```text
._design_docs/cache-handling-test-scripts/compare-legacy-vs-hybrid.ps1 PASS
._design_docs/cache-handling-test-scripts/lib/compare-legacy-vs-hybrid-workload.ps1 PASS
```

README metric grep:

```text
rg "llamacpp_cache_" ._design_docs/cache-handling-test-scripts/README.md
no README underscore metric refs
```

Burst-shape proof:

```json
{"metadata_count":48,"row_count":48,"group_count":8,"all_groups_six":true,"exact_count":48,"unique_payloads":8}
```

Invalid filler proof:

```text
New-ComparisonWorkload: FillerCount must be <= 48 for burst mode (got 49)
```

## Handoff

Ready for Architect implementation re-review.
