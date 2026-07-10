# Stage 36 implementation: Hybrid hit and performance validation

Status: CLOSED PASS
Date: 2026-07-10
Stage: 36
Owner: Developer
Design baseline: [cache-handling-phase36-design.md](cache-handling-phase36-design.md)
Current gate: closed

## Baseline

Stage 36 design review and Manager design gate passed on 2026-07-10.
Implementation-plan review and Manager implementation-plan gate passed on
2026-07-10.

Design constraints:

- Do not rerun the unchanged Stage 33 workload as Stage 36 evidence.
- Preserve the Stage 29/33 driver lineage and output layout.
- Make positive hybrid hits expected through tight duplicate bursts.
- Keep product code out of scope unless QA evidence later proves a product bug.
- Do not commit or push.

## Implementation approach

Use the smallest runner change: add Stage-36 workload controls to the existing
comparison driver and workload helper.

Planned script changes:

| File | Change |
| --- | --- |
| `._design_docs/cache-handling-test-scripts/compare-legacy-vs-hybrid.ps1` | Add parameters for Stage 36 burst workload mode and pass them to workload generation |
| `._design_docs/cache-handling-test-scripts/lib/compare-legacy-vs-hybrid-workload.ps1` | Add optional burst generation path that emits repeated identical chat messages within each burst |
| `._design_docs/cache-handling-test-scripts/README.md` | Document the Stage 36 workload mode and expected evidence |

No product code or C++ test code is planned.

## Review and gate records

| Document | Result |
| --- | --- |
| [Part 01: Implementation-plan review](./cache-handling-phase36-implementation/part-01-implementation-plan-review-20260710.md) | PASS |
| [Part 02: Manager implementation-plan gate](./cache-handling-phase36-implementation/part-02-manager-implementation-plan-gate-20260710.md) | PASS |
| [Part 03: Implementation review](./cache-handling-phase36-implementation/part-03-implementation-review-20260710.md) | REWORK |
| [Part 04: Implementation rework evidence](./cache-handling-phase36-implementation/part-04-implementation-rework-evidence-20260710.md) | READY-FOR-REVIEW |
| [Part 05: Implementation re-review](./cache-handling-phase36-implementation/part-05-implementation-re-review-20260710.md) | PASS |
| [Part 06: Manager implementation gate](./cache-handling-phase36-implementation/part-06-manager-implementation-gate-20260710.md) | PASS |
| [Part 07: Manager closure](./cache-handling-phase36-implementation/part-07-manager-closure-20260710.md) | PASS |

## Ordered steps

1. Extend the workload helper with an opt-in burst mode:
   `-BurstDuplicateMode`, `-BurstCount`, `-RepeatsPerBurst`, and optional
   `-FillerCount`.
2. Extend the driver parameters and `Invoke-Phase05WorkloadBuild` to pass the
   burst-mode options only when requested.
3. Keep the default Stage 29/33 workload unchanged when burst mode is absent.
4. Update script README with the Stage 36 command shape and evidence intent.
5. Run static checks:
   - PowerShell parse of both edited scripts.
   - Dry-run preflight with Stage 36 parameters.
6. Run focused setup checks before QA handoff if build tools are available:
   - clean Release CUDA configure;
   - build `llama-server` and `test-cache-controller`;
   - direct `test-cache-controller.exe`;
   - `ctest --test-dir build-cuda -C Release -R cache -V`.

## Implementation evidence

Changed files:

- `._design_docs/cache-handling-test-scripts/compare-legacy-vs-hybrid.ps1`
- `._design_docs/cache-handling-test-scripts/lib/compare-legacy-vs-hybrid-workload.ps1`
- `._design_docs/cache-handling-test-scripts/README.md`
- Stage 36 docs listed in this implementation log

Implemented behavior:

- `compare-legacy-vs-hybrid.ps1` now accepts `-BurstDuplicateMode`,
  `-BurstCount`, `-RepeatsPerBurst`, and `-FillerCount`.
- `Invoke-Phase05WorkloadBuild` passes those options only when
  `-BurstDuplicateMode` is set.
- `compare-legacy-vs-hybrid-workload.ps1` now has an opt-in burst path that
  emits repeated identical chat messages within each burst.
- Default Stage 29/33 workload behavior remains unchanged when burst mode is
  absent.
- README documents the Stage 36 command shape and evidence intent.

Static evidence:

```text
PowerShell parser PASS:
._design_docs/cache-handling-test-scripts/compare-legacy-vs-hybrid.ps1
._design_docs/cache-handling-test-scripts/lib/compare-legacy-vs-hybrid-workload.ps1
```

Burst-shape proof with a stub prompt generator:

```json
{"metadata_count":48,"row_count":48,"group_count":8,"all_groups_six":true,"exact_count":48,"unique_payloads":8}
```

Stage 36 dry-run preflight:

```json
{"ps_version_ok":true,"binary_exists":true,"fixture_exists":true,"port_free":true,"cuda_proof":"PASS","git_head":"89d13d2e3047c9976d37f22dfe3e8375862c0e87","git_dirty":14,"status":"PASS"}
```

Build evidence is not yet captured in this implementation session. QA remains
responsible for the clean Release CUDA build before execution, and the intake
records that `test-cache-controller.exe` was missing before rebuild.

## Implementation review rework

Architect implementation review returned REWORK on 2026-07-10 because the
touched script README still documented retired underscore-form public metrics
(`llamacpp_cache_*`) while Stage 36 and the comparison driver require current
colon-form metrics (`llamacpp:cache_*`).

Developer correction:

- Updated README metric references to current colon-form names.
- Updated benchmark evidence rows from `llamacpp_cache_hits_total` and
  `llamacpp_cache_misses_total` to `llamacpp:cache_hits_total` and
  `llamacpp:cache_misses_total`.
- Tightened Stage 36 burst `FillerCount` validation to the design cap
  (`0..48`).

Rework evidence:

```text
rg "llamacpp_cache_" ._design_docs/cache-handling-test-scripts/README.md
no matches
```

## Test-plan review rework

Independent QA test-plan review returned REWORK on 2026-07-10 for two
documentation issues:

- Part 41 status still said design review was pending even though design and
  implementation gates had passed.
- README Stage 36 example used `_test_output\...` instead of the active
  `._test_output\...` convention.

Developer correction:

- Updated Part 41 status to reflect design and implementation gate PASS with
  test-plan re-review pending.
- Updated the README Stage 36 example run root to `._test_output\...`.

QA re-review passed and Manager test-plan gate passed on 2026-07-10.

## QA execution harness fix

The first Stage 36 live execution completed traffic but the driver exited 1
during report emission:

```text
Exception calling "Add" with "1" argument(s): "Collection was of a fixed size."
```

Root cause: `Write-Stage29Report` initialized `$lines` as a fixed PowerShell
array and then called `.Add()`.

Fix: initialize `$lines` as `System.Collections.Generic.List[string]` before
adding report rows. This is a harness/report-emission fix only; it does not
change product code or traffic behavior.

## Evidence plan

Implementation evidence must include:

- exact changed-file list;
- proof default workload parameters still parse;
- proof burst-mode parameters parse;
- proof the burst workload contains 8 groups of 6 identical message payloads
  when configured with the Stage 36 defaults;
- dry-run preflight output for Stage 36 paths;
- build/test evidence or a clear BLOCKED note if local toolchain setup blocks
  the clean build.

## Risks

| Risk | Mitigation |
| --- | --- |
| Burst mode accidentally changes Stage 29/33 default workload | Keep burst mode opt-in and test default parameter parse |
| Workload helper produces shallow object copies that mutate anchors | Serialize/deserialize or copy arrays without modifying source anchors |
| Tight bursts reduce hot-RAM delta below 40 percent | QA reports the delta and uses the design-approved exception only if no product bug is present |
| Full model-backed run remains slow | Stage 36 uses one cold cycle plus one warm cycle unless Manager expands scope |

## QA and closure

QA execution passed in
`._design_docs/.test_reports/test-report-20260710-02-stage36-stage33-rerun.md`.
Developer test-results review passed in
`._design_docs/.test_reports/test-report-20260710-02-stage36-stage33-rerun-developer-review.md`.

Manager closure passed in
`._design_docs/cache-handling-phase36-implementation/part-07-manager-closure-20260710.md`.

Final state: CLOSED PASS.

Non-blocking follow-up: `cache_cold_budget_bytes{mode="hybrid"}` reported
`-2147483648` for a 2048 MiB budget. It is outside the Stage 36 Part 41 gate
and should be handled in a separate follow-up if budget gauge correctness needs
to be gated.
