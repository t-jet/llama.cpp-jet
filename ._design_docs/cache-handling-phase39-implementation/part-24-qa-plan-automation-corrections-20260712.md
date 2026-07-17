# Part 24: QA-plan automation corrections

Date: 2026-07-12
Status: READY FOR FRESH QA RE-REVIEW

## Scope

This correction addresses F39-QAPR-01 and F39-QAPR-02 from Part 23. It changes
the reusable Stage 39 live driver and its README. It does not change production
cache behavior or relax Part 43's row-level evidence requirements.

## F39-QAPR-01: structured evidence

`stage39-two-layer-pressure.ps1` now writes:

- `cold-files-before.csv` before pressure and `cold-files-after.csv` afterward;
- `metric-delta.txt`, with sorted Prometheus sample keys and numeric before,
  after, and delta values;
- `state.json`, with before, after, and delta values for hot bytes, descriptor
  cold bytes, cold payload bytes, promotions, payload evictions, entries, branch
  nodes, and pruning;
- cold file count, cold file bytes, quarantine bytes, restore evidence, and
  explicit byte, eviction, and pruning reconciliation results.

The raw metric snapshots remain authoritative. The structured files make the
same evidence deterministic and machine-readable; they do not replace manual
review against Part 43.

## F39-QAPR-02: standard scenario acceptance

The `standard` scenario now repeats the first pressure request and requires all
of these results before it writes `PASS`:

1. Positive `timings.cache_n` on the repeated request.
2. A positive cold-promotion counter delta.
3. A positive `retained_cold/cold_room` or
   `retained_cold/cold_room_made` decision delta.
4. A positive `commit/none` cold-transaction delta.
5. Zero payload-eviction delta.
6. Zero branch-pruning delta.

These checks reject rollback, recovery, bypass, error-only, and eviction-only
runs. Budget selection remains a QA responsibility because serialized object
sizes depend on the model and workload.

## Verification

- PowerShell parser: PASS.
- Static artifact-name check: PASS.
- Static standard-acceptance check: PASS.
- `git diff --check` on touched tracked files: PASS.
- Model-backed run: not run; this correction session excludes full model work.

## Next gate

Fresh QA reviewer must inspect Part 43, the revised driver, README, and this
correction. Full Stage 39 execution remains closed until that review passes and
the Manager records the test-plan gate.
