# Stage 10 implementation plan - Part 2: evidence plan and risks

Source: [../cache-handling-phase10-implementation.md](../cache-handling-phase10-implementation.md)

## Status

Planning date: 2026-06-02
Plan state: drafted.
Implementation state: closed.
QA execution state: closed.

## Focused tests

Add or extend focused tests in the existing cache test style:

- `tests/test-cache-controller.cpp` for descriptor validation, restore
  validation, marker decisions, fallback decisions, protected-root pressure, and
  workload-profile unsupported cases.
- `tests/test-step10-metrics.cpp` for Prometheus and JSON metric shape, bounded
  labels, safe values, byte gauges, latency buckets, queue pressure, and
  structured event counters if they are exported.
- `tests/test-step12-branch-graph.cpp` for branch pruning, metadata-only
  ancestors, large forests, mismatch-parent selection, and protected-root
  retention under metadata pressure.
- `tests/test-step13-stage8.cpp` for re-materialization, equivalent dedup, and
  metadata-only validation regressions.
- `tests/test-step6-demotion-protocol.cpp`,
  `tests/test-step7-promotion-protocol.cpp`, and
  `tests/test-step11-test-hooks-fault-injection.cpp` for hot/cold pressure,
  corruption, queue pressure, worker shutdown, and paired target/draft failure
  paths.
- `tools/server/tests/unit/test_cache_modes.py` for startup validation, public
  marker handling if enabled, public metrics shape, and legacy-disabled behavior.

Required focused cases:

- exact hit, checkpoint hit, fallback, restore failure, promotion, demotion,
  eviction, branch pruning, protected-root, and validation metrics use bounded
  labels only
- diagnostics omit prompt text, marker text, model paths, file paths, payload
  bytes, checksums, and serialized state
- unsafe cold-store roots fail at startup or warn according to platform support
- traversal-like payload names cannot escape the normalized cold root
- invalid cold files invalidate descriptors and fall back without live mutation
- descriptor owner, kind, version, size, checksum, residency, namespace, profile,
  pair state, and speculative identity mismatches reject before live mutation
- paired target/draft restore cannot partially apply
- repeated invalid markers are bounded in logs and metrics
- tiny hot or branch budgets produce diagnostics and safe recompute
- large branch forests use fixed tie-breaking
- worker completion order is deterministic in tests

## Public and integration evidence

Use public HTTP, logs, and `/metrics` for operator-visible behavior:

- startup validation accepts safe hybrid configuration and rejects unsafe cold
  roots or impossible budgets
- hybrid-disabled requests keep legacy cache behavior and legacy metric shape
- live `/metrics` exposes required Stage 10 hybrid metrics with bounded labels
- public request marker behavior is visible only if the implementation accepts a
  marker surface
- public completion or chat flow can prove exact-hit and checkpoint-hit metrics
  when suitable model fixtures exist
- structured logs show bounded failure reasons for fallback and unsupported
  configurations

If a model-backed checkpoint fixture is unavailable, the report must state that
gap and use focused controller, metrics-exporter, and task-flow substitute
evidence. Do not claim public checkpoint-hit evidence unless a live server
scrape proves the row.

## Benchmark measurement classification for 10-02

Each benchmark row must classify its evidence source before execution:

| Benchmark group | Measurement | Evidence source |
| --- | --- | --- |
| Exact blob hit rate | accepted exact hits | public Prometheus |
| Exact blob hit rate | rejected candidates | direct stats |
| Exact blob hit rate | fallback count | public Prometheus |
| Exact blob hit rate | prompt-processing time saved | harness-only evidence |
| Exact blob hit rate | resident bytes | public Prometheus |
| Checkpoint hit rate | accepted checkpoint hits | public Prometheus |
| Checkpoint hit rate | restore strategy | structured log |
| Checkpoint hit rate | workload profile | public Prometheus |
| Checkpoint hit rate | pair state | public Prometheus |
| Checkpoint hit rate | re-materialization count | public Prometheus |
| Checkpoint hit rate | prompt-processing time saved | harness-only evidence |
| Cold transition frequency | demotions | public Prometheus |
| Cold transition frequency | promotions | public Prometheus |
| Cold transition frequency | evictions | public Prometheus |
| Cold transition frequency | cold queue pressure | public Prometheus |
| Cold transition frequency | cold operation latency | public Prometheus |
| Cold transition frequency | fallback after promotion failure | public Prometheus |
| End-to-end savings | request latency before and after hybrid reuse | harness-only evidence |
| End-to-end savings | prompt-processing duration before and after reuse | harness-only evidence |
| End-to-end savings | fallback reason for degraded runs | structured log |
| End-to-end savings | internal restored-token accounting | direct stats |

Public Prometheus means the value is visible through `/metrics`. Structured log
means the value comes from bounded event fields in server logs. Direct stats
means a focused test reads controller or exporter state that is not public.
Harness-only evidence means the benchmark runner calculates the value from its
own timing, request sequence, or before/after comparison.

## Coverage tool and denominator for 10-01

Primary coverage tool: Clang/LLVM source-based coverage on platforms where
Clang, `llvm-profdata`, and `llvm-cov` are available for the CMake build.

Command family:

- configure a focused Debug CMake build with Clang and source coverage flags:
  `-fprofile-instr-generate -fcoverage-mapping -O0 -g`
- build the Stage 10 focused C++ test targets named in Part 1
- run the focused C++ coverage target set with `LLVM_PROFILE_FILE` pointing to a
  per-process `.profraw` pattern
- merge profiles with `llvm-profdata merge -sparse`
- report included hybrid-path files with `llvm-cov report` and, when useful for
  review, `llvm-cov show`

LLVM coverage can report line coverage and branch information for the
instrumented C++ sources. Stage 10 records both when the installed LLVM toolset
emits branch totals for the included files. The reviewed pass target is at
least 80% branch coverage for the included hybrid-mode denominator when branch
totals are available.

Reviewed fallback exception: if LLVM source-based coverage is unavailable on
the implementation platform, or if the installed LLVM toolset cannot emit stable
branch totals for the included files, Stage 10 may use line coverage as the
acceptance metric. The fallback command family is GCC/GCOV instrumentation with
LCOV or `gcovr` reporting, limited to line coverage. The implementation evidence
must state why LLVM branch coverage was unavailable, name the fallback commands,
and keep the same included and excluded file sets below.

Coverage target: at least 80% coverage for the included hybrid-mode
denominator.

The denominator includes hybrid-mode code paths in:

- hybrid mode gate and legacy-disabled checks
- exact blob save, lookup, restore, fallback, and observability
- checkpoint save, lookup, restore, fallback, and observability
- protected-root decisions and pressure handling
- payload descriptor validation
- hot and cold residency transitions
- branch pruning and metadata-only retention
- mismatch validation and re-materialization
- target/draft pair validation, promotion, demotion, restore, eviction, and
  fallback
- request marker validation if a marker surface is enabled
- metric and diagnostic emission paths required by R61-R68
- cold-store path validation and integrity failure handling
- unsupported configuration detection and safe fallback

Allowed exclusions:

- generated files
- third-party code
- legacy-only paths outside hybrid mode
- unreachable platform branches with a written reason
- public model-backed fixture paths that cannot run locally, if covered by
  focused substitute evidence and called out as a QA limit

Coverage evidence must list the included file set, excluded file set, tool,
command, percentage, and any uncovered hybrid path above risk threshold.

## Security evidence plan

Record a focused OWASP review before implementation can close. The review must
classify each item as mitigated, accepted with rationale, or not applicable:

- A01: cold-store root permissions, root containment, file ownership
  assumptions, and marker influence on protected cache state
- A03: path traversal, log injection, metric-label injection, marker parsing,
  enum parsing, and externally influenced diagnostic fields
- A04: fail-safe restore, budget exhaustion, protection abuse, descriptor owner
  checks, paired restore atomicity, and unsupported runtime combinations
- A05: unsafe cold-store paths, impractical budgets, world-writable directories,
  stale startup configuration, and metrics or logs exposing sensitive material
- A08: descriptor version, checksum, kind, pair state, cold file magic,
  staging-file handling, and cleanup ownership checks
- A09: diagnostics for integrity failures, fallback paths, unsupported
  configurations, marker rejection, cold errors, and repeated validation
  failures

Any unmitigated item that can affect correctness, confidentiality, or operator
control blocks Stage 10 closure.

## Build, test, benchmark, and coverage evidence

Expected developer evidence after implementation opens:

- clean configure and build for `llama-server`, `test-cache-controller`,
  `test-step10-metrics`, `test-step12-branch-graph`, `test-step13-stage8`,
  demotion, promotion, and fault-injection targets
- focused `ctest` run for the Stage 10 target set
- focused server Python tests for startup validation, marker handling if
  enabled, public metrics, and hybrid-disabled legacy behavior
- benchmark runner output for exact hit, checkpoint hit, cold transition, and
  end-to-end savings groups
- coverage command and report proving the denominator above
- scoped `git diff --check` for touched paths

Do not record run-specific results in this planning document. Add dated
implementation evidence parts after implementation opens.

## Known risks

| Risk | Handling |
| --- | --- |
| Metrics pass focused tests but not public `/metrics`. | Require public Prometheus evidence for operator-facing metrics and direct stats only for internal state. |
| Coverage denominator excludes real hybrid behavior. | Review included and excluded file sets before implementation starts. |
| Cold-store permission checks differ across platforms. | Use platform-specific expectations and record warn-versus-reject behavior. |
| Benchmarks depend on local model fixtures. | Record fixture identity without local paths and provide harness-only or focused substitute evidence where needed. |
| Marker validation expands the public request surface. | Keep markers disabled unless required by implementation, and review any enabled surface before code work. |
| Hardening touches legacy request flow too broadly. | Apply the minimal-intrusion rule in Part 1 and stop for review if a legacy change lacks a listed reason. |
| Operator docs drift from actual flags or metrics. | Update docs as implementation evidence and verify names against code and `/metrics`. |

## Handoff state

Implementation planning is ready for independent review. Production code, test
code, benchmark execution, coverage execution, security review execution, and QA
execution remain closed.
