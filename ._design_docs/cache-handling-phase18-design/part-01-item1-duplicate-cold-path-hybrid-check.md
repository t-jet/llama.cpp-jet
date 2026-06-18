# Part 1: Item 1 design - remove duplicate cold-path-hybrid check

Status: authored; pending Architect design review
Date: 2026-06-18
Stage: 18 (Stage 17 Closure Trivial Follow-ups)
Source: [entry doc](../cache-handling-phase18-design.md), Manager decision D17-EXEC-03

## Item 1: Remove duplicate cold-path-hybrid check (D17-EXEC-03)

### Context

The Stage 17 F-17-EXEC-01 fix moved the cache validation block from the
post-slot-init location to the top of `load_model()`. After the move, the
post-slot-init block contains a duplicate of one of the seven validation
checks. The duplicate is unreachable in practice because the moved block
already rejects the same combination before slot init runs.

Evidence: [part-06](../cache-handling-phase17-implementation/part-06-architect-bugfix-review-gate-01.md)
finding N17-BUGFIX-01 (non-blocking).

### Current state (verified)

`Select-String` against `tools/server/server-context.cpp` for the
`--cache-cold-path requires --cache-mode hybrid` text returns two matches:

- Line 1419-1420: inside the moved validation block (line 1419 SRV_ERR,
  line 1420 throw). This is the canonical, byte-identical check that runs
  BEFORE slot init.
- Line 1555-1556: inside the post-slot-init "Phase 6: Validate cold path
  configuration" block (line 1555 SRV_ERR, line 1556 throw). This is the
  unreachable duplicate.

Surrounding context at the duplicate site:

```cpp
1553            if (!params_base.cache_cold_path.empty()) {
1554                if (cache_mode_active != CACHE_MODE_HYBRID) {
1555                    SRV_ERR("%s", " - cache: --cache-cold-path requires --cache-mode hybrid\n");
1556                    throw std::runtime_error("--cache-cold-path requires --cache-mode hybrid");
1557                }
1558                SRV_INF(" - cache: cold store path: %s\n", params_base.cache_cold_path.c_str());
1559                if (params_base.cache_cold_max_mib == 0) {
1560                    SRV_INF("%s", " - cache: cold writes disabled by --cache-cold-max-mib 0\n");
1561                } else if (params_base.cache_cold_max_mib < 0) {
1562                    SRV_INF("%s", " - cache: cold budget: unlimited\n");
1563                } else {
1564                    SRV_INF(" - cache: cold budget: %d MiB\n", params_base.cache_cold_max_mib);
1565                }
1566            }
```

### Deletion scope

Delete lines 1554-1557 inclusive (the inner if-block). Specifically:

- Line 1554: `if (cache_mode_active != CACHE_MODE_HYBRID) {`
- Line 1555: `SRV_ERR(...)` (the duplicate SRV_ERR log line)
- Line 1556: `throw std::runtime_error(...)` (the duplicate throw)
- Line 1557: closing brace `}`

After deletion, the surrounding `if (!params_base.cache_cold_path.empty())`
block at line 1553 retains only the cold-path log lines (lines 1558-1565).
The block structure becomes:

```cpp
1553            if (!params_base.cache_cold_path.empty()) {
                 // moved-block already enforced cache_mode_active == CACHE_MODE_HYBRID
1558                SRV_INF(" - cache: cold store path: %s\n", params_base.cache_cold_path.c_str());
1559                if (params_base.cache_cold_max_mib == 0) {
1560                    SRV_INF("%s", " - cache: cold writes disabled by --cache-cold-max-mib 0\n");
1561                } else if (params_base.cache_cold_max_mib < 0) {
1562                    SRV_INF("%s", " - cache: cold budget: unlimited\n");
1563                } else {
1564                    SRV_INF(" - cache: cold budget: %d MiB\n", params_base.cache_cold_max_mib);
1565                }
1566            }
```

The `if (!params_base.cache_cold_path.empty())` outer guard at line 1553
stays. The cold-budget log lines (1559-1565) stay. Only the inner
duplicate validation if-block at 1554-1557 is removed.

### Behavior change analysis

Safe path (cold-path set with hybrid mode):

- Before: enters `if (!cache_cold_path.empty())`, passes the inner check,
  logs cold store path, logs cold budget.
- After: enters the same outer guard, skips the removed inner check (no-op
  because the condition was false), logs cold store path, logs cold budget.
- No behavior change. The log lines run identically.

Unsafe path (cold-path set with non-hybrid mode):

- Before: moved block at lines 1384-1428 rejects with
  `SRV_ERR("--cache-cold-path requires --cache-mode hybrid")` and
  `throw std::runtime_error(...)` BEFORE slot init. Control never reaches
  the post-slot-init block. The duplicate check at lines 1554-1557 is
  unreachable.
- After: same. The moved block rejects before slot init. The post-slot-init
  block has no duplicate check; it would not run anyway.
- No behavior change. Same bounded error, same throw, same exit code.

### Log line disposition

The duplicate `SRV_ERR` log line at line 1555 is part of the deletion. The
moved block at line 1419 produces the same log message; no log message is
lost. The `SRV_INF` log lines for cold store path (1558) and cold budget
(1559-1565) remain because they are normal-operation info logs, not
duplicate validation.

### Comment disposition

The `// Phase 6: Validate cold path configuration` comment at line 1552
becomes slightly misleading after deletion because there is no longer any
"Validate" inside the block. The design recommends updating the comment to
`// Phase 6: Cold store path configuration logs` or removing it. Removing
it is preferred because the surrounding code is self-explanatory after the
deletion. The Developer implements either choice; the choice is not a
design blocker.
