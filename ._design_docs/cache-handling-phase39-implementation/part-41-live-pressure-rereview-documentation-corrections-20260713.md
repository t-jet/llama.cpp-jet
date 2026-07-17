# Part 41: live pressure re-review documentation corrections

Date: 2026-07-13
Status: ACCEPTED BY INDEPENDENT ARCHITECT RE-REVIEW PART 14
Scope: documentation only; no code, scripts, tests, commits, or pushes

## Review findings closed

F39-LPCR-RR-01 is corrected in design Part 11, implementation Part 39, and
test-plan Part 43. The request now carries two disjoint arrays:

- `hot_candidates` is the complete production-eligible hot pressure set. Every
  descriptor is exclusively hot.
- `cold_victims` is the complete production-eligible cold selector set. Every
  descriptor is exclusively cold.

Validation recomputes both sets independently under the cache-state lock. It
requires exact live ownership, unique payload and owner IDs within and across
the arrays, unique hot order, deterministic cold rank and payload-ID tie order,
and no missing or extra eligible row. Wrong residency fails before mutation.

TP-39-02 now creates reachable production state. Normal admissions and
`tx_save()` pressure demote two measured victims to cold while the incoming
candidate remains hot. Control verifies those complete sets, assigns equal
cold ranks, lowers positive budgets, and calls normal `tx_update()` once. The
incoming hot candidate then drives normal demotion and production cold
room-making. The seam still cannot choose an outcome or call eviction,
demotion, decision, metric, log, or accounting helpers directly.

F39-LPCR-RR-02 is corrected in implementation Part 39 and test-plan Part 43.
Part 39 now contains exact default-OFF and explicit-ON configure, build, route,
and controller commands. It also contains literal disposable fixture text and
copy-ready success and forced-failure invocations for PowerShell 7 and Windows
PowerShell 5. Each shell uses separate fresh output directories.

Success must exit 0, produce `coverage-merged.xml` and `coverage-report.md`,
and meet 80 percent. Forced merge returns 23, makes the runner exit 1, retains
capture `.cov` files, emits the fixed error, and produces neither final
artifact. All commands, logs, exits, fixture text, and output trees are kept.

## Preserved boundaries

D39-EXEC-01, one-shot consumption, admission serialization, lock order,
pre-pressure restoration, post-pressure transaction recovery, compile/runtime
isolation, loopback restriction, strict token and schema checks, redaction,
positive budgets, production ordering, topology invariants, fixed coverage
denominator and phases, server probe, 80 percent threshold, and absolute
no-argument `whoami.exe` remain unchanged.

## Handoff

Independent Architect re-review Part 14 covers design Part 11, implementation
Parts 39-41, and test-plan Part 43 against design review Parts 12-13 and records
PASS. Manager correction-plan gate is next. Code, script, test implementation,
and QA execution remain blocked until that gate authorizes the next step.
