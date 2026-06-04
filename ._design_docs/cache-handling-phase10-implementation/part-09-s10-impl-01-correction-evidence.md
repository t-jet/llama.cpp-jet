# Stage 10 S10-IMPL-01 correction evidence

Source: [../cache-handling-phase10-implementation.md](../cache-handling-phase10-implementation.md)
Correction date: 2026-06-02
Finding: S10-IMPL-01
Owner: Developer agent
Status: corrected; Architect implementation re-review PASS in Part 10

## Scope

This correction addresses only S10-IMPL-01 from Part 8. QA execution remains
closed.

The finding was that controller direct stats kept the Stage 10 dimensions, but
`write_stage10_rows()` collapsed the public Prometheus rows. Operators could not
separate promotion from demotion through `cache_payload_transitions_total`, and
`cache_exact_blob_restores_total` did not carry the R62 public dimensions claimed
in Part 7.

## Code correction

Changed files:

- `tools/server/server-context.cpp`
- `tools/server/server-context.h`
- `tests/test-step10-metrics.cpp`
- `tools/server/hybrid-cache.md`

The exporter now writes Stage 10 rows through a bounded-label helper shared by
the production metrics path and a test-only hook. The public rows keep these
dimensions:

| Metric | Public labels |
| --- | --- |
| `cache_exact_blob_restores_total` | `payload_kind`, `profile`, `pair_state`, `residency`, `result`, `reason` |
| `cache_payload_transitions_total` | `operation`, `payload_kind`, `pair_state`, `result`, `reason` |
| `cache_payload_evictions_by_shape_total` | `payload_kind`, `pair_state`, `result`, `reason` |

The controller shape maps remain unchanged. Labels still come from bounded
controller values and pass through the existing Prometheus escaping behavior,
now factored into the shared helper.

## Test correction

`tests/test-step10-metrics.cpp` now includes an exporter-level regression test.
It renders Stage 10 Prometheus rows from shaped cache stats and checks:

- exact-blob restore label names and values, including `profile` and
  `residency`;
- transition `operation` values for promotion and demotion;
- bounded payload kind, pair state, result, and reason values;
- quote and newline escaping in a reason label.

This covers the public exporter path, not only controller `get_stats()` rows.

## Evidence

Build:

- `cmake --build build --config Release --target test-step10-metrics`
  - Result: PASS.

Focused tests:

- `ctest --test-dir build -C Release -R "test-(step10-metrics|stage10-cold-store-hardening)" --output-on-failure`
  - Result: PASS, 2/2 tests.

## Handoff

S10-IMPL-01 is corrected for Developer scope and passed Architect implementation
re-review in Part 10. QA planning and QA execution remain closed.
