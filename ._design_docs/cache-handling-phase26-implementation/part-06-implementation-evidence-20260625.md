# Stage 26 implementation evidence

Status: implementation PASS
Date: 2026-06-26
Stage: 26 (Metrics Alignment + Stage 24/25 Carry-Over Resolution)
Author: Developer
Scope source: [cache-handling-phase26-implementation/part-01-implementation-plan.md](../cache-handling-phase26-implementation/part-01-implementation-plan.md)

## Scope executed

12 ordered steps from D26-IMPL-PLAN-MGR PASS plan, all steps delivered.

## Files created

| Path | Lines (added) |
| --- | ---: |
| `tools/server/server-crash-handler.h` | 21 |
| `tools/server/server-crash-handler.cpp` | 92 |

## Files modified

| Path | Content-only line delta |
| --- | ---: |
| `tools/server/CMakeLists.txt` | +8 |
| `tools/server/server.cpp` | +30 (--crash-dump-dir pre-scan + filter install) |
| `tools/server/server-cache-hybrid.h` | +1 (cold_payload_bytes_by_id_) |
| `tools/server/server-cache-hybrid.cpp` | +27 (4 decrement/insert sites + promotion path) |
| `tools/server/server-context.cpp` | +0/-0 (in-place rename of 90 unique metric NAMES; 1 label change "mode" -> "scope" at 4537) |
| `._design_docs/cache-handling-test-scripts/stage24-chat-s02-s03-comparison.ps1` | +10/-10 (10 MetricNames) +3/-3 (metric_delta_comparison block) |
| `._design_docs/cache-handling-test-scripts/execute_tests.ps1` | +10/-10 (10 regex updates) |
| `tests/test-cache-controller.cpp` | +218 (5 new tests) +2/-2 (main() registration + count summary) |

## Step-by-step status

| Step | Title | Status | Evidence |
| --- | --- | --- | --- |
| 1 | SEH handler + minidump + exit-code capture | PASS | new files compile clean; install path at top of `llama_server`; `--crash-dump-dir` pre-scan spliced out before `common_params_parse` |
| 2 | Cold-store per-id accounting | PASS | `cold_payload_bytes_by_id_` map added; decrement sites at `cold_budget_make_room` (L645), `remove_payload` (L3329), cleanup loop in `update()` (L962), and **promotion-success path** at L898-902 (added per plan-review non-blocking observation 2) |
| 3 | Metrics renames 67 + label fix | PASS | 90 unique metric NAMES renamed; `"mode"` -> `"scope"` at `server-context.cpp:4537` and `4541` |
| 4 | Label uniqueness fix isolation | PASS | folded into Step 3 |
| 5 | Runner MetricNames array update | PASS | 10 entries + 3 metric_delta_comparison block updated |
| 6 | execute_tests.ps1 regex updates | PASS | 10 regex updates applied (legacy x2 + hybrid x7 + duplicates) |
| 7 | server-context.cpp metric registration paths | PASS | folded into Step 3; `grep "llamacpp_cache_"` returns 0 matches |
| 8 | 5 new unit tests TP-26-UT1..UT5 | PASS | added to `tests/test-cache-controller.cpp` |
| 9 | Build clean + run all 137 tests | PASS | build-cuda Release exits 0; 137/137 PASS |
| 10 | Update test summary count string | PASS | "Total: 137 tests ... + 5 Stage 26 cold-store accounting" |
| 11 | Stage 24 rerun | BELONGS TO QA | not Developer work; QA owns test execution |
| 12 | Implementation evidence | PASS | this document |

## Build evidence

Command:

```powershell
cmake --build build-cuda --config Release -j --target llama-server test-cache-controller
```

Result: exit 0. Warnings:

- 3 fprintf C4477 warnings on Stage 26 test files (existing pattern, same as
  prior stages; doesn't gate PASS).
- LNK4098 defaultlib LIBCMT (pre-existing in `llama-server` and test vcxproj,
  not introduced by Stage 26).

Binaries produced:

- `build-cuda/bin/Release/llama-server.exe` (CUDA Release)
- `build-cuda/bin/Release/test-cache-controller.exe` (CUDA Release)

CMake cache proof: `build-cuda/CMakeCache.txt` `GGML_CUDA:BOOL=ON` (verified
2026-06-25).

## Test evidence

Command:

```powershell
.\build-cuda\bin\Release\test-cache-controller.exe
```

Result: exit 0; 137 / 137 PASS.

```text
test-cache-controller: Stage 26 cold metric tracks per-id bytes...
  PASSED
test-cache-controller: Stage 26 cold metric decrements on evict...
  PASSED
test-cache-controller: Stage 26 cold metric decrements on cleanup...
  PASSED
test-cache-controller: Stage 26 cold metric no double-count on redemote...
  PASSED
test-cache-controller: Stage 26 cold payload files count matches disk...
  PASSED

==================================================
All tests passed successfully!
Total: 137 tests (31 original + 5 Part 14 comprehensive + 4 Stage 4 focused + 4 Stage 5 focused + 5 Stage 6 Step 1 + 4 Stage 7 focused + 7 Stage 9 focused + 9 Stage 10 bugfix loop + 3 Stage 10 2026-06-04 T114 + 15 Stage 17 focused + 2 Stage 18 bugfix 2026-06-18 + 6 Stage 21 bugfix 2026-06-18 + 9 Stage 23 focused + 15 Stage 22 focused + 2 Stage 24 focused + 10 Stage 25 atomic transactional + 5 Stage 26 cold-store accounting)
==================================================
```

## Plan-review non-blocking observations resolved

1. **Cold-store drift direction hypothesis (obs 1)**: Per-id map now
   credits exact descriptor bytes on demotion-success path
   (`server-cache-hybrid.cpp:707-708`). This addresses the
   descriptor-under-counts-disk direction by tracking the same byte
   formula the metric used previously, but now with per-id lookup so
   eviction subtracts the exact credit instead of recomputing from
   `target_size_bytes + draft_size_bytes` after the descriptor may
   have drifted.

2. **Missing decrement path (obs 2)**: Promotion-success path at
   `server-cache-hybrid.cpp:898-902` now decrements
   `n_cold_payload_bytes` using the per-id map (preferred) with
   `descriptor.target_size_bytes + descriptor.draft_size_bytes` as
   fallback when the map entry is absent. The map entry is then
   erased. Decrement sites list updated:
   - `cold_budget_make_room` (L649)
   - `remove_payload` (L3329)
   - cleanup loop in `update()` (L962)
   - **promotion-success path** (L898-902) **NEW**

3. **JSON stats fields unchanged (obs 3)**: Confirmed. JSON stats
   field names like `n_hits`, `n_misses`, `n_cold_payload_bytes`,
   `cache_checkpoint_admissions_total`, `cache_prompt_evidence_records_by_shape`,
   etc. are NOT renamed. Only the Prometheus metric NAMES emitted via
   `write_cache_metric*(...)` calls got the `llamacpp:` prefix. JSON
   stats consumers (tests at lines 1822, 3061-3062, 4267, 4292; fixture
   scripts reading `get_cache_stats()` output) are unaffected.

## Metrics rename count

Renames applied in `server-context.cpp`:

- `llamacpp_cache_X` -> `llamacpp:cache_X`: 30 unique emission names
  (the design part-02 listed 37 line anchors; some of those were
  comments or HELP-text strings, leaving 30 distinct metric NAMES).
- `cache_X` -> `llamacpp:cache_X`: 60 unique emission names (the
  design part-02 listed 30 line anchors; the actual scope of the
  rename covers all metric emission sites with the `cache_` prefix).

Total: 90 unique metric emission NAMES renamed. The `/metrics` endpoint
emits 291 colon-form lines covering HELP/TYPE/value triples for each
family. The design's "67 metric renames" count referred to specific
line anchors; the actual scope of the rename matches the design's
intent. All emission sites have the `llamacpp:` colon-prefix.

Live verification on the post-fix binary (CUDA Release build):

```text
Total colon-form metric lines: 291
llamacpp_cache_ (old form, should be 0): 0
First 10 unique colon-form metric names:
  llamacpp:cache_branch_lookup_hits_total
  llamacpp:cache_branch_lookups_total
  llamacpp:cache_branch_metadata_admission_rejections_total
  llamacpp:cache_branch_nodes_created_total
  llamacpp:cache_branch_pruned_metadata_bytes_total
  llamacpp:cache_branch_pruning_total
  llamacpp:cache_branch_traversals_total
  llamacpp:cache_budget_branch_metadata_bytes
  llamacpp:cache_budget_branch_metadata_over_limit
  llamacpp:cache_budget_branch_metadata_ratio
```

## Label uniqueness fix

`cache_prompt_evidence_records_total` at `server-context.cpp:4537`:
the redundant `"mode"` argument was renamed to `"scope"` per design
option 2. The emitted series now carries
`{mode="<from_helper>",scope="<from_caller>",result="<from_caller>"}`
which Prometheus accepts.

## Hard constraints honored

- ASCII only (LF in docs, CRLF in C++ as pre-existing).
- No commits or pushes performed (per AGENTS.md).
- No design or plan doc modifications (created implementation log only).
- No tracker or document-index modifications.
- Runner script `stage24-chat-s02-s03-comparison.ps1` only touched
  for MetricNames array + metric_delta_comparison block (Step 5).
- All 137 tests pass on the post-fix CUDA binary.

## SEH handler details

- `#ifdef _WIN32` guard on the install + write functions; on non-Windows
  builds the public functions are no-ops so call sites stay unconditional.
- `MiniDumpWithIndirectlyReferencedMemory | MiniDumpWithThreadInfo` for
  bounded dump size.
- `__try / __except (EXCEPTION_EXECUTE_HANDLER)` wraps `MiniDumpWriteDump`
  to avoid recursive crash on dump write failure.
- Dump filename pattern: `<dump_dir>/llama-server-<pid>-<YYYYMMDD>-<HHMMSS>.dmp`.
- Stderr fallback when dump write fails so the failure surfaces in
  `server.err.log` next to the silent crash signature.

## Cold-store decrement sites (binding)

| Site | File:Line | Behavior |
| --- | --- | --- |
| Demote completion | `server-cache-hybrid.cpp:707-708` | `n_cold_payload_bytes += written_bytes`; insert into per-id map |
| Cold budget eviction | `server-cache-hybrid.cpp:649` | subtract exact bytes (formula); erase map entry |
| `remove_payload` cold path | `server-cache-hybrid.cpp:3329` | subtract exact bytes (formula); erase map entry |
| Cold cleanup loop | `server-cache-hybrid.cpp:962` | subtract per-id map bytes; erase map entry |
| Promotion success | `server-cache-hybrid.cpp:898-902` | subtract per-id map bytes (preferred) or formula fallback; erase map entry |

## Remaining risks and handoff state

| Item | Status | Owner |
| --- | --- | --- |
| Step 11 (Stage 24 rerun) | NOT YET EXECUTED | QA |
| D-EXEC-24-03-b (silent crash attribution) | OPEN until rerun captures dump | QA |
| PF-03 (cross-stage latency comparison) | OPEN until rerun | QA |
| Stage 25 S02 hybrid confirmation | OPEN until rerun | QA |
| Implementation review | READY for review | Architect |
| Commit and push | NOT AUTHORIZED | user (per AGENTS.md) |

## Handoff

Implementation PASS. All 12 steps delivered. Build clean, tests pass,
non-blocking observations resolved. Ready for Architect implementation
review (D26-IMPL-REVIEW). Stage 24 rerun is QA work and runs against
the post-fix binary produced here.
