# Stage 38 design: cold-budget gauge fix

Source: [../cache-handling-phase38-design.md](../cache-handling-phase38-design.md)

## Problem

Stage 36 observed:

```text
cache_cold_budget_bytes{mode="hybrid"} -2147483648
```

for a 2048 MiB cold budget. The correct byte value is:

```text
2147483648
```

The runtime budget itself may still be enforced correctly. Stage 38 treats this
as an observability bug until Developer proves otherwise.

## Root-cause hypotheses to validate

Developer must trace the value through the whole emission path before changing
code:

1. Constructor conversion from `cache_cold_max_mib` to `cold_budget_bytes`.
2. JSON stats entry `cache_cold_budget_bytes`.
3. `json_value(...)` extraction in metrics emission.
4. Prometheus formatting helper type used by `write_cache_metric`.
5. Any dashboard or runner parser that narrows gauge values.

Likely cause: a signed 32-bit boundary in the stats or metric helper path.
`2048 * 1024 * 1024` equals `2147483648`, which is one above `INT32_MAX` and
wraps to `INT32_MIN` when narrowed to `int32_t`.

## Required behavior

- Positive MiB values must be converted with at least 64-bit arithmetic.
- The stats object must preserve the value without signed 32-bit narrowing.
- Prometheus gauge output must print the byte value as non-negative decimal for
  positive budgets.
- `-1` remains the unlimited sentinel unless a later approved design replaces
  it with a separate state metric.
- `0` remains "cold writes disabled" and reports `0`.
- Invalid negative values below `-1` remain startup validation failures.

## Affected path

Current code anchors at design time:

- `tools/server/server-cache-hybrid.cpp`: constructor stores
  `cold_budget_bytes`.
- `tools/server/server-cache-hybrid.cpp`: stats include
  `cache_cold_budget_bytes`.
- `tools/server/server-context.cpp`: Prometheus emission writes
  `llamacpp:cache_cold_budget_bytes`.

Implementation may touch different helper code if the narrowing happens below
these anchors. It must not change unrelated cold-byte accounting.

## Acceptance criteria

- `--cache-cold-max-mib 2048` emits:

```text
llamacpp:cache_cold_budget_bytes{mode="hybrid"} 2147483648
```

- No public scrape row for a positive cold budget emits a negative value.
- 1 MiB, 2047 MiB, 2048 MiB, 4096 MiB, `0`, and `-1` are covered in focused
  regression evidence.
- `cache_cold_bytes` and cold demotion/eviction counters keep their existing
  meaning.
- Stage 36 hit/performance behavior is not changed by this fix.

## Observability

No new metric family is required. The fixed gauge is enough. Developer should
include one focused log or stats assertion showing the internal stats value and
the public Prometheus value agree for 2048 MiB.

## Risks

| Risk | Impact | Mitigation |
| --- | --- | --- |
| Fix changes unlimited sentinel behavior | Operators lose `-1` meaning | Keep `-1` tests and do not reinterpret it in this stage |
| Helper type change affects counters | Metrics drift outside scope | Limit changes to numeric extraction/formatting needed for gauges, or add regression checks for nearby cold counters |
| Runtime budget path also overflows elsewhere | Budget enforcement still wrong | Trace constructor, budget checks, stats, and scrape before review |
